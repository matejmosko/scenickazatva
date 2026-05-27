import 'package:flutter/cupertino.dart';
import 'package:scenickazatva_app/requests/WordPressService.dart';
import 'package:wordpress_client/wordpress_client.dart';
import 'package:scenickazatva_app/models/Festival.dart';

class NewsProvider extends ChangeNotifier {
  List<Post> _wpnews = [];
  List<Post> _wparticles = [];
  bool newsLoading = false;
  bool articlesLoading = false;
  bool allnews = false;
  bool allarticles = false;
  int newspage = 1;
  int magazinepage = 1;

  String? _currentFestivalId;
  String? _newsSrc;
  String? _magazineSrc;

  List<Post> get wpnews => _wpnews;
  List<Post> get wparticles => _wparticles;

  void updateFromFestival(Festival festival) {
    if (_currentFestivalId != festival.id) {
      debugPrint("NewsProvider: Festival changed to ${festival.id}, clearing news.");
      _currentFestivalId = festival.id;
      _newsSrc = festival.news_src;
      _magazineSrc = festival.magazine_src;

      // Clear data when festival changes
      _wpnews = [];
      _wparticles = [];
      newspage = 1;
      magazinepage = 1;
      allnews = false;
      allarticles = false;
      newsLoading = false;
      articlesLoading = false;

      notifyListeners();

      // Initial fetch for new festival
      fetchWpNews(refresh: false); // Initially try cache
      fetchWpMagazine(refresh: false);
    }
  }

  Future<void> fetchWpNews({bool refresh = false}) async {
    if (_newsSrc == null || _newsSrc!.isEmpty) return;
    if (newsLoading || (!refresh && allnews)) return;

    setLoading("news_src", true);
    if (refresh) {
      allnews = false;
      newspage = 1;
    }

    try {
      final data = await WordPressService().fetchWpNews(_newsSrc!, newspage, refresh);
      if (data.isEmpty) {
        allnews = true;
      }
      setArrangementsWp(data, "news_src", refresh);
    } catch (e) {
      debugPrint("Error fetching WP news: $e");
      setLoading("news_src", false);
    }
  }

  Future<void> fetchWpMagazine({bool refresh = false}) async {
    if (_magazineSrc == null || _magazineSrc!.isEmpty) return;
    if (articlesLoading || (!refresh && allarticles)) return;

    setLoading("magazine_src", true);
    if (refresh) {
      allarticles = false;
      magazinepage = 1;
    }

    try {
      final data = await WordPressService().fetchWpNews(_magazineSrc!, magazinepage, refresh);
      if (data.isEmpty) {
        allarticles = true;
      }
      setArrangementsWp(data, "magazine_src", refresh);
    } catch (e) {
      debugPrint("Error fetching WP magazine: $e");
      setLoading("magazine_src", false);
    }
  }

  void setLoading(String category, bool val) {
    if (category == "news_src") {
      newsLoading = val;
    } else {
      articlesLoading = val;
    }
    notifyListeners();
  }

  void setArrangementsWp(List<Post> list, String category, bool refresh) {
    if (category == "news_src") {
      if (refresh) _wpnews = [];
      _wpnews.addAll(list);
      newspage++;
    } else {
      if (refresh) _wparticles = [];
      _wparticles.addAll(list);
      magazinepage++;
    }
    setLoading(category, false);
  }
}
