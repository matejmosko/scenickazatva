import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/models/GameType.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/providers/QuizDraftProvider.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';
import 'package:scenickazatva_app/widgets/FirebaseImage.dart';
import 'package:scenickazatva_app/widgets/QuestionSummaryCard.dart';
import 'package:scenickazatva_app/widgets/game/QuestionInput.dart';

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
  bool _initialized = false;
  bool _submitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final question = _question(context);
      if (question != null) {
        Provider.of<QuizDraftProvider>(context, listen: false).init(widget.gameId, [question]);
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

  Future<void> _submit(GameQuestion question) async {
    final draft = Provider.of<QuizDraftProvider>(context, listen: false);
    final answer = draft.buildAnswer(question);

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
      final prevQuestion = (index > 0) ? questions[index - 1] : null;

      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          QuestionSummaryCard(
            question: question,
            submission: submission,
            index: index >= 0 ? index : 0,
            showCorrectness: provider.game?.isForm == false,
          ),
          if (index == questions.length - 1) ...[
            const SizedBox(height: 16),
            if (prevQuestion != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.pushReplacement("/game/${widget.gameId}/${prevQuestion.id}"),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text("Predošlá otázka"),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: () => context.go('/game/${widget.gameId}/results'),
                icon: const Icon(Icons.emoji_events),
                label: const Text("Zobraziť výsledky"),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                children: [
                  if (prevQuestion != null)
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.pushReplacement("/game/${widget.gameId}/${prevQuestion.id}"),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text("Predošlá"),
                    ),
                  const Spacer(),
                  if (nextQuestion != null)
                    FilledButton.icon(
                      onPressed: () =>
                          context.pushReplacement("/game/${widget.gameId}/${nextQuestion.id}"),
                      label: const Icon(Icons.arrow_forward, size: 18),
                      icon: const Text("Ďalšia otázka"),
                    ),
                ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: QuestionInput(question: question),
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
