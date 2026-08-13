import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Fixed-size 120x120 thumbnail used by the news and magazine article tiles.
class PostThumbnail extends StatelessWidget {
  const PostThumbnail({Key? key, required this.imageUrl}) : super(key: key);

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120.0,
      height: 120.0,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        height: double.infinity,
        width: double.infinity,
        placeholder: (context, url) => Image.asset('assets/images/icon512.png'),
        errorWidget: (context, url, error) => Image.asset('assets/images/icon512.png'),
      ),
    );
  }
}
