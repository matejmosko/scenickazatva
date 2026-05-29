import 'package:flutter/material.dart';
import 'package:scenickazatva_app/models/InfoPost.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/providers/InfoProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:firebase_cached_image/firebase_cached_image.dart';

/// Page for managing festival-specific information posts.
/// Only accessible by users with editing privileges.
class InfoEditPage extends StatefulWidget {
  final String infoId;
  const InfoEditPage({Key? key, required this.infoId}) : super(key: key);

  @override
  InfoEditPageState createState() => InfoEditPageState();
}

class InfoEditPageState extends State<InfoEditPage> {
  final _formKey = GlobalKey<FormState>();
  late InfoPost edited;
  late QuillController _controller;
  bool _isInitialized = false;
  bool _isNew = false;

  @override
  void initState() {
    super.initState();
    _controller = QuillController.basic();
    _isNew = widget.infoId == "new";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      // 1. Authorization guard
      final userProvider = Provider.of<UserProvider>(context);
      if (!userProvider.canEdit) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/info');
          }
        });
        return;
      }

      // 2. Data source initialization
      if (_isNew) {
        edited = InfoPost(
          id: "",
          title: "",
          description: "",
        );
        _isInitialized = true;
      } else {
        final infoProvider = Provider.of<InfoProvider>(context);
        final foundPost = infoProvider.info.cast<InfoPost?>().firstWhere(
              (e) => e?.id == widget.infoId,
              orElse: () => null,
            );

        if (foundPost != null) {
          // Edit a clone to maintain local/global separation until save
          edited = foundPost.copy();

          // Initialize Quill editor with HTML content
          if (edited.description.isNotEmpty) {
            try {
              var delta = HtmlToDelta().convert(edited.description, transformTableAsEmbed: false);
              _controller.document = Document.fromDelta(delta);
            } catch (e) {
              debugPrint("Error converting HTML to Delta: $e");
            }
          }
          _isInitialized = true;
        } else {
          // Redirect if post not found and app finished loading
          if (!infoProvider.loading) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.go('/info');
              }
            });
          }
        }
      }
    }
  }

  /// Handles form submission and Firebase update
  void _saveForm() async {
    if (_formKey.currentState!.validate()) {
      // Convert Quill Delta back to HTML for storage
      var delta = _controller.document.toDelta().toJson();
      final converter = QuillDeltaToHtmlConverter(
        List.castFrom(delta),
        ConverterOptions.forEmail(),
      );

      String desc = converter.convert();
      
      _formKey.currentState!.save();
      edited.description = desc;

      final provider = Provider.of<InfoProvider>(context, listen: false);
      if (_isNew) {
        final newId = await provider.createInfoPost(edited);
        if (newId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vytvorené')),
          );
          context.go("/info/$newId");
        }
      } else {
        await provider.updateInfoPost(edited);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uložené')),
        );
        context.go("/info/${widget.infoId}");
      }
    }
  }

  /// Modal confirmation for safe deletion
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => PointerInterceptor(
        child: AlertDialog(
          title: const Text("Zmazať informáciu?"),
          content: const Text("Naozaj chcete zmazať túto informáciu? Táto akcia je nevratná."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Zrušiť"),
            ),
            TextButton(
              onPressed: () {
                Provider.of<InfoProvider>(context, listen: false).deleteInfoPost(widget.infoId);
                Navigator.of(ctx).pop();
                context.go("/info");
              },
              child: const Text("Zmazať", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        foregroundColor: Colors.redAccent,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => _isNew ? context.go("/info") : context.go("/info/${widget.infoId}")),
        title: Text(_isNew ? "Nová informácia" : "Upraviť informáciu"),
        actions: <Widget>[
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _confirmDelete,
            ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () => _isNew ? context.go("/info") : context.go("/info/${widget.infoId}"),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              initialValue: edited.title,
                              onSaved: (value) => edited.title = value!,
                              decoration: const InputDecoration(
                                labelText: "Názov informácie",
                              ),
                              validator: (value) => (value == null || value.isEmpty) ? 'Prosím zadajte názov' : null,
                            ),
                          ),
                          if (!_isNew) ...[
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 100,
                              child: TextFormField(
                                initialValue: edited.id,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: "ID",
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Image input and cloud storage preview
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: edited.image,
                              decoration: const InputDecoration(
                                labelText: "URL obrázka (gs://...)",
                              ),
                              onChanged: (val) => setState(() => edited.image = val.trim()),
                              onSaved: (value) => edited.image = value?.trim() ?? "",
                            ),
                          ),
                          if (edited.image.isNotEmpty && edited.image.startsWith("gs://")) ...[
                            const SizedBox(width: 16),
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image(
                                  image: FirebaseImageProvider(FirebaseUrl(edited.image)),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Material Icon numeric ID
                      TextFormField(
                        initialValue: edited.icon.toString(),
                        keyboardType: TextInputType.number,
                        onSaved: (value) => edited.icon = int.tryParse(value ?? "0") ?? 0,
                        decoration: const InputDecoration(
                          labelText: "Ikona (ID)",
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Rich Text Section
                      QuillSimpleToolbar(
                        controller: _controller,
                        config: const QuillSimpleToolbarConfig(),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 400.0,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: QuillEditor.basic(
                          controller: _controller,
                          config: QuillEditorConfig(
                            customStyles: DefaultStyles.getInstance(context).merge(
                              DefaultStyles(
                                h1: DefaultTextBlockStyle(
                                  TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 32, fontWeight: FontWeight.bold),
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(16, 0),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                                h2: DefaultTextBlockStyle(
                                  TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold),
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(8, 0),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                                h3: DefaultTextBlockStyle(
                                  TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(8, 0),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                                paragraph: DefaultTextBlockStyle(
                                  TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(0, 0),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                                lists: DefaultListBlockStyle(
                                  TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(0, 0),
                                  const VerticalSpacing(0, 0),
                                  null,
                                  null,
                                ),
                                link: const TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: PointerInterceptor(
        child: FloatingActionButton(
          onPressed: _saveForm,
          child: const Icon(Icons.save),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
