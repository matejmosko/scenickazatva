import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:scenickazatva_app/models/GameConfig.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/models/GameSubmission.dart';
import 'package:scenickazatva_app/models/GameParticipant.dart';
import 'package:scenickazatva_app/models/GameType.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/models/UserData.dart';
import 'package:scenickazatva_app/requests/ConnectivityService.dart';

/// Provider for festival games (quiz / feedback).
/// Manages multiple games per festival. Subscribes to the games list
/// and to the current user's submissions for the selected game.
class GameProvider extends ChangeNotifier {
  final Map<String, GameConfig> _games = {};
  String? _selectedGameId;
  List<GameParticipant> _participants = [];
  Map<String, GameSubmission> _submissions = {};
  bool _loading = true;
  bool _canEdit = false;
  String? _currentFestivalId;
  String _uid = "";

  StreamSubscription<DatabaseEvent>? _gamesSubscription;
  StreamSubscription<DatabaseEvent>? _submissionsSubscription;
  StreamSubscription<DatabaseEvent>? _liveStateSubscription;
  Map<String, dynamic>? _liveState;

  GameProvider();

  // ── Getters ──────────────────────────────────────────────────────────

  /// All games for the current festival.
  List<GameConfig> get games => _games.values.toList();

  /// The currently selected game (or null).
  GameConfig? get game => _selectedGameId != null ? _games[_selectedGameId] : null;

  /// Whether the festival has any games.
  bool get hasGames => _games.isNotEmpty;

  /// Convenience: whether a game is currently selected and loaded.
  bool get hasGame => game != null;

  List<GameQuestion> get questions => game?.questions ?? [];
  List<GameParticipant> get participants => _participants;
  Map<String, GameSubmission> get submissions => _submissions;
  bool get loading => _loading;

  bool get isGameClosed {
    if (game?.status == "ended") return true;
    final endsAt = game?.endsAt;
    return endsAt != null && !DateTime.now().isBefore(endsAt);
  }

  bool get isGamePlayable => game?.status == "published" && !isGameClosed;
  bool get isGameDraft => game?.status == "draft" || game == null;
  String get gameStatus => game?.status ?? "draft";

  int get answeredCount => _submissions.length;
  int get totalPoints => game?.totalPoints ?? 0;
  int get score => _submissions.values
      .where((s) => s.correct)
      .fold(0, (sum, s) => sum + s.points);

  bool isAnswered(String questionId) => _submissions.containsKey(questionId);
  GameSubmission? submissionFor(String questionId) => _submissions[questionId];

  /// Live quiz state (current question, isOpen, openedAt, etc.).
  Map<String, dynamic>? get liveState => _liveState;
  bool get isLiveActive => _liveState != null && (_liveState!['isOpen'] == true);
  String? get currentQuestionId => _liveState?['currentQuestionId']?.toString();
  String? get currentFestivalId => _currentFestivalId;

  /// Games visible to the current user (admin sees all, others see published/ended).
  List<GameConfig> get visibleGames {
    if (_canEdit) return games;
    return games.where((g) => g.status != "draft").toList();
  }

  // ── Reactivity ───────────────────────────────────────────────────────

  void updateFromUser(UserData user) {
    _canEdit = user.userRole == "admin" || user.userRole == "editor";
    if (_uid != user.id) {
      _uid = user.id;
      if (_uid.isNotEmpty && _currentFestivalId != null && _selectedGameId != null) {
        _fetchSubmissions(_currentFestivalId!, _uid, _selectedGameId!);
      }
    }
  }

  void updateFromFestival(Festival festival) {
    if (_currentFestivalId != festival.id) {
      _currentFestivalId = festival.id;
      _games.clear();
      _selectedGameId = null;
      _participants = [];
      _submissions = {};
      _fetchGames(festival.id);
    }
  }

  /// Select a specific game and fetch its submissions.
  void selectGame(String gameId) {
    if (_selectedGameId == gameId) return;
    _stopLiveStateListener();
    _selectedGameId = gameId;
    _participants = [];
    _submissions = {};
    if (_currentFestivalId != null && _uid.isNotEmpty) {
      _fetchSubmissions(_currentFestivalId!, _uid, gameId);
    }
    // Start live state listener if this is a live quiz.
    final g = _games[gameId];
    if (g != null && g.type == GameType.live && _currentFestivalId != null) {
      _listenToLiveState(_currentFestivalId!, gameId);
    }
    notifyListeners();
  }

  // ── Firebase subscriptions ───────────────────────────────────────────

