import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/providers/QuizDraftProvider.dart';
import 'package:scenickazatva_app/widgets/GameBottomBar.dart';
import 'package:scenickazatva_app/widgets/GameProgressBar.dart';
import 'package:scenickazatva_app/widgets/QuestionHeader.dart';
import 'package:scenickazatva_app/widgets/game/QuestionInput.dart';

class QuizGameView extends StatefulWidget {
  final List<GameQuestion> questions;
  final Widget header;
  final Function() onSubmit;

  const QuizGameView({
    Key? key,
    required this.questions,
    required this.header,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<QuizGameView> createState() => _QuizGameViewState();
}

class _QuizGameViewState extends State<QuizGameView> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final draft = Provider.of<QuizDraftProvider>(context);
    final total = widget.questions.length;
    final q = widget.questions[_currentIndex];
    final allAnswered = widget.questions.every((q) => draft.hasAnswer(q.id));

    return Column(
      children: [
        widget.header,
        SlideIndicator(current: _currentIndex, total: total),
        Expanded(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QuestionHeader(question: q, index: _currentIndex),
                  const SizedBox(height: 12),
                  Expanded(child: SingleChildScrollView(child: QuestionInput(question: q))),
                ],
              ),
            ),
          ),
        ),
        GameBottomBar(
          child: _currentIndex == total - 1
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_currentIndex > 0)
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _currentIndex--),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text("Predošlá otázka"),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: allAnswered ? widget.onSubmit : null,
                      icon: const Icon(Icons.send),
                      label: const Text("Odovzdať všetko"),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    if (_currentIndex > 0)
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _currentIndex--),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text("Predošlá otázka"),
                      )
                    else
                      const Spacer(),
                    const Spacer(),
                    if (_currentIndex < total - 1)
                      FilledButton.icon(
                        onPressed: () => setState(() => _currentIndex++),
                        icon: const Text("Ďalšia otázka"),
                        label: const Icon(Icons.arrow_forward, size: 18),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
