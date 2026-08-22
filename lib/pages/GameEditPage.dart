import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/GameConfig.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/models/GameType.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';
import 'package:scenickazatva_app/widgets/DeepLinkButton.dart';
import 'package:scenickazatva_app/widgets/FirebaseImage.dart';
import 'package:scenickazatva_app/widgets/admin/AdminFormSection.dart';
import 'package:scenickazatva_app/widgets/admin/AdminImagePicker.dart';

/// Admin page: edits the game meta (title, description, draw date) and
/// manages the question list.
class GameEditPage extends StatefulWidget {
  final String gameId;
  const GameEditPage({Key? key, required this.gameId}) : super(key: key);

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
            context.go('/game/${widget.gameId}');
          }
        });
      }
      final game = Provider.of<GameProvider>(context).game;
      _edited = game != null
          ? GameConfig(
              id: game.id,
              title: game.title,
              description: game.description,
              endsAt: game.endsAt,
              status: game.status,
              type: game.type,
              timeLimitSeconds: game.timeLimitSeconds,
              imageUrl: game.imageUrl,
              ctaText: game.ctaText,
              showInAds: game.showInAds,
              replayable: game.replayable,
            )
          : GameConfig(id: widget.gameId);
      _authorized = true;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1);
    final lastDate = DateTime(now.year + 3);
    var initial = _edited.endsAt ?? now;
    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(lastDate)) initial = lastDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      setState(() => _edited.endsAt = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    try {
      await Provider.of<GameProvider>(context, listen: false).saveGameMeta(_edited);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uložené')),
      );
    } catch (e) {
      AppLog.error("GameEditPage._save failed", error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba pri ukladaní: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    }
  }

  void _confirmDeleteGame() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Zmazať hru?"),
        content: const Text(
          "Naozaj chcete zmazať túto hru? Táto akcia je nevratná a vymaže všetky otázky a odpovede účastníkov.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Zrušiť"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final provider = Provider.of<GameProvider>(context, listen: false);
              await provider.deleteGame();
              if (mounted) context.go('/games');
            },
            child: const Text("Zmazať", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
          onPressed: () => context.go('/game/${widget.gameId}'),
        ),
        title: const Text("Upraviť hru"),
        actions: [
          const DeepLinkButton(),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _save,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminFormSection(
                  title: "Základné informácie",
                  children: [
                    TextFormField(
                      initialValue: _edited.title,
                      onSaved: (value) => _edited.title = value ?? "",
                      decoration: const InputDecoration(
                        labelText: "Názov hry",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? 'Prosím zadajte názov' : null,
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
                    const SizedBox(height: 16),
                    AdminImagePicker(
                      url: _edited.imageUrl,
                      label: "hlavný obrázok",
                      onChanged: (url) => setState(() => _edited.imageUrl = url),
                    ),
                  ],
                ),
                AdminFormSection(
                  title: "Nastavenia a stav",
                  children: [
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: "Dátum vyžrebovania víťaza",
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.event),
                        ),
                        child: Text(
                          _edited.endsAt != null ? DateFormat('d.M.yyyy').format(_edited.endsAt!) : "Nezadané",
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _edited.status,
                      decoration: const InputDecoration(
                        labelText: "Stav hry",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: "draft", child: Text("Koncept")),
                        DropdownMenuItem(value: "published", child: Text("Publikovaná")),
                        DropdownMenuItem(value: "ended", child: Text("Ukončená")),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _edited.status = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<GameType>(
                      initialValue: _edited.type,
                      decoration: const InputDecoration(
                        labelText: "Typ hry",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: GameType.game, child: Text("Festivalová hra")),
                        DropdownMenuItem(value: GameType.quiz, child: Text("Kvíz")),
                        DropdownMenuItem(value: GameType.form, child: Text("Formulár")),
                        DropdownMenuItem(value: GameType.live, child: Text("Živý kvíz")),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _edited.type = value);
                      },
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 8),
                      child: Text(
                        _typeDescription(_edited.type),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ),
                    if (_edited.type == GameType.live) ...[
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: _edited.timeLimitSeconds.toString(),
                        keyboardType: TextInputType.number,
                        onSaved: (value) {
                          _edited.timeLimitSeconds = int.tryParse(value ?? '') ?? 0;
                        },
                        decoration: const InputDecoration(
                          labelText: "Časový limit na otázku (sekundy)",
                          hintText: "0 = bez limitu",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
                AdminFormSection(
                  title: "Propagácia",
                  children: [
                    TextFormField(
                      initialValue: _edited.ctaText,
                      onSaved: (value) => _edited.ctaText = value ?? "",
                      decoration: const InputDecoration(
                        labelText: "Text tlačidla v reklamách",
                        hintText: "Hrať",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    CheckboxListTile(
                      value: _edited.showInAds,
                      onChanged: (value) {
                        setState(() => _edited.showInAds = value ?? true);
                      },
                      title: const Text("Zobraziť v reklamách"),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      value: _edited.replayable,
                      onChanged: (value) {
                        setState(() => _edited.replayable = value ?? true);
                      },
                      title: const Text("Hráč môže hrať opakovane"),
                      subtitle: const Text("Ak nie je zaškrtnuté, hráč uvidí po dokončení len súhrn."),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _confirmDeleteGame,
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text("Zmazať hru", style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
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
                  onPressed: () => context.go("/game/${widget.gameId}/edit/new"),
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
                leading: question.imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: FirebaseImage(
                            url: question.imageUrl,
                            fit: BoxFit.cover,
                            errorPlaceholder: Icon(
                              _typeIcon(question.type),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      )
                    : Icon(
                        _typeIcon(question.type),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                title: Text(question.title),
                subtitle: Text(
                  question.type == GameQuestionType.textarea
                      ? "Textové pole  •  Bez bodov"
                      : "${question.type.label}  •  ${question.points} b",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      context.go("/game/${widget.gameId}/edit/${question.id}");
                    } else if (value == 'delete') {
                      _confirmDelete(question);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Upraviť')),
                    PopupMenuItem(value: 'delete', child: Text('Zmazať')),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  static IconData _typeIcon(GameQuestionType type) {
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

  static String _typeDescription(GameType type) {
    switch (type) {
      case GameType.quiz:
        return "Všetky otázky naraz, odpovede sa kontrolujú až po odovzdaní.";
      case GameType.game:
        return "Otázky jedna po druhej, okamžitá spätná väzba, oprava pri zlej odpovedi.";
      case GameType.form:
        return "Všetky otázky naraz, bez kontroly odpovedí — na spätnú väzbu.";
      case GameType.live:
        return "Režisér ovláda otázky v reálnom čase, hráči vidia len aktuálnu otázku.";
    }
  }
}
