import 'package:flutter/material.dart';
import 'package:firebase_cached_image/firebase_cached_image.dart';
import 'package:scenickazatva_app/requests/ImagePrecacheService.dart';

/// Renders a Firebase Storage image (gs:// URL) after checking that it exists.
///
/// Falls back to [fallbackUrl] (and finally to [placeholder]/[errorPlaceholder])
/// when the primary image is missing or fails to decode. When [url] is empty,
/// [placeholder] is shown immediately without touching Firebase.
class FirebaseImage extends StatelessWidget {
  const FirebaseImage({
    Key? key,
    required this.url,
    this.fallbackUrl = '',
    this.fit = BoxFit.cover,
    this.placeholder = const SizedBox.shrink(),
    this.errorPlaceholder,
  }) : super(key: key);

  final String url;
  final String fallbackUrl;
  final BoxFit fit;
  final Widget placeholder;
  final Widget? errorPlaceholder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: url.isNotEmpty
          ? ImagePrecacheService().doesImageExist(url)
          : Future.value(false),
      builder: (context, snapshot) {
        final bool exists =
            snapshot.data ?? (ImagePrecacheService().checkCache(url) ?? false);
        return _render(exists ? url : fallbackUrl);
      },
    );
  }

  Widget _render(String effectiveUrl) {
    if (effectiveUrl.isEmpty) return placeholder;
    return Image(
      image: FirebaseImageProvider(FirebaseUrl(effectiveUrl)),
      fit: fit,
      errorBuilder: (context, _, __) {
        if (effectiveUrl == fallbackUrl || fallbackUrl.isEmpty) {
          return errorPlaceholder ?? placeholder;
        }
        return Image(
          image: FirebaseImageProvider(FirebaseUrl(fallbackUrl)),
          fit: fit,
          errorBuilder: (context, _, __) => errorPlaceholder ?? placeholder,
        );
      },
    );
  }
}
