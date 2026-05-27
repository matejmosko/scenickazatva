import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:scenickazatva_app/models/InfoPost.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:scenickazatva_app/models/Festival.dart';

class InfoProvider extends ChangeNotifier {
  List<InfoPost> _info = [InfoPost()];
  bool loading = false;
  StreamSubscription<DatabaseEvent>? _infoSubscription;
  String? _currentFestivalId;

  InfoProvider();

  List<InfoPost> get info => _info;

  void updateFromFestival(Festival festival) {
    if (_currentFestivalId != festival.id) {
      debugPrint("InfoProvider: Festival changed to ${festival.id}, updating subscription.");
      _currentFestivalId = festival.id;
      _fetchInfo(festival.id);
    }
  }

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
          // Firebase returns a Map or List. If it's ordered, it might come back as a Map with keys.
          final data = event.snapshot.value;
          List<dynamic> list = [];

          if (data is Map) {
            // Sort by keys if it's a map to maintain order
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
          debugPrint("Error parsing info data: $e");
          setLoading(false);
        }
      } else {
        setInfo([]);
      }
    }, onError: (error) {
      debugPrint("Info subscription error: $error");
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

  @override
  void dispose() {
    _infoSubscription?.cancel();
    super.dispose();
  }
}
