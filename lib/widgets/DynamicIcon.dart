import 'package:flutter/material.dart';

/// Renders a MaterialIcons glyph from a runtime [codePoint] (e.g. loaded from
/// the database). Uses [Text] instead of [IconData], because
/// [IconData.codePoint] is `@mustBeConst` (required for web icon
/// tree-shaking), so a dynamic codepoint cannot be used there.
class DynamicIcon extends StatelessWidget {
  final int codePoint;
  final double? size;
  final Color? color;

  const DynamicIcon({
    super.key,
    required this.codePoint,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      String.fromCharCode(codePoint),
      style: TextStyle(
        fontFamily: 'MaterialIcons',
        fontSize: size,
        color: color,
      ),
      textAlign: TextAlign.center,
    );
  }
}
