import 'package:flutter/cupertino.dart';
import 'package:scenickazatva_app/requests/WordPressService.dart';
import 'package:wordpress_client/wordpress_client.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/models/AppSettings.dart';
import 'package:hive_ce/hive.dart';
import 'package:scenickazatva_app/requests/ImagePrecacheService.dart';

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
  String? _magazineSrc2;
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
      debugPrint("NewsProvider: Update triggered. Festival changed: $festivalChanged, News updated: $newsUpdated");
      
      if (festivalChanged) {
        _currentFestivalId = festival.id;
        _newsSrc = festival.news_src;
        _magazineSrc = festival.magazine_src;
        _magazineSrc2 = (festival as dynamic).magazine_src2;

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
      debugPrint("NewsProvider: Magazine updated signal received.");
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
        debugPrint("News is already up to date. Skipping network request. ID: $_lastNewsPostId");
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
      debugPrint("Error fetching WP news: $e");
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
          cachedData = await WordPressService().fetchWpNews(_magazineSrc2!, 1, false, search: _magazineSearchQuery);
          for (var p in cachedData) {
            _postLabels[p.link] = "blog";
          }
        } else if (_selectedMagazineCategoryId != null) {
          cachedData = await WordPressService().fetchWpNews(_magazineSrc!, 1, false, categoryId: _selectedMagazineCategoryId, search: _magazineSearchQuery);
        } else {
          if (_magazineSrc2 != null && _magazineSrc2!.isNotEmpty) {
            final results = await Future.wait([
              WordPressService().fetchWpNews(_magazineSrc!, 1, false, search: _magazineSearchQuery),
              WordPressService().fetchWpNews(_magazineSrc2!, 1, false, search: _magazineSearchQuery),
            ]);
            for (var p in results[1]) {
              _postLabels[p.link] = "blog";
            }
            cachedData = [...results[0], ...results[1]];
            cachedData.sort((a, b) {
              final dateA = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
              final dateB = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
              return dateB.compareTo(dateA);
            });
          } else {
            cachedData = await WordPressService().fetchWpNews(_magazineSrc!, 1, false, search: _magazineSearchQuery);
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
        debugPrint("Magazine is already up to date. Skipping network request. ID: $_lastMagazinePostId");
        setLoading("magazine_src", false);
        return;
      }

      List<Post> data = [];
      if (_selectedMagazineCategoryId == blogCategoryId) {
        data = await WordPressService().fetchWpNews(_magazineSrc2!, magazinepage, refresh, search: _magazineSearchQuery);
        for (var p in data) {
          _postLabels[p.link] = "blog";
        }
      } else if (_selectedMagazineCategoryId != null) {
        data = await WordPressService().fetchWpNews(_magazineSrc!, magazinepage, refresh, categoryId: _selectedMagazineCategoryId, search: _magazineSearchQuery);
      } else {
        if (_magazineSrc2 != null && _magazineSrc2!.isNotEmpty) {
          final results = await Future.wait([
            WordPressService().fetchWpNews(_magazineSrc!, magazinepage, refresh, search: _magazineSearchQuery),
            WordPressService().fetchWpNews(_magazineSrc2!, magazinepage, refresh, search: _magazineSearchQuery),
          ]);
          for (var p in results[1]) {
            _postLabels[p.link] = "blog";
          }
          data = [...results[0], ...results[1]];
          data.sort((a, b) {
            final dateA = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dateB = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA);
          });
        } else {
          data = await WordPressService().fetchWpNews(_magazineSrc!, magazinepage, refresh, search: _magazineSearchQuery);
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
      debugPrint("Error fetching WP magazine: $e");
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

      if (_magazineSrc2 != null && _magazineSrc2!.isNotEmpty) {
        try {
          // Attempt to add a virtual Blog category if we can instantiate it
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
          debugPrint("Could not add virtual Blog category: $e");
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching categories: $e");
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
