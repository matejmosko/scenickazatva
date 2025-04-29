import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:scenickazatva_app/models/UserData.dart';

class authService {
  var userData;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  authService() {
    //getFCMtoken();
    //authFirebase();
  }

  Future<UserCredential?> authFirebase() async {
    try {
      final userCredential = await _firebaseAuth.signInAnonymously();
      userData = userCredential;
      return userData;

      /* Log user login time */
    } on FirebaseAuthException catch (e) {
      /* Catch login errors */
      switch (e.code) {
        case "operation-not-allowed":
          print("Anonymous auth hasn't been enabled for this project.");
          break;
        default:
          print("Firebase Auth FAILED: " + e.code);
      }
      return null;
    }
  }

  Future<String> getFCMtoken() async{
    FirebaseMessaging _messaging;
    _messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission: ${settings.authorizationStatus}');
    } else {
      print('User declined or has not accepted permission');
    }

    final fcmToken = await _messaging.getToken();
    return fcmToken ?? "";
  }

  Future<UserData> getUserData(user) async{
    UserData result = UserData();
    if (user == null) {
      print('(getting) User is currently signed out! We cannot get data');
    } else {
      print('(getting) User is signed in with UID: ' + user.uid);
      try {

        var _uid = user.uid;
        DatabaseReference _usersdb = FirebaseDatabase.instance.ref("users/$_uid");
        var _user = await _usersdb.get();
        if (_user.value == null ) {
          await saveUserData(UserData(
            id: user.uid,
            userRole: "user"
          ));
          _user = await _usersdb.get();
        }
        //var json = jsonEncode(_user.value);
        //print(json);

        final temp = jsonDecode(jsonEncode(_user.value)) as Map<String, dynamic>;

       result = UserData.fromData(temp); // type '_Map<Object?, Object?>' is not a subtype of type 'Map<String, dynamic>' in type cast
        print(await result.id);
        saveUserData(result);
        return result;
      } catch (e) {
        print(e);
      }
    }
    return result;
  }

  Future<UserData> saveUserData(UserData _user) async{
    if (_user == {}) {
      print('(saving) User is currently signed out! We cannot get data');
    } else {
      print('(saving) User is signed in with UID: ' + _user.id);

        FirebaseDatabase.instance
            .ref("users/" + _user.id)
            .update(_user.toJson())
            .then((_) {
             print("Firebase save success");
        }).catchError((error) {
          print(error);
        });
    }
    return _user;
  }

}
