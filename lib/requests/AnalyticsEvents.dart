/// Firebase Analytics event names and parameter keys.
abstract final class AnalyticsEvents {
  static const String tabSelected = 'tab_selected';
  static const String menuFavorites = 'menu_favorites';
  static const String menuSettings = 'menu_settings';
  static const String articleOpened = 'article_opened';
  static const String infoOpened = 'info_opened';
  static const String eventOpened = 'event_opened';
  static const String gameOpened = 'game_opened';
  static const String gameCreateOpened = 'game_create_opened';
  static const String gameQuestionOpened = 'game_question_opened';
  static const String gameAnswerSubmitted = 'game_answer_submitted';
  static const String notificationTapped = 'notification_tapped';

  static const String paramItemId = 'item_id';
  static const String paramTitle = 'title';
  static const String paramTabIndex = 'tab_index';
  static const String paramQuestionId = 'question_id';
  static const String paramCorrect = 'correct';
  static const String paramPayload = 'payload';
}
