import 'package:flutter/foundation.dart' hide Category;
import 'dart:async';
import 'package:wordpress_client/wordpress_client.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';
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
      var cacheDir = await getApplicationSupportDirectory();
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
      // Serve the stale cached copy when a request fails offline so previously
      // fetched lists/articles stay readable without a connection.
      hitCacheOnNetworkFailure: true,
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
      
      // Determine the API root and endpoint.
      String urlWithoutParams = fullUri.toString().split('?')[0];
      String base = _getRestBase(url);
      String endpoint = 'posts';

      if (urlWithoutParams.contains('/wp/v2/')) {
        int index = urlWithoutParams.indexOf('/wp/v2/');
        String rest = urlWithoutParams.substring(index + 7);
        if (rest.isNotEmpty) {
          endpoint = rest;
          if (endpoint.endsWith('/')) {
            endpoint = endpoint.substring(0, endpoint.length - 1);
          }
        }
      }
      
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
      WordpressResponse<List<Post>> wpResponse;
      
      if (endpoint == 'posts') {
        wpResponse = await client.posts.list(request);
      } else {
        // Build manual query params for raw request to support Custom Post Types
        final Map<String, dynamic> finalParams = Map.from(queryParams);
        finalParams['page'] = page;
        finalParams['per_page'] = perPage;
        if (order != null) finalParams['order'] = order == Order.asc ? 'asc' : 'desc';
        if (search != null) finalParams['search'] = StringUtils.removeDiacritics(search.trim());
        if (categories.isNotEmpty) finalParams['categories'] = categories.join(',');
        finalParams.addAll(extra);
        
        final rawResponse = await client.raw(WordpressRequest(
          url: RequestUrl.relative(endpoint),
          method: HttpMethod.get,
          queryParameters: finalParams,
        ));
        
        wpResponse = rawResponse.asResponse<List<Post>>(
          decoder: (data) => (data as Iterable<dynamic>).map((e) => Post.fromJson(e as Map<String, dynamic>)).toList(),
        );
      }

      if (wpResponse is WordpressSuccessResponse<List<Post>>) {
        return wpResponse.data;
      } else if (wpResponse is WordpressFailureResponse<List<Post>>) {
        AppLog.error("WP Error: ${wpResponse.message}");
        if (wpResponse.error != null) {
          AppLog.error("WP Error Details: ${wpResponse.error}");
        }
        // Log the request parameters to help debug Bad Request
        AppLog.warn("WP Request Failed for URL: $url, Page: $page, Search: $search, Category: $categoryId");
      }
    } catch (e) {
      AppLog.error("API Error", error: e);
    }

    return [];
  }

  /// Fetches the list of categories for the given WordPress site.
  Future<List<Category>> fetchCategories(String url) async {
    if (url.isEmpty) return [];

    try {
      final base = _getRestBase(url);
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
      AppLog.error("API Error fetching categories", error: e);
    }

    return [];
  }

  /// Fetches a single post by ID.
  Future<Post?> fetchSinglePost(String url, int id, bool refresh) async {
    if (url.isEmpty) return null;

    try {
      final base = _getRestBase(url);
      final baseUrl = Uri.parse(base);
      final client = await _getClient(baseUrl, refresh);

      String endpoint = 'posts';
      if (url.contains('/wp/v2/')) {
        int index = url.indexOf('/wp/v2/');
        String rest = url.substring(index + 7);
        if (rest.isNotEmpty) {
          endpoint = rest.split('?')[0];
          if (endpoint.endsWith('/')) {
            endpoint = endpoint.substring(0, endpoint.length - 1);
          }
        }
      }

      WordpressResponse<Post> wpResponse;
      if (endpoint == 'posts') {
        final request = RetrievePostRequest(
          id: id,
          extra: {'_embed': 'true'},
        );
        wpResponse = await client.posts.retrieve(request);
      } else {
        final rawResponse = await client.raw(WordpressRequest(
          url: RequestUrl.relative('$endpoint/$id'),
          method: HttpMethod.get,
          queryParameters: {'_embed': 'true'},
        ));
        wpResponse = rawResponse.asResponse<Post>(
          decoder: (data) => Post.fromJson(data as Map<String, dynamic>),
        );
      }

      if (wpResponse is WordpressSuccessResponse<Post>) {
        return wpResponse.data;
      }
    } catch (e) {
      AppLog.error("API Error fetching single post $id from $url", error: e);
    }

    return null;
  }

  /// Extracts the REST API base URL from a given WordPress URL.
  String _getRestBase(String url) {
    Uri fullUri = Uri.parse(url);
    String urlWithoutParams = fullUri.toString().split('?')[0];
    String base = urlWithoutParams;

    if (base.contains('/wp/v2/')) {
      int index = base.indexOf('/wp/v2/');
      base = base.substring(0, index + 6);
    } else {
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
      if (base.endsWith('/posts')) base = base.substring(0, base.length - 6);
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    }
    return base;
  }
}
