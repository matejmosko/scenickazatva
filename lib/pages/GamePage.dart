import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/models/GameSubmission.dart';
import 'package:scenickazatva_app/models/GameType.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';
import 'package:scenickazatva_app/widgets/DeepLinkButton.dart';
import 'package:scenickazatva_app/widgets/DraftBanner.dart';
import 'package:scenickazatva_app/widgets/GameBottomBar.dart';
import 'package:scenickazatva_app/widgets/GameInfoCard.dart';
import 'package:scenickazatva_app/widgets/GameNameField.dart';
import 'package:scenickazatva_app/widgets/GameProgressBar.dart';
import 'package:scenickazatva_app/widgets/QuestionHeader.dart';
import 'package:scenickazatva_app/widgets/QuizSummary.dart';
import 'package:scenickazatva_app/widgets/FormSummary.dart';
import 'package:scenickazatva_app/widgets/QuestionSummaryCard.dart';

/// Overview of a specific festival game: shows every question and lets the user
/// pick one to solve. Completed questions are marked in the list.
class GamePage extends StatefulWidget {
  final String gameId;
  const GamePage({Key? key, required this.gameId}) : super(key: key);

  @override
  State<GamePage> createState() => _GamePageState();

  static IconData typeIcon(GameQuestionType type) {
    switch (type) {
      case GameQuestionType.text:
        return Icons.text_fields;
      case GameQuestionType.abc:
        return Icons.radio_button_checked;
      case GameQuestionType.sort:
        return Icons.swap_vert;
      case GameQuestionType.match:
        return Icons.link;
      case GameQuestionType.textarea:
        return Icons.notes;
    }
  }
}

class _GamePageState extends State<GamePage> {
  final TextEditingController _nameController = TextEditingController();

  // Quiz/form inline state: per-question local answers
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, Set<int>> _selectedIndexes = {};
  final Map<String, List<String>> _sortItems = {};
  final Map<String, Map<String, String?>> _matchPlaced = {};
  final Map<String, List<String>> _matchAvailable = {};
  bool _submitting = false;
  bool _submitted = false;

  // Start screen state
  bool _gameStarted = false;

  // Quiz slide state
  int _quizSlideIndex = 0;

  // Live quiz state
  Timer? _liveCountdown;
  int _liveSecondsRemaining = 0;
  String? _liveSubmittedQuestionId;

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
    _liveCountdown?.cancel();
    for (final c in _textControllers.values) {
      c.dispose();
    }
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
        title: Text(provider.game?.title.isNotEmpty == true
            ? provider.game!.title
            : "Hra"),
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

