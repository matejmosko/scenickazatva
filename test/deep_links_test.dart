import 'package:flutter_test/flutter_test.dart';
import 'package:scenickazatva_app/utils/DeepLinks.dart';

void main() {
  group('static routes', () {
    const cases = <String, String>{
      'https://javisko.sk/': '/',
      'https://javisko.sk/news': '/news',
      'https://javisko.sk/magazine': '/magazine',
      'https://javisko.sk/events': '/events',
      'https://javisko.sk/info': '/info',
      'https://javisko.sk/settings': '/settings',
      'https://javisko.sk/favorites': '/favorites',
      'https://javisko.sk/game': '/game',
      'https://javisko.sk/game/results': '/game/results',
      'https://javisko.sk/game/edit': '/game/edit',
    };
    cases.forEach((input, expected) {
      test('$input → $expected', () {
        expect(DeepLinks.normalizeDeepLink(input), expected);
      });
    });
  });

  group('parameterized routes', () {
    test('news detail', () {
      expect(DeepLinks.normalizeDeepLink('https://javisko.sk/news/123'),
          '/news/123');
    });
    test('magazine detail', () {
      expect(
          DeepLinks.normalizeDeepLink('javisko.sk/magazine/42'), '/magazine/42');
    });
    test('event detail', () {
      expect(DeepLinks.normalizeDeepLink('https://javisko.sk/events/7'),
          '/events/7');
    });
    test('event edit', () {
      expect(DeepLinks.normalizeDeepLink('https://javisko.sk/events/7/edit'),
          '/events/7/edit');
    });
    test('info detail', () {
      expect(
          DeepLinks.normalizeDeepLink('https://javisko.sk/info/abc'), '/info/abc');
    });
    test('info edit', () {
      expect(
          DeepLinks.normalizeDeepLink('https://javisko.sk/info/abc/edit'),
          '/info/abc/edit');
    });
    test('game question', () {
      expect(
          DeepLinks.normalizeDeepLink('https://javisko.sk/game/q-1'), '/game/q-1');
    });
    test('game edit question', () {
      expect(
          DeepLinks.normalizeDeepLink('https://javisko.sk/game/edit/q-1'),
          '/game/edit/q-1');
    });
  });

  group('normalization', () {
    test('strips query string and fragment', () {
      expect(
          DeepLinks.normalizeDeepLink('https://javisko.sk/news/123?utm=x#top'),
          '/news/123');
    });
    test('strips trailing slash', () {
      expect(DeepLinks.normalizeDeepLink('https://javisko.sk/events/'),
          '/events');
    });
    test('bare path without leading slash', () {
      expect(DeepLinks.normalizeDeepLink('news/123'), '/news/123');
    });
    test('custom scheme', () {
      expect(
          DeepLinks.normalizeDeepLink('scenickazatva://news/123'), '/news/123');
    });
    test('uppercase host still maps', () {
      expect(DeepLinks.normalizeDeepLink('HTTPS://JAVISKO.SK/game'), '/game');
    });
  });

  group('unknown routes', () {
    test('returns null for unknown path', () {
      expect(DeepLinks.normalizeDeepLink('https://javisko.sk/unknown'), isNull);
    });
    test('returns null for too-deep parameterized paths', () {
      expect(
          DeepLinks.normalizeDeepLink('https://javisko.sk/news/123/extra'),
          isNull);
    });
    test('returns null for empty input', () {
      expect(DeepLinks.normalizeDeepLink(''), isNull);
    });
    test('host is ignored for known paths', () {
      expect(
          DeepLinks.normalizeDeepLink('https://other.example/news/123'),
          '/news/123');
    });
    test('returns null for unknown path on any host', () {
      expect(
          DeepLinks.normalizeDeepLink('https://javisko.sk/unknown'), isNull);
    });
  });
}
