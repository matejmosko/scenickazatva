/// A user's submitted answer for one question.
/// Lives at `users/{uid}/game/{festivalId}/{questionId}` in the Realtime Database.
class GameSubmission {
  String questionId;
  Map<String, dynamic> answer;
  bool correct;
  int points;
  DateTime? answeredAt;

  GameSubmission({
    this.questionId = "",
    this.answer = const {},
    this.correct = false,
    this.points = 0,
    this.answeredAt,
  });

  factory GameSubmission.fromJson(Map<String, dynamic> json) {
    return GameSubmission(
      questionId: json['questionId'] ?? "",
      answer: json['answer'] is Map
          ? Map<String, dynamic>.from(json['answer'] as Map)
          : {},
      correct: json['correct'] ?? false,
      points: json['points'] is int
          ? json['points'] as int
          : (int.tryParse(json['points']?.toString() ?? "0") ?? 0),
      answeredAt: DateTime.tryParse(json['answeredAt']?.toString() ?? ""),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'answer': answer,
      'correct': correct,
      'points': points,
      'answeredAt': answeredAt?.toIso8601String() ?? "",
    };
  }
}
