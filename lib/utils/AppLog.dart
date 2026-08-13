import 'package:flutter/foundation.dart';

/// Central, structured logger replacing bare `debugPrint` calls.
///
/// Every entry is tagged with a level (INFO / WARN / ERROR) and a
/// local timestamp so logs can be filtered and correlated. [errorHandler]
/// lets a remote reporting service subscribe to errors later; it is a no-op
/// by default and never touches the log output.
class AppLog {
  AppLog._();

  /// Called for every [error] entry. Set this to forward errors to a remote
  /// reporting service (e.g. Crashlytics); `null` keeps logging local only.
  static void Function(String message, Object? error, StackTrace? stackTrace)?
      errorHandler;

  static void info(String message) => _log('INFO', message);

  static void warn(String message) => _log('WARN', message);

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log('ERROR', message);
    errorHandler?.call(message, error, stackTrace);
  }

  static void _log(String level, String message) {
    debugPrint('[app] ${_now()} $level $message');
  }

  static String _now() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }
}
