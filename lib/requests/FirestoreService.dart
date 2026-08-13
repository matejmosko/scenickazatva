import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:scenickazatva_app/models/UserData.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';

/// Service for managing Firebase Authentication and user profile synchronization
/// with the Realtime Database.
class authService {
  static final authService _instance = authService._internal();
  factory authService() => _instance;
  authService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// Ensures a user is authenticated (signs in anonymously if no user is present)
  Future<User?> authFirebase() async {
    try {
      if (_firebaseAuth.currentUser != null) {
        return _firebaseAuth.currentUser;
      }
      final userCredential = await _firebaseAuth.signInAnonymously();
      
      // Initialize DB record for anonymous user
      if (userCredential.user != null) {
        await getUserData(userCredential.user!);
      }
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      AppLog.error("Firebase Auth FAILED: ${e.code}", error: e);
      return null;
    }
  }

  /// Requests notification permission and retrieves the unique FCM device token
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

  /// Fetches user metadata from DB or initializes a new record.
  /// Roles are assigned server-side by a Cloud Function (predefinedRoles is
  /// not client-readable), so this only syncs safe profile fields.
  Future<UserData> getUserData(User user) async {
    try {
      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/${user.uid}");
      final snapshot = await userRef.get();
      
      if (snapshot.exists) {
        final data = jsonDecode(jsonEncode(snapshot.value)) as Map<String, dynamic>;
        UserData existingUser = UserData.fromData(data);
        
        bool needsUpdate = false;

        // Sync Auth metadata to DB (userRole is excluded from the write).
        // id must always match the auth UID (self-heals legacy records that
        // predate the id field, which left GameProvider._uid empty).
        if (existingUser.id != user.uid) {
          existingUser.id = user.uid;
          needsUpdate = true;
        }
        if (user.email != null && user.email != existingUser.email) {
          existingUser.email = user.email!;
          needsUpdate = true;
        }
        if (user.displayName != null && user.displayName != existingUser.fullName) {
          existingUser.fullName = user.displayName!;
          needsUpdate = true;
        }
        
        if (needsUpdate) {
          await saveUserData(existingUser);
        }
        
        return existingUser;
      } else {
        // Initialize new user record (role is assigned by the Cloud Function)
        UserData newUser = UserData(
          id: user.uid,
          email: user.email ?? "",
          fullName: user.displayName ?? "",
          timestamp: DateTime.now().toIso8601String(),
        );
        await saveUserData(newUser);
        return newUser;
      }
    } catch (e) {
      AppLog.error("Error in getUserData", error: e);
      return UserData(id: user.uid);
    }
  }

  /// Persists user profile changes to Firebase.
  /// userRole is never written by clients; it is managed by the Cloud Function.
  Future<void> saveUserData(UserData user) async {
    try {
      // Security: toSafeJson() excludes userRole to prevent role elevation
      final data = user.toSafeJson();
      
      await FirebaseDatabase.instance
          .ref("users/${user.id}")
          .update(data);
      AppLog.info("Firebase UserData save success");
    } catch (error) {
      AppLog.error("Error in saveUserData", error: error);
    }
  }
}
