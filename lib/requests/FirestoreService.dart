import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:scenickazatva_app/models/UserData.dart';

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
      debugPrint("Firebase Auth FAILED: ${e.code}");
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
  /// Also handles automatic role assignment from the predefinedRoles list.
  Future<UserData> getUserData(User user) async {
    try {
      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/${user.uid}");
      final snapshot = await userRef.get();
      
      if (snapshot.exists) {
        final data = jsonDecode(jsonEncode(snapshot.value)) as Map<String, dynamic>;
        UserData existingUser = UserData.fromData(data);
        
        bool needsUpdate = false;
        
        // 1. Role Assignment Logic (checks appsettings/predefinedRoles)
        if (user.email != null && user.email!.isNotEmpty) {
          String normalizedEmail = user.email!.toLowerCase().trim();
          
          final rolesRef = FirebaseDatabase.instance.ref("appsettings/predefinedRoles");
          final rolesSnapshot = await rolesRef.get();
          
          if (rolesSnapshot.exists) {
             final Object? rawRoles = rolesSnapshot.value;
             if (rawRoles is Map) {
               final rolesData = rawRoles;
               String? assignedRole;
               
               // Search through role categories (admin, editor, etc.)
               rolesData.forEach((role, value) {
                 if (value is List) {
                   // Value is an array of emails
                   if (value.any((e) => e != null && e.toString().toLowerCase().trim() == normalizedEmail)) {
                     assignedRole = role.toString();
                   }
                 } else if (value != null && value.toString().toLowerCase().trim() == normalizedEmail) {
                   // Value is a single email string
                   assignedRole = role.toString();
                 }
               });
               
               // Apply found role if it differs from current
               if (assignedRole != null && existingUser.userRole != assignedRole) {
                 existingUser.userRole = assignedRole!;
                 needsUpdate = true;
               }
             }
          }
        }

        // 2. Sync Auth metadata to DB
        if (user.email != null && user.email != existingUser.email) {
          existingUser.email = user.email!;
          needsUpdate = true;
        }
        if (user.displayName != null && user.displayName != existingUser.fullName) {
          existingUser.fullName = user.displayName!;
          needsUpdate = true;
        }
        
        if (needsUpdate) {
          await saveUserData(existingUser, systemUpdate: true);
        }
        
        return existingUser;
      } else {
        // Initialize new user record
        String initialRole = "user";
        
        // Initial role check for new sign-ups
        if (user.email != null && user.email!.isNotEmpty) {
          String normalizedEmail = user.email!.toLowerCase().trim();
          final rolesSnapshot = await FirebaseDatabase.instance.ref("appsettings/predefinedRoles").get();
          
          if (rolesSnapshot.exists) {
            final Object? rawRoles = rolesSnapshot.value;
            if (rawRoles is Map) {
              rawRoles.forEach((role, value) {
                if (value is List) {
                  if (value.any((e) => e != null && e.toString().toLowerCase().trim() == normalizedEmail)) {
                    initialRole = role.toString();
                  }
                } else if (value != null && value.toString().toLowerCase().trim() == normalizedEmail) {
                  initialRole = role.toString();
                }
              });
            }
          }
        }

        UserData newUser = UserData(
          id: user.uid,
          userRole: initialRole,
          email: user.email ?? "",
          fullName: user.displayName ?? "",
          timestamp: DateTime.now().toIso8601String(),
        );
        await saveUserData(newUser, systemUpdate: true);
        return newUser;
      }
    } catch (e) {
      debugPrint("Error in getUserData: $e");
      return UserData(id: user.uid);
    }
  }

  /// Persists user profile changes to Firebase.
  /// Use systemUpdate=true only when modifying internal fields like roles.
  Future<void> saveUserData(UserData user, {bool systemUpdate = false}) async {
    try {
      // Security: use toSafeJson() to prevent users from elevating their own roles
      final data = systemUpdate ? user.toJson() : user.toSafeJson();
      
      await FirebaseDatabase.instance
          .ref("users/${user.id}")
          .update(data);
      debugPrint("Firebase UserData save success (systemUpdate: $systemUpdate)");
    } catch (error) {
      debugPrint("Error in saveUserData: $error");
    }
  }
}