  void _fetchGames(String festivalId) async {
    await _gamesSubscription?.cancel();
    await _submissionsSubscription?.cancel();
    _loading = true;
    notifyListeners();

    final gamesRef = FirebaseDatabase.instance.ref("festivals/$festivalId/games");
    if (!kIsWeb) {
      gamesRef.keepSynced(true);
    }

    _gamesSubscription = gamesRef.onValue.listen((DatabaseEvent event) {
      _games.clear();
      final Object? raw = event.snapshot.value;
      if (raw is Map) {
        raw.forEach((key, value) {
          if (value is Map) {
            final map = Map<String, dynamic>.from(value);
            final config = GameConfig.fromJson(map);
            config.id = key.toString();
            _games[config.id] = config;

            // Parse participants nested inside each game node
            final rawParticipants = map['participants'];
            if (rawParticipants is Map && config.id == _selectedGameId) {
              _participants = rawParticipants.entries.map((entry) {
                final participant = GameParticipant.fromJson(
                  Map<String, dynamic>.from(entry.value as Map),
                );
                if (participant.uid.isEmpty) {
                  participant.uid = entry.key.toString();
                }
                return participant;
              }).toList();
            }
          }
        });
      }

      // Auto-select first game if none selected
      if (_selectedGameId == null || !_games.containsKey(_selectedGameId)) {
        _selectedGameId = _games.isNotEmpty ? _games.keys.first : null;
      }

      // Refresh participants for the selected game
      if (_selectedGameId != null) {
        final selectedGame = _games[_selectedGameId];
        if (selectedGame != null) {
          // Re-parse participants from the raw data for the selected game
          if (raw is Map) {
            final gameData = raw[_selectedGameId];
            if (gameData is Map) {
              final rawParticipants = gameData['participants'];
              if (rawParticipants is Map) {
                _participants = rawParticipants.entries.map((entry) {
                  final participant = GameParticipant.fromJson(
                    Map<String, dynamic>.from(entry.value as Map),
                  );
                  if (participant.uid.isEmpty) {
                    participant.uid = entry.key.toString();
                  }
                  return participant;
                }).toList();
              } else {
                _participants = [];
              }
            }
          }
        }
      }

      // Fetch submissions for the selected game
      if (_selectedGameId != null && _uid.isNotEmpty) {
        _fetchSubmissions(festivalId, _uid, _selectedGameId!);
      }

      // Start live state listener if the selected game is live.
      if (_selectedGameId != null) {
        final g = _games[_selectedGameId];
        if (g != null && g.type == GameType.live) {
          _listenToLiveState(festivalId, _selectedGameId!);
        }
      }

      _loading = false;
      notifyListeners();
    }, onError: (err) {
      AppLog.error("Firebase Games Error", error: err);
      _loading = false;
      notifyListeners();
    });
  }

  void _fetchSubmissions(String festivalId, String uid, String gameId) async {
    await _submissionsSubscription?.cancel();
    _submissions = {};
    final subRef = FirebaseDatabase.instance.ref("users/$uid/game/$festivalId/$gameId");

    _submissionsSubscription = subRef.onValue.listen((DatabaseEvent event) {
      _submissions = {};
      final Object? raw = event.snapshot.value;
      if (raw is Map) {
        raw.forEach((key, value) {
          if (value is Map) {
            final submission =
                GameSubmission.fromJson(Map<String, dynamic>.from(value));
            if (submission.questionId.isEmpty) {
              submission.questionId = key.toString();
            }
            _submissions[key.toString()] = submission;
          }
        });
      }
      notifyListeners();
    }, onError: (err) {
      AppLog.error("Firebase Submissions Error", error: err);
    });
  }

  void _listenToLiveState(String festivalId, String gameId) async {
    await _liveStateSubscription?.cancel();
    _liveState = null;
    final ref = FirebaseDatabase.instance.ref("festivals/$festivalId/games/$gameId/liveState");

    _liveStateSubscription = ref.onValue.listen((DatabaseEvent event) {
      final Object? raw = event.snapshot.value;
      if (raw is Map) {
        _liveState = Map<String, dynamic>.from(raw);
      } else {
        _liveState = null;
      }
      notifyListeners();
    }, onError: (err) {
      AppLog.error("Firebase LiveState Error", error: err);
    });
  }

  void _stopLiveStateListener() {
    _liveStateSubscription?.cancel();
    _liveStateSubscription = null;
    _liveState = null;
  }

  // ── User actions ─────────────────────────────────────────────────────

