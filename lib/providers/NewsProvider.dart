import 'package:flutter/cupertino.dart';
import 'package:scenickazatva_app/requests/WordPressService.dart';
import 'package:wordpress_client/wordpress_client.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/models/AppSettings.dart';
import 'package:hive_ce/hive.dart';
import 'package:scenickazatva_app/requests/ImagePrecacheService.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';

class NewsProvider extends ChangeNotifier {
  static const int blogCategoryId = 999999;
  List<Post> _wpnews = [];
  List<Post> _wparticles = [];
  List<Category> _magazineCategories = [];
  final Map<String, String> _postLabels = {};
  int? _selectedMagazineCategoryId;
  bool newsLoading = false;
  bool articlesLoading = false;
  bool allnews = false;
  bool allarticles = false;
  int newspage = 1;
  int magazinepage = 1;

  String? _newsSearchQuery;
  String? _magazineSearchQuery;

  Set<int> _readArticleIds = {};
  Box? _readArticlesBox;

  String? _currentFestivalId;
  String? _newsSrc;
  String? _magazineSrc;
  List<String> _secondaryMagazineUrls = [];
  int _lastNewsPostId = 0;
  int _lastMagazinePostId = 0;

  NewsProvider() {
    _initReadArticles();
  }

  Future<void> _initReadArticles() async {
    _readArticlesBox = await Hive.openBox('read_articles');
    final List<dynamic> ids = _readArticlesBox!.get('ids', defaultValue: []);
    _readArticleIds = ids.cast<int>().toSet();
    notifyListeners();
  }

  List<Post> get wpnews => _wpnews;
  List<Post> get wparticles => _wparticles;
  List<Category> get magazineCategories => _magazineCategories;
  String getPostLabel(String link) => _postLabels[link] ?? "";
  int? get selectedMagazineCategoryId => _selectedMagazineCategoryId;
  int get unreadMagazineCount => _wparticles.where((p) => !_readArticleIds.contains(p.id)).length;
  String? get newsSearchQuery => _newsSearchQuery;
  String? get magazineSearchQuery => _magazineSearchQuery;

  bool isRead(int? id) => id == null || _readArticleIds.contains(id);

  void markAsRead(int? id) {
    if (id != null && !_readArticleIds.contains(id)) {
      _readArticleIds.add(id);
      _readArticlesBox?.put('ids', _readArticleIds.toList());
      notifyListeners();
    }
  }

  void markAllMagazineAsRead() {
    for (var post in _wparticles) {
      _readArticleIds.add(post.id);
    }
    _readArticlesBox?.put('ids', _readArticleIds.toList());
    notifyListeners();
  }

  void updateFromFestival(Festival festival) {
    bool festivalChanged = _currentFestivalId != festival.id;
    bool newsUpdated = _lastNewsPostId != festival.lastNewsPostId;

    if (festivalChanged || newsUpdated) {
      AppLog.info("NewsProvider: Update triggered. Festival changed: $festivalChanged, News updated: $newsUpdated");
      
      if (festivalChanged) {
        _currentFestivalId = festival.id;
        _newsSrc = festival.news_src;
        
        _magazineSrc = festival.magazine_src;
        _secondaryMagazineUrls = festival.magazine_blog_srcs
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        // Clear data when festival changes
        _wpnews = [];
        _wparticles = [];
        _magazineCategories = [];
        _selectedMagazineCategoryId = null;
        newspage = 1;
        magazinepage = 1;
        allnews = false;
        allarticles = false;
      }

      _lastNewsPostId = festival.lastNewsPostId;
      newsLoading = false;
      articlesLoading = false;

      notifyListeners();

      // Initial fetch for new festival or when news are updated
      fetchWpNews(refresh: newsUpdated || festivalChanged); 
      fetchWpMagazine(refresh: festivalChanged); 
      fetchMagazineCategories();
    }
  }

  void updateFromSettings(AppSettings settings) {
    if (_lastMagazinePostId != settings.lastMagazinePostId) {
      AppLog.info("NewsProvider: Magazine updated signal received.");
      _lastMagazinePostId = settings.lastMagazinePostId;
      if (_currentFestivalId != null) {
        fetchWpMagazine(refresh: true);
      }
    }
  }

