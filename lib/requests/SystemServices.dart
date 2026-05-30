import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

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
      debugPrint('Could not launch $url: $e');
    }
  }
}

class Analytics {
  sendEvent(String? name) async {
    if (name == null) return;
    await FirebaseAnalytics.instance.logEvent(
      name: "select_content",
      parameters: {"content_type": "post", "item_id": name},
    );
  }
}
