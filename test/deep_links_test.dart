import 'package:flutter_test/flutter_test.dart';
import 'package:scenickazatva_app/utils/DeepLinks.dart';

void main() {
  group('static routes', () {
    const cases = <String, String>{
      'javisko://': '/',
      'javisko://news': '/news',
      'javisko://magazine': '/magazine',
      'javisko://events': '/events',
      'javisko://info': '/info',
      'javisko://settings': '/settings',
      'javisko://favorites': '/favorites',
      'javisko://games': '/games',
      'javisko://game': '/games',
    };
    cases.forEach((input, expected) {
      test('$input → $expected', () {
        expect(DeepLinks.normalizeDeepLink(input), expected);
      });
    });
  });

  group('parameterized routes', () {
    test('news detail', () {
      expect(DeepLinks.normalizeDeepLink('javisko://news/123'),
          '/news/123');
    });
    test('magazine detail', () {
      expect(
          DeepLinks.normalizeDeepLink('javisko://magazine/42'), '/magazine/42');
    });
    test('event detail', () {
      expect(DeepLinks.normalizeDeepLink('javisko://events/7'),
          '/events/7');
    });
    test('event edit', () {
      expect(DeepLinks.normalizeDeepLink('javisko://events/7/edit'),
          '/events/7/edit');
    });
    test('info detail', () {
      expect(
          DeepLinks.normalizeDeepLink('javisko://info/abc'), '/info/abc');
    });
    test('info edit', () {
      expect(
          DeepLinks.normalizeDeepLink('javisko://info/abc/edit'),
          '/info/abc/edit');
    });
    test('game detail by push key', () {
      expect(
          DeepLinks.normalizeDeepLink('javisko://game/-OzqFBxvxs_sHCKDWL0Y'),
          '/game/-OzqFBxvxs_sHCKDWL0Y');
    });
    test('game edit', () {
      expect(
          DeepLinks.normalizeDeepLink('javisko://game/-OzqFBxvxs_sHCKDWL0Y/edit'),
          '/game/-OzqFBxvxs_sHCKDWL0Y/edit');
    });
    test('game results', () {
      expect(
          DeepLinks.normalizeDeepLink('javisko://game/-OzqFBxvxs_sHCKDWL0Y/results'),
          '/game/-OzqFBxvxs_sHCKDWL0Y/results');
    });
    test('game winners', () {
      expect(
          DeepLinks.normalizeDeepLink('javisko://game/-OzqFBxvxs_sHCKDWL0Y/winners'),
          '/game/-OzqFBxvxs_sHCKDWL0Y/winners');
    });
    test('game question', () {
      expect(
          DeepLinks.normalizeDeepLink('javisko://game/-OzqFBxvxs_sHCKDWL0Y/-OzqFFGza6ZqhE0eBoqL'),
          '/game/-OzqFBxvxs_sHCKDWL0Y/-OzqFFGza6ZqhE0eBoqL');
    });
    test('game edit question (legacy)', () {
      expect(
          DeepLinks.normalizeDeepLink('javisko://game/edit/q-1'),
          '/game/edit/q-1');
    });
    test('game edit question (new)', () {
      expect(
          DeepLinks.normalizeDeepLink('javisko://game/-OzqFBxvxs_sHCKDWL0Y/edit/q-1'),
          '/game/-OzqFBxvxs_sHCKDWL0Y/edit/q-1');
    });
  });

  group('normalization', () {
    test('strips query string and fragment', () {
      expect(
          DeepLinks.normalizeDeepLink('javisko://news/123?utm=x#top'),
          '/news/123');
    });
    test('strips trailing slash', () {
      expect(DeepLinks.normalizeDeepLink('javisko://events/'),
          '/events');
    });
    test('bare path without leading slash', () {
      expect(DeepLinks.normalizeDeepLink('news/123'), '/news/123');
    });
    test('https URL still maps (host ignored)', () {
      expect(
          DeepLinks.normalizeDeepLink('https://javisko.sk/news/123'),
          '/news/123');
    });
    test('uppercase host still maps', () {
      expect(DeepLinks.normalizeDeepLink('HTTPS://JAVIKO.SK/games'), '/games');
    });
  });

  group('unknown routes', () {
    test('returns null for unknown path', () {
      expect(DeepLinks.normalizeDeepLink('javisko://unknown'), isNull);
    });
    test('returns null for too-deep parameterized paths', () {
      expect(
          DeepLinks.normalizeDeepLink('javisko://news/123/extra'),
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
    test('non-push-key game segment returns null', () {
      expect(
          DeepLinks.normalizeDeepLink('javisko://game/results'),
          isNull);
    });
  });
}
