import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:scenickazatva_app/providers/NewsProvider.dart';
import 'package:wordpress_client/wordpress_client.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('news_provider_test');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    final box = await Hive.openBox('read_later');
    await box.clear();
    final articles = await Hive.openBox('read_articles');
    await articles.clear();
    await Hive.close();
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  Post makePost(int id, String link,
      {String title = 'Titulok', String excerpt = 'Úryvok'}) {
    return Post.fromJson({
      'id': id,
      'link': link,
      'title': {'rendered': title},
      'excerpt': {'rendered': excerpt},
      '_embedded': {
        'wp:featuredmedia': [
          {'source_url': 'https://example.com/img$id.jpg'}
        ]
      },
    });
  }

  Future<NewsProvider> openProvider() async {
    final provider = NewsProvider();
    await pumpEventQueue();
    return provider;
  }

  test('read-later toggle stores a post and persists it across providers',
      () async {
    final provider = await openProvider();
    expect(provider.isReadLater('https://example.com/1'), isFalse);

    await provider.toggleReadLater(makePost(1, 'https://example.com/1'),
        route: '/news/1');
    expect(provider.isReadLater('https://example.com/1'), isTrue);
    expect(provider.readLaterPosts, hasLength(1));
    expect(provider.readLaterPosts.single['title'], 'Titulok');
    expect(provider.readLaterPosts.single['excerpt'], 'Úryvok');
    expect(provider.readLaterPosts.single['route'], '/news/1');
    expect(provider.readLaterPosts.single['image'], 'https://example.com/img1.jpg');

    // A fresh provider instance reads the saved queue from the Hive box.
    final provider2 = await openProvider();
    expect(provider2.isReadLater('https://example.com/1'), isTrue);
    expect(provider2.readLaterPosts.single['title'], 'Titulok');
  });

  test('toggling read-later twice removes the entry', () async {
    final provider = await openProvider();
    await provider.toggleReadLater(makePost(1, 'https://example.com/1'),
        route: '/news/1');
    await provider.toggleReadLater(makePost(1, 'https://example.com/1'),
        route: '/news/1');
    expect(provider.isReadLater('https://example.com/1'), isFalse);
    expect(provider.readLaterPosts, isEmpty);
  });

  test('readLaterPosts is sorted newest first', () async {
    final provider = await openProvider();
    await provider.toggleReadLater(makePost(1, 'https://example.com/1'),
        route: '/news/1');
    await Future.delayed(const Duration(milliseconds: 5));
    await provider.toggleReadLater(makePost(2, 'https://example.com/2'),
        route: '/news/2');
    final posts = provider.readLaterPosts;
    expect(posts, hasLength(2));
    expect(posts.first['id'], 2);
    expect(posts.last['id'], 1);
  });

  test('removeReadLater deletes a single entry and persists', () async {
    final provider = await openProvider();
    await provider.toggleReadLater(makePost(1, 'https://example.com/1'),
        route: '/news/1');
    await provider.removeReadLater('https://example.com/1');
    expect(provider.readLaterPosts, isEmpty);

    final provider2 = await openProvider();
    expect(provider2.isReadLater('https://example.com/1'), isFalse);
  });

  test('news category selection updates state and resets pagination',
      () async {
    final provider = await openProvider();
    expect(provider.selectedNewsCategoryId, isNull);

    provider.setNewsCategory(5);
    expect(provider.selectedNewsCategoryId, 5);
    expect(provider.newspage, 1);
    expect(provider.allnews, isFalse);

    provider.setNewsCategory(null);
    expect(provider.selectedNewsCategoryId, isNull);
  });

  test('fetchPostById tries to fetch from all sources', () async {
    // This test verifies the logic of iterating through sources.
    // It won't hit the network because sources are empty by default, 
    // but we can check if it returns null gracefully.
    final provider = await openProvider();
    final result = await provider.fetchPostById(999);
    expect(result, isNull);
  });
}
