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
        // The banner lives directly above the Navigator, so it must claim the
        // status-bar inset itself (an outer SafeArea would keep reserving that
        // space even while online, pushing the whole app down and exposing the
        // AppBar's top padding as a colored band above the title).
        final topInset = MediaQuery.paddingOf(context).top;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: online ? 0 : topInset + 36,
          color: online ? Colors.transparent : scheme.errorContainer,
          child: online
              ? null
              : Padding(
                  padding: EdgeInsets.only(top: topInset),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Ste offline — zmeny sa uložia po obnovení pripojenia',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onErrorContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
