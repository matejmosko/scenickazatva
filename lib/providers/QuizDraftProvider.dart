import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';

/// Manages local (unsubmitted) state for a quiz or form.
/// Prevents data loss during scrolling and simplifies multi-field state management.
class QuizDraftProvider extends ChangeNotifier {
  String? _gameId;
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, Set<int>> _selectedIndexes = {};
  final Map<String, List<String>> _sortItems = {};
  final Map<String, Map<String, String?>> _matchPlaced = {};
  final Map<String, List<String>> _matchAvailable = {};

  String? get gameId => _gameId;

  /// Initializes draft state for a new game.
  void init(String gameId, List<GameQuestion> questions) {
    if (_gameId == gameId) return;
    
    _disposeControllers();
    _gameId = gameId;
    _selectedIndexes.clear();
    _sortItems.clear();
    _matchPlaced.clear();
    _matchAvailable.clear();

    for (final q in questions) {
      _ensureStateFor(q);
    }
    notifyListeners();
  }

  void _ensureStateFor(GameQuestion q) {
    if (q.type == GameQuestionType.text || q.type == GameQuestionType.textarea) {
      _textControllers.putIfAbsent(q.id, () => TextEditingController());
    } else if (q.type == GameQuestionType.abc) {
      _selectedIndexes.putIfAbsent(q.id, () => {});
    } else if (q.type == GameQuestionType.sort) {
      _sortItems.putIfAbsent(q.id, () {
        final items = [...q.sortOrder];
        if (items.length > 1) {
          items.shuffle();
          // Safety: try to avoid starting with the correct order by accident
          var attempts = 0;
          while (listEquals(items, q.sortOrder) && attempts < 5) {
            items.shuffle();
            attempts++;
          }
        }
        return items;
      });
    } else if (q.type == GameQuestionType.match) {
      _matchPlaced.putIfAbsent(q.id, () => {
        for (final pair in q.pairs) pair.left: null,
      });
      _matchAvailable.putIfAbsent(q.id, () {
        final rights = q.pairs.map((p) => p.right).toList()..shuffle();
        return rights;
      });
    }
  }

  TextEditingController? getTextController(String questionId) => _textControllers[questionId];
  Set<int> getSelectedIndexes(String questionId) => _selectedIndexes[questionId] ?? {};
  List<String> getSortItems(String questionId) => _sortItems[questionId] ?? [];
  Map<String, String?> getMatchPlaced(String questionId) => _matchPlaced[questionId] ?? {};
  List<String> getMatchAvailable(String questionId) => _matchAvailable[questionId] ?? [];

  void setSelectedIndexes(String questionId, Set<int> indexes) {
    _selectedIndexes[questionId] = indexes;
    notifyListeners();
  }

  void setSortItems(String questionId, List<String> items) {
    _sortItems[questionId] = items;
    notifyListeners();
  }

  void setMatchState(String questionId, Map<String, String?> placed, List<String> available) {
    _matchPlaced[questionId] = placed;
    _matchAvailable[questionId] = available;
    notifyListeners();
  }

  /// Public bridge to trigger rebuilds from widgets.
  void notify() => notifyListeners();

  bool hasAnswer(String questionId) {
    if (_textControllers.containsKey(questionId)) {
      return _textControllers[questionId]!.text.trim().isNotEmpty;
    }
    if (_selectedIndexes.containsKey(questionId)) {
      return _selectedIndexes[questionId]!.isNotEmpty;
    }
    if (_sortItems.containsKey(questionId)) {
      return _sortItems[questionId]!.isNotEmpty;
    }
    if (_matchPlaced.containsKey(questionId)) {
      final placed = _matchPlaced[questionId]!;
      return placed.values.every((v) => v != null);
    }
    return false;
  }

  Map<String, dynamic>? buildAnswer(GameQuestion q) {
    switch (q.type) {
      case GameQuestionType.text:
      case GameQuestionType.textarea:
        final text = _textControllers[q.id]?.text.trim() ?? "";
        if (text.isEmpty) return null;
        return {'text': text};
      case GameQuestionType.abc:
        final indexes = _selectedIndexes[q.id];
        if (indexes == null || indexes.isEmpty) return null;
        return {'indexes': indexes.toList()..sort()};
      case GameQuestionType.sort:
        final items = _sortItems[q.id];
        if (items == null || items.isEmpty) return null;
        return {'order': items};
      case GameQuestionType.match:
        final placed = _matchPlaced[q.id];
        if (placed == null) return null;
        final mapping = <String, String>{};
        for (final pair in q.pairs) {
          final value = placed[pair.left];
          if (value == null || value.isEmpty) return null;
          mapping[pair.left] = value;
        }
        return {'mapping': mapping};
    }
  }

  void clear() {
    _disposeControllers();
    _gameId = null;
    _selectedIndexes.clear();
    _sortItems.clear();
    _matchPlaced.clear();
    _matchAvailable.clear();
    notifyListeners();
  }

  void _disposeControllers() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    _textControllers.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }
}
