import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:scenickazatva_app/models/InfoPost.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:scenickazatva_app/requests/api.dart';

class InfoProvider extends ChangeNotifier {
  List<InfoPost> _info = [InfoPost()];
  bool loading = false;

  InfoProvider() {
    fetchInfo();
  }

  List<InfoPost> get info => _info;

  void /*Future<List<InfoPost>>*/ fetchInfo() async {
    setLoading(true);
    FirebaseDatabase database = FirebaseDatabase.instance;
    if(!kIsWeb){database.setPersistenceEnabled(true);}


    String festival = await API().getdefaultfestival();
    final infodb = FirebaseDatabase.instance.ref("festivals/$festival/info").orderByChild("id");
    if(!kIsWeb){infodb.keepSynced(true);}
    // Get the Stream
    Stream<DatabaseEvent> stream = infodb.onValue;

// Subscribe to the stream!
    stream.listen((DatabaseEvent info) {
      List<dynamic> list = [];
      Map validMap = json.decode(json.encode(info.snapshot.value));
      var sortedKeys = validMap.keys.toList()..sort();
      for (var it = 0; it < sortedKeys.length; it++) {
        list.add(validMap[sortedKeys[it]]);
      }
/*      for (var e in validMap.values) {
        list.add(e);
      }*/

      setInfo(
        list.map((model) => InfoPost.fromJson(model)).toList(),
      );
    });
    /*API().fetchInfo().then((data) {
      if (data.statusCode == 200) {
        Iterable list = json.decode(utf8.decode(data.bodyBytes));
        setInfo(
          list.map((model) => InfoPost.fromJson(model)).toList(),
        );
      }
    });*/
  }

  void setLoading(bool val) {
    loading = val;
    notifyListeners();
  }

  void setInfo(List<InfoPost> list) {
    _info = list;
    notifyListeners();
    setLoading(false);
  }
}
