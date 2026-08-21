import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:scenickazatva_app/models/GameConfig.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/models/GameType.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';

/// Speaker control panel for live quiz.
/// Writes to `festivals/{fid}/games/{gid}/liveState` in RTDB.
class LiveGameControlPage extends StatefulWidget {
  final String gameId;
  const LiveGameControlPage({Key? key, required this.gameId}) : super(key: key);

  @override
  State<LiveGameControlPage> createState() => _LiveGameControlPageState();
}

class _LiveGameControlPageState extends State<LiveGameControlPage> {
  Timer? _countdown;
  int _secondsRemaining = 0;
  bool _starting = false;
  String? _lastCountdownQuestionId;

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  void _syncCountdown(GameProvider provider) {
    final liveState = provider.liveState;
    if (liveState == null) return;
    final isOpen = liveState['isOpen'] == true;
    final currentQuestionId = liveState['currentQuestionId']?.toString();
    final openedAtStr = liveState['openedAt']?.toString();
    final game = provider.game;
    final timeLimit = (liveState['timeLimitSeconds'] ?? game?.timeLimitSeconds ?? 0) as int;

    if (!isOpen || timeLimit <= 0 || openedAtStr == null || currentQuestionId == null) {
      _countdown?.cancel();
      _countdown = null;
      _secondsRemaining = 0;
      _lastCountdownQuestionId = null;
      return;
    }

    // Only restart timer when question changes
    if (currentQuestionId == _lastCountdownQuestionId && _countdown != null) return;
    _lastCountdownQuestionId = currentQuestionId;
    _countdown?.cancel();

    final openedAt = DateTime.tryParse(openedAtStr);
    if (openedAt == null) {
      _secondsRemaining = 0;
      return;
    }

    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final sec = (timeLimit - DateTime.now().difference(openedAt).inSeconds)
          .clamp(0, timeLimit);
      setState(() => _secondsRemaining = sec);
      if (sec <= 0) timer.cancel();
    });

    // Initial tick
    final sec = (timeLimit - DateTime.now().difference(openedAt).inSeconds)
        .clamp(0, timeLimit);
    setState(() => _secondsRemaining = sec);
  }

  DatabaseReference _liveRef(GameProvider provider) {
    return FirebaseDatabase.instance.ref(
        "festivals/${provider.currentFestivalId}/games/${widget.gameId}/liveState");
  }

  Future<void> _startGame(GameProvider provider, GameConfig game) async {
    if (game.questions.isEmpty) return;
    setState(() => _starting = true);
    try {
      final firstQuestion = game.questions.first;
      await _liveRef(provider).set({
        'currentQuestionId': firstQuestion.id,
        'isOpen': true,
        'openedAt': DateTime.now().toUtc().toIso8601String(),
        'timeLimitSeconds': game.timeLimitSeconds,
      });
      Analytics().logEvent(AnalyticsEvents.liveGameStarted, parameters: {
        'questionCount': game.questions.length,
        'timeLimitSeconds': game.timeLimitSeconds.toString(),
      });
    } catch (e) {
      AppLog.error("LiveGame: start error", error: e);
    }
    if (mounted) setState(() => _starting = false);
  }

  Future<void> _nextQuestion(GameProvider provider, GameConfig game) async {
    final liveState = provider.liveState;
    final currentId = liveState?['currentQuestionId']?.toString();
    final currentIndex = game.questions.indexWhere((q) => q.id == currentId);
    final nextIndex = currentIndex + 1;

    if (nextIndex >= game.questions.length) {
      await _endGame(provider, game);
      return;
    }

    final nextQuestion = game.questions[nextIndex];
    try {
      await _liveRef(provider).update({
        'currentQuestionId': nextQuestion.id,
        'isOpen': true,
        'openedAt': DateTime.now().toUtc().toIso8601String(),
      });
      Analytics().logEvent(AnalyticsEvents.liveGameQuestionChanged, parameters: {
        'questionIndex': nextIndex.toString(),
        'questionCount': game.questions.length.toString(),
      });
    } catch (e) {
      AppLog.error("LiveGame: nextQuestion error", error: e);
    }
  }

  Future<void> _toggleOpen(GameProvider provider, bool currentOpen) async {
    try {
      await _liveRef(provider).update({'isOpen': !currentOpen});
    } catch (e) {
      AppLog.error("LiveGame: toggleOpen error", error: e);
    }
  }

  Future<void> _endGame(GameProvider provider, GameConfig game) async {
    try {
      await _liveRef(provider).update({'isOpen': false});
      final gameRef = FirebaseDatabase.instance.ref(
          "festivals/${provider.currentFestivalId}/games/${widget.gameId}");
      await gameRef.update({'status': 'ended'});
      Analytics().logEvent(AnalyticsEvents.liveGameEnded, parameters: {
        'questionCount': game.questions.length.toString(),
      });
    } catch (e) {
      AppLog.error("LiveGame: endGame error", error: e);
    }
    if (mounted) context.go('/game/${widget.gameId}/results');
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GameProvider>(context);
    final canEdit = Provider.of<UserProvider>(context).canEdit;
    final game = provider.game;

    if (game == null || game.type != GameType.live) {
      return Scaffold(
        appBar: AppBar(title: const Text("Ovládanie kvízu")),
        body: const Center(child: Text("Táto hra nie je živý kvíz.")),
      );
    }

    if (!canEdit) {
      return Scaffold(
        appBar: AppBar(title: const Text("Ovládanie kvízu")),
        body: const Center(child: Text("Prístup iba pre administrátorov.")),
      );
    }

    final liveState = provider.liveState;
    final isOpen = liveState?['isOpen'] == true;
    final currentQuestionId = liveState?['currentQuestionId']?.toString();
    final currentIndex = game.questions.indexWhere((q) => q.id == currentQuestionId);
    final started = liveState != null;

    // Sync countdown timer from live state
    _syncCountdown(provider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/game/${widget.gameId}'),
        ),
        title: Text("Ovládanie: ${game.title}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: isOpen ? Colors.green.shade50 : Colors.orange.shade50,
            child: Row(
              children: [
                Icon(
                  isOpen ? Icons.play_circle : Icons.pause_circle,
                  color: isOpen ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOpen
                        ? "OTVORENÉ — otázka ${currentIndex + 1} / ${game.questions.length}"
                        : (started ? "POZASTAVENÉ" : "NEZAČATÉ"),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOpen ? Colors.green.shade800 : Colors.orange.shade800,
                    ),
                  ),
                ),
                if (_secondsRemaining > 0)
                  Text(
                    _formatDuration(_secondsRemaining),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _secondsRemaining <= 5 ? Colors.red : Colors.grey[800],
                    ),
                  ),
              ],
            ),
          ),

          // Questions list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: game.questions.length,
              itemBuilder: (context, index) {
                final q = game.questions[index];
                final isCurrent = q.id == currentQuestionId;
                final isPast = index < currentIndex || (!isOpen && started && index <= currentIndex);
                return Card(
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primaryContainer
                      : (isPast ? Colors.grey.shade100 : null),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : (isPast ? Colors.grey : Colors.grey.shade300),
                      child: Text(
                        "${index + 1}",
                        style: TextStyle(
                          color: isCurrent ? Colors.white : (isPast ? Colors.white : Colors.grey[800]),
                        ),
                      ),
                    ),
                    title: Text(
                      q.title,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isPast ? Colors.grey : null,
                      ),
                    ),
                    subtitle: Text(
                      _questionTypeLabel(q.type),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: isCurrent
                        ? const Icon(Icons.play_arrow, color: Colors.green)
                        : (isPast ? const Icon(Icons.check, color: Colors.grey) : null),
                  ),
                );
              },
            ),
          ),

          // Control buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!started)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _starting ? null : () => _startGame(provider, game),
                        icon: _starting
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.play_arrow),
                        label: const Text("Spustiť kvíz"),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _toggleOpen(provider, isOpen),
                            icon: Icon(isOpen ? Icons.pause : Icons.play_arrow),
                            label: Text(isOpen ? "Pozastaviť" : "Otvoriť"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: currentIndex >= game.questions.length - 1 && isOpen
                                ? null
                                : () => _nextQuestion(provider, game),
                            icon: const Icon(Icons.skip_next),
                            label: Text(
                              currentIndex >= game.questions.length - 1 && isOpen
                                  ? "Ukončiť"
                                  : "Ďalšia",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmEndGame(provider, game),
                        icon: const Icon(Icons.stop, color: Colors.red),
                        label: const Text("Ukončiť hru", style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmEndGame(GameProvider provider, GameConfig game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ukončiť hru?"),
        content: const Text("Hra bude ukončená a hráči už nebudú môcť odpovedať."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Zrušiť"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _endGame(provider, game);
            },
            child: const Text("Ukončiť"),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  static String _questionTypeLabel(GameQuestionType type) {
    switch (type) {
      case GameQuestionType.text:
        return "Text";
      case GameQuestionType.abc:
        return "ABC";
      case GameQuestionType.sort:
        return "Zoradenie";
      case GameQuestionType.match:
        return "Priradenie";
      case GameQuestionType.textarea:
        return "Dlhá odpoveď";
    }
  }
}
