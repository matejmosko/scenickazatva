import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class SystemServices {
  static final SystemServices _instance = SystemServices._internal();
  factory SystemServices() => _instance;
  SystemServices._internal();

  launchURL(String url) async {
    final Uri _url = Uri.parse(url);
    if (await canLaunchUrl(_url)) {
      await launchUrl(_url, mode: LaunchMode.inAppWebView);
    } else {
      throw 'Could not launch $url';
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
