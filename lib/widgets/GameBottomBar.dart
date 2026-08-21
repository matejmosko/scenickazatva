import 'package:flutter/material.dart';

/// Standard bottom bar with scaffold background color and top shadow.
/// Used for quiz navigation bar and live submit bar.
class GameBottomBar extends StatelessWidget {
  final Widget child;
  const GameBottomBar({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: child,
    );
  }
}
