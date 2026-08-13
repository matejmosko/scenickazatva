import 'package:flutter/material.dart';
import 'package:scenickazatva_app/requests/ConnectivityService.dart';

/// Slim banner pinned above the app content that appears when the Realtime
/// Database connection is lost. Writes (game answers, favorites, edits) are
/// still queued locally by the RTDB offline queue, so the banner reassures
/// the user their changes will sync once the connection returns.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: ConnectivityService.instance,
      builder: (context, _) {
        final online = ConnectivityService.instance.isOnline;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: online ? 0 : 36,
          color: scheme.errorContainer,
          alignment: Alignment.center,
          child: online
              ? null
              : Text(
                  'Ste offline — zmeny sa uložia po obnovení pripojenia',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontSize: 13,
                  ),
                ),
        );
      },
    );
  }
}
