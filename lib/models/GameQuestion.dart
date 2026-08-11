import 'package:flutter/foundation.dart';
import 'package:scenickazatva_app/utils/GameUtils.dart';

enum GameQuestionType {
  text('text', 'Textová odpoveď'),
  abc('abc', 'ABC odpoveď'),
  sort('sort', 'Zoradenie'),
  match('match', 'Priraďovanie');

  final String id;
  final String label;

  const GameQuestionType(this.id, this.label);

  static GameQuestionType fromId(String? id) {
    return GameQuestionType.values.firstWhere(
      (t) => t.id == id,
      orElse: () => GameQuestionType.text,
    );
  }
}

class GameMatchPair {
  String left;
  String right;

  GameMatchPair({this.left = '', this.right = ''});

  factory GameMatchPair.fromJson(Map<String, dynamic> json) {
    return GameMatchPair(
      left: json['left'] ?? '',
      right: json['right'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'left': left, 'right': right};
  }
}

/// A single quiz question. Only the fields relevant to its [type] are used
/// during evaluation, but all fields are preserved in JSON so admins can
/// switch types without losing data.
class GameQuestion {
  String id;
  String title;
  String description;
  GameQuestionType type;
  int points;

  /// Text answers: the correct answer text.
  String answer;

  /// Text answers: optional accepted alternatives.
  List<String> acceptableAnswers;

  /// ABC answers: option texts in display order.
  List<String> options;

  /// ABC answers: indices (into [options]) of the correct options.
  List<int> correctIndexes;

  /// Sort answers: the items in their correct order.
  List<String> sortOrder;

  /// Match answers: left/right pairs.
  List<GameMatchPair> pairs;

  GameQuestion({
    this.id = '',
    this.title = '',
    this.description = '',
    this.type = GameQuestionType.text,
    this.points = 10,
    this.answer = '',
    this.acceptableAnswers = const [],
    this.options = const [],
    this.correctIndexes = const [],
    this.sortOrder = const [],
    this.pairs = const [],
  });

  factory GameQuestion.fromJson(Map<String, dynamic> json, {String? id}) {
    List<String> stringList(dynamic raw) {
      if (raw is! List) return [];
      return raw.whereType<String>().toList();
    }

    List<int> intList(dynamic raw) {
      if (raw is! List) return [];
      return raw.map((e) => int.tryParse(e.toString()) ?? 0).toList();
    }

    final rawPairs = json['pairs'];
    List<GameMatchPair> pairs = [];
    if (rawPairs is List) {
      pairs = rawPairs
          .where((p) => p is Map)
          .map((p) => GameMatchPair.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
    }

    return GameQuestion(
      id: id ?? json['id'] ?? "",
      title: json['title'] ?? "",
      description: json['description'] ?? "",
      type: GameQuestionType.fromId(json['type']?.toString()),
      points: json['points'] is int
          ? json['points'] as int
          : (int.tryParse(json['points']?.toString() ?? "10") ?? 10),
      answer: json['answer'] ?? "",
      acceptableAnswers: stringList(json['acceptableAnswers']),
      options: stringList(json['options']),
      correctIndexes: intList(json['correctIndexes']),
      sortOrder: stringList(json['sortOrder']),
      pairs: pairs,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'type': type.id,
      'points': points,
    };
    if (answer.isNotEmpty) data['answer'] = answer;
    if (acceptableAnswers.isNotEmpty) data['acceptableAnswers'] = acceptableAnswers;
    if (options.isNotEmpty) data['options'] = options;
    if (correctIndexes.isNotEmpty) data['correctIndexes'] = correctIndexes;
    if (sortOrder.isNotEmpty) data['sortOrder'] = sortOrder;
    if (pairs.isNotEmpty) data['pairs'] = pairs.map((p) => p.toJson()).toList();
    return data;
  }

  /// Structural check: is the submitted payload a complete, well-formed
  /// answer for this question type?
  bool validateAnswer(Map<String, dynamic> answer) {
    switch (type) {
      case GameQuestionType.text:
        final text = answer['text'];
        return text is String && text.trim().isNotEmpty;
      case GameQuestionType.abc:
        final indexes = answer['indexes'];
        if (indexes is! List || indexes.isEmpty) return false;
        return indexes.every((e) => e is int && e >= 0 && e < options.length);
      case GameQuestionType.sort:
        final order = answer['order'];
        if (order is! List) return false;
        return GameUtils.sameItems(
          order.whereType<String>().toList(),
          sortOrder,
        );
      case GameQuestionType.match:
        final mapping = answer['mapping'];
        if (mapping is! Map) return false;
        for (final pair in pairs) {
          final value = mapping[pair.left];
          if (value is! String || value.isEmpty) return false;
        }
        return true;
    }
  }

  /// Correctness check: is the submitted payload the correct answer?
  bool checkAnswer(Map<String, dynamic> answer) {
    switch (type) {
      case GameQuestionType.text:
        final submitted = answer['text']?.toString() ?? "";
        if (GameUtils.textEquals(submitted, this.answer)) return true;
        return acceptableAnswers.any((a) => GameUtils.textEquals(submitted, a));
      case GameQuestionType.abc:
        final indexes = (answer['indexes'] as List).whereType<int>().toSet();
        return setEquals(indexes, correctIndexes.toSet());
      case GameQuestionType.sort:
        final order = answer['order'].whereType<String>().toList();
        return listEquals(order, sortOrder);
      case GameQuestionType.match:
        final mapping = answer['mapping'] as Map;
        for (final pair in pairs) {
          if (mapping[pair.left]?.toString() != pair.right) return false;
        }
        return true;
    }
  }
}
