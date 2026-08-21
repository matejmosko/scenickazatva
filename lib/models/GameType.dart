enum GameType {
  quiz('quiz', 'Kvíz'),
  game('game', 'Festivalová hra'),
  form('form', 'Formulár'),
  live('live', 'Živý kvíz');

  final String id;
  final String label;

  const GameType(this.id, this.label);

  static GameType fromId(String? id) {
    return GameType.values.firstWhere(
      (t) => t.id == id,
      orElse: () => GameType.game,
    );
  }
}
