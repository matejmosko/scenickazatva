import 'package:flutter/cupertino.dart';
import 'package:scenickazatva_app/models/Arrangement.dart';

class ArrangementProvider extends ChangeNotifier {
  List<Arrangement> _arrangements = [];
  bool loading = false;

  ArrangementProvider(){
    fetchArrangements();
  }

  List<Arrangement> get arrangements => _arrangements;

  void /*Future<List<Arrangement>>*/ fetchArrangements() async {
    setLoading(true);
   /* API().fetchArrangements().then((data) {
      if (data.statusCode == 200) {
        Iterable list = json.decode(utf8.decode(data.bodyBytes));
        setArrangements(
          list.map((model) => Arrangement.fromJson(model)).toList(),
        );
      }
    });*/
  }

  void setLoading(bool val) {
    loading = val;
    notifyListeners();
  }

  void setArrangements(List<Arrangement> list) {
    _arrangements = list;
    //print(list);
    notifyListeners();
  }
}
