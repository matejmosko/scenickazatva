import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenickazatva_app/models/ColorScheme.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/utils/ThemeFactory.dart';

void main() {
  group('parseFestivalColor', () {
    test('parses 6-digit hex', () {
      expect(parseFestivalColor('123456', Colors.black), const Color(0xFF123456));
    });

    test('parses 8-digit hex', () {
      expect(parseFestivalColor('ffabcdef', Colors.black), const Color(0xFFABCDEF));
    });

    test('tolerates leading #', () {
      expect(parseFestivalColor('#654321', Colors.black), const Color(0xFF654321));
    });

    test('falls back on invalid input', () {
      expect(parseFestivalColor('', Colors.red), Colors.red);
      expect(parseFestivalColor('zzzzzz', Colors.red), Colors.red);
      expect(parseFestivalColor(null, Colors.red), Colors.red);
    });
  });

  group('isFestivalConfigured', () {
    test('false for the placeholder default festival', () {
      expect(isFestivalConfigured(null), isFalse);
      expect(isFestivalConfigured(Festival()), isFalse);
    });

    test('false when colors are still model defaults', () {
      final festival = Festival(id: 'zatva');
      expect(isFestivalConfigured(festival), isFalse);
    });

    test('true when a festival defines its own colors', () {
      final festival = Festival(
        id: 'zatva',
        festivalBackgroundColor: 'ff123456',
        festivalForegroundColor: 'ff654321',
      );
      expect(isFestivalConfigured(festival), isTrue);
    });
  });

  group('buildFestivalTheme', () {
    test('uses the static chrome when no festival is configured', () {
      final theme = buildFestivalTheme(brightness: Brightness.light, fontSizeFactor: 1.0);
      expect(theme.appBarTheme.backgroundColor, darkColor);
      expect(theme.appBarTheme.foregroundColor, lightColor);
      expect(theme.navigationBarTheme.backgroundColor, accentColor);
      expect(theme.navigationBarTheme.indicatorColor, accentColorDarker);
      expect(theme.navigationBarTheme.labelTextStyle!.resolve({})!.color, darkColor);
    });

    test('keeps the static chrome for the default festival instance', () {
      final theme = buildFestivalTheme(
        brightness: Brightness.light,
        fontSizeFactor: 1.0,
        festival: Festival(),
      );
      expect(theme.appBarTheme.backgroundColor, darkColor);
      expect(theme.navigationBarTheme.backgroundColor, accentColor);
    });

    test('applies festival colors when configured', () {
      final festival = Festival(
        id: 'zatva',
        festivalBackgroundColor: 'ff123456',
        festivalForegroundColor: 'ff654321',
        festivalThirdColor: 'ff00aa00',
      );
      final theme = buildFestivalTheme(
        brightness: Brightness.light,
        fontSizeFactor: 1.0,
        festival: festival,
      );
      expect(theme.appBarTheme.backgroundColor, const Color(0xFF123456));
      expect(theme.appBarTheme.foregroundColor, const Color(0xFF654321));
      expect(theme.navigationBarTheme.backgroundColor, const Color(0xFF123456));
      expect(theme.navigationBarTheme.indicatorColor, const Color(0xFF00AA00));
      expect(theme.navigationBarTheme.labelTextStyle!.resolve({})!.color, const Color(0xFF654321));
    });

    test('dark theme ignores festival colors', () {
      final festival = Festival(
        id: 'zatva',
        festivalBackgroundColor: 'ff123456',
      );
      final theme = buildFestivalTheme(
        brightness: Brightness.dark,
        fontSizeFactor: 1.0,
        festival: festival,
      );
      expect(theme.appBarTheme.backgroundColor, darkColor);
    });
  });
}
