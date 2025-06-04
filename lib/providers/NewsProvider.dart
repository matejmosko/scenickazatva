import 'package:flutter/cupertino.dart';
//import 'package:scenickazatva_app/models/NewsPost.dart';
import 'package:scenickazatva_app/requests/api.dart';
import 'package:wordpress_client/wordpress_client.dart';




class NewsProvider extends ChangeNotifier {
  //List<NewsPost> _news = [];
  //List<NewsPost> _articles = [];
  List<Post> _wpnews = [];
  List<Post> _wparticles = [];
  bool newsLoading = false;
  bool articlesLoading = false;
  bool allnews = false;
  bool allarticles = false;
  int newspage = 1;
  int magazinepage = 1;

  NewsProvider() {
    fetchWpNews("news_src");
    fetchWpMagazine("magazine_src");
  }

  //List<NewsPost> get arrangements => _news;

  //List<NewsPost> get news => _news;
  List<Post> get wpnews => _wpnews;
  List<Post> get wparticles => _wparticles;
 // List<NewsPost> get articles => _articles;

  /*
  void /*Future<List<NewsPost>>*/ fetchNews(src, {refresh = false}) async {
    setLoading(true);
    if (refresh){
      allnews = false;
      newspage = 1;
    }

    API().fetchNews(src, newspage).then((data) {
      Iterable _list = json.decode(data);
      if (data == []) {
        allnews = true;
      }
      setArrangements(
          _list.map((model) => NewsPost.fromJson(model)).toList(), "news", refresh);
    });
  }
*/


  void /* Future<List<NewsPost>>*/ fetchWpMagazine(src,
      {refresh = false}) async {
    setLoading("articles", true);
    if (refresh) {
      allarticles = false;
      magazinepage = 1;
    }

    if (!allarticles) {
      API().fetchWpNews(src, magazinepage, refresh).then((data) {
        if (data == []) {
          allarticles = true;
        }
        setArrangementsWp(data, src, refresh);
      });
    }
  }

  void /* Future<List<NewsPost>>*/ fetchWpNews(src, {refresh = false}) async {
    setLoading("news", true);
    if (refresh) {
      allnews = false;
      newspage = 1;
    }
    if (!allnews) {

      API().fetchWpNews(src, newspage, refresh).then((data) {
        if (data == []) {
          allnews = true;
        }

        setArrangementsWp(data, src, refresh);
        //_list.map((model) => NewsPost.fromJson(model)).toList(), "news", refresh);
      });


    }
  }

  void setLoading(String category, bool val) {
    switch (category) {
      case "news":
        newsLoading = val;
        notifyListeners();
        break;
      case "magazine":
        articlesLoading = val;
        notifyListeners();
        break;
    }


  }
/*
  void setArrangements(List<NewsPost> list, category, refresh) {
    if (category == "news_src") {
      if (refresh) {
        _news = [];
        refresh = false;
      }
      _news = _news + list;
      newspage++;
    }
    if (category == "magazine_src") {
      if (refresh) {
        _articles = [];
        refresh = false;
      }
      _articles = _articles + list;
      magazinepage++;
    }
    setLoading(false);
    notifyListeners();
  }
  */

  void setArrangementsWp(List<Post> list, category, refresh) {
    switch (category) {
      case "news_src":
        if (refresh) {
          _wpnews = [];
          refresh = false;
        }
        _wpnews = _wpnews + list;

        newspage++;
        setLoading(category, false);
        notifyListeners();
        break;
      case "magazine_src":
        if (refresh) {
          _wparticles = [];
          refresh = false;
        }
        _wparticles = _wparticles + list;
        magazinepage++;
        setLoading(category, false);
        notifyListeners();
        break;
    }
  }

}
