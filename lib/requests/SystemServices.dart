import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';

class SystemServices {
  static final SystemServices _instance = SystemServices._internal();
  factory SystemServices() => _instance;
  SystemServices._internal();

  launchURL(String url, {bool forceExternal = false}) async {
    final Uri _url = Uri.parse(url.trim());
    
    // List of common document/file extensions that should open in external apps
    final fileExtensions = [
      '.pdf', '.doc', '.docx', '.odt', '.rtf', '.txt', // Documents
      '.xls', '.xlsx', '.ods', '.csv',                // Spreadsheets
      '.ppt', '.pptx', '.odp',                        // Presentations
      '.zip', '.rar', '.7z', '.tar', '.gz'            // Archives
    ];

    final bool isFile = fileExtensions.any((ext) => 
      _url.path.toLowerCase().endsWith(ext) || 
      url.toLowerCase().contains('$ext?') || 
      url.toLowerCase().endsWith(ext)
    );

    final LaunchMode mode = (forceExternal || isFile)
        ? LaunchMode.externalApplication
        : LaunchMode.inAppWebView;

    try {
      if (await canLaunchUrl(_url)) {
        await launchUrl(_url, mode: mode);
      } else {
        // Fallback: try to launch externally if canLaunchUrl fails
        await launchUrl(_url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLog.error('Could not launch $url', error: e);
    }
  }
}

class Analytics {
  static final Analytics _instance = Analytics._();
  factory Analytics() => _instance;
  Analytics._();

  String? _lastFestivalId;

  /// Keeps the `festival_id` user property and default event parameters in
  /// sync with the currently selected festival. No-ops when unchanged.
  Future<void> syncFestival(String? festivalId) async {
    if (festivalId == null || festivalId.isEmpty || festivalId == _lastFestivalId) {
      return;
    }
    _lastFestivalId = festivalId;
    try {
      await FirebaseAnalytics.instance
          .setUserProperty(name: 'festival_id', value: festivalId);
      await FirebaseAnalytics.instance
          .setDefaultEventParameters(<String, Object>{'festival_id': festivalId});
    } catch (e) {
      AppLog.warn("Analytics: failed to sync festival: $e");
    }
  }

  Future<void> logEvent(String name,
      {Map<String, Object> parameters = const {}}) async {
    try {
      await FirebaseAnalytics.instance.logEvent(name: name, parameters: parameters);
    } catch (e) {
      AppLog.warn("Analytics: failed to log '$name': $e");
    }
  }
}
