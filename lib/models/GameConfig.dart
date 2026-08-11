import 'package:scenickazatva_app/models/GameQuestion.dart';

/// Top-level configuration of the festival game.
/// Lives at `festivals/{festivalId}/game` in the Realtime Database.
class GameConfig {
  String title;
  String description;

  /// The date when the winner is drawn among participants.
  DateTime? endsAt;

  List<GameQuestion> questions;

  GameConfig({
    this.title = "",
    this.description = "",
    this.endsAt,
    this.questions = const [],
  });

  factory GameConfig.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'];
    List<GameQuestion> questions = [];

    if (rawQuestions is Map) {
      rawQuestions.forEach((key, value) {
        if (value is Map) {
          questions.add(
            GameQuestion.fromJson(
              Map<String, dynamic>.from(value),
              id: key.toString(),
            ),
          );
        }
      });
    } else if (rawQuestions is List) {
      questions = rawQuestions
          .where((q) => q is Map)
          .map((q) => GameQuestion.fromJson(Map<String, dynamic>.from(q as Map)))
          .toList();
    }

    return GameConfig(
      title: json['title'] ?? "",
      description: json['description'] ?? "",
      endsAt: DateTime.tryParse(json['endsAt']?.toString() ?? ""),
      questions: questions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'endsAt': endsAt?.toIso8601String() ?? "",
    };
  }

  int get totalPoints =>
      questions.fold(0, (sum, q) => sum + q.points);
}
