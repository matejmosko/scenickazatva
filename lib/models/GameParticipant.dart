/// A quiz participant, used by organizers to pick the winner.
/// Lives at `festivals/{festivalId}/games/{gameId}/participants/{uid}`.
class GameParticipant {
  String uid;
  String fullName;
  int score;
  int correctCount;
  int answeredCount;
  DateTime? lastAnsweredAt;
  bool winner;

  GameParticipant({
    this.uid = "",
    this.fullName = "",
    this.score = 0,
    this.correctCount = 0,
    this.answeredCount = 0,
    this.lastAnsweredAt,
    this.winner = false,
  });

  factory GameParticipant.fromJson(Map<String, dynamic> json) {
    return GameParticipant(
      uid: json['uid'] ?? "",
      fullName: json['fullName'] ?? "",
      score: json['score'] is int
          ? json['score'] as int
          : (int.tryParse(json['score']?.toString() ?? "0") ?? 0),
      correctCount: json['correctCount'] is int
          ? json['correctCount'] as int
          : (int.tryParse(json['correctCount']?.toString() ?? "0") ?? 0),
      answeredCount: json['answeredCount'] is int
          ? json['answeredCount'] as int
          : (int.tryParse(json['answeredCount']?.toString() ?? "0") ?? 0),
      lastAnsweredAt:
          DateTime.tryParse(json['lastAnsweredAt']?.toString() ?? ""),
      winner: json['winner'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'fullName': fullName,
      'score': score,
      'correctCount': correctCount,
      'answeredCount': answeredCount,
      'lastAnsweredAt': lastAnsweredAt?.toIso8601String() ?? "",
    };
  }

  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    return "Neznámy hráč";
  }
}
