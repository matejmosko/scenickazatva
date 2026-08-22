import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/models/GameSubmission.dart';
import 'package:scenickazatva_app/models/GameType.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/providers/QuizDraftProvider.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';
import 'package:scenickazatva_app/widgets/DeepLinkButton.dart';
import 'package:scenickazatva_app/widgets/DraftBanner.dart';
import 'package:scenickazatva_app/widgets/GameInfoCard.dart';
import 'package:scenickazatva_app/widgets/GameNameField.dart';
import 'package:scenickazatva_app/widgets/GameProgressBar.dart';
import 'package:scenickazatva_app/widgets/QuizSummary.dart';
import 'package:scenickazatva_app/widgets/FormSummary.dart';
import 'package:scenickazatva_app/widgets/game/QuizGameView.dart';
import 'package:scenickazatva_app/widgets/game/FormGameView.dart';
import 'package:scenickazatva_app/widgets/game/LiveGameView.dart';
import 'package:scenickazatva_app/widgets/game/TileGameView.dart';

class GamePage extends StatefulWidget {
  final String gameId;
  const GamePage({Key? key, required this.gameId}) : super(key: key);

  @override
  State<GamePage> createState() => _GamePageState();

  static IconData typeIcon(GameQuestionType type) {
    switch (type) {
      case GameQuestionType.text: return Icons.text_fields;
      case GameQuestionType.abc: return Icons.radio_button_checked;
      case GameQuestionType.sort: return Icons.swap_vert;
      case GameQuestionType.match: return Icons.link;
      case GameQuestionType.textarea: return Icons.notes;
    }
  }
}

