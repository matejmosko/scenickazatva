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

  final Map<String, Future<bool>> _pendingChecks = {};
  final Set<String> _scannedFolders = {};

  /// Normalizes a GS path using Firebase Storage's own parser
  String? _normalizePath(String path) {
    if (path.isEmpty || !path.startsWith("gs://")) return null;
    try {
      final ref = FirebaseStorage.instance.refFromURL(path);
      return "gs://${ref.bucket}/${ref.fullPath}";
    } catch (e) {
      return null;
    }
  }

  /// Checks if a Firebase Storage image exists.
  /// Uses a combination of folder listing (efficient for many images in same folder)
  /// and metadata check (fallback).
  Future<bool> doesImageExist(String path) async {
    final normalizedPath = _normalizePath(path);
    if (normalizedPath == null) return false;
    
    // 1. Check synchronous cache
    if (_invalidImages.contains(normalizedPath)) return false;
    if (_validImages.contains(normalizedPath)) return true;

    // 2. Check if there's an ongoing check for this specific path
    if (_pendingChecks.containsKey(normalizedPath)) {
      return _pendingChecks[normalizedPath]!;
    }

    final Future<bool> checkFuture = _doCheckImage(normalizedPath);
    _pendingChecks[normalizedPath] = checkFuture;
    
    try {
      final result = await checkFuture;
      return result;
    } finally {
      _pendingChecks.remove(normalizedPath);
    }
  }

  Future<bool> _doCheckImage(String normalizedPath) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(normalizedPath);
      final parentPath = ref.parent?.fullPath ?? "";
      final bucket = ref.bucket;

      debugPrint("ImagePrecacheService: Checking $normalizedPath");

      // Try folder scanning for efficiency
      // Allow root scanning (parentPath == "") to prevent getMetadata fallback for root files
      if (!_scannedFolders.contains(parentPath)) {
        if (!_pendingScans.containsKey(parentPath)) {
          _pendingScans[parentPath] = _scanFolder(ref.parent, parentPath, bucket);
        }
        await _pendingScans[parentPath];
      }
      
      // If folder was scanned, we should have the answer in our sets
      if (_validImages.contains(normalizedPath)) return true;
      
      // Only if scan was successful and we still don't have it, we can be sure it's invalid
      if (_scannedFolders.contains(parentPath)) {
        debugPrint("ImagePrecacheService: $normalizedPath NOT found in successfully scanned folder '$parentPath'");
        _invalidImages.add(normalizedPath);
        return false;
      }

      // Fallback: Direct check via metadata (e.g. if folder scan failed or was not scannable)
      await ref.getMetadata();
      _validImages.add(normalizedPath);
      return true;
    } catch (e) {
      debugPrint("ImagePrecacheService: Existence check failed for $normalizedPath: $e");
      _invalidImages.add(normalizedPath);
      return false;
    }
  }

  Future<void> _scanFolder(Reference? parentRef, String parentPath, String bucket) async {
    // If parentRef is null, it means we are likely at the root. 
    // We use storage root ref in that case.
    final Reference scanRef = parentRef ?? FirebaseStorage.instance.ref();
    
    try {
      final ListResult result = await scanRef.listAll();
      debugPrint("ImagePrecacheService: Scanned folder '$parentPath', found ${result.items.length} items");
      for (var item in result.items) {
        final fullGsPath = "gs://$bucket/${item.fullPath}";
        _validImages.add(fullGsPath);
      }
      _scannedFolders.add(parentPath);
    } catch (e) {
      debugPrint("ImagePrecacheService: Folder scan failed for '$parentPath': $e");
      // Don't add to _scannedFolders so we can try fallback or retry later
    } finally {
      _pendingScans.remove(parentPath);
    }
  }

  /// Synchronously checks if we already know the image is valid
  bool? checkCache(String path) {
    final normalized = _normalizePath(path);
    if (normalized == null) return false;
    if (_invalidImages.contains(normalized)) return false;
    if (_validImages.contains(normalized)) return true;
    return null;
  }

  /// Precaches a list of Firebase images (used for Events)
  void precacheFirebaseImages(List<Event> events) async {
    for (var event in events) {
      if (event.image.isNotEmpty && event.image.startsWith("gs://")) {
        final exists = await doesImageExist(event.image);
        if (exists) {
          try {
            final provider = FirebaseImageProvider(FirebaseUrl(event.image));
            provider.resolve(ImageConfiguration.empty).addListener(
              ImageStreamListener((_, __) {
                // Success
              }, onError: (dynamic exception, StackTrace? stackTrace) {
                debugPrint("ImagePrecacheService: Background precache failed for ${event.image}: $exception");
              }),
            );
          } catch (e) {
            debugPrint("ImagePrecacheService: Error resolving ${event.image}: $e");
          }
        }
      }
    }
  }

  /// Precaches a single Firebase image (used for Festival logo)
  void precacheFirebaseImage(String path) async {
    if (path.isEmpty || !path.startsWith("gs://")) return;
    if (await doesImageExist(path)) {
      try {
        final provider = FirebaseImageProvider(FirebaseUrl(path));
        provider.resolve(ImageConfiguration.empty).addListener(
          ImageStreamListener((_, __) {}, onError: (dynamic exception, StackTrace? stackTrace) {
            debugPrint("ImagePrecacheService: Background precache failed for $path: $exception");
          }),
        );
      } catch (e) {
        debugPrint("ImagePrecacheService: Error resolving $path: $e");
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
