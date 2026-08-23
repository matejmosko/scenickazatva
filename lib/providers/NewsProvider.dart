import 'package:flutter/cupertino.dart';
import 'package:scenickazatva_app/requests/WordPressService.dart';
import 'package:wordpress_client/wordpress_client.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/models/AppSettings.dart';
import 'package:hive_ce/hive.dart';
import 'package:scenickazatva_app/requests/ImagePrecacheService.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';
import 'package:scenickazatva_app/requests/ConnectivityService.dart';
import 'package:scenickazatva_app/utils/StringUtils.dart';
import 'package:scenickazatva_app/models/PostExtension.dart';
import 'package:cloud_functions/cloud_functions.dart';

class NewsProvider extends ChangeNotifier {
  static const int blogCategoryId = 999999;
  List<Post> _wpnews = [];
  List<Post> _wparticles = [];
  List<Category> _magazineCategories = [];
  List<Category> _newsCategories = [];
  final Map<String, String> _postLabels = {};
  int? _selectedMagazineCategoryId;
  int? _selectedNewsCategoryId;
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

  final Map<String, Map<String, dynamic>> _readLaterPosts = {};
  Box? _readLaterBox;

  String? _currentFestivalId;
  String? _newsSrc;
  String? _magazineSrc;
  List<String> _secondaryMagazineUrls = [];
  int _lastNewsPostId = 0;
  int _lastMagazinePostId = 0;

  // Cache of metadata healing attempts in the current session to avoid redundant Cloud Function calls.
  static final Set<String> _healedIds = {};

  NewsProvider() {
    _initReadArticles();
    _initReadLater();
  }

  Future<void> _initReadArticles() async {
    _readArticlesBox = await Hive.openBox('read_articles');
    final List<dynamic> ids = _readArticlesBox!.get('ids', defaultValue: []);
    _readArticleIds = ids.cast<int>().toSet();
    notifyListeners();
  }

