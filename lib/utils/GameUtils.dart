import 'package:flutter/foundation.dart';

/// Pure evaluation helpers for the festival quiz game.
/// Kept side-effect free so answer correctness is unit-testable.
class GameUtils {
  GameUtils._();

  static const Map<String, String> _diacritics = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ă': 'a', 'ą': 'a',
    'ć': 'c', 'č': 'c', 'ç': 'c',
    'ď': 'd', 'đ': 'd',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ě': 'e', 'ę': 'e', 'ė': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ľ': 'l', 'ĺ': 'l', 'ł': 'l',
    'ň': 'n', 'ń': 'n', 'ñ': 'n',
    'ó': 'o', 'ô': 'o', 'ö': 'o', 'ò': 'o', 'õ': 'o', 'ø': 'o',
    'ř': 'r', 'ŕ': 'r',
    'š': 's', 'ś': 's',
    'ť': 't',
    'ú': 'u', 'ů': 'u', 'ü': 'u', 'ù': 'u', 'û': 'u',
    'ý': 'y', 'ÿ': 'y',
    'ž': 'z', 'ź': 'z', 'ż': 'z',
    'ß': 'ss',
  };

  /// Lowercases, trims, collapses whitespace, strips punctuation and
  /// diacritics so "  Práha! " and "praha" compare equal.
  static String normalize(String input) {
    var s = input.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    s = s.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '');
    final buffer = StringBuffer();
    for (final rune in s.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_diacritics[ch] ?? ch);
    }
    return buffer.toString();
  }

  static bool textEquals(String submitted, String correct) {
    return normalize(submitted) == normalize(correct);
  }

  /// True when both lists contain exactly the same items (order-insensitive).
  static bool sameItems(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sortedA = [...a]..sort();
    final sortedB = [...b]..sort();
    return listEquals(sortedA, sortedB);
  }
}
