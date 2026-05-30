import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_cached_image/firebase_cached_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:wordpress_client/wordpress_client.dart';
import 'package:scenickazatva_app/models/PostExtension.dart';
import 'package:scenickazatva_app/models/Event.dart';

class ImagePrecacheService {
  static final ImagePrecacheService _instance = ImagePrecacheService._internal();
  factory ImagePrecacheService() => _instance;
  ImagePrecacheService._internal();

  final Set<String> _invalidImages = {};
  final Set<String> _validImages = {};
  final Map<String, Future<void>> _pendingScans = {};

  /// Checks if a Firebase Storage image exists by listing the parent folder
  /// This avoids native 404 error logs in the console.
  Future<bool> doesImageExist(String path) async {
    if (path.isEmpty) return false;
    if (_invalidImages.contains(path)) return false;
    if (_validImages.contains(path)) return true;

    try {
      final ref = FirebaseStorage.instance.refFromURL(path);
      final parentPath = ref.parent?.fullPath ?? "/";

      // If we haven't scanned this folder yet, or isn't currently scanning
      if (!_pendingScans.containsKey(parentPath)) {
        _pendingScans[parentPath] = _scanFolder(ref.parent, parentPath, ref.bucket);
      }
      
      await _pendingScans[parentPath];

      // Check again after scanning
      if (_validImages.contains(path)) {
        return true;
      } else {
        _invalidImages.add(path);
        return false;
      }
    } catch (e) {
      // Fallback to metadata check if listing fails (e.g. permission issues on list)
      try {
        await FirebaseStorage.instance.refFromURL(path).getMetadata();
        _validImages.add(path);
        return true;
      } catch (_) {
        _invalidImages.add(path);
        return false;
      }
    }
  }

  Future<void> _scanFolder(Reference? parentRef, String parentPath, String bucket) async {
    debugPrint("ImagePrecacheService: Scanning folder for existence check: $parentPath");
    try {
      final actualRef = parentRef ?? FirebaseStorage.instance.ref();
      final ListResult result = await actualRef.listAll();
      for (var item in result.items) {
        _validImages.add("gs://$bucket/${item.fullPath}");
      }
    } catch (e) {
      debugPrint("ImagePrecacheService: Failed to scan folder $parentPath: $e");
    }
  }

  /// Synchronously checks if we already know the image is valid
  bool? checkCache(String path) {
    if (path.isEmpty) return false;
    if (_invalidImages.contains(path)) return false;
    if (_validImages.contains(path)) return true;
    return null;
  }

  /// Precaches a list of Firebase images (used for Events)
  void precacheFirebaseImages(List<Event> events) async {
    for (var event in events) {
      if (event.image.isNotEmpty) {
        if (await doesImageExist(event.image)) {
          try {
            final provider = FirebaseImageProvider(FirebaseUrl(event.image));
            provider.resolve(ImageConfiguration.empty).addListener(
              ImageStreamListener((_, __) {}, onError: (dynamic exception, StackTrace? stackTrace) {
                // Already handled by existence check, but keeping for safety
              }),
            );
          } catch (e) {
            debugPrint("Error resolving Firebase image: $e");
          }
        }
      }
    }
  }

  /// Precaches a single Firebase image (used for Festival logo)
  void precacheFirebaseImage(String path) async {
    if (path.isEmpty) return;
    if (await doesImageExist(path)) {
      try {
        final provider = FirebaseImageProvider(FirebaseUrl(path));
        provider.resolve(ImageConfiguration.empty);
      } catch (e) {
        debugPrint("Error precaching single Firebase image: $e");
      }
    }
  }

  /// Precaches WordPress featured images
  void precacheWpImages(List<Post> posts) {
    for (var post in posts) {
      final url = post.featuredImageSourceUrl();
      if (url.isNotEmpty) {
        try {
          final provider = CachedNetworkImageProvider(url);
          provider.resolve(ImageConfiguration.empty);
        } catch (e) {
          debugPrint("Error precaching WP image: $e");
        }
      }
    }
  }
}
