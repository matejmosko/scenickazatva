import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/models/GameSubmission.dart';
import 'package:scenickazatva_app/models/GameType.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';
import 'package:scenickazatva_app/widgets/DeepLinkButton.dart';
import 'package:scenickazatva_app/widgets/FirebaseImage.dart';

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
  bool _isEditingName = false;
  Timer? _debounce;

  // Quiz/form inline state: per-question local answers
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, Set<int>> _selectedIndexes = {};
  final Map<String, List<String>> _sortItems = {};
  final Map<String, Map<String, String?>> _matchSelection = {};
  bool _submitting = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      gameProvider.selectGame(widget.gameId);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      _nameController.text = userProvider.userData.fullName;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
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

    // Keep controller in sync with provider if not currently typing
    if (!_isEditingName && _nameController.text != userProvider.userData.fullName) {
      _nameController.text = userProvider.userData.fullName;
    }

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
    if (gameType == GameType.quiz || gameType == GameType.form) {
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

  Widget _buildQuizFormBody(BuildContext context, GameProvider provider, GameType gameType) {
    final questions = provider.questions;
    final canEdit = Provider.of<UserProvider>(context).canEdit;
    final isForm = gameType == GameType.form;
    final allAnswered = questions.every((q) =>
        provider.isAnswered(q.id) || _hasLocalAnswer(q.id));
    final allCorrect = provider.score == provider.totalPoints &&
        provider.totalPoints > 0;

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
        if (!provider.isGameClosed) ...[
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
        ],
        if (provider.isGameClosed && !isForm) ...[
          if (allCorrect)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Card(
                color: Colors.green,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Všetky odpovede sú správne!",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 80),
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
    if (_matchSelection.containsKey(questionId)) {
      return _matchSelection[questionId]!.values.every((v) => v != null);
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
      _matchSelection.putIfAbsent(q.id, () => {
        for (final pair in q.pairs) pair.left: null,
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
        final selection = _matchSelection[q.id];
        if (selection == null) return null;
        final mapping = <String, String>{};
        for (final pair in q.pairs) {
          final value = selection[pair.left];
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

  Widget _buildInlineQuestion(BuildContext context, GameQuestion q, int index, GameProvider provider) {
    _ensureLocalState(q);
    final submission = provider.submissionFor(q.id);
    final isTextarea = q.type == GameQuestionType.textarea;
    final isClosed = provider.isGameClosed;
    final isForm = provider.game?.type == GameType.form;
    final showResult = isClosed || _submitted;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(GamePage.typeIcon(q.type), size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${index + 1}. ${q.title}",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (!isTextarea)
                  Text("${q.points} b", style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            if (q.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(q.description, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            if (showResult && submission != null)
              _buildInlineResult(context, q, submission)
            else if (showResult && isForm && _hasLocalAnswer(q.id))
              _buildInlineSubmittedAnswer(context, q)
            else
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
        final selection = _matchSelection[q.id] ?? {};
        final shuffledRights = q.pairs.map((p) => p.right).toList()..shuffle();
        return Column(
          children: [
            for (final pair in q.pairs)
              ListTile(
                dense: true,
                title: Text(pair.left, style: Theme.of(context).textTheme.bodyMedium),
                trailing: DropdownButton<String?>(
                  value: selection[pair.left],
                  hint: const Text("Vybrať"),
                  items: [
                    for (final right in shuffledRights)
                      DropdownMenuItem<String?>(value: right, child: Text(right)),
                  ],
                  onChanged: (value) {
                    setState(() => selection[pair.left] = value);
                  },
                ),
              ),
          ],
        );
    }
  }

  Widget _buildInlineResult(BuildContext context, GameQuestion q, GameSubmission submission) {
    final correct = submission.correct;
    final isTextarea = q.type == GameQuestionType.textarea;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTextarea
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
            : (correct ? Colors.green.shade50 : Colors.orange.shade50),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isTextarea ? Icons.check_circle : (correct ? Icons.check_circle : Icons.cancel),
            color: isTextarea ? Theme.of(context).colorScheme.primary : (correct ? Colors.green : Colors.orange),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isFormData(q, submission) ? "Odpoveď uložená" : (correct ? "Správne!" : "Nesprávne."),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  bool isFormData(GameQuestion q, GameSubmission submission) {
    return q.type == GameQuestionType.textarea;
  }

  Widget _buildInlineSubmittedAnswer(BuildContext context, GameQuestion q) {
    final answer = _buildAnswerForQuestion(q);
    if (answer == null) return const SizedBox.shrink();
    String text;
    switch (q.type) {
      case GameQuestionType.text:
      case GameQuestionType.textarea:
        text = answer['text']?.toString() ?? "";
        break;
      case GameQuestionType.abc:
        final indexes = (answer['indexes'] as List).whereType<int>().toList()..sort();
        text = indexes.map((i) => q.options[i]).join(", ");
        break;
      case GameQuestionType.sort:
        text = (answer['order'] as List).whereType<String>().join(" → ");
        break;
      case GameQuestionType.match:
        final mapping = answer['mapping'] as Map;
        text = q.pairs.map((p) => "${p.left} → ${mapping[p.left]}").join(", ");
        break;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text("Tvoja odpoveď: $text", style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  Widget _buildHeaderCard(BuildContext context, GameProvider provider, int answered, int total, bool canEdit) {
    final game = provider.game!;
    final progress = total == 0 ? 0.0 : answered / total;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (provider.isGameDraft) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_note, size: 18, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Toto je koncept – vidia ho len administrátori.",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange[700]),
                      ),
                    ),
                  ],
                ),
              ),
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
            if (game.imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: FirebaseImage(
                    url: game.imageUrl,
                    fit: BoxFit.cover,
                    errorPlaceholder: const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (game.description.isNotEmpty) ...[
              Text(game.description),
              const SizedBox(height: 12),
            ],
            if (game.endsAt != null) ...[
              Row(
                children: [
                  Icon(Icons.emoji_events,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    "Vyžrebovanie víťaza: ${DateFormat('d.M.yyyy').format(game.endsAt!)}",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (!provider.isGameClosed || canEdit) ...[
              const Divider(),
              Text(
                "Tvoje meno pre hru",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: "Zadaj svoje meno...",
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                style: Theme.of(context).textTheme.bodyLarge,
                onTap: () => setState(() => _isEditingName = true),
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      Provider.of<UserProvider>(context, listen: false).updateFullName(value);
                    }
                  });
                },
                onSubmitted: (value) => setState(() => _isEditingName = false),
                onTapOutside: (_) {
                  FocusScope.of(context).unfocus();
                  setState(() => _isEditingName = false);
                },
              ),
            ],
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Zodpovedané: $answered / $total"),
                Text("Skóre: ${provider.score} / ${provider.totalPoints}"),
              ],
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
    if (!answered) {
      statusIcon = isTextarea ? Icons.notes : Icons.radio_button_unchecked;
      statusColor = Colors.grey;
    } else if (submission!.correct) {
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
