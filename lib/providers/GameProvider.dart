import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:scenickazatva_app/models/GameConfig.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/models/GameSubmission.dart';
import 'package:scenickazatva_app/models/GameParticipant.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/models/UserData.dart';

/// Provider for the festival game (quiz).
/// Subscribes to the festival game config + participants and to the current
/// user's submissions, and handles answer evaluation + persistence.
class GameProvider extends ChangeNotifier {
  GameConfig? _game;
  List<GameParticipant> _participants = [];
  Map<String, GameSubmission> _submissions = {};
  bool _loading = true;
  bool _canEdit = false;
  String? _currentFestivalId;
  String _uid = "";
  String _fullName = "";
  String _email = "";

  StreamSubscription<DatabaseEvent>? _gameSubscription;
  StreamSubscription<DatabaseEvent>? _submissionsSubscription;

  GameProvider();

  // Getters
  GameConfig? get game => _game;
  List<GameQuestion> get questions => _game?.questions ?? [];
  List<GameParticipant> get participants => _participants;
  Map<String, GameSubmission> get submissions => _submissions;
  bool get loading => _loading;

  /// True when the festival has a configured game node.
  bool get hasGame => _game != null;

  int get answeredCount => _submissions.length;
  int get totalPoints => _game?.totalPoints ?? 0;
  int get score => _submissions.values
      .where((s) => s.correct)
      .fold(0, (sum, s) => sum + s.points);

  bool isAnswered(String questionId) => _submissions.containsKey(questionId);
  GameSubmission? submissionFor(String questionId) => _submissions[questionId];

  /// Reacts to the logged-in user changing.
  void updateFromUser(UserData user) {
    _canEdit = user.userRole == "admin" || user.userRole == "editor";
    _fullName = user.fullName;
    _email = user.email;
    if (_uid != user.id) {
      _uid = user.id;
      if (_uid.isNotEmpty && _currentFestivalId != null) {
        _fetchSubmissions(_currentFestivalId!, _uid);
      }
    }
  }

  /// Reacts to the active festival changing.
  void updateFromFestival(Festival festival) {
    if (_currentFestivalId != festival.id) {
      _currentFestivalId = festival.id;
      _game = null;
      _participants = [];
      _submissions = {};
      _fetchGame(festival.id);
      if (_uid.isNotEmpty) {
        _fetchSubmissions(festival.id, _uid);
      }
    }
  }

  /// Subscribes to the game config and participants for a festival.
  void _fetchGame(String festivalId) async {
    await _gameSubscription?.cancel();
    _loading = true;
    notifyListeners();

    final gameRef = FirebaseDatabase.instance.ref("festivals/$festivalId/game");
    if (!kIsWeb) {
      gameRef.keepSynced(true);
    }

    _gameSubscription = gameRef.onValue.listen((DatabaseEvent event) {
      final Object? raw = event.snapshot.value;
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        _game = GameConfig.fromJson(map);

        final rawParticipants = map['participants'];
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
      } else {
        _game = null;
        _participants = [];
      }
      _loading = false;
      notifyListeners();
    }, onError: (err) {
      debugPrint("Firebase Game Error: $err");
      _loading = false;
      notifyListeners();
    });
  }

  /// Subscribes to the current user's submissions for a festival.
  void _fetchSubmissions(String festivalId, String uid) async {
    await _submissionsSubscription?.cancel();
    final subRef = FirebaseDatabase.instance.ref("users/$uid/game/$festivalId");

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
      debugPrint("Firebase Submissions Error: $err");
    });
  }

  /// Evaluates and persists a user's answer. Marks the question completed.
  Future<GameSubmission?> submitAnswer(
      GameQuestion question, Map<String, dynamic> answer) async {
    final uid = _uid.isEmpty
        ? FirebaseAuth.instance.currentUser?.uid ?? ""
        : _uid;
    if (_currentFestivalId == null || uid.isEmpty) return null;
    if (!question.validateAnswer(answer)) return null;

    final correct = question.checkAnswer(answer);
    final submission = GameSubmission(
      questionId: question.id,
      answer: answer,
      correct: correct,
      points: correct ? question.points : 0,
      answeredAt: DateTime.now(),
    );

    _submissions[question.id] = submission;
    notifyListeners();

    try {
      await FirebaseDatabase.instance
          .ref("users/$uid/game/$_currentFestivalId/${question.id}")
          .set(submission.toJson());
      await _updateParticipant(submission, uid);
    } catch (e) {
      debugPrint("Firebase answer save error: $e");
    }
    return submission;
  }

  /// (Re)writes the participant record used for winner selection.
  Future<void> _updateParticipant(GameSubmission submission, String uid) async {
    final participant = GameParticipant(
      uid: uid,
      fullName: _fullName,
      email: _email,
      score: score,
      correctCount: _submissions.values.where((s) => s.correct).length,
      answeredCount: _submissions.length,
      lastAnsweredAt: submission.answeredAt ?? DateTime.now(),
    );
    try {
      // update() preserves the `winner` flag.
      await FirebaseDatabase.instance
          .ref("festivals/$_currentFestivalId/game/participants/$uid")
          .update(participant.toJson());
    } catch (e) {
      debugPrint("Firebase participant update error: $e");
    }
  }

  /// Marks (or clears) a participant as the quiz winner (admin only).
  Future<void> setWinner(String uid, {required bool winner}) async {
    if (!_canEdit || _currentFestivalId == null) return;
    try {
      await FirebaseDatabase.instance
          .ref("festivals/$_currentFestivalId/game/participants/$uid")
          .update({"winner": winner});
    } catch (e) {
      debugPrint("Firebase setWinner error: $e");
    }
  }

  // Admin CRUD

  Future<void> saveGameMeta(GameConfig config) async {
    if (!_canEdit || _currentFestivalId == null) return;
    try {
      await FirebaseDatabase.instance
          .ref("festivals/$_currentFestivalId/game")
          .update(config.toJson());
    } catch (e) {
      debugPrint("Firebase saveGameMeta error: $e");
    }
  }

  Future<String?> createQuestion(GameQuestion question) async {
    if (!_canEdit || _currentFestivalId == null) return null;
    try {
      final newRef = FirebaseDatabase.instance
          .ref("festivals/$_currentFestivalId/game/questions")
          .push();
      question.id = newRef.key ?? "";
      await newRef.set(question.toJson());
      return question.id;
    } catch (e) {
      debugPrint("Firebase createQuestion error: $e");
      return null;
    }
  }

  Future<void> updateQuestion(GameQuestion question) async {
    if (!_canEdit || _currentFestivalId == null || question.id.isEmpty) return;
    try {
      await FirebaseDatabase.instance
          .ref("festivals/$_currentFestivalId/game/questions/${question.id}")
          .update(question.toJson());
    } catch (e) {
      debugPrint("Firebase updateQuestion error: $e");
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    if (!_canEdit || _currentFestivalId == null) return;
    try {
      await FirebaseDatabase.instance
          .ref("festivals/$_currentFestivalId/game/questions/$questionId")
          .remove();
    } catch (e) {
      debugPrint("Firebase deleteQuestion error: $e");
    }
  }

  @override
  void dispose() {
    _gameSubscription?.cancel();
    _submissionsSubscription?.cancel();
    super.dispose();
  }
}
