import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/widgets/GameBottomBar.dart';
import 'package:scenickazatva_app/widgets/QuestionHeader.dart';
import 'package:scenickazatva_app/widgets/QuestionSummaryCard.dart';
import 'package:scenickazatva_app/widgets/game/QuestionInput.dart';

class LiveGameView extends StatelessWidget {
  final Widget header;
  final bool submitting;
  final String? submittedQuestionId;
  final Function(GameQuestion q) onSubmit;

  const LiveGameView({
    Key? key,
    required this.header,
    required this.submitting,
    this.submittedQuestionId,
    required this.onSubmit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GameProvider>(context);
    final liveState = provider.liveState;

    if (liveState == null) {
      return _buildWaiting(context, provider);
    }

    final isOpen = liveState['isOpen'] == true;
    final currentQuestionId = provider.currentQuestionId;
    
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

    final alreadySubmitted = provider.isAnswered(currentQuestionId ?? '');
    final locallySubmitted = submittedQuestionId == currentQuestionId;
    final isLocked = alreadySubmitted || locallySubmitted;

    return Column(
      children: [
        header,
        Expanded(
          child: !isOpen || currentQuestion == null
              ? _buildWaiting(context, provider)
              : _buildQuestion(context, provider, currentQuestion, currentIndex, isLocked),
        ),
        if (isOpen && currentQuestion != null && !isLocked)
          _buildSubmitBar(context, currentQuestion),
      ],
    );
  }

  Widget _buildWaiting(BuildContext context, GameProvider provider) {
    final isOpen = provider.isLiveActive;
    final message = isOpen ? "Načítavam otázku..." : "Čakajte na ďalšiu otázku...";

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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic),
          ),
          if (provider.liveSecondsRemaining > 0) ...[
            const SizedBox(height: 12),
            Text(
              _formatDuration(provider.liveSecondsRemaining),
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

  Widget _buildQuestion(BuildContext context, GameProvider provider, GameQuestion question, int index, bool isLocked) {
    final remaining = provider.liveSecondsRemaining;
    final total = provider.game?.timeLimitSeconds ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (remaining > 0) ...[
          LinearProgressIndicator(
            value: total > 0 ? remaining / total : 1.0,
            backgroundColor: Colors.grey[300],
            color: remaining <= 5 ? Colors.red : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              _formatDuration(remaining),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: remaining <= 5 ? Colors.red : null,
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
                if (isLocked)
                  QuestionSummaryCard(
                    question: question,
                    submission: provider.submissionFor(question.id),
                    index: index,
                  )
                else
                  QuestionInput(question: question),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitBar(BuildContext context, GameQuestion question) {
    return GameBottomBar(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: submitting ? null : () => onSubmit(question),
          icon: submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send),
          label: const Text("Odoslať odpoveď"),
        ),
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }
}