  Future<GameSubmission?> submitAnswer(
      GameQuestion question, Map<String, dynamic> answer) async {
    final uid = _uid.isEmpty
        ? FirebaseAuth.instance.currentUser?.uid ?? ""
        : _uid;
    final gameId = _selectedGameId;
    if (_currentFestivalId == null || uid.isEmpty || gameId == null) return null;
    if (isGameClosed) return null;
    if (!question.validateAnswer(answer)) return null;

    final gameType = game?.type ?? GameType.game;
    final correct = question.checkAnswer(answer);
    final isTextarea = question.type == GameQuestionType.textarea;
    final isForm = gameType == GameType.form;
    final isLive = gameType == GameType.live;
    final submission = GameSubmission(
      questionId: question.id,
      answer: answer,
      correct: isTextarea || isForm ? false : correct,
      points: isTextarea || isForm ? 0 : (correct ? question.points : 0),
      answeredAt: DateTime.now(),
    );

    // Game type: persist only correct or textarea.
    // Quiz type: submitAnswer is not used (use submitQuizAll instead).
    // Form type: always persist.
    // Live type: always persist (no retry, speaker controls the flow).
    final shouldPersist = isForm || isTextarea || isLive || correct;
    if (shouldPersist) {
      _submissions[question.id] = submission;
      notifyListeners();

      try {
        final data = submission.toJson();
        if (isForm) data.remove('correct');
        await FirebaseDatabase.instance
            .ref("users/$uid/game/$_currentFestivalId/$gameId/${question.id}")
            .set(data);
      } catch (e) {
        AppLog.error("Firebase answer save error", error: e);
        ConnectivityService.instance.showTemporaryBanner(
            "Odpoveď sa nepodarilo uložiť — skúste znova");
      }
    }

    return submission;
  }

  /// Batch submit all answers for quiz type.
  /// Returns the list of submissions (one per question).
  Future<List<GameSubmission>> submitQuizAll(
      Map<String, GameQuestion> questions, Map<String, Map<String, dynamic>> answers) async {
    final uid = _uid.isEmpty
        ? FirebaseAuth.instance.currentUser?.uid ?? ""
        : _uid;
    final gameId = _selectedGameId;
    if (_currentFestivalId == null || uid.isEmpty || gameId == null) return [];
    if (isGameClosed) return [];

    final results = <GameSubmission>[];
    final updates = <String, dynamic>{};

    for (final entry in answers.entries) {
      final question = questions[entry.key];
      if (question == null) continue;
      if (!question.validateAnswer(entry.value)) continue;

      final correct = question.checkAnswer(entry.value);
      final submission = GameSubmission(
        questionId: entry.key,
        answer: entry.value,
        correct: correct,
        points: correct ? question.points : 0,
        answeredAt: DateTime.now(),
      );
      _submissions[entry.key] = submission;
      results.add(submission);
      updates[entry.key] = submission.toJson();
    }

    if (updates.isNotEmpty) {
      notifyListeners();
      try {
        await FirebaseDatabase.instance
            .ref("users/$uid/game/$_currentFestivalId/$gameId")
            .update(updates);
      } catch (e) {
        AppLog.error("Firebase quiz batch save error", error: e);
        ConnectivityService.instance.showTemporaryBanner(
            "Odpovede sa nepodarilo uložiť — skúste znova");
      }
    }

    return results;
  }

  /// Batch submit all answers for form type (no correctness check).
  Future<List<GameSubmission>> submitFormAll(
      Map<String, GameQuestion> questions, Map<String, Map<String, dynamic>> answers) async {
    final uid = _uid.isEmpty
        ? FirebaseAuth.instance.currentUser?.uid ?? ""
        : _uid;
    final gameId = _selectedGameId;
    if (_currentFestivalId == null || uid.isEmpty || gameId == null) return [];
    if (isGameClosed) return [];

    final results = <GameSubmission>[];
    final updates = <String, dynamic>{};

    for (final entry in answers.entries) {
      final question = questions[entry.key];
      if (question == null) continue;
      if (!question.validateAnswer(entry.value)) continue;

      final submission = GameSubmission(
        questionId: entry.key,
        answer: entry.value,
        correct: false,
        points: 0,
        answeredAt: DateTime.now(),
      );
      _submissions[entry.key] = submission;
      results.add(submission);
      final data = submission.toJson();
      data.remove('correct');
      updates[entry.key] = data;
    }

    if (updates.isNotEmpty) {
      notifyListeners();
      try {
        await FirebaseDatabase.instance
            .ref("users/$uid/game/$_currentFestivalId/$gameId")
            .update(updates);
      } catch (e) {
        AppLog.error("Firebase form batch save error", error: e);
        ConnectivityService.instance.showTemporaryBanner(
            "Odpovede sa nepodarilo uložiť — skúste znova");
      }
    }

    return results;
  }

