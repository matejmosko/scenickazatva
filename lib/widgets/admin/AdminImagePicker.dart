import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/providers/AppSettingsProvider.dart';
import 'package:scenickazatva_app/requests/ImageUploadService.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';
import 'package:scenickazatva_app/widgets/FirebaseImage.dart';

class AdminImagePicker extends StatefulWidget {
  final String url;
  final Function(String url) onChanged;
  final String label;
  final double aspectRatio;

  const AdminImagePicker({
    Key? key,
    required this.url,
    required this.onChanged,
    this.label = "Obrázok",
    this.aspectRatio = 16 / 9,
  }) : super(key: key);

  @override
  State<AdminImagePicker> createState() => _AdminImagePickerState();
}

class _AdminImagePickerState extends State<AdminImagePicker> {
  bool _uploading = false;
  final ImagePicker _picker = ImagePicker();
  final ImageUploadService _uploader = ImageUploadService();

  Future<void> _pickAndUpload() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      
      setState(() => _uploading = true);
      final bytes = await picked.readAsBytes();
      final festivalId = Provider.of<AppSettingsProvider>(context, listen: false).defaultfestival;
      
      final url = await _uploader.uploadBytes(bytes, festivalId: festivalId);
      if (!mounted) return;
      
      if (url == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Nepodarilo sa nahrať obrázok')));
        return;
      }
      
      widget.onChanged(url);
    } catch (e) {
      AppLog.error('AdminImagePicker: upload failed', error: e);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Nepodarilo sa nahrať obrázok')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.url.isNotEmpty)
          Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: widget.aspectRatio,
                  child: FirebaseImage(
                    url: widget.url,
                    fit: BoxFit.cover,
                    errorPlaceholder: const Center(child: Icon(Icons.error_outline)),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => widget.onChanged(''),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        if (widget.url.isNotEmpty) const SizedBox(height: 12),
        if (_uploading)
          const LinearProgressIndicator()
        else
          OutlinedButton.icon(
            onPressed: _pickAndUpload,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(widget.url.isEmpty ? 'Pridať ${widget.label}' : 'Zmeniť ${widget.label}'),
          ),
      ],
    );
  }
}