  Future<void> fetchWpNews({bool refresh = false, bool fetchMore = false}) async {
    if (_newsSrc == null || _newsSrc!.isEmpty) return;
    if (newsLoading || (!refresh && allnews)) return;

    if (!refresh && !fetchMore && _wpnews.isNotEmpty) return;

    setLoading("news_src", true);
    if (refresh) {
      allnews = false;
      newspage = 1;
    }

    try {
      // 1. Try to load from cache first if we are refreshing and the memory list is empty
      if (refresh && _wpnews.isEmpty) {
        final cachedData = await WordPressService().fetchWpNews(_newsSrc!, 1, false, search: _newsSearchQuery);
        if (cachedData.isNotEmpty) {
          _wpnews = List.from(cachedData);
          newspage = 2;
          notifyListeners();
        }
      }

      // 2. Check if cache is already up-to-date with Firestore update signal
      if (_newsSearchQuery == null && _wpnews.isNotEmpty && _wpnews.first.id == _lastNewsPostId) {
        AppLog.info("News is already up to date. Skipping network request. ID: $_lastNewsPostId");
        setLoading("news_src", false);
        return;
      }

      final data = await WordPressService().fetchWpNews(_newsSrc!, newspage, refresh, search: _newsSearchQuery);
      if (data.isEmpty) {
        if (newspage == 1) {
          if (_wpnews.isEmpty) {
            allnews = true;
          }
        } else {
          allnews = true;
        }
      }
      
      if (newspage == 1) {
        _wpnews = List.from(data);
        newspage = 2;
      } else {
        _wpnews.addAll(data);
        newspage++;
      }

      ImagePrecacheService().precacheWpImages(data);
      setLoading("news_src", false);
    } catch (e) {
      AppLog.error("Error fetching WP news", error: e);
      setLoading("news_src", false);
    }
  }