  Future<void> setWinner(String uid, {required bool winner}) async {
    if (!_canEdit || _currentFestivalId == null || _selectedGameId == null) return;
    try {
      await FirebaseDatabase.instance
          .ref("festivals/$_currentFestivalId/games/$_selectedGameId/participants/$uid")
          .update({"winner": winner});
    } catch (e) {
      AppLog.error("Firebase setWinner error", error: e);
    }
  }

  // ── Admin CRUD ───────────────────────────────────────────────────────

  /// Creates a new game and returns its ID.
  Future<String?> createGame() async {
    if (!_canEdit || _currentFestivalId == null) return null;
    try {
      final newRef = FirebaseDatabase.instance
          .ref("festivals/$_currentFestivalId/games")
          .push();
      final config = GameConfig(
        id: newRef.key ?? "",
        title: "Nová hra",
        status: "draft",
      );
      await newRef.set(config.toJson());
      _selectedGameId = newRef.key;
      notifyListeners();
      return newRef.key;
    } catch (e) {
      AppLog.error("Firebase createGame error", error: e);
      return null;
    }
  }

  Future<void> saveGameMeta(GameConfig config) async {
    if (!_canEdit || _currentFestivalId == null || config.id.isEmpty) {
      AppLog.warn("saveGameMeta skipped: _canEdit=$_canEdit, festivalId=$_currentFestivalId, gameId=${config.id}");
      throw Exception("saveGameMeta skipped: _canEdit=$_canEdit, festivalId=$_currentFestivalId");
    }
    try {
      AppLog.info("saveGameMeta: saving to festivals/$_currentFestivalId/games/${config.id}");
      await FirebaseDatabase.instance
          .ref("festivals/$_currentFestivalId/games/${config.id}")
          .update(config.toJson());
      AppLog.info("saveGameMeta: update completed");
    } catch (e) {
      AppLog.error("saveGameMeta failed", error: e);
      ConnectivityService.instance.showTemporaryBanner(
          "Zmeny sa nepodarilo uložiť — skúste znova");
      throw Exception("saveGameMeta failed: $e");
    }
  }

  Future<String?> createQuestion(GameQuestion question) async {
    if (!_canEdit || _currentFestivalId == null || _selectedGameId == null) return null;
    try {
      final newRef = FirebaseDatabase.instance
          .ref("festivals/$_currentFestivalId/games/$_selectedGameId/questions")
          .push();
      question.id = newRef.key ?? "";
      await newRef.set(question.toJson());
      return question.id;
    } catch (e) {
      AppLog.error("Firebase createQuestion error", error: e);
      return null;
    }
  }

  Future<void> updateQuestion(GameQuestion question) async {
    if (!_canEdit || _currentFestivalId == null || _selectedGameId == null || question.id.isEmpty) return;
    try {
      await FirebaseDatabase.instance
          .ref("festivals/$_currentFestivalId/games/$_selectedGameId/questions/${question.id}")
          .update(question.toJson());
    } catch (e) {
      AppLog.error("Firebase updateQuestion error", error: e);
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    if (!_canEdit || _currentFestivalId == null || _selectedGameId == null) return;
    try {
      await FirebaseDatabase.instance
          .ref("festivals/$_currentFestivalId/games/$_selectedGameId/questions/$questionId")
          .remove();
    } catch (e) {
      AppLog.error("Firebase deleteQuestion error", error: e);
    }
  }

  Future<void> deleteGame() async {
    if (!_canEdit || _currentFestivalId == null || _selectedGameId == null) return;
    final gameId = _selectedGameId!;
    try {
      await FirebaseDatabase.instance
          .ref("festivals/$_currentFestivalId/games/$gameId")
          .remove();
      // The _gamesSubscription onValue callback will fire automatically,
      // re-populate _games (minus the deleted one), auto-select the first
      // remaining game, and call notifyListeners().
    } catch (e) {
      AppLog.error("Firebase deleteGame error", error: e);
    }
  }

  @override
  void dispose() {
    _gamesSubscription?.cancel();
    _submissionsSubscription?.cancel();
    _liveStateSubscription?.cancel();
    super.dispose();
  }
}
