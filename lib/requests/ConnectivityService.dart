import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';

/// Tracks backend connectivity via the RTDB `.info/connected` signal.
///
/// Unlike a platform connectivity plugin this reflects the real state of the
/// Realtime Database connection — including the offline write queue — which
/// is what matters for the offline-first behavior of game answers and
/// favorites. It is a singleton so widgets and providers can react to the
/// same state.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  bool _online = true;

  bool get isOnline => _online;

  StreamSubscription<DatabaseEvent>? _subscription;
  bool _initialized = false;

  /// Subscribes to `.info/connected`. Idempotent; safe to call after
  /// `Firebase.initializeApp` only.
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
          notifyListeners();
        }
      });
    } catch (e) {
      AppLog.error('Connectivity: failed to subscribe', error: e);
      _initialized = false;
    }
  }

  /// Test hook to flip the state without a live Firebase connection.
  @visibleForTesting
  void debugSetOnline(bool online) {
    if (online != _online) {
      _online = online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