    // Draft: only visible to admins/editors
    if (provider.isGameDraft && !canEdit) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "Žiadna hra momentálne nie je aktívna.",
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600]),
          ),
        ),
      );
    }

    final gameType = provider.game?.type ?? GameType.game;
    final isFinished = provider.questions.isNotEmpty && provider.answeredCount == provider.questions.length;
    final isReplayable = provider.game?.replayable ?? true;

    if (gameType == GameType.live) {
      return _buildLiveBody(context, provider);
    }

    // If already played, show summary directly
    if (isFinished || _submitted) {
      if (gameType == GameType.form) {
        return FormSummary(
          questions: provider.questions,
          submissions: provider.submissions,
          header: _buildHeaderCard(context, provider, provider.answeredCount, provider.questions.length, canEdit),
          onRestart: isReplayable ? () => _handleRestart(provider) : null,
        );
      } else if (gameType == GameType.quiz || gameType == GameType.game) {
        return QuizSummary(
          questions: provider.questions,
          submissions: provider.submissions,
          score: provider.score,
          totalPoints: provider.totalPoints,
          header: _buildHeaderCard(context, provider, provider.answeredCount, provider.questions.length, canEdit),
          onRestart: isReplayable ? () => _handleRestart(provider) : null,
        );
      }
    }

    // Start screen for game/quiz/form
    if (!_gameStarted && !provider.isGameClosed) {
      return _buildStartScreen(context, provider, gameType);
    }

    if (gameType == GameType.quiz) {
      return _buildQuizBody(context, provider);
    }
    if (gameType == GameType.form) {
      return _buildQuizFormBody(context, provider, gameType);
    }

    // Game type: tile-based one-question-per-page (existing flow)
    return _buildGameBody(context, provider);
  }

  Widget _buildGameBody(BuildContext context, GameProvider provider) {
    final questions = provider.questions;
    final answered = provider.answeredCount;
    final total = questions.length;
    final canEdit = Provider.of<UserProvider>(context).canEdit;

    return ListView(
      children: [
        _buildHeaderCard(context, provider, answered, total, canEdit),
        if (questions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              "Otázky",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Otázky pridáme čoskoro.",
              textAlign: TextAlign.center,
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ...questions.map((q) => _buildQuestionTile(context, q)),
        const SizedBox(height: 80),
      ],
    );
  }

  // ── Start screen ────────────────────────────────────────────────────

  Widget _buildStartScreen(BuildContext context, GameProvider provider, GameType gameType) {
    final game = provider.game!;
    final hasName = _nameController.text.trim().isNotEmpty;

    String buttonText;
    switch (gameType) {
      case GameType.quiz:
        buttonText = "Spustiť kvíz";
        break;
      case GameType.form:
        buttonText = "Začať formulár";
        break;
      default:
        buttonText = "Začať hru";
    }

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
                    onPressed: hasName
                        ? () => setState(() => _gameStarted = true)
                        : null,
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

  // ── Quiz: one question per slide ─────────────────────────────────────

  Widget _buildQuizBody(BuildContext context, GameProvider provider) {
    final questions = provider.questions;
    final canEdit = Provider.of<UserProvider>(context).canEdit;
    final total = questions.length;
    if (total == 0) {
      return const Center(child: Text("Žiadne otázky."));
    }

    if (_submitted) {
      return QuizSummary(
        questions: questions,
        submissions: provider.submissions,
        score: provider.score,
        totalPoints: provider.totalPoints,
        header: _buildHeaderCard(context, provider, provider.answeredCount, total, canEdit),
      );
    }

    final index = _quizSlideIndex.clamp(0, total - 1);
    final q = questions[index];
    final allAnswered = questions.every((q) =>
        provider.isAnswered(q.id) || _hasLocalAnswer(q.id));

    return Column(
      children: [
        _buildHeaderCard(context, provider, provider.answeredCount, total, canEdit),
        // Slide indicator
        SlideIndicator(current: index, total: total),
        Expanded(
          child: _buildInlineQuestion(context, q, index, provider),
        ),
        // Navigation bar
        GameBottomBar(
          child: Row(
            children: [
              if (index > 0)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _quizSlideIndex--),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text("Späť"),
                )
              else
                const Spacer(),
              const Spacer(),
              if (index < total - 1)
                FilledButton.icon(
                  onPressed: () => setState(() => _quizSlideIndex++),
                  icon: const Text("Ďalej"),
                  label: const Icon(Icons.arrow_forward, size: 18),
                )
              else
                FilledButton.icon(
                  onPressed: (_submitting || !allAnswered)
                      ? null
                      : () => _submitAll(context, provider, GameType.quiz),
                  icon: _submitting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: const Text("Odovzdať všetko"),
                ),
            ],
          ),
        ),
      ],
    );
  }

  bool _hasLocalAnswer(String questionId) {
    if (_textControllers.containsKey(questionId)) {
      return _textControllers[questionId]!.text.trim().isNotEmpty;
    }
    if (_selectedIndexes.containsKey(questionId)) {
      return _selectedIndexes[questionId]!.isNotEmpty;
    }
    if (_sortItems.containsKey(questionId)) {
      return _sortItems[questionId]!.isNotEmpty;
    }
    if (_matchPlaced.containsKey(questionId)) {
      final placed = _matchPlaced[questionId]!;
      return placed.values.every((v) => v != null);
    }
    return false;
  }

  void _ensureLocalState(GameQuestion q) {
    if (q.type == GameQuestionType.text || q.type == GameQuestionType.textarea) {
      _textControllers.putIfAbsent(q.id, () => TextEditingController());
    } else if (q.type == GameQuestionType.abc) {
      _selectedIndexes.putIfAbsent(q.id, () => {});
    } else if (q.type == GameQuestionType.sort) {
      _sortItems.putIfAbsent(q.id, () => [...q.sortOrder]);
    } else if (q.type == GameQuestionType.match) {
      _matchPlaced.putIfAbsent(q.id, () => {
        for (final pair in q.pairs) pair.left: null,
      });
      _matchAvailable.putIfAbsent(q.id, () {
        final rights = q.pairs.map((p) => p.right).toList()..shuffle();
        return rights;
      });
    }
  }

  Map<String, dynamic>? _buildAnswerForQuestion(GameQuestion q) {
    switch (q.type) {
      case GameQuestionType.text:
      case GameQuestionType.textarea:
        final controller = _textControllers[q.id];
        if (controller == null) return null;
        final text = controller.text.trim();
        if (text.isEmpty) return null;
        return {'text': text};
      case GameQuestionType.abc:
        final indexes = _selectedIndexes[q.id];
        if (indexes == null || indexes.isEmpty) return null;
        return {'indexes': indexes.toList()..sort()};
      case GameQuestionType.sort:
        final items = _sortItems[q.id];
        if (items == null || items.isEmpty) return null;
        return {'order': items};
      case GameQuestionType.match:
        final placed = _matchPlaced[q.id];
        if (placed == null) return null;
        final mapping = <String, String>{};
        for (final pair in q.pairs) {
          final value = placed[pair.left];
          if (value == null || value.isEmpty) return null;
          mapping[pair.left] = value;
        }
        return {'mapping': mapping};
    }
  }

  Future<void> _submitAll(BuildContext context, GameProvider provider, GameType gameType) async {
    setState(() => _submitting = true);

    final questionsMap = <String, GameQuestion>{};
    final answers = <String, Map<String, dynamic>>{};
    for (final q in provider.questions) {
      questionsMap[q.id] = q;
      final answer = _buildAnswerForQuestion(q);
      if (answer != null) {
        answers[q.id] = answer;
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Odpovede boli uložené.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Výsledok: $correctCount / ${results.length} správne"),
          backgroundColor: correctCount == results.length ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Widget _buildQuizFormBody(BuildContext context, GameProvider provider, GameType gameType) {
    final questions = provider.questions;
    final canEdit = Provider.of<UserProvider>(context).canEdit;
    final isForm = gameType == GameType.form;
    final isClosed = provider.isGameClosed;
    final showResult = isClosed || _submitted;

    if (showResult) {
      if (isForm) {
        return FormSummary(
          questions: questions,
          submissions: provider.submissions,
          header: _buildHeaderCard(context, provider, provider.answeredCount, questions.length, canEdit),
        );
      } else {
        return QuizSummary(
          questions: questions,
          submissions: provider.submissions,
          score: provider.score,
          totalPoints: provider.totalPoints,
          header: _buildHeaderCard(context, provider, provider.answeredCount, questions.length, canEdit),
        );
      }
    }

    final allAnswered = questions.every((q) =>
        provider.isAnswered(q.id) || _hasLocalAnswer(q.id));

    return ListView(
      children: [
        _buildHeaderCard(context, provider, provider.answeredCount, questions.length, canEdit),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            isForm ? "Formulár" : "Kvíz",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        for (var i = 0; i < questions.length; i++)
          _buildInlineQuestion(context, questions[i], i, provider),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            onPressed: (_submitting || !allAnswered)
                ? null
                : () => _submitAll(context, provider, gameType),
            icon: _submitting
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(isForm ? "Uložiť odpovede" : "Odovzdať všetko"),
          ),
        ),
        const SizedBox(height: 8),
        if (!allAnswered)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Vyplňte všetky otázky pred odovzdaním.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildInlineQuestion(BuildContext context, GameQuestion q, int index, GameProvider provider) {
    _ensureLocalState(q);
    final submission = provider.submissionFor(q.id);
    final isClosed = provider.isGameClosed;
    final showResult = isClosed || _submitted;

    if (showResult) {
      return QuestionSummaryCard(
        question: q,
        submission: submission,
        index: index,
        showCorrectness: provider.game?.isForm == false,
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            QuestionHeader(
              question: q,
              index: index,
              showPoints: provider.game?.isForm == false,
            ),
            const SizedBox(height: 12),
            _buildInlineInput(context, q),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineInput(BuildContext context, GameQuestion q) {
    switch (q.type) {
      case GameQuestionType.text:
      case GameQuestionType.textarea:
        return TextField(
          controller: _textControllers[q.id],
          maxLines: null,
          minLines: q.type == GameQuestionType.textarea ? 3 : 1,
          decoration: InputDecoration(
            hintText: q.type == GameQuestionType.textarea ? "Tvoja spätná väzba" : "Tvoja odpoveď",
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        );
      case GameQuestionType.abc:
        return Column(
          children: [
            for (var i = 0; i < q.options.length; i++)
              ListTile(
                dense: true,
                leading: Icon(
                  _selectedIndexes[q.id]?.contains(i) == true
                      ? Icons.check_circle
                      : (q.correctIndexes.length <= 1
                          ? Icons.radio_button_unchecked
                          : Icons.check_box_outline_blank),
                  color: _selectedIndexes[q.id]?.contains(i) == true
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(q.options[i], style: Theme.of(context).textTheme.bodyMedium),
                onTap: () {
                  setState(() {
                    if (q.correctIndexes.length <= 1) {
                      _selectedIndexes[q.id] = {i};
                    } else {
                      final set = _selectedIndexes[q.id] ?? {};
                      set.contains(i) ? set.remove(i) : set.add(i);
                      _selectedIndexes[q.id] = set;
                    }
                  });
                },
              ),
          ],
        );
      case GameQuestionType.sort:
        final items = _sortItems[q.id] ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Potiahni a pusti pre zoradenie:", style: Theme.of(context).textTheme.bodySmall),
            SizedBox(
              height: items.length * 48.0,
              child: ReorderableListView(
                buildDefaultDragHandles: true,
                shrinkWrap: true,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    final item = items.removeAt(oldIndex);
                    items.insert(newIndex, item);
                  });
                },
                children: [
                  for (var i = 0; i < items.length; i++)
                    ListTile(
                      key: ValueKey('sort-${q.id}-$i'),
                      dense: true,
                      leading: const Icon(Icons.drag_handle, size: 20),
                      title: Text(items[i], style: Theme.of(context).textTheme.bodyMedium),
                    ),
                ],
              ),
            ),
          ],
        );
      case GameQuestionType.match:
        final placed = _matchPlaced[q.id] ?? {};
        final available = _matchAvailable[q.id] ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drop targets
            for (final pair in q.pairs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DragTarget<String>(
                  onAcceptWithDetails: (details) {
                    setState(() {
                      placed[pair.left] = details.data;
                      available.remove(details.data);
                    });
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isHovering = candidateData.isNotEmpty;
                    final currentPlaced = placed[pair.left];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isHovering
                              ? Theme.of(context).colorScheme.primary
                              : (currentPlaced != null
                                  ? Colors.green.shade300
                                  : Colors.grey.shade400),
                          width: currentPlaced != null ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: isHovering
                            ? Theme.of(context).colorScheme.primaryContainer.withAlpha(80)
                            : (currentPlaced != null ? Colors.green.shade50 : null),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              pair.left,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (currentPlaced != null)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  available.add(currentPlaced);
                                  placed[pair.left] = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      currentPlaced,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.close, size: 14, color: Colors.white),
                                  ],
                                ),
                              ),
                            )
                          else
                            Text(
                              isHovering ? "Pustiť sem" : "Sem presuň odpoveď",
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            // Available pool
            if (available.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                "Dostupné odpovede:",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final right in available)
                    Draggable<String>(
                      data: right,
                      feedback: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(right, style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: Chip(label: Text(right)),
                      ),
                      child: Chip(
                        label: Text(right),
                        avatar: const Icon(Icons.drag_indicator, size: 18),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
    }
  }

  Widget _buildLiveBody(BuildContext context, GameProvider provider) {
    final canEdit = Provider.of<UserProvider>(context).canEdit;
    final liveState = provider.liveState;

    // No live state yet — waiting for speaker to start
    if (liveState == null) {
      final isPublished = provider.game?.status == "published";
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isPublished) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                "Čakanie na spustenie kvízu...",
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "Žiadna hra momentálne nie je aktívna.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            if (canEdit) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/game/${widget.gameId}/live'),
                icon: const Icon(Icons.play_arrow),
                label: const Text("Ovládanie kvízu"),
              ),
            ],
          ],
        ),
      );
    }

    final isOpen = liveState['isOpen'] == true;
    final currentQuestionId = liveState['currentQuestionId']?.toString();
    final openedAtStr = liveState['openedAt']?.toString();
    final timeLimit = (liveState['timeLimitSeconds'] ?? provider.game?.timeLimitSeconds ?? 0) as int;

    // Find the current question
    GameQuestion? currentQuestion;
    int currentIndex = -1;
    if (currentQuestionId != null) {
      for (var i = 0; i < provider.questions.length; i++) {
        if (provider.questions[i].id == currentQuestionId) {
          currentQuestion = provider.questions[i];
          currentIndex = i;
          break;
        }
      }
    }

    // Track whether we already submitted for this question
    final alreadySubmitted = provider.isAnswered(currentQuestionId ?? '');
    final locallySubmitted = _liveSubmittedQuestionId == currentQuestionId;

    // Manage countdown timer
    _manageLiveTimer(openedAtStr, timeLimit, currentQuestionId);

    return Column(
      children: [
        _buildHeaderCard(
          context,
          provider,
          provider.answeredCount,
          provider.questions.length,
          canEdit,
        ),
        Expanded(
          child: !isOpen || currentQuestion == null
              ? _buildLiveWaiting(context, provider)
              : _buildLiveQuestion(
                  context,
                  provider,
                  currentQuestion,
                  currentIndex,
                  alreadySubmitted || locallySubmitted,
                ),
        ),
        if (isOpen && currentQuestion != null && !alreadySubmitted && !locallySubmitted)
          _buildLiveSubmitBar(context, provider, currentQuestion),
      ],
    );
  }

  Widget _buildLiveWaiting(BuildContext context, GameProvider provider) {
    final liveState = provider.liveState;
    final isOpen = liveState?['isOpen'] == true;
    final message = isOpen
        ? "Načítavam otázku..."
        : "Čakajte na ďalšiu otázku...";

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOpen ? Icons.hourglass_top : Icons.timer_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
          if (_liveSecondsRemaining > 0) ...[
            const SizedBox(height: 12),
            Text(
              _formatDuration(_liveSecondsRemaining),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveQuestion(
      BuildContext context, GameProvider provider, GameQuestion question,
      int index, bool alreadySubmitted) {
    _ensureLocalState(question);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_liveSecondsRemaining > 0) ...[
          LinearProgressIndicator(
            value: provider.game!.timeLimitSeconds > 0
                ? _liveSecondsRemaining / provider.game!.timeLimitSeconds
                : 1.0,
            backgroundColor: Colors.grey[300],
            color: _liveSecondsRemaining <= 5 ? Colors.red : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              _formatDuration(_liveSecondsRemaining),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: _liveSecondsRemaining <= 5 ? Colors.red : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                QuestionHeader(question: question, index: index),
                const SizedBox(height: 12),
                if (alreadySubmitted) ...[
                  if (provider.submissionFor(question.id) != null)
                    QuestionSummaryCard(
                      question: question,
                      submission: provider.submissionFor(question.id)!,
                      index: index,
                    ),
                ] else
                  _buildInlineInput(context, question),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveSubmitBar(
      BuildContext context, GameProvider provider, GameQuestion question) {
    return GameBottomBar(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _submitting
              ? null
              : () => _submitLiveAnswer(context, provider, question),
          icon: _submitting
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: const Text("Odoslať odpoveď"),
        ),
      ),
    );
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
      setState(() {
        _submitted = false;
        _gameStarted = false;
        _quizSlideIndex = 0;
        // Reset local answer state
        _textControllers.clear();
        _selectedIndexes.clear();
        _sortItems.clear();
        _matchPlaced.clear();
        _matchAvailable.clear();
      });
    }
  }

  Future<void> _submitLiveAnswer(
      BuildContext context, GameProvider provider, GameQuestion question) async {
    final answer = _buildAnswerForQuestion(question);
    if (answer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vyplň prosím odpoveď.")),
      );
      return;
    }

    setState(() => _submitting = true);
    final result = await provider.submitAnswer(question, answer);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (result != null) _liveSubmittedQuestionId = question.id;
    });

    if (result != null) {
      Analytics().logEvent(AnalyticsEvents.gameAnswerSubmitted, parameters: {
        'gameType': 'live',
      });
    }
  }

  void _manageLiveTimer(String? openedAtStr, int timeLimit, String? questionId) {
    // Cancel old timer if question changed
    if (questionId != _liveSubmittedQuestionId && _liveCountdown != null) {
      // Don't cancel — let it run for the current question
    }

    if (timeLimit <= 0 || openedAtStr == null || questionId == null) {
      _liveCountdown?.cancel();
      _liveCountdown = null;
      _liveSecondsRemaining = 0;
      return;
    }

    final openedAt = DateTime.tryParse(openedAtStr);
    if (openedAt == null) {
      _liveSecondsRemaining = 0;
      return;
    }

    final elapsed = DateTime.now().difference(openedAt).inSeconds;
    final remaining = (timeLimit - elapsed).clamp(0, timeLimit);

    if (remaining != _liveSecondsRemaining) {
      setState(() => _liveSecondsRemaining = remaining);
    }

    // Start/restart timer if not already running for this question
    if (_liveCountdown == null || remaining <= 0) {
      _liveCountdown?.cancel();
      if (remaining > 0) {
        _liveCountdown = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          final now = DateTime.now();
          final sec = (timeLimit - now.difference(openedAt).inSeconds)
              .clamp(0, timeLimit);
          setState(() => _liveSecondsRemaining = sec);
          if (sec <= 0) {
            timer.cancel();
            _liveCountdown = null;
          }
        });
      }
    }
  }

  static String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
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
                  Icon(Icons.lock_clock,
                      size: 18, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Text(
                    "Hra sa skončila – odpovede už nemožno posielať.",
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
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

  Widget _buildQuestionTile(BuildContext context, GameQuestion q) {
    final provider = Provider.of<GameProvider>(context);
    final answered = provider.isAnswered(q.id);
    final submission = provider.submissionFor(q.id);
    final isTextarea = q.type == GameQuestionType.textarea;

    final IconData statusIcon;
    final Color statusColor;
    if (!answered || submission == null) {
      statusIcon = isTextarea ? Icons.notes : Icons.radio_button_unchecked;
      statusColor = Colors.grey;
    } else if (submission.correct) {
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
    } else {
      statusIcon = isTextarea ? Icons.check_circle : Icons.cancel;
      statusColor = isTextarea ? Colors.green : Colors.orange;
    }

    return Card(
      child: ListTile(
        leading: Icon(GamePage.typeIcon(q.type), color: Theme.of(context).colorScheme.primary),
        title: Text(q.title),
        subtitle: q.description.isNotEmpty
            ? Text(
                q.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (provider.game?.isForm == false)
              Text(
                isTextarea ? "Spätná väzba" : "${q.points} b",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(width: 8),
            Icon(statusIcon, color: statusColor),
          ],
        ),
        onTap: () {
                Analytics().logEvent(AnalyticsEvents.gameQuestionOpened,
                    parameters: {AnalyticsEvents.paramQuestionId: q.id});
                context.go("/game/${widget.gameId}/${q.id}");
              },
      ),
    );
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
