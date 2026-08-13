import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';

/// Uploads rich-text images to Firebase Storage and returns a `gs://` URL
/// that the rest of the app (FirebaseImage, ImagePrecacheService) can render.
class ImageUploadService {
  Future<String?> uploadBytes(
    Uint8List bytes, {
    required String festivalId,
  }) async {
    try {
      final storage = FirebaseStorage.instance;
      final path =
          'festivals/$festivalId/images/${DateTime.now().millisecondsSinceEpoch}_rich.png';
      final ref = storage.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
      return 'gs://${storage.bucket}/${ref.fullPath}';
    } catch (e) {
      AppLog.error('ImageUploadService: upload failed', error: e);
      return null;
    }
  }
}
