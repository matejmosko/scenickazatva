import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/GameConfig.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/pages/GamePage.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';

/// Admin page: edits the game meta (title, description, draw date) and
/// manages the question list.
class GameEditPage extends StatefulWidget {
  const GameEditPage({Key? key}) : super(key: key);

  @override
  State<GameEditPage> createState() => _GameEditPageState();
}

class _GameEditPageState extends State<GameEditPage> {
  final _formKey = GlobalKey<FormState>();
  late GameConfig _edited;
  bool _authorized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_authorized) {
      final canEdit = Provider.of<UserProvider>(context).canEdit;
      if (!canEdit) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/game');
          }
        });
      }
      final game = Provider.of<GameProvider>(context).game;
      _edited = game != null
          ? GameConfig(
              title: game.title,
              description: game.description,
              endsAt: game.endsAt,
            )
          : GameConfig();
      _authorized = true;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _edited.endsAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      setState(() => _edited.endsAt = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    await Provider.of<GameProvider>(context, listen: false).saveGameMeta(_edited);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uložené')),
    );
  }

  void _confirmDelete(GameQuestion question) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Zmazať otázku?"),
        content: Text("Naozaj chcete zmazať otázku „${question.title}“?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Zrušiť"),
          ),
          TextButton(
            onPressed: () {
              Provider.of<GameProvider>(context, listen: false)
                  .deleteQuestion(question.id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text("Zmazať", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GameProvider>(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/game'),
        ),
        title: const Text("Upraviť hru"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      initialValue: _edited.title,
                      onSaved: (value) => _edited.title = value ?? "",
                      decoration: const InputDecoration(
                        labelText: "Názov hry",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value == null || value.isEmpty) ? 'Prosím zadajte názov' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _edited.description,
                      onSaved: (value) => _edited.description = value ?? "",
                      maxLines: null,
                      decoration: const InputDecoration(
                        labelText: "Popis hry",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: "Dátum vyžrebovania víťaza",
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.event),
                        ),
                        child: Text(
                          _edited.endsAt != null
                              ? DateFormat('d.M.yyyy').format(_edited.endsAt!)
                              : "Nezadané",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Otázky (${provider.questions.length})",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                FilledButton.icon(
                  onPressed: () => context.go("/game/edit/new"),
                  icon: const Icon(Icons.add),
                  label: const Text("Pridať"),
                ),
              ],
            ),
          ),
          if (provider.questions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                "Zatiaľ žiadne otázky. Pridaj prvú otázku.",
                textAlign: TextAlign.center,
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          for (final question in provider.questions)
            Card(
              child: ListTile(
                leading: Icon(
                  GamePage.typeIcon(question.type),
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(question.title),
                subtitle: Text(
                  "${question.type.label}  •  ${question.points} b",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => context.go("/game/edit/${question.id}"),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(question),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
