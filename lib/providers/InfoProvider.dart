import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:scenickazatva_app/models/InfoPost.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';

/// Provider for managing general festival information (static content).
/// Synchronizes with Firebase Realtime Database and supports administrative edits.
class InfoProvider extends ChangeNotifier {
  // List of informational posts (e.g., tickets, directions, about)
  List<InfoPost> _info = [];
  bool loading = false;
  StreamSubscription<DatabaseEvent>? _infoSubscription;
  String? _currentFestivalId;
  bool _canEdit = false;

  InfoProvider();

  List<InfoPost> get info => _info;

  /// Updates local permission state from UserProvider
  void updateFromUser(bool canEdit) {
    _canEdit = canEdit;
  }

  /// Reacts to festival changes and updates the data stream
  void updateFromFestival(Festival festival) {
    if (_currentFestivalId != festival.id) {
      _currentFestivalId = festival.id;
      _fetchInfo(festival.id);
    }
  }

  /// Subscribes to info posts for the current festival
  void _fetchInfo(String festivalId) async {
    await _infoSubscription?.cancel();
    setLoading(true);

    final infodb = FirebaseDatabase.instance.ref("festivals/$festivalId/info").orderByChild("id");
    
    if (!kIsWeb) {
      infodb.keepSynced(true);
    }

    _infoSubscription = infodb.onValue.listen((DatabaseEvent event) {
      if (event.snapshot.exists) {
        try {
          final data = event.snapshot.value;
          List<dynamic> list = [];

          // Handle Map (keyed) vs List formats from Firebase
          if (data is Map) {
            var sortedKeys = data.keys.toList()..sort();
            for (var key in sortedKeys) {
              list.add(data[key]);
            }
          } else if (data is List) {
            list = data;
          }

          setInfo(
            list.where((e) => e != null).map((model) => InfoPost.fromJson(Map<String, dynamic>.from(model))).toList(),
          );
        } catch (e) {
          AppLog.error("Error parsing info data", error: e);
          setLoading(false);
        }
      } else {
        setInfo([]);
      }
    }, onError: (error) {
      AppLog.error("Info subscription error", error: error);
      setLoading(false);
    });
  }

  void setLoading(bool val) {
    loading = val;
    notifyListeners();
  }

  void setInfo(List<InfoPost> list) {
    _info = list;
    setLoading(false);
    notifyListeners();
  }

  /// Updates an existing info post (authorized only)
  Future<void> updateInfoPost(InfoPost post) async {
    if (!_canEdit) {
      AppLog.warn("Unauthorized info update attempt blocked");
      return;
    }
    try {
      setLoading(true);
      if (_currentFestivalId != null && post.id.isNotEmpty) {
        await FirebaseDatabase.instance
            .ref("festivals/$_currentFestivalId/info/${post.id}")
            .update(post.toJson());
        AppLog.info("Firebase info save success");
      }
    } catch (error) {
      AppLog.error("Firebase info update error", error: error);
    } finally {
      setLoading(false);
    }
  }

  /// Creates a new info post (authorized only)
  Future<String?> createInfoPost(InfoPost post) async {
    if (!_canEdit) {
      AppLog.warn("Unauthorized info create attempt blocked");
      return null;
    }
    try {
      setLoading(true);
      if (_currentFestivalId != null) {
        DatabaseReference newRef = FirebaseDatabase.instance
            .ref("festivals/$_currentFestivalId/info")
            .push();
        post.id = newRef.key ?? "";
        await newRef.set(post.toJson());
        AppLog.info("Firebase info create success: ${post.id}");
        return post.id;
      }
    } catch (error) {
      AppLog.error("Firebase info create error", error: error);
    } finally {
      setLoading(false);
    }
    return null;
  }

  /// Deletes an info post (authorized only)
  Future<void> deleteInfoPost(String postId) async {
    if (!_canEdit) {
      AppLog.warn("Unauthorized info delete attempt blocked");
      return;
    }
    try {
      setLoading(true);
      if (_currentFestivalId != null && postId.isNotEmpty) {
        await FirebaseDatabase.instance
            .ref("festivals/$_currentFestivalId/info/$postId")
            .remove();
        AppLog.info("Firebase info delete success");
      }
    } catch (error) {
      AppLog.error("Firebase info delete error", error: error);
    } finally {
      setLoading(false);
    }
  }

  @override
  void dispose() {
    _infoSubscription?.cancel();
    super.dispose();
  }
}
