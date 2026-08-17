import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
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
        actions: const [
          DeepLinkButton(),
        ],
      ),
      body: _buildBody(context, provider),
      floatingActionButton: canEdit ? _buildAdminFab(context) : null,
    );
  }

  Widget _buildBody(BuildContext context, GameProvider provider) {
    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!provider.hasGame) {
      final canEdit = Provider.of<UserProvider>(context).canEdit;
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
    if (provider.isGameDraft && !Provider.of<UserProvider>(context).canEdit) {
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

    final questions = provider.questions;
    final answered = provider.answeredCount;
    final total = questions.length;

    return ListView(
      children: [
        _buildHeaderCard(context, provider, answered, total),
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

  Widget _buildHeaderCard(BuildContext context, GameProvider provider, int answered, int total) {
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
                onPressed: () => context.go('/game/${widget.gameId}/winners'),
                icon: const Icon(Icons.emoji_events_outlined),
                label: const Text("Kto už hru vyriešil?"),
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
        onTap: provider.isGameClosed
            ? null
            : () {
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
