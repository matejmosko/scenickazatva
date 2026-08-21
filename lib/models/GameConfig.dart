import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/models/GameType.dart';

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

  /// Game type: "quiz" (batch submit), "game" (instant per-question),
  /// "form" (no validation), "live" (speaker-controlled).
  GameType type;

  /// Per-question time limit in seconds for live quiz (0 = no limit).
  int timeLimitSeconds;

  /// Optional cover image URL (Firebase Storage gs:// URL) shown on the game
  /// list and at the top of the game page.
  String imageUrl;

  /// Call-to-action button text shown in the magazine carousel.
  /// Defaults to "Hrať" when empty.
  String ctaText;

  /// Whether to show this game in the magazine top carousel ads.
  bool showInAds;

  List<GameQuestion> questions;

  GameConfig({
    this.id = "",
    this.title = "",
    this.description = "",
    this.endsAt,
    this.status = "draft",
    this.type = GameType.game,
    this.timeLimitSeconds = 0,
    this.imageUrl = "",
    this.ctaText = "",
    this.showInAds = true,
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
      type: GameType.fromId(json['type']?.toString()),
      timeLimitSeconds: json['timeLimitSeconds'] ?? 0,
      imageUrl: json['imageUrl'] ?? "",
      ctaText: json['ctaText'] ?? "",
      showInAds: json['showInAds'] ?? true,
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
      'type': type.id,
      'timeLimitSeconds': timeLimitSeconds,
      'imageUrl': imageUrl,
      'ctaText': ctaText,
      'showInAds': showInAds,
    };
  }

  int get totalPoints =>
      questions.fold(0, (sum, q) => sum + q.points);
}
