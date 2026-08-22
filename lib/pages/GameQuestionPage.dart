import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/models/GameType.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';
import 'package:scenickazatva_app/widgets/FirebaseImage.dart';
import 'package:scenickazatva_app/widgets/QuestionSummaryCard.dart';

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
  Map<String, String?> _matchPlaced = {};
  List<String> _matchAvailable = [];
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
        _matchAvailable = question.pairs.map((p) => p.right).toList()..shuffle(random);
        for (final pair in question.pairs) {
          _matchPlaced[pair.left] = null;
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
          final placed = _matchPlaced[pair.left];
          if (placed == null || placed.isEmpty) return null;
          mapping[pair.left] = placed;
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
    final questions = provider.questions;
    final index = questions.indexWhere((q) => q.id == question.id);

    if (submission != null) {
      final nextQuestion = (index >= 0 && index < questions.length - 1) ? questions[index + 1] : null;

      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          QuestionSummaryCard(
            question: question,
            submission: submission,
            index: index >= 0 ? index : 0,
            showCorrectness: provider.game?.isForm == false,
          ),
          if (nextQuestion != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: FilledButton.icon(
                onPressed: () =>
                    context.pushReplacement("/game/${widget.gameId}/${nextQuestion.id}"),
                icon: const Text("Ďalšia otázka"),
                label: const Icon(Icons.arrow_forward, size: 18),
              ),
            ),
          const SizedBox(height: 32),
        ],
      );
    }

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
        if (!isTextarea && provider.game?.isForm == false) ...[
          Row(
            children: [
              const Icon(Icons.stars, size: 18),
              const SizedBox(width: 6),
              Text("${question.points} bodov", style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 16),
        ] else if (isTextarea) ...[
          Row(
            children: [
              const Icon(Icons.notes, size: 18),
              const SizedBox(width: 6),
              Text("Textové pole – spätná väzba", style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (provider.isGameClosed) ...[
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
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drop targets
                for (final pair in question.pairs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DragTarget<String>(
                      onAcceptWithDetails: (details) {
                        setState(() {
                          _matchPlaced[pair.left] = details.data;
                          _matchAvailable.remove(details.data);
                        });
                      },
                      builder: (context, candidateData, rejectedData) {
                        final isHovering = candidateData.isNotEmpty;
                        final currentPlaced = _matchPlaced[pair.left];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
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
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withAlpha(80)
                                : (currentPlaced != null
                                    ? Colors.green.shade50
                                    : null),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pair.left,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                ),
                              ),
                              if (currentPlaced != null)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _matchAvailable.add(currentPlaced);
                                      _matchPlaced[pair.left] = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          currentPlaced,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.close,
                                            size: 14,
                                            color: Colors.white),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  isHovering
                                      ? "Pustiť sem"
                                      : "Sem presuň odpoveď",
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
                if (_matchAvailable.isNotEmpty) ...[
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
                      for (final right in _matchAvailable)
                        Draggable<String>(
                          data: right,
                          feedback: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(right,
                                  style: const TextStyle(
                                      color: Colors.white)),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: Chip(label: Text(right)),
                          ),
                          child: Chip(
                            label: Text(right),
                            avatar:
                                const Icon(Icons.drag_indicator, size: 18),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
    }
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
