import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/providers/AppSettingsProvider.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/requests/ImageUploadService.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';
import 'package:scenickazatva_app/widgets/FirebaseImage.dart';

/// Admin page: creates or edits a single quiz question, with per-type editors.
class GameQuestionEditPage extends StatefulWidget {
  final String gameId;
  final String questionId;
  const GameQuestionEditPage({Key? key, required this.gameId, required this.questionId}) : super(key: key);

  @override
  State<GameQuestionEditPage> createState() => _GameQuestionEditPageState();
}

class _GameQuestionEditPageState extends State<GameQuestionEditPage> {
  final _formKey = GlobalKey<FormState>();
  late GameQuestion _edited;
  late bool _isNew;
  bool _initialized = false;

  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _acceptableController = TextEditingController();
  final TextEditingController _sortController = TextEditingController();
  final List<TextEditingController> _optionControllers = [];
  final List<bool> _optionCorrect = [];
  final List<TextEditingController> _leftControllers = [];
  final List<TextEditingController> _rightControllers = [];
  final ImagePicker _picker = ImagePicker();
  final ImageUploadService _uploader = ImageUploadService();
  bool _uploadingImage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final canEdit = Provider.of<UserProvider>(context).canEdit;
    if (!canEdit) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/game/${widget.gameId}/edit');
        }
      });
    }

    _isNew = widget.questionId == "new";
    final provider = Provider.of<GameProvider>(context);

    if (_isNew) {
      _edited = GameQuestion(type: GameQuestionType.abc);
      for (var i = 0; i < 3; i++) {
        _optionControllers.add(TextEditingController());
        _optionCorrect.add(false);
      }
      _initialized = true;
    } else {
      final found = provider.questions
          .cast<GameQuestion?>()
          .firstWhere((q) => q?.id == widget.questionId, orElse: () => null);
      if (found != null) {
        _loadFrom(found);
        _initialized = true;
      } else if (!provider.loading) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/game/${widget.gameId}/edit');
          }
        });
      }
    }
  }

  void _loadFrom(GameQuestion question) {
    _edited = GameQuestion(
      id: question.id,
      title: question.title,
      description: question.description,
      type: question.type,
      points: question.points,
      answer: question.answer,
      acceptableAnswers: [...question.acceptableAnswers],
      options: [...question.options],
      correctIndexes: [...question.correctIndexes],
      sortOrder: [...question.sortOrder],
      pairs: question.pairs
          .map((p) => GameMatchPair(left: p.left, right: p.right))
          .toList(),
      imageUrl: question.imageUrl,
    );
    _answerController.text = question.answer;
    _acceptableController.text = question.acceptableAnswers.join('\n');
    _sortController.text = question.sortOrder.join('\n');
    for (var i = 0; i < question.options.length; i++) {
      _optionControllers.add(TextEditingController(text: question.options[i]));
      _optionCorrect.add(question.correctIndexes.contains(i));
    }
    for (final pair in question.pairs) {
      _leftControllers.add(TextEditingController(text: pair.left));
      _rightControllers.add(TextEditingController(text: pair.right));
    }
  }

  void _addAbcOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
      _optionCorrect.add(false);
    });
  }

  void _removeAbcOption(int index) {
    setState(() {
      _optionControllers.removeAt(index).dispose();
      _optionCorrect.removeAt(index);
    });
  }

  void _addMatchPair() {
    setState(() {
      _leftControllers.add(TextEditingController());
      _rightControllers.add(TextEditingController());
    });
  }

  void _removeMatchPair(int index) {
    setState(() {
      _leftControllers.removeAt(index).dispose();
      _rightControllers.removeAt(index).dispose();
    });
  }

  Future<void> _pickAndUploadImage() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      setState(() => _uploadingImage = true);
      final bytes = await picked.readAsBytes();
      final festivalId =
          Provider.of<AppSettingsProvider>(context, listen: false).defaultfestival;
      final url = await _uploader.uploadBytes(bytes, festivalId: festivalId);
      if (!mounted) return;
      if (url == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Nepodarilo sa nahrať obrázok')),
        );
        return;
      }
      setState(() => _edited.imageUrl = url);
    } catch (e) {
      AppLog.error('GameQuestionEditPage: image upload failed', error: e);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Nepodarilo sa nahrať obrázok')),
      );
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  List<String> _lines(TextEditingController controller) {
    return controller.text
        .split(RegExp(r'[\n,;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final correctIndexes = [
      for (var i = 0; i < _optionControllers.length; i++)
        if (_optionCorrect[i] && _optionControllers[i].text.trim().isNotEmpty) i,
    ];
    final pairs = [
      for (var i = 0; i < _leftControllers.length; i++)
        if (_leftControllers[i].text.trim().isNotEmpty &&
            _rightControllers[i].text.trim().isNotEmpty)
          GameMatchPair(
            left: _leftControllers[i].text.trim(),
            right: _rightControllers[i].text.trim(),
          ),
    ];

    final question = GameQuestion(
      id: _edited.id,
      title: _edited.title,
      description: _edited.description,
      type: _edited.type,
      points: _edited.points,
      answer: _answerController.text.trim(),
      acceptableAnswers: _lines(_acceptableController),
      options: options,
      correctIndexes: correctIndexes,
      sortOrder: _lines(_sortController),
      pairs: pairs,
      imageUrl: _edited.imageUrl,
    );

    final provider = Provider.of<GameProvider>(context, listen: false);
    if (_isNew) {
      await provider.createQuestion(question);
    } else {
      await provider.updateQuestion(question);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uložené')),
    );
    context.go('/game/${widget.gameId}/edit');
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/game/${widget.gameId}/edit'),
        ),
        title: Text(_isNew ? "Nová otázka" : "Upraviť otázku"),
        actions: [
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
                        labelText: "Znenie otázky",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value == null || value.isEmpty) ? 'Prosím zadajte otázku' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _edited.description,
                      onSaved: (value) => _edited.description = value ?? "",
                      maxLines: null,
                      decoration: const InputDecoration(
                        labelText: "Popis / nápoveda (voliteľné)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_edited.imageUrl.isNotEmpty)
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FirebaseImage(
                              url: _edited.imageUrl,
                              fit: BoxFit.cover,
                              errorPlaceholder: const SizedBox.shrink(),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => setState(() => _edited.imageUrl = ''),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.close, size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_edited.imageUrl.isNotEmpty) const SizedBox(height: 12),
                    if (_uploadingImage)
                      const LinearProgressIndicator()
                    else
                      OutlinedButton.icon(
                        onPressed: _pickAndUploadImage,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          _edited.imageUrl.isEmpty
                              ? 'Pridať obrázok'
                              : 'Zmeniť obrázok',
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<GameQuestionType>(
                            initialValue: _edited.type,
                            decoration: const InputDecoration(
                              labelText: "Typ otázky",
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final type in GameQuestionType.values)
                                DropdownMenuItem(
                                  value: type,
                                  child: Text(type.label),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _edited.type = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: _edited.type == GameQuestionType.textarea
                                ? "0"
                                : _edited.points.toString(),
                            keyboardType: TextInputType.number,
                            onSaved: (value) =>
                                _edited.points = int.tryParse(value ?? "") ?? 10,
                            decoration: const InputDecoration(
                              labelText: "Body",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          switch (_edited.type) {
            GameQuestionType.text => _buildTextEditor(),
            GameQuestionType.textarea => _buildTextareaEditor(),
            GameQuestionType.abc => _buildAbcEditor(context),
            GameQuestionType.sort => _buildSortEditor(),
            GameQuestionType.match => _buildMatchEditor(context),
          },
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTextEditor() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _answerController,
              decoration: const InputDecoration(
                labelText: "Správna odpoveď",
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Prosím zadajte odpoveď' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _acceptableController,
              maxLines: null,
              decoration: const InputDecoration(
                labelText: "Akceptované varianty (každá na nový riadok)",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextareaEditor() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.notes, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Textové pole – používatelia sem napíšu voľný text (spätná väzba, návrhy, komentáre).",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Body sú automaticky nastavené na 0. Odpoveď sa nekontroluje.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbcEditor(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Možnosti a správna odpoveď:",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _optionControllers.length; i++)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _optionControllers[i],
                      decoration: InputDecoration(
                        labelText: "Možnosť ${i + 1}",
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Checkbox(
                    value: _optionCorrect[i],
                    onChanged: (value) =>
                        setState(() => _optionCorrect[i] = value ?? false),
                  ),
                  Text(
                    "Správna",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _optionControllers.length > 2
                        ? () => _removeAbcOption(i)
                        : null,
                  ),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addAbcOption,
                icon: const Icon(Icons.add),
                label: const Text("Pridať možnosť"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortEditor() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextFormField(
          controller: _sortController,
          maxLines: null,
          decoration: const InputDecoration(
            labelText: "Správne poradie (zhora nadol, každá položka na nový riadok)",
            border: OutlineInputBorder(),
          ),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? 'Prosím zadajte poradie' : null,
        ),
      ),
    );
  }

  Widget _buildMatchEditor(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Dvojice (ľavé → pravé):",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _leftControllers.length; i++)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _leftControllers[i],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _rightControllers[i],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _removeMatchPair(i),
                  ),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addMatchPair,
                icon: const Icon(Icons.add),
                label: const Text("Pridať dvojicu"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _answerController.dispose();
    _acceptableController.dispose();
    _sortController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    for (final controller in _leftControllers) {
      controller.dispose();
    }
    for (final controller in _rightControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
