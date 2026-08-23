import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Fixed-size 120x120 thumbnail used by the news and magazine article tiles.
class PostThumbnail extends StatelessWidget {
  const PostThumbnail({
    Key? key,
    required this.imageUrl,
    this.onBookmark,
    this.isBookmarked = false,
  }) : super(key: key);

  final String imageUrl;
  final VoidCallback? onBookmark;
  final bool isBookmarked;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Container(
        width: 120,
        height: 120,
        child: Image.asset('assets/images/icon512.png', fit: BoxFit.cover),
      );
    }

    return Container(
      width: 120.0,
      height: 120.0,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
            placeholder: (context, url) => Image.asset('assets/images/icon512.png'),
            errorWidget: (context, url, error) => Image.asset('assets/images/icon512.png'),
          ),
          if (onBookmark != null)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onBookmark,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: isBookmarked ? const Color(0xffCCA965) : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
