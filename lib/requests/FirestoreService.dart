import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:scenickazatva_app/models/UserData.dart';

class authService {
  static final authService _instance = authService._internal();
  factory authService() => _instance;
  authService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Future<User?> authFirebase() async {
    try {
      if (_firebaseAuth.currentUser != null) {
        return _firebaseAuth.currentUser;
      }
      final userCredential = await _firebaseAuth.signInAnonymously();
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth FAILED: ${e.code}");
      return null;
    }
  }

  Future<String> getFCMtoken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final fcmToken = await messaging.getToken();
      return fcmToken ?? "";
    }
    return "";
  }

  Future<UserData> getUserData(User user) async {
    try {
      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/${user.uid}");
      final snapshot = await userRef.get();
      
      if (snapshot.exists) {
        final data = jsonDecode(jsonEncode(snapshot.value)) as Map<String, dynamic>;
        return UserData.fromData(data);
      } else {
        // Initialize new user
        UserData newUser = UserData(
          id: user.uid,
          userRole: "user",
          email: user.email ?? "",
          fullName: user.displayName ?? "",
          timestamp: DateTime.now().toIso8601String(),
        );
        await saveUserData(newUser);
        return newUser;
      }
    } catch (e) {
      print("Error in getUserData: $e");
      return UserData(id: user.uid);
    }
  }

  Future<void> saveUserData(UserData user) async {
    try {
      await FirebaseDatabase.instance
          .ref("users/${user.id}")
          .update(user.toJson());
      print("Firebase UserData save success");
    } catch (error) {
      print("Error in saveUserData: $error");
    }
  }
}
