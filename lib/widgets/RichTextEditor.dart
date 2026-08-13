import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/providers/AppSettingsProvider.dart';
import 'package:scenickazatva_app/requests/ImageUploadService.dart';

/// Shared Quill rich-text editor with an image-upload toolbar button.
///
/// Image pasting is wired up by creating the [QuillController] via
/// [createController], which uploads pasted images to Firebase Storage.
class RichTextEditor extends StatefulWidget {
  const RichTextEditor({super.key, required this.controller, this.height = 400});

  final QuillController controller;
  final double height;

  /// Creates a [QuillController] whose image-paste handler uploads to
  /// Firebase Storage and inserts the returned `gs://` URL.
  static QuillController createController({
    required String Function() resolveFestivalId,
  }) {
    return QuillController.basic(
      // ignore: experimental_member_use
      config: QuillControllerConfig(
        // ignore: experimental_member_use
        clipboardConfig: QuillClipboardConfig(
          onImagePaste: (bytes) => ImageUploadService()
              .uploadBytes(bytes, festivalId: resolveFestivalId()),
        ),
      ),
    );
  }

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  final ImagePicker _picker = ImagePicker();
  final ImageUploadService _uploader = ImageUploadService();

  String get _festivalId =>
      Provider.of<AppSettingsProvider>(context, listen: false).defaultfestival;

  Future<void> _pickAndUploadImage() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final url = await _uploader.uploadBytes(bytes, festivalId: _festivalId);
      if (url == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Nepodarilo sa nahrať obrázok')),
        );
        return;
      }
      widget.controller.replaceText(
        widget.controller.selection.baseOffset,
        0,
        BlockEmbed.image(url),
        widget.controller.selection,
      );
    } catch (e) {
      debugPrint('RichTextEditor: image upload failed: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Nepodarilo sa nahrať obrázok')),
      );
    }
  }

  DefaultStyles _styles(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return DefaultStyles.getInstance(context).merge(
      DefaultStyles(
        h1: DefaultTextBlockStyle(
          TextStyle(color: onSurface, fontSize: 32, fontWeight: FontWeight.bold),
          const HorizontalSpacing(0, 0),
          const VerticalSpacing(16, 0),
          const VerticalSpacing(0, 0),
          null,
        ),
        h2: DefaultTextBlockStyle(
          TextStyle(color: onSurface, fontSize: 24, fontWeight: FontWeight.bold),
          const HorizontalSpacing(0, 0),
          const VerticalSpacing(8, 0),
          const VerticalSpacing(0, 0),
          null,
        ),
        h3: DefaultTextBlockStyle(
          TextStyle(color: onSurface, fontSize: 20, fontWeight: FontWeight.bold),
          const HorizontalSpacing(0, 0),
          const VerticalSpacing(8, 0),
          const VerticalSpacing(0, 0),
          null,
        ),
        paragraph: DefaultTextBlockStyle(
          TextStyle(color: onSurface),
          const HorizontalSpacing(0, 0),
          const VerticalSpacing(0, 0),
          const VerticalSpacing(0, 0),
          null,
        ),
        lists: DefaultListBlockStyle(
          TextStyle(color: onSurface),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        QuillSimpleToolbar(
          controller: widget.controller,
          config: QuillSimpleToolbarConfig(
            customButtons: [
              QuillToolbarCustomButtonOptions(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                tooltip: 'Nahrať obrázok',
                onPressed: _pickAndUploadImage,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: QuillEditor.basic(
            controller: widget.controller,
            config: QuillEditorConfig(customStyles: _styles(context)),
          ),
        ),
      ],
    );
  }
}
