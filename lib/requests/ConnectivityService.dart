import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';

/// Tracks backend connectivity via the RTDB `.info/connected` signal.
/// Also manages a temporary bottom banner that appears on connection loss
/// or failed writes, auto-dismissing after 7 seconds.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  static const _bannerDuration = Duration(seconds: 7);

  bool _online = true;
  bool get isOnline => _online;

  String? _bannerMessage;
  String? get bannerMessage => _bannerMessage;

  Timer? _bannerTimer;

  StreamSubscription<DatabaseEvent>? _subscription;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _subscription = FirebaseDatabase.instance
          .ref('.info/connected')
          .onValue
          .listen((event) {
        final connected = event.snapshot.value as bool? ?? false;
        if (connected != _online) {
          _online = connected;
          AppLog.info('Connectivity: ${_online ? 'online' : 'offline'}');
          if (!_online) {
            showTemporaryBanner('Ste offline — zmeny sa uložia po obnovení pripojenia');
          } else {
            hideBanner();
          }
          notifyListeners();
        }
      });
    } catch (e) {
      AppLog.error('Connectivity: failed to subscribe', error: e);
      _initialized = false;
    }
  }

  /// Shows a temporary banner for 7 seconds. Used when a save or refresh fails.
  void showTemporaryBanner(String message) {
    _bannerMessage = message;
    _bannerTimer?.cancel();
    _bannerTimer = Timer(_bannerDuration, hideBanner);
    notifyListeners();
  }

  /// Immediately hides the banner.
  void hideBanner() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    _bannerMessage = null;
    notifyListeners();
  }

  @visibleForTesting
  void debugSetOnline(bool online) {
    if (online != _online) {
      _online = online;
      if (!_online) {
        showTemporaryBanner(
            'Ste offline — zmeny sa uložia po obnovení pripojenia');
      } else {
        hideBanner();
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
