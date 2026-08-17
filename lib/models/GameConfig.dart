import 'package:scenickazatva_app/models/GameQuestion.dart';

/// Top-level configuration of the festival game.
/// Lives at `festivals/{festivalId}/games/{gameId}` in the Realtime Database.
class GameConfig {
  String id;
  String title;
  String description;

  /// The date when the winner is drawn among participants.
  DateTime? endsAt;

  /// Game visibility: "draft" (admin only), "published" (public), "ended" (read-only).
  String status;

  /// Optional cover image URL (Firebase Storage gs:// URL) shown on the game
  /// list and at the top of the game page.
  String imageUrl;

  List<GameQuestion> questions;

  GameConfig({
    this.id = "",
    this.title = "",
    this.description = "",
    this.endsAt,
    this.status = "draft",
    this.imageUrl = "",
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

    // endsAtMs is the epoch-millis mirror used by the RTDB security rule for
    // deadline enforcement (rules can't parse ISO strings).
    final parsed = DateTime.tryParse(json['endsAt']?.toString() ?? "");
    final endsAtMs = json['endsAtMs'];
    final fromMs = (endsAtMs is int && endsAtMs > 0)
        ? DateTime.fromMillisecondsSinceEpoch(endsAtMs, isUtc: true)
        : null;
    final effective = parsed ?? fromMs;
    // Treat dates before 2000 as "not set" (legacy epoch from old code).
    final endsAt = (effective?.isAfter(DateTime(2000)) == true) ? effective : null;

    return GameConfig(
      id: json['id'] ?? "",
      title: json['title'] ?? "",
      description: json['description'] ?? "",
      endsAt: endsAt,
      status: json['status'] ?? "draft",
      imageUrl: json['imageUrl'] ?? "",
      questions: questions,
    );
  }

  /// Epoch milliseconds of [endsAt] (0 when unset). Written alongside
  /// [endsAt] so the RTDB rules can compare it with `now`.
  int get endsAtMs => endsAt?.millisecondsSinceEpoch ?? 0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'endsAt': endsAt?.toIso8601String() ?? "",
      'endsAtMs': endsAtMs,
      'status': status,
      'imageUrl': imageUrl,
    };
  }

  int get totalPoints =>
      questions.fold(0, (sum, q) => sum + q.points);
}