class _GamePageState extends State<GamePage> {
  final TextEditingController _nameController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  bool _gameStarted = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      gameProvider.selectGame(widget.gameId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = Provider.of<UserProvider>(context);
    if (_nameController.text.isEmpty && userProvider.userData.fullName.isNotEmpty) {
      _nameController.text = userProvider.userData.fullName;
    }
  }

  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GameProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final canEdit = userProvider.canEdit;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/games'),
        ),
        title: Text(provider.game?.title.isNotEmpty == true ? provider.game!.title : "Hra"),
        actions: [
          const DeepLinkButton(),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: _buildBody(context, provider),
      floatingActionButton: canEdit ? _buildAdminFab(context) : null,
    );
  }

  Widget _buildBody(BuildContext context, GameProvider provider) {
    final canEdit = Provider.of<UserProvider>(context).canEdit;
    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!provider.hasGame) {
      return _buildNoGame(context, canEdit);
    }

    if (provider.isGameDraft && !canEdit) {
      return _buildNoGame(context, false);
    }

    final gameType = provider.game?.type ?? GameType.game;
    final isFinished = provider.questions.isNotEmpty && provider.answeredCount == provider.questions.length;
    final isReplayable = provider.game?.replayable ?? true;

    if (gameType == GameType.live) {
      return LiveGameView(
        header: _buildHeaderCard(context, provider, provider.answeredCount, provider.questions.length, canEdit),
        submitting: _submitting,
        onSubmit: (q) => _submitLiveAnswer(context, provider, q),
      );
    }

    // Initialize draft state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<QuizDraftProvider>(context, listen: false).init(widget.gameId, provider.questions);
      }
    });

    if (isFinished || _submitted) {
      final header = _buildHeaderCard(context, provider, provider.answeredCount, provider.questions.length, canEdit);
      final restart = isReplayable ? () => _handleRestart(provider) : null;

      if (gameType == GameType.form) {
        return FormSummary(
          questions: provider.questions,
          submissions: provider.submissions,
          header: header,
          onRestart: restart,
        );
      } else {
        return QuizSummary(
          questions: provider.questions,
          submissions: provider.submissions,
          score: provider.score,
          totalPoints: provider.totalPoints,
          header: header,
          onRestart: restart,
        );
      }
    }

    if (!_gameStarted && !provider.isGameClosed) {
      return _buildStartScreen(context, provider, gameType);
    }

    final header = _buildHeaderCard(context, provider, provider.answeredCount, provider.questions.length, canEdit);

    switch (gameType) {
      case GameType.quiz:
        return QuizGameView(
          questions: provider.questions,
          header: header,
          onSubmit: () => _submitAll(context, provider, gameType),
        );
      case GameType.form:
        return FormGameView(
          questions: provider.questions,
          header: header,
          submitting: _submitting,
          onSubmit: () => _submitAll(context, provider, gameType),
        );
      default:
        return TileGameView(
          questions: provider.questions,
          header: header,
          gameId: widget.gameId,
        );
    }
  }

  Widget _buildNoGame(BuildContext context, bool canEdit) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Žiadna hra momentálne nie je aktívna.",
              textAlign: TextAlign.center,
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
          if (canEdit) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go('/games'),
              icon: const Icon(Icons.arrow_back),
              label: const Text("Späť na zoznam hier"),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStartScreen(BuildContext context, GameProvider provider, GameType gameType) {
    final game = provider.game!;
    final hasName = _nameController.text.trim().isNotEmpty;

    String buttonText = "Začať hru";
    if (gameType == GameType.quiz) buttonText = "Spustiť kvíz";
    if (gameType == GameType.form) buttonText = "Začať formulár";

    return ListView(
      children: [
        if (provider.isGameDraft) const DraftBanner(),
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GameInfoCard(game: game),
                const Divider(),
                GameNameField(controller: _nameController),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: hasName ? () => setState(() => _gameStarted = true) : null,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(buttonText),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                if (!hasName)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "Zadaj svoje meno pre pokračovanie.",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(BuildContext context, GameProvider provider, int answered, int total, bool canEdit) {
    final game = provider.game!;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (provider.isGameDraft) ...[
              const DraftBanner(),
              const SizedBox(height: 12),
            ],
            if (provider.isGameClosed) ...[
              Row(
                children: [
                  Icon(Icons.lock_clock, size: 18, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Text(
                    "Hra sa skončila – odpovede už nemožno posielať.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            GameInfoCard(game: game),
            if (!provider.isGameClosed || canEdit) ...[
              const Divider(),
              GameNameField(controller: _nameController),
            ],
            const SizedBox(height: 16),
            GameProgressBar(
              answered: answered,
              total: total,
              score: provider.score,
              totalPoints: provider.totalPoints,
              showScore: provider.game?.isForm == false,
            ),
            if (total > 0) ...[
              const Divider(height: 24),
              OutlinedButton.icon(
                onPressed: () => context.go('/game/${widget.gameId}/results'),
                icon: const Icon(Icons.emoji_events_outlined),
                label: const Text("Výsledky a víťaz"),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitAll(BuildContext context, GameProvider provider, GameType gameType) async {
    final draft = Provider.of<QuizDraftProvider>(context, listen: false);
    setState(() => _submitting = true);

    final questionsMap = <String, GameQuestion>{};
    final answers = <String, Map<String, dynamic>>{};
    for (final q in provider.questions) {
      questionsMap[q.id] = q;
      final answer = draft.buildAnswer(q);
      if (answer != null) answers[q.id] = answer;
    }

    List<GameSubmission> results;
    if (gameType == GameType.form) {
      results = await provider.submitFormAll(questionsMap, answers);
    } else {
      results = await provider.submitQuizAll(questionsMap, answers);
    }

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitted = true;
    });

    Analytics().logEvent(AnalyticsEvents.gameAnswerSubmitted, parameters: {
      'gameType': gameType.id,
      'questionCount': results.length,
    });

    final correctCount = results.where((s) => s.correct).length;
    if (gameType == GameType.form) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Odpovede boli uložené.")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Výsledok: $correctCount / ${results.length} správne"),
        backgroundColor: correctCount == results.length ? Colors.green : Colors.orange,
      ));
    }
  }

  Future<void> _submitLiveAnswer(BuildContext context, GameProvider provider, GameQuestion question) async {
    final draft = Provider.of<QuizDraftProvider>(context, listen: false);
    final answer = draft.buildAnswer(question);
    if (answer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vyplň prosím odpoveď.")));
      return;
    }

    setState(() => _submitting = true);
    final result = await provider.submitAnswer(question, answer);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result != null) {
      Analytics().logEvent(AnalyticsEvents.gameAnswerSubmitted, parameters: {'gameType': 'live'});
    }
  }

  Future<void> _handleRestart(GameProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Spustiť znova?"),
        content: const Text("Tvoje doterajšie odpovede budú vymazané a môžeš začať odznova."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Zrušiť")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Áno, spustiť znova")),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.restartGame();
      Provider.of<QuizDraftProvider>(context, listen: false).clear();
      setState(() {
        _submitted = false;
        _gameStarted = false;
      });
    }
  }

  Widget _buildAdminFab(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text("Upraviť hru"),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go("/game/${widget.gameId}/edit");
                },
              ),
              ListTile(
                leading: const Icon(Icons.emoji_events),
                title: const Text("Výsledky a víťaz"),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go("/game/${widget.gameId}/results");
                },
              ),
            ],
          ),
        ),
      ),
      child: const Icon(Icons.more_vert),
    );
  }
}
