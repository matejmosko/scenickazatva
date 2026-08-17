import 'package:flutter_test/flutter_test.dart';
import 'package:scenickazatva_app/models/GameConfig.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/utils/GameUtils.dart';

void main() {
  group('GameUtils.normalize', () {
    test('lowercases, trims and collapses whitespace', () {
      expect(GameUtils.normalize('  Práha   je tu! '), GameUtils.normalize('praha je tu'));
    });

    test('strips diacritics', () {
      expect(GameUtils.normalize('žaba'), 'zaba');
      expect(GameUtils.normalize('ŠČŽ ď ť ň ľ'), 'scz d t n l');
      expect(GameUtils.normalize('ä ö ü'), 'a o u');
    });

    test('strips punctuation', () {
      expect(GameUtils.normalize('Divadlo, Praha!?'), 'divadlo praha');
    });
  });

  group('text question', () {
    final q = GameQuestion(
      type: GameQuestionType.text,
      answer: 'Scénická žatva',
      acceptableAnswers: ['Szenicka zatva', 'scenicka zatva'],
    );

    test('accepts exact match (case/diacritics insensitive)', () {
      expect(q.checkAnswer({'text': 'scénická žatva'}), isTrue);
      expect(q.checkAnswer({'text': '  SCÉNICKÁ ŽATVA  '}), isTrue);
    });

    test('accepts acceptable answers', () {
      expect(q.checkAnswer({'text': 'scenicka zatva'}), isTrue);
      expect(q.checkAnswer({'text': 'szenicka zatva'}), isTrue);
    });

    test('rejects wrong answer', () {
      expect(q.checkAnswer({'text': 'Divadlo'}), isFalse);
    });

    test('validateAnswer requires non-empty text', () {
      expect(q.validateAnswer({'text': 'aha'}), isTrue);
      expect(q.validateAnswer({'text': '  '}), isFalse);
      expect(q.validateAnswer({}), isFalse);
    });
  });

  group('abc question', () {
    final q = GameQuestion(
      type: GameQuestionType.abc,
      options: ['javisko.sk', 'google.sk', 'youtube.sk'],
      correctIndexes: [0],
    );

    test('single correct index', () {
      expect(q.checkAnswer({'indexes': [0]}), isTrue);
      expect(q.checkAnswer({'indexes': [1]}), isFalse);
    });

    test('validateAnswer checks range and non-empty', () {
      expect(q.validateAnswer({'indexes': [0]}), isTrue);
      expect(q.validateAnswer({'indexes': [3]}), isFalse);
      expect(q.validateAnswer({'indexes': []}), isFalse);
    });

    test('multiple correct options require full set match', () {
      final multi = GameQuestion(
        type: GameQuestionType.abc,
        options: ['a', 'b', 'c', 'd'],
        correctIndexes: [0, 2],
      );
      expect(multi.checkAnswer({'indexes': [2, 0]}), isTrue);
      expect(multi.checkAnswer({'indexes': [0, 3]}), isFalse);
      expect(multi.checkAnswer({'indexes': [0]}), isFalse);
    });
  });

  group('sort question', () {
    final q = GameQuestion(
      type: GameQuestionType.sort,
      sortOrder: ['Ponuka', 'Žiadosť', 'Divadlo', 'Výber'],
    );

    test('correct order passes', () {
      expect(q.checkAnswer({'order': ['Ponuka', 'Žiadosť', 'Divadlo', 'Výber']}), isTrue);
    });

    test('wrong order fails', () {
      expect(q.checkAnswer({'order': ['Výber', 'Ponuka', 'Žiadosť', 'Divadlo']}), isFalse);
    });

    test('validateAnswer requires the same items', () {
      expect(q.validateAnswer({'order': ['Ponuka', 'Žiadosť', 'Divadlo', 'Výber']}), isTrue);
      expect(q.validateAnswer({'order': ['Ponuka', 'Žiadosť', 'Divadlo']}), isFalse);
      expect(q.validateAnswer({'order': ['Ponuka', 'Žiadosť', 'Divadlo', 'Iné']}), isFalse);
    });
  });

  group('match question', () {
    final q = GameQuestion(
      type: GameQuestionType.match,
      pairs: [
        GameMatchPair(left: 'Režisér', right: 'P. Juráček'),
        GameMatchPair(left: 'Hudba', right: 'M. Smolka'),
      ],
    );

    test('correct mapping passes', () {
      expect(
        q.checkAnswer({'mapping': {'Režisér': 'P. Juráček', 'Hudba': 'M. Smolka'}}),
        isTrue,
      );
    });

    test('swapped mapping fails', () {
      expect(
        q.checkAnswer({'mapping': {'Režisér': 'M. Smolka', 'Hudba': 'P. Juráček'}}),
        isFalse,
      );
    });

    test('validateAnswer requires every left item answered', () {
      expect(
        q.validateAnswer({'mapping': {'Režisér': 'P. Juráček', 'Hudba': 'M. Smolka'}}),
        isTrue,
      );
      expect(
        q.validateAnswer({'mapping': {'Režisér': 'P. Juráček'}}),
        isFalse,
      );
      expect(q.validateAnswer({}), isFalse);
    });
  });

  group('serialization', () {
    test('round-trips a match question', () {
      final q = GameQuestion(
        id: 'q1',
        title: 'Spoj dvojice',
        type: GameQuestionType.match,
        points: 20,
        pairs: [
          GameMatchPair(left: 'A', right: '1'),
          GameMatchPair(left: 'B', right: '2'),
        ],
      );
      final restored = GameQuestion.fromJson(q.toJson(), id: 'q1');
      expect(restored.type, GameQuestionType.match);
      expect(restored.pairs.length, 2);
      expect(restored.pairs[0].left, 'A');
      expect(restored.pairs[1].right, '2');
    });

    test('round-trips an abc question with indexes', () {
      final q = GameQuestion(
        id: 'q2',
        title: 'Vyber',
        type: GameQuestionType.abc,
        options: ['x', 'y', 'z'],
        correctIndexes: [0, 2],
      );
      final restored = GameQuestion.fromJson(q.toJson(), id: 'q2');
      expect(restored.options, ['x', 'y', 'z']);
      expect(restored.correctIndexes, [0, 2]);
    });

    test('fromJson defaults missing values safely', () {
      final restored = GameQuestion.fromJson({'id': 'x', 'type': 'sort'});
      expect(restored.type, GameQuestionType.sort);
      expect(restored.points, 10);
      expect(restored.sortOrder, isEmpty);
      expect(restored.validateAnswer({'order': []}), isTrue);
    });

    test('type fromId falls back to text for unknown', () {
      expect(GameQuestionType.fromId('nonsense'), GameQuestionType.text);
      expect(GameQuestionType.fromId('match'), GameQuestionType.match);
    });
  });

  group('textarea question', () {
    final q = GameQuestion(
      type: GameQuestionType.textarea,
      points: 0,
    );

    test('checkAnswer always returns true', () {
      expect(q.checkAnswer({'text': 'Any feedback'}), isTrue);
      expect(q.checkAnswer({'text': ''}), isTrue);
    });

    test('validateAnswer requires non-empty text', () {
      expect(q.validateAnswer({'text': 'Great festival!'}), isTrue);
      expect(q.validateAnswer({'text': '  '}), isFalse);
      expect(q.validateAnswer({}), isFalse);
    });

    test('fromId resolves textarea', () {
      expect(GameQuestionType.fromId('textarea'), GameQuestionType.textarea);
    });

    test('serialization round-trips textarea type', () {
      final q = GameQuestion(
        id: 'fb1',
        title: 'Spätná väzba',
        type: GameQuestionType.textarea,
        points: 0,
      );
      final restored = GameQuestion.fromJson(q.toJson(), id: 'fb1');
      expect(restored.type, GameQuestionType.textarea);
      expect(restored.points, 0);
    });
  });

  group('game config deadline', () {
    test('toJson writes endsAtMs as epoch millis for the security rule', () {
      final endsAt = DateTime.utc(2026, 8, 1, 12);
      final config = GameConfig(endsAt: endsAt);
      final json = config.toJson();
      expect(json['endsAtMs'], endsAt.millisecondsSinceEpoch);
      expect(json['endsAt'], endsAt.toIso8601String());
    });

    test('fromJson accepts legacy ISO endsAt without endsAtMs', () {
      final config = GameConfig.fromJson({
        'title': 'Hra',
        'endsAt': '2026-08-01T12:00:00.000Z',
      });
      expect(config.endsAt, DateTime.utc(2026, 8, 1, 12));
      expect(config.endsAtMs, DateTime.utc(2026, 8, 1, 12).millisecondsSinceEpoch);
    });

    test('fromJson accepts endsAtMs when the ISO string is missing', () {
      final config = GameConfig.fromJson({
        'endsAtMs': DateTime.utc(2026, 8, 1, 12).millisecondsSinceEpoch,
      });
      expect(config.endsAt, DateTime.utc(2026, 8, 1, 12));
    });

    test('round-trips endsAtMs', () {
      final endsAt = DateTime.utc(2026, 8, 15, 20, 30);
      final restored =
          GameConfig.fromJson(GameConfig(endsAt: endsAt).toJson());
      expect(restored.endsAt, endsAt);
      expect(restored.endsAtMs, endsAt.millisecondsSinceEpoch);
    });

    test('fromJson treats epoch dates as null', () {
      final config = GameConfig.fromJson({
        'endsAt': '1970-01-01T00:00:00.000Z',
        'endsAtMs': 0,
      });
      expect(config.endsAt, isNull);
    });

    test('fromJson treats endsAtMs=0 as null', () {
      final config = GameConfig.fromJson({
        'endsAtMs': 0,
      });
      expect(config.endsAt, isNull);
    });

    test('fromJson reads and writes id field', () {
      final config = GameConfig(id: 'game-123', title: 'Test');
      final json = config.toJson();
      expect(json['id'], 'game-123');
      final restored = GameConfig.fromJson(json);
      expect(restored.id, 'game-123');
    });
  });
}
