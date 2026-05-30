import 'package:flutter/foundation.dart' hide Category;
import 'dart:async';
import 'package:wordpress_client/wordpress_client.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scenickazatva_app/utils/StringUtils.dart';

/// Service for fetching news and magazine articles from WordPress REST APIs.
/// Features multi-site support, automatic caching, and offline access.
class WordPressService {
  static final WordPressService _instance = WordPressService._internal();
  factory WordPressService() => _instance;
  WordPressService._internal();

  // Active clients indexed by their base URL
  final Map<String, WordpressClient> _clients = {};
  HiveCacheStore? _cacheStore;

  /// Initializes the Hive box used for caching HTTP responses
  Future<HiveCacheStore> _getCacheStore() async {
    if (_cacheStore != null) return _cacheStore!;
    
    String? directory;
    if (!kIsWeb) {
      var cacheDir = await getTemporaryDirectory();
      directory = cacheDir.path;
    }
    
    _cacheStore = HiveCacheStore(
      directory,
      hiveBoxName: "scenickazatva_v2",
    );
    return _cacheStore!;
  }

  /// Returns a WordPress client for a specific URL, configuring cache policies
  Future<WordpressClient> _getClient(Uri baseUrl, bool refresh) async {
    final urlString = baseUrl.toString();
    
    final cacheStore = await _getCacheStore();
    final cacheOptions = CacheOptions(
      store: cacheStore,
      policy: refresh ? CachePolicy.refresh : CachePolicy.forceCache,
      priority: CachePriority.high,
      maxStale: const Duration(days: 30),
      keyBuilder: CacheOptions.defaultCacheKeyBuilder,
    );
    
    if (!_clients.containsKey(urlString)) {
      final client = WordpressClient(
        baseUrl: baseUrl,
        bootstrapper: (bootstrapper) => bootstrapper
            .withDioInterceptor(DioCacheInterceptor(options: cacheOptions))
            .build());
      _clients[urlString] = client;
    }
    
    return _clients[urlString]!;
  }

  /// Fetches a paginated list of posts from the specified WordPress URL.
  /// Automatically parses and preserves filters (like categories or tags) from the input URL.
  Future<List<Post>> fetchWpNews(String url, int page, bool refresh, {int? categoryId, String? search}) async {
    if (url.isEmpty) return [];
    
    try {
      // 1. Cleanup & Parsing
      Uri fullUri = Uri.parse(url);
      
      // Determine the API root. The library expects the path up to the namespace (e.g. /wp-json/wp/v2)
      String urlWithoutParams = fullUri.toString().split('?')[0];
      String base = urlWithoutParams;
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
      if (base.endsWith('/posts')) base = base.substring(0, base.length - 6);
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
      
      final baseUrl = Uri.parse(base);
      
      // Capture all existing filters/options from the URL
      Map<String, String> queryParams = Map.from(fullUri.queryParameters);
      
      final client = await _getClient(baseUrl, refresh);

      // 2. Build the request parameters
      Map<String, dynamic> extra = {};
      int perPage = 20;
      Order? order;
      List<int> categories = [];

      // Map parameters from the URL to the request
      queryParams.forEach((key, value) {
        if (key == 'per_page') {
          perPage = int.tryParse(value) ?? 20;
        } else if (key == 'order') {
          order = value.toLowerCase() == 'asc' ? Order.asc : Order.desc;
        } else if (key == 'page' || key == 'search') {
          // Ignored here, we use the function parameters
        } else if (key == '_embed' && (value == "" || value == "1")) {
          extra[key] = 'true';
        } else {
          extra[key] = value;
        }
      });

      // Always ensure at least featured media is embedded if not specified otherwise
      if (!extra.containsKey('_embed')) {
        extra['_embed'] = 'true';
      }

      if (categoryId != null && categoryId != 0) {
        categories.add(categoryId);
      }

      var request = ListPostRequest(
          page: page,
          perPage: perPage,
          order: order,
          search: search != null ? StringUtils.removeDiacritics(search.trim()) : null,
          categories: categories.isNotEmpty ? categories : null,
          extra: extra
      );

      // 3. Execute
      final wpResponse = await client.posts.list(request);

      if (wpResponse is WordpressSuccessResponse<List<Post>>) {
        return wpResponse.data;
      } else if (wpResponse is WordpressFailureResponse) {
        debugPrint("WP Error: ${wpResponse.message}");
      }
    } catch (e) {
      debugPrint("API Error: $e");
    }

    return [];
  }

  /// Fetches the list of categories for the given WordPress site.
  Future<List<Category>> fetchCategories(String url) async {
    if (url.isEmpty) return [];

    try {
      Uri fullUri = Uri.parse(url);
      String urlWithoutParams = fullUri.toString().split('?')[0];
      String base = urlWithoutParams;
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
      if (base.endsWith('/posts')) base = base.substring(0, base.length - 6);
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);

      final baseUrl = Uri.parse(base);

      final client = await _getClient(baseUrl, false);

      final request = ListCategoryRequest(
        perPage: 100,
      );

      final wpResponse = await client.categories.list(request);

      if (wpResponse is WordpressSuccessResponse<List<Category>>) {
        return wpResponse.data;
      }
    } catch (e) {
      debugPrint("API Error fetching categories: $e");
    }

    return [];
  }
}