  Future<void> fetchWpMagazine({bool refresh = false, bool fetchMore = false}) async {
    if (_magazineSrc == null || _magazineSrc!.isEmpty) return;
    if (articlesLoading || (!refresh && allarticles)) return;

    if (!refresh && !fetchMore && _wparticles.isNotEmpty) return;

    setLoading("magazine_src", true);
    if (refresh) {
      allarticles = false;
      magazinepage = 1;
    }

    try {
      // 1. Try to load from cache first if we are refreshing and the memory list is empty
      if (refresh && _wparticles.isEmpty) {
        List<Post> cachedData = [];
        if (_selectedMagazineCategoryId == blogCategoryId) {
          final results = await Future.wait(
            _secondaryMagazineUrls.map((url) => WordPressService().fetchWpNews(url, 1, false, search: _magazineSearchQuery))
          );
          for (int i = 0; i < results.length; i++) {
            for (var p in results[i]) {
              _postLabels[p.link] = "blog";
            }
            cachedData.addAll(results[i]);
          }
          cachedData.sort((a, b) => (b.date ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.date ?? DateTime.fromMillisecondsSinceEpoch(0)));
        } else if (_selectedMagazineCategoryId != null) {
          cachedData = await WordPressService().fetchWpNews(_magazineSrc!, 1, false, categoryId: _selectedMagazineCategoryId, search: _magazineSearchQuery);
        } else {
          final primaryResults = await WordPressService().fetchWpNews(_magazineSrc!, 1, false, search: _magazineSearchQuery);
          
          if (_secondaryMagazineUrls.isNotEmpty) {
            final secondaryResults = await Future.wait(
              _secondaryMagazineUrls.map((url) => WordPressService().fetchWpNews(url, 1, false, search: _magazineSearchQuery))
            );
            
            cachedData.addAll(primaryResults);
            for (int i = 0; i < secondaryResults.length; i++) {
              for (var p in secondaryResults[i]) {
                _postLabels[p.link] = "blog";
              }
              cachedData.addAll(secondaryResults[i]);
            }
            cachedData.sort((a, b) => (b.date ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(a.date ?? DateTime.fromMillisecondsSinceEpoch(0)));
          } else {
            cachedData = primaryResults;
          }
        }

        if (cachedData.isNotEmpty) {
          _wparticles = List.from(cachedData);
          magazinepage = 2;
          notifyListeners();
        }
      }

      // 2. Check if cache is already up-to-date with settings update signal
      if (_magazineSearchQuery == null &&
          _selectedMagazineCategoryId == null &&
          _wparticles.isNotEmpty &&
          _wparticles.first.id == _lastMagazinePostId) {
        AppLog.info("Magazine is already up to date. Skipping network request. ID: $_lastMagazinePostId");
        setLoading("magazine_src", false);
        return;
      }

      List<Post> data = [];
      if (_selectedMagazineCategoryId == blogCategoryId) {
        final results = await Future.wait(
          _secondaryMagazineUrls.map((url) => WordPressService().fetchWpNews(url, magazinepage, refresh, search: _magazineSearchQuery))
        );
        for (int i = 0; i < results.length; i++) {
          for (var p in results[i]) {
            _postLabels[p.link] = "blog";
          }
          data.addAll(results[i]);
        }
        data.sort((a, b) => (b.date ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.date ?? DateTime.fromMillisecondsSinceEpoch(0)));
      } else if (_selectedMagazineCategoryId != null) {
        data = await WordPressService().fetchWpNews(_magazineSrc!, magazinepage, refresh, categoryId: _selectedMagazineCategoryId, search: _magazineSearchQuery);
      } else {
        final primaryResults = await WordPressService().fetchWpNews(_magazineSrc!, magazinepage, refresh, search: _magazineSearchQuery);
        
        if (_secondaryMagazineUrls.isNotEmpty) {
          final secondaryResults = await Future.wait(
            _secondaryMagazineUrls.map((url) => WordPressService().fetchWpNews(url, magazinepage, refresh, search: _magazineSearchQuery))
          );
          
          data.addAll(primaryResults);
          for (int i = 0; i < secondaryResults.length; i++) {
            for (var p in secondaryResults[i]) {
              _postLabels[p.link] = "blog";
            }
            data.addAll(secondaryResults[i]);
          }
          data.sort((a, b) => (b.date ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.date ?? DateTime.fromMillisecondsSinceEpoch(0)));
        } else {
          data = primaryResults;
        }
      }

      if (data.isEmpty) {
        if (magazinepage == 1) {
          if (_wparticles.isEmpty) {
            allarticles = true;
          }
        } else {
          allarticles = true;
        }
      }

      if (magazinepage == 1) {
        _wparticles = List.from(data);
        magazinepage = 2;
      } else {
        _wparticles.addAll(data);
        magazinepage++;
      }

      ImagePrecacheService().precacheWpImages(data);
      setLoading("magazine_src", false);
    } catch (e) {
      AppLog.error("Error fetching WP magazine", error: e);
      setLoading("magazine_src", false);
    }
  }

  void setNewsSearchQuery(String? query) {
    if (_newsSearchQuery != query) {
      _newsSearchQuery = query;
      fetchWpNews(refresh: true);
    }
  }

  void setMagazineSearchQuery(String? query) {
    if (_magazineSearchQuery != query) {
      _magazineSearchQuery = query;
      fetchWpMagazine(refresh: true);
    }
  }

  Future<void> fetchMagazineCategories() async {
    if (_magazineSrc == null || _magazineSrc!.isEmpty) return;
    try {
      final categories = await WordPressService().fetchCategories(_magazineSrc!);
      _magazineCategories = List<Category>.from(categories);

      if (_secondaryMagazineUrls.isNotEmpty) {
        try {
          // Attempt to add a virtual Blog category
          _magazineCategories.add(Category.fromJson({
            'id': blogCategoryId,
            'name': 'Blog',
            'slug': 'blog',
            'count': 0,
            'description': '',
            'link': '',
            'taxonomy': 'category',
            'parent': 0,
          }));
        } catch (e) {
          AppLog.warn("Could not add virtual Blog category: $e");
        }
      }

      notifyListeners();
    } catch (e) {
      AppLog.error("Error fetching categories", error: e);
    }
  }

  void setMagazineCategory(int? categoryId) {
    if (_selectedMagazineCategoryId != categoryId) {
      _selectedMagazineCategoryId = categoryId;
      magazinepage = 1;
      allarticles = false;
      fetchWpMagazine(refresh: true); // Try cache first for the category
      notifyListeners();
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
    
    // Precache news images
    ImagePrecacheService().precacheWpImages(list);

    setLoading(category, false);
  }
}
