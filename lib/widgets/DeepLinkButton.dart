import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';

/// Shows a small link icon in the AppBar (visible only to admin/editor users)
/// that opens a dialog with the deep link for the current screen, plus a
/// copy-to-clipboard button.
class DeepLinkButton extends StatelessWidget {
  final String? pathOverride;
  const DeepLinkButton({super.key, this.pathOverride});

  static const String _baseUrl = 'javisko://';

  @override
  Widget build(BuildContext context) {
    final canEdit = context.watch<UserProvider>().canEdit;
    if (!canEdit) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.link, color: Colors.white70),
      onPressed: () => _showDeepLinkDialog(context),
    );
  }

  void _showDeepLinkDialog(BuildContext context) {
    final path = pathOverride ?? GoRouterState.of(context).uri.toString();
    final url = '$_baseUrl$path';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hlboký odkaz'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              url,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Kopírovať'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Odkaz skopírovaný')),
                    );
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Zavrieť'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
