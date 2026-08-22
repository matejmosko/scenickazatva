import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/providers/QuizDraftProvider.dart';

/// Unified input widget for all question types (ABC, Sort, Match, Text).
/// Uses QuizDraftProvider for state persistence.
class QuestionInput extends StatelessWidget {
  final GameQuestion question;

  const QuestionInput({
    Key? key,
    required this.question,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final draft = Provider.of<QuizDraftProvider>(context);

    switch (question.type) {
      case GameQuestionType.text:
      case GameQuestionType.textarea:
        return _buildTextInput(context, draft);
      case GameQuestionType.abc:
        return _buildAbcInput(context, draft);
      case GameQuestionType.sort:
        return _buildSortInput(context, draft);
      case GameQuestionType.match:
        return _buildMatchInput(context, draft);
    }
  }

  Widget _buildTextInput(BuildContext context, QuizDraftProvider draft) {
    final controller = draft.getTextController(question.id);
    return TextField(
      controller: controller,
      maxLines: null,
      minLines: question.type == GameQuestionType.textarea ? 3 : 1,
      decoration: InputDecoration(
        hintText: question.type == GameQuestionType.textarea 
            ? "Tvoja spätná väzba" 
            : "Tvoja odpoveď",
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (_) => draft.notify(), // Trigger validation in parent if needed
    );
  }

  Widget _buildAbcInput(BuildContext context, QuizDraftProvider draft) {
    final selected = draft.getSelectedIndexes(question.id);
    return Column(
      children: [
        for (var i = 0; i < question.options.length; i++)
          ListTile(
            dense: true,
            leading: Icon(
              selected.contains(i)
                  ? Icons.check_circle
                  : (question.correctIndexes.length <= 1
                      ? Icons.radio_button_unchecked
                      : Icons.check_box_outline_blank),
              color: selected.contains(i)
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            title: Text(question.options[i], style: Theme.of(context).textTheme.bodyMedium),
            onTap: () {
              final newSet = Set<int>.from(selected);
              if (question.correctIndexes.length <= 1) {
                newSet.clear();
                newSet.add(i);
              } else {
                newSet.contains(i) ? newSet.remove(i) : newSet.add(i);
              }
              draft.setSelectedIndexes(question.id, newSet);
            },
          ),
      ],
    );
  }

  Widget _buildSortInput(BuildContext context, QuizDraftProvider draft) {
    final items = draft.getSortItems(question.id);
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
              final newList = List<String>.from(items);
              final item = newList.removeAt(oldIndex);
              newList.insert(newIndex, item);
              draft.setSortItems(question.id, newList);
            },
            children: [
              for (var i = 0; i < items.length; i++)
                ListTile(
                  key: ValueKey('sort-${question.id}-$i'),
                  dense: true,
                  leading: const Icon(Icons.drag_handle, size: 20),
                  title: Text(items[i], style: Theme.of(context).textTheme.bodyMedium),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchInput(BuildContext context, QuizDraftProvider draft) {
    final placed = draft.getMatchPlaced(question.id);
    final available = draft.getMatchAvailable(question.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final pair in question.pairs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DragTarget<String>(
              onAcceptWithDetails: (details) {
                final newPlaced = Map<String, String?>.from(placed);
                final newAvailable = List<String>.from(available);
                newPlaced[pair.left] = details.data;
                newAvailable.remove(details.data);
                draft.setMatchState(question.id, newPlaced, newAvailable);
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
                          : (currentPlaced != null ? Colors.green.shade300 : Colors.grey.shade400),
                      width: currentPlaced != null ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isHovering
                        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : (currentPlaced != null ? Colors.green.shade50 : null),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          pair.left,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (currentPlaced != null)
                        GestureDetector(
                          onTap: () {
                            final newPlaced = Map<String, String?>.from(placed);
                            final newAvailable = List<String>.from(available);
                            newAvailable.add(currentPlaced);
                            newPlaced[pair.left] = null;
                            draft.setMatchState(question.id, newPlaced, newAvailable);
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
        if (available.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            "Dostupné odpovede:",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
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
