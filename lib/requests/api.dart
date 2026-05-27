import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:wordpress_client/wordpress_client.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_analytics/firebase_analytics.dart'; // imported for firebase messaging to log events
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
//import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:path_provider/path_provider.dart';

class API {
  final String selectedArrangement = '5e19cdd924cfa04fc3de1d3a';

  Future<String> getRestSrc(src) async {
    DatabaseReference optionsdb = FirebaseDatabase.instance.ref("appsettings");
    final options = await optionsdb.get();
    if (options.exists) {
      final _options = (options.value
          as Map); // https://github.com/firebase/flutterfire/issues/7945#issuecomment-1065871088
      return _options["festivals"][_options["defaultfestival"]][src];
    } else {
      print('No data in AppSettings');
      return "";
    }
  }

  Future<String> getdefaultfestival() async {
    DatabaseReference optionsdb = FirebaseDatabase.instance.ref("appsettings");
    final options = await optionsdb.get();
    if (options.exists) {
      final _options = (options.value as Map);
      return _options["defaultfestival"];
      //return "hk2025";
    } else {
      return "";
    }
  }

  Future<List<Post>> fetchWpNews(src, page, refresh) async {
    var _url = await getRestSrc(src);
    final baseUrl = Uri.parse(_url);
    List<Post> data = [];
    print(baseUrl);

    //var cacheStore = MemCacheStore(maxSize: 10485760, maxEntrySize: 1048576);

    var directory = null;
    if (!kIsWeb) {
      var cacheDir = !kIsWeb ? await getTemporaryDirectory() : null;
      directory = cacheDir!.path;
    }

    HiveCacheStore cacheStore = HiveCacheStore(
      directory,
      hiveBoxName: "scenickazatva",
    );
    var cacheOptions = CacheOptions(
      store: cacheStore,
      policy: refresh ? CachePolicy.refresh : CachePolicy.forceCache,
      priority: CachePriority.high,
      maxStale: const Duration(hours: 5),
      /*keyBuilder: (request) {
        return request.uri.toString();
      },*/
      keyBuilder: CacheOptions.defaultCacheKeyBuilder,
    );
    final client = WordpressClient(
        baseUrl: baseUrl,
        bootstrapper: (bootstrapper) => bootstrapper
            .withDioInterceptor(DioCacheInterceptor(options: cacheOptions))
            .build());

    final request = ListPostRequest(
        page: page, perPage: 20, extra: {"_embed": "wp:featuredmedia"});


     final wpResponse = await client.posts.list(request);
     print(wpResponse);

     if (wpResponse.code == 304 || wpResponse.code == 200){
       switch (wpResponse) {
         case WordpressSuccessResponse():
           data = wpResponse.data; // List<Post>
           break;

         case WordpressFailureResponse():
           final error = wpResponse.error; //// WordpressError
           print(error);
           break;
       }
     }else{
       print(wpResponse.code);
       return data;
     }

    return data;
  }

/*
  Future<String> fetchNews(src, page) async {
    try {
      var _url = await getRestSrc(src);
      _url = _url.toString() + page.toString();
      /* if (!kIsWeb) { */
      var file = await DefaultCacheManager()
          .getSingleFile(_url, headers: {'Cache-Control': 'max-age=0'});
      /*} else {
        print(_url);
        file = await getFileForWeb(_url);
        print(file);
      }*/

      if (await file.exists()) {
        final text = await file.readAsString();
        return text;
      }
      return "[]";
    } catch (e) {
      return "[]";
    }
  }
*/
  launchURL(url) async {
    final Uri _url = Uri.parse(url);
    if (await canLaunchUrl(_url)) {
      await launchUrl(_url, mode: LaunchMode.inAppWebView);
    } else {
      throw 'Could not launch $url';
    }
  }
}

class Analytics {
  sendEvent(id) async {
    await FirebaseAnalytics.instance.logEvent(
      name: "select_content",
      parameters: {"content_type": "post", "item_id": id},
    );
  }
}
