import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';

/// Name input field with debounce save. Used in header card and start screen.
class GameNameField extends StatefulWidget {
  final TextEditingController controller;
  const GameNameField({Key? key, required this.controller}) : super(key: key);

  @override
  State<GameNameField> createState() => _GameNameFieldState();
}

class _GameNameFieldState extends State<GameNameField> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Tvoje meno pre hru",
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: widget.controller,
          decoration: const InputDecoration(
            hintText: "Zadaj svoje meno...",
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
          style: Theme.of(context).textTheme.bodyLarge,
          onChanged: (value) {
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _debounce = Timer(const Duration(milliseconds: 500), () {
              if (mounted) {
                Provider.of<UserProvider>(context, listen: false)
                    .updateFullName(value);
              }
            });
          },
          onSubmitted: (_) {},
          onTapOutside: (_) {
            FocusScope.of(context).unfocus();
          },
        ),
      ],
    );
  }
}
