import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/models/GameSubmission.dart';
import 'package:scenickazatva_app/models/GameType.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';
import 'package:scenickazatva_app/widgets/FirebaseImage.dart';

/// Solves a single quiz question. Renders the input UI according to the
/// question type and locks the question once the answer is submitted.
class GameQuestionPage extends StatefulWidget {
  final String gameId;
  final String questionId;
  const GameQuestionPage({Key? key, required this.gameId, required this.questionId}) : super(key: key);

  @override
  State<GameQuestionPage> createState() => _GameQuestionPageState();
}

class _GameQuestionPageState extends State<GameQuestionPage> {
  final TextEditingController _textController = TextEditingController();
  Set<int> _selectedIndexes = {};
  List<String> _sortItems = [];
  List<String> _shuffledRights = [];
  Map<String, String?> _matchSelection = {};
  bool _initialized = false;
  bool _submitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final question = _question(context);
      if (question != null) {
        _initFor(question);
      }
      _initialized = true;
    }
  }

  GameQuestion? _question(BuildContext context) {
    return Provider.of<GameProvider>(context)
        .questions
        .cast<GameQuestion?>()
        .firstWhere((q) => q?.id == widget.questionId, orElse: () => null);
  }

  void _initFor(GameQuestion question) {
    final random = Random();
    switch (question.type) {
      case GameQuestionType.sort:
        _sortItems = [...question.sortOrder]..shuffle(random);
        var attempts = 0;
        while (listEquals(_sortItems, question.sortOrder) &&
            question.sortOrder.length > 1 &&
            attempts < 10) {
          _sortItems = [...question.sortOrder]..shuffle(random);
          attempts++;
        }
        break;
      case GameQuestionType.match:
        _shuffledRights = question.pairs.map((p) => p.right).toList()..shuffle(random);
        for (final pair in question.pairs) {
          _matchSelection[pair.left] = null;
        }
        break;
      default:
        break;
    }
  }

  Map<String, dynamic>? _buildAnswer(GameQuestion question) {
    switch (question.type) {
      case GameQuestionType.text:
      case GameQuestionType.textarea:
        final text = _textController.text.trim();
        if (text.isEmpty) return null;
        return {'text': text};
      case GameQuestionType.abc:
        if (_selectedIndexes.isEmpty) return null;
        final indexes = _selectedIndexes.toList()..sort();
        return {'indexes': indexes};
      case GameQuestionType.sort:
        if (_sortItems.isEmpty) return null;
        return {'order': _sortItems};
      case GameQuestionType.match:
        final mapping = <String, String>{};
        for (final pair in question.pairs) {
          final selection = _matchSelection[pair.left];
          if (selection == null || selection.isEmpty) return null;
          mapping[pair.left] = selection;
        }
        return {'mapping': mapping};
    }
  }

  Future<void> _submit(GameQuestion question) async {
    final answer = _buildAnswer(question);
    if (answer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vyplň prosím odpoveď.")),
      );
      return;
    }

    setState(() => _submitting = true);
    final provider = Provider.of<GameProvider>(context, listen: false);
    final submission = await provider.submitAnswer(question, answer);
    if (!mounted) return;
    setState(() => _submitting = false);

    Analytics().logEvent(AnalyticsEvents.gameAnswerSubmitted, parameters: {
      AnalyticsEvents.paramQuestionId: question.id,
      AnalyticsEvents.paramCorrect: (submission?.correct ?? false).toString(),
    });
    if (submission == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Odpoveď sa nepodarilo uložiť.")),
      );
    } else if (question.type == GameQuestionType.textarea) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ďakujeme za spätnú väzbu!")),
      );
    } else if (!submission.correct) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nie, nie je to správne. Skús to znova."),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GameProvider>(context);
    final gameType = provider.game?.type ?? GameType.game;

    // Quiz/form types use inline presentation on GamePage — redirect away.
    if (gameType == GameType.quiz || gameType == GameType.form) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/game/${widget.gameId}');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final question = _question(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/game/${widget.gameId}'),
        ),
        title: Text(question?.title ?? "Otázka"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: question == null
          ? const Center(child: Text("Otázka sa nenašla."))
          : _buildBody(context, question),
    );
  }

  Widget _buildBody(BuildContext context, GameQuestion question) {
    final provider = Provider.of<GameProvider>(context);
    final submission = provider.submissionFor(question.id);
    final isTextarea = question.type == GameQuestionType.textarea;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (question.description.isNotEmpty)
          Text(
            question.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        if (question.description.isNotEmpty && question.imageUrl.isNotEmpty)
          const SizedBox(height: 8),
        if (question.imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FirebaseImage(
              url: question.imageUrl,
              fit: BoxFit.fitWidth,
              errorPlaceholder: const SizedBox.shrink(),
            ),
          ),
        const SizedBox(height: 8),
        if (!isTextarea) ...[
          Row(
            children: [
              const Icon(Icons.stars, size: 18),
              const SizedBox(width: 6),
              Text("${question.points} bodov", style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 16),
        ] else ...[
          Row(
            children: [
              const Icon(Icons.notes, size: 18),
              const SizedBox(width: 6),
              Text("Textové pole – spätná väzba", style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (submission != null)
          _buildResult(context, question, submission)
        else if (provider.isGameClosed) ...[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.lock_clock),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Hra sa skončila – odpovede už nemožno posielať.",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          _buildInput(context, question),
          buildSubmitButton(context, question),
        ],
      ],
    );
  }

  Widget _buildInput(BuildContext context, GameQuestion question) {
    switch (question.type) {
      case GameQuestionType.text:
      case GameQuestionType.textarea:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _textController,
              maxLines: null,
              minLines: question.type == GameQuestionType.textarea ? 4 : 1,
              decoration: InputDecoration(
                labelText: question.type == GameQuestionType.textarea
                    ? "Tvoja spätná väzba"
                    : "Tvoja odpoveď",
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        );
      case GameQuestionType.abc:
        return Card(
          child: Column(
            children: [
              for (var i = 0; i < question.options.length; i++)
                ListTile(
                  leading: Icon(
                    _selectedIndexes.contains(i)
                        ? Icons.check_circle
                        : (question.correctIndexes.length <= 1
                            ? Icons.radio_button_unchecked
                            : Icons.check_box_outline_blank),
                    color: _selectedIndexes.contains(i)
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(question.options[i]),
                  onTap: () {
                    setState(() {
                      if (question.correctIndexes.length <= 1) {
                        _selectedIndexes = {i};
                      } else {
                        _selectedIndexes.contains(i)
                            ? _selectedIndexes.remove(i)
                            : _selectedIndexes.add(i);
                      }
                    });
                  },
                ),
            ],
          ),
        );
      case GameQuestionType.sort:
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Zoraď správne (potiahni a pusti):",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              SizedBox(
                height: _sortItems.length * 56.0,
                child: ReorderableListView(
                  buildDefaultDragHandles: true,
                  shrinkWrap: true,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final item = _sortItems.removeAt(oldIndex);
                      _sortItems.insert(newIndex, item);
                    });
                  },
                  children: [
                    for (var i = 0; i < _sortItems.length; i++)
                      ListTile(
                        key: ValueKey('sort-item-$i'),
                        leading: const Icon(Icons.drag_handle),
                        title: Text(_sortItems[i]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      case GameQuestionType.match:
        return Card(
          child: Column(
            children: [
              for (final pair in question.pairs)
                ListTile(
                  title: Text(pair.left),
                  trailing: DropdownButton<String?>(
                    value: _matchSelection[pair.left],
                    hint: const Text("Vybrať"),
                    items: [
                      for (final right in _shuffledRights)
                        DropdownMenuItem<String?>(
                          value: right,
                          child: Text(right),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() => _matchSelection[pair.left] = value);
                    },
                  ),
                ),
            ],
          ),
        );
    }
  }

  Widget _buildResult(BuildContext context, GameQuestion question, GameSubmission submission) {
    final correct = submission.correct;
    final isTextarea = question.type == GameQuestionType.textarea;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: isTextarea
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
              : (correct ? Colors.green.shade50 : Colors.orange.shade50),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  isTextarea ? Icons.check_circle : (correct ? Icons.check_circle : Icons.cancel),
                  color: isTextarea ? Theme.of(context).colorScheme.primary : (correct ? Colors.green : Colors.orange),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTextarea ? "Ďakujeme za spätnú väzbu!" : (correct ? "Správne!" : "Nesprávne."),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (!isTextarea)
                        Text(correct ? "Získal si ${submission.points} bodov." : "Skóre sa nezmenilo."),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!isTextarea) ...[
          _buildCorrectAnswer(context, question),
          const SizedBox(height: 16),
        ],
        _buildSubmittedAnswer(context, question, submission.answer),
      ],
    );
  }

  Widget _buildCorrectAnswer(BuildContext context, GameQuestion question) {
    String text;
    switch (question.type) {
      case GameQuestionType.text:
      case GameQuestionType.textarea:
        final corrects = [question.answer, ...question.acceptableAnswers]
            .where((a) => a.isNotEmpty)
            .toSet()
            .toList();
        text = "Správna odpoveď: ${corrects.join(" / ")}";
        break;
      case GameQuestionType.abc:
        final correct = question.correctIndexes
            .map((i) => question.options[i])
            .join(", ");
        text = "Správne: $correct";
        break;
      case GameQuestionType.sort:
        text = "Správne poradie: ${question.sortOrder.join(" → ")}";
        break;
      case GameQuestionType.match:
        text = "Správne dvojice: ${question.pairs.map((p) => "${p.left} → ${p.right}").join(", ")}";
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text),
      ),
    );
  }

  Widget _buildSubmittedAnswer(BuildContext context, GameQuestion question, Map<String, dynamic> answer) {
    String text;
    switch (question.type) {
      case GameQuestionType.text:
      case GameQuestionType.textarea:
        text = "Tvoja odpoveď: ${answer['text']}";
        break;
      case GameQuestionType.abc:
        final indexes = (answer['indexes'] as List).whereType<int>().toList()..sort();
        text = "Tvoja odpoveď: ${indexes.map((i) => question.options[i]).join(", ")}";
        break;
      case GameQuestionType.sort:
        final order = (answer['order'] as List).whereType<String>().toList();
        text = "Tvoje poradie: ${order.join(" → ")}";
        break;
      case GameQuestionType.match:
        final mapping = answer['mapping'] as Map;
        text = "Tvoje dvojice: ${question.pairs.map((p) => "${p.left} → ${mapping[p.left]}").join(", ")}";
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text),
      ),
    );
  }

  Widget buildSubmitButton(BuildContext context, GameQuestion question) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: ElevatedButton.icon(
        onPressed: _submitting ? null : () => _submit(question),
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send),
        label: Text(question.type == GameQuestionType.textarea
            ? "Odoslať"
            : "Odoslať odpoveď"),
      ),
    );
  }
}
