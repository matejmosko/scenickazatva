import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';

void main() {
  final captured = <String>[];
  setUp(() {
    captured.clear();
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) captured.add(message);
    };
    AppLog.errorHandler = null;
  });
  tearDown(() => debugPrint = debugPrintThrottled);

  test('info entries carry a level tag', () {
    AppLog.info('hello world');
    expect(captured.single, contains('[app]'));
    expect(captured.single, contains('INFO hello world'));
  });

  test('warn entries carry a level tag', () {
    AppLog.warn('careful');
    expect(captured.single, contains('WARN careful'));
  });

  test('error entries carry a level tag', () {
    AppLog.error('boom');
    expect(captured.single, contains('ERROR boom'));
  });

  test('errorHandler receives errors but does not replace the log line', () {
    Object? seenError;
    StackTrace? seenStack;
    AppLog.errorHandler = (message, error, stack) {
      seenError = error;
      seenStack = stack;
    };
    final err = StateError('x');
    AppLog.error('boom', error: err);
    expect(seenError, same(err));
    expect(seenStack, isNull);
    expect(captured.single, contains('ERROR boom'));
  });

  test('errorHandler is not called for info/warn', () {
    var calls = 0;
    AppLog.errorHandler = (message, error, stack) => calls++;
    AppLog.info('a');
    AppLog.warn('b');
    expect(calls, 0);
  });
}
