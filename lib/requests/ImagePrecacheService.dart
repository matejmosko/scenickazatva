import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_cached_image/firebase_cached_image.dart';
import 'package:wordpress_client/wordpress_client.dart';
import 'package:scenickazatva_app/models/PostExtension.dart';
import 'package:scenickazatva_app/models/Event.dart';

class ImagePrecacheService {
  static final ImagePrecacheService _instance = ImagePrecacheService._internal();
  factory ImagePrecacheService() => _instance;
  ImagePrecacheService._internal();

  /// Precaches a list of Firebase images (used for Events)
  void precacheFirebaseImages(List<Event> events) {
    for (var event in events) {
      if (event.image.isNotEmpty) {
        try {
          final provider = FirebaseImageProvider(FirebaseUrl(event.image));
          provider.resolve(ImageConfiguration.empty).addListener(
            ImageStreamListener((_, __) {}, onError: (dynamic exception, StackTrace? stackTrace) {
              debugPrint("Failed to precache Firebase image: ${event.image}");
            }),
          );
        } catch (e) {
          debugPrint("Error resolving Firebase image: $e");
        }
      }
    }
  }

  /// Precaches a single Firebase image (used for Festival logo)
  void precacheFirebaseImage(String path) {
    if (path.isEmpty) return;
    try {
      final provider = FirebaseImageProvider(FirebaseUrl(path));
      provider.resolve(ImageConfiguration.empty);
    } catch (e) {
      debugPrint("Error precaching single Firebase image: $e");
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
