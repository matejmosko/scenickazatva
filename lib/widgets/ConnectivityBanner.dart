import 'package:flutter/material.dart';
import 'package:scenickazatva_app/requests/ConnectivityService.dart';

/// Temporary overlay banner that appears just above the bottom navigation bar
/// when a save/refresh fails or the device goes offline. Auto-dismisses after
/// 7 seconds (managed by [ConnectivityService]).
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: ConnectivityService.instance,
      builder: (context, _) {
        final message = ConnectivityService.instance.bannerMessage;
        final visible = message != null;
        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: visible
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: scheme.errorContainer,
                  child: SafeArea(
                    top: false,
                    child: Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onErrorContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}