  Future<void> _initReadLater() async {
    _readLaterBox = await Hive.openBox('read_later');
    final raw = _readLaterBox!.get('posts', defaultValue: <String, dynamic>{});
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is Map) {
          _readLaterPosts[key.toString()] = Map<String, dynamic>.from(value);
        }
      });
    }
    notifyListeners();
  }

  List<Post> get wpnews => _wpnews;
  List<Post> get wparticles => _wparticles;
  List<Category> get magazineCategories => _magazineCategories;
  List<Category> get newsCategories => _newsCategories;
  String getPostLabel(String link) => _postLabels[link] ?? "";
  int? get selectedMagazineCategoryId => _selectedMagazineCategoryId;
  int? get selectedNewsCategoryId => _selectedNewsCategoryId;
  int get unreadMagazineCount => _wparticles.where((p) => !_readArticleIds.contains(p.id)).length;
  int get unreadNewsCount => _wpnews.where((p) => !_readArticleIds.contains(p.id)).length;
  String? get newsSearchQuery => _newsSearchQuery;
  String? get magazineSearchQuery => _magazineSearchQuery;

  bool isRead(int? id) => id == null || _readArticleIds.contains(id);

  // --- Read later queue ---

  bool isReadLater(String link) => _readLaterPosts.containsKey(link);

  /// Read-later posts, most recently saved first. Entries store title/excerpt/
  /// image locally so the queue remains browsable offline.
  List<Map<String, dynamic>> get readLaterPosts {
    final list = _readLaterPosts.values.toList();
    list.sort((a, b) =>
        (b['savedAt'] as int? ?? 0).compareTo(a['savedAt'] as int? ?? 0));
    return list;
  }

  Future<void> toggleReadLater(Post post, {required String route}) async {
    final link = post.link;
    if (_readLaterPosts.containsKey(link)) {
      _readLaterPosts.remove(link);
    } else {
      _readLaterPosts[link] = {
        'id': post.id,
        'title': post.title?.rendered?.replaceAll('&amp;', '&') ?? '',
        'link': link,
        'excerpt': StringUtils.stripHtml(post.excerpt?.rendered ?? ''),
        'image': post.featuredImageSourceUrl(),
        'route': route,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      };
    }
    notifyListeners();
    if (_readLaterBox != null) {
      await _readLaterBox!.put('posts', Map<String, dynamic>.from(_readLaterPosts));
    }
  }

  Future<void> removeReadLater(String link) async {
    if (_readLaterPosts.remove(link) != null) {
      notifyListeners();
      if (_readLaterBox != null) {
        await _readLaterBox!.put('posts', Map<String, dynamic>.from(_readLaterPosts));
      }
    }
  }

  /// Offline fallback for the article detail page: locates a post by id in any
  /// of the configured sources. The WP HTTP cache (Hive-backed) serves the
  /// payload without a connection.
  Future<Post?> fetchPostById(int id) async {
    final sources = <String>{
      if (_newsSrc != null && _newsSrc!.isNotEmpty) _newsSrc!,
      if (_magazineSrc != null && _magazineSrc!.isNotEmpty) _magazineSrc!,
      ..._secondaryMagazineUrls,
    };
    for (final src in sources) {
      try {
        final post = await WordPressService().fetchSinglePost(src, id, false);
        if (post != null) return post;
      } catch (e) {
        AppLog.error("fetchPostById error for $src", error: e);
      }
    }
    return null;
  }

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

  void markAllNewsAsRead() {
    for (var post in _wpnews) {
      _readArticleIds.add(post.id);
    }
    _readArticlesBox?.put('ids', _readArticleIds.toList());
    notifyListeners();
  }

  void updateFromFestival(Festival festival) {
    bool festivalChanged = _currentFestivalId != festival.id;
    bool newsSignalReceived = _lastNewsPostId != festival.lastNewsPostId;

    if (festivalChanged) {
      AppLog.info("NewsProvider: Festival changed: ${festival.id}");
      
      _currentFestivalId = festival.id;
      _lastNewsPostId = festival.lastNewsPostId;
      
      _newsSrc = festival.news_src;
      _magazineSrc = festival.magazine_src;
      _secondaryMagazineUrls = festival.magazine_blog_srcs
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // Clear all data when festival changes
      _wpnews = [];
      _wparticles = [];
      _magazineCategories = [];
      _newsCategories = [];
      _selectedMagazineCategoryId = null;
      _selectedNewsCategoryId = null;
      newspage = 1;
      magazinepage = 1;
      allnews = false;
      allarticles = false;

      newsLoading = false;
      articlesLoading = false;

      notifyListeners();

      fetchWpNews(refresh: true);
      fetchWpMagazine(refresh: true);
      fetchMagazineCategories();
      fetchNewsCategories();
    } else if (newsSignalReceived) {
      // Signal: new article published (Cloud Function updated festival.lastNewsPostId)
      AppLog.info("NewsProvider: News update signal received. ID: ${festival.lastNewsPostId}");
      _lastNewsPostId = festival.lastNewsPostId;
      if (_newsSrc != null && _newsSrc!.isNotEmpty) {
        fetchWpNews(refresh: true);
      }
    }
  }

  void updateFromSettings(AppSettings settings) {
    // Signal: new magazine article (Cloud Function updated lastMagazinePostId)
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
      // This provides a "shimmer" effect with old data while fetching.
      if (refresh && _wpnews.isEmpty) {
        final cachedData = await WordPressService().fetchWpNews(_newsSrc!, 1, false, search: _newsSearchQuery, categoryId: _selectedNewsCategoryId);
        if (cachedData.isNotEmpty) {
          _wpnews = List.from(cachedData);
          notifyListeners();
        }
      }

      // 2. Skip network if already up-to-date (unless explicit refresh)
      if (!refresh &&
          _newsSearchQuery == null &&
          _selectedNewsCategoryId == null &&
          _wpnews.isNotEmpty &&
          _wpnews.first.id == _lastNewsPostId) {
        AppLog.info("News is already up to date. Skipping network request. ID: $_lastNewsPostId");
        setLoading("news_src", false);
        return;
      }

      final fetchPage = refresh ? 1 : newspage;
      final data = await WordPressService().fetchWpNews(_newsSrc!, fetchPage, refresh, search: _newsSearchQuery, categoryId: _selectedNewsCategoryId);
      
      if (data.isEmpty) {
        if (fetchPage == 1) {
          if (_wpnews.isEmpty || refresh) {
            _wpnews = [];
            allnews = true;
          }
        } else {
          allnews = true;
        }
      } else {
        if (fetchPage == 1) {
          _wpnews = List.from(data);
          newspage = 2;

          // Metadata Healing: Any user can trigger a global ID update signal if a newer post is found.
          if (data.isNotEmpty && data.first.id > _lastNewsPostId) {
            final id = data.first.id;
            _lastNewsPostId = id; // Update locally immediately

            final healKey = "$_currentFestivalId-$id";
            if (!_healedIds.contains(healKey)) {
              _healedIds.add(healKey); // Optimistically mark as healed
              AppLog.info("Invoking updateLatestNewsId for $_currentFestivalId to $id");
              FirebaseFunctions.instanceFor(region: 'europe-west1')
                  .httpsCallable('updateLatestNewsId')
                  .call({
                'festivalId': _currentFestivalId,
                'postId': id,
              }).then((_) {
                AppLog.info("Metadata healed successfully.");
              }).catchError((e) {
                AppLog.warn("Failed to heal metadata via Cloud Function: $e");
                return null;
              });
            }
          }
        } else {
          _wpnews.addAll(data);
          newspage++;
        }
      }

      ImagePrecacheService().precacheWpImages(data);
      setLoading("news_src", false);
    } catch (e) {
      AppLog.error("Error fetching WP news", error: e);
      ConnectivityService.instance.showTemporaryBanner(
          "Nepodarilo sa načítať novinky — skúste znova");
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

      final fetchPage = refresh ? 1 : magazinepage;
      List<Post> data = [];
      if (_selectedMagazineCategoryId == blogCategoryId) {
        final results = await Future.wait(
          _secondaryMagazineUrls.map((url) => WordPressService().fetchWpNews(url, fetchPage, refresh, search: _magazineSearchQuery))
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
        data = await WordPressService().fetchWpNews(_magazineSrc!, fetchPage, refresh, categoryId: _selectedMagazineCategoryId, search: _magazineSearchQuery);
      } else {
        final primaryResults = await WordPressService().fetchWpNews(_magazineSrc!, fetchPage, refresh, search: _magazineSearchQuery);
        
        if (_secondaryMagazineUrls.isNotEmpty) {
          final secondaryResults = await Future.wait(
            _secondaryMagazineUrls.map((url) => WordPressService().fetchWpNews(url, fetchPage, refresh, search: _magazineSearchQuery))
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
        if (fetchPage == 1) {
          if (_wparticles.isEmpty || refresh) {
            _wparticles = [];
            allarticles = true;
          }
        } else {
          allarticles = true;
        }
      } else {
        if (fetchPage == 1) {
          _wparticles = List.from(data);
          magazinepage = 2;
        } else {
          _wparticles.addAll(data);
          magazinepage++;
        }
      }

      ImagePrecacheService().precacheWpImages(data);
      setLoading("magazine_src", false);
    } catch (e) {
      AppLog.error("Error fetching WP magazine", error: e);
      ConnectivityService.instance.showTemporaryBanner(
          "Nepodarilo sa načítať články — skúste znova");
      setLoading("magazine_src", false);
    }
  }

  void setNewsSearchQuery(String? query) {
    if (_newsSearchQuery != query) {
      _newsSearchQuery = query;
      fetchWpNews(refresh: true);
    }
  }

  /// Fetches the category list for the festival news feed (shown as a filter
  /// dropdown above the news list).
  Future<void> fetchNewsCategories() async {
    if (_newsSrc == null || _newsSrc!.isEmpty) return;
    try {
      final categories = await WordPressService().fetchCategories(_newsSrc!);
      _newsCategories = List<Category>.from(categories);
      notifyListeners();
    } catch (e) {
      AppLog.error("Error fetching news categories", error: e);
    }
  }

  void setNewsCategory(int? categoryId) {
    if (_selectedNewsCategoryId != categoryId) {
      _selectedNewsCategoryId = categoryId;
      newspage = 1;
      allnews = false;
      fetchWpNews(refresh: true); // Try cache first for the category
      notifyListeners();
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
