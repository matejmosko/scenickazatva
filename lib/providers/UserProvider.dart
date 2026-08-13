import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scenickazatva_app/models/UserData.dart';
import 'package:scenickazatva_app/models/Event.dart';
import 'package:scenickazatva_app/requests/FirestoreService.dart';
import 'package:scenickazatva_app/requests/NotificationService.dart';

/// Provider responsible for managing the user session, profile data, and favorites.
/// Listens to authentication state changes and synchronizes metadata with FirestoreService.
class UserProvider extends ChangeNotifier {
  UserData _userData = UserData();
  StreamSubscription<User?>? _authSubscription;
  bool _loading = true;

  UserProvider() {
    _initAuthListener();
  }

  // Getters
  UserData get userData => _userData;
  bool get loading => _loading;

  /// Returns true if the current user has administrative or editing rights
  bool get canEdit => _userData.userRole == "admin" || _userData.userRole == "editor";

  /// Sets up a listener for Firebase Auth state changes (Login, Logout, Token refresh)
  void _initAuthListener() {
    _authSubscription = FirebaseAuth.instance.idTokenChanges().listen((user) async {
      if (user != null) {
        _loading = true;
        notifyListeners();
        
        // Sync database record with authenticated user
        _userData = await authService().getUserData(user);
        
        _loading = false;
        notifyListeners();
      } else {
        // Reset to default empty state on logout
        _userData = UserData();
        notifyListeners();
      }
    });
  }

  /// Checks if a specific event is in the user's favorites for a given festival
  bool isFavorite(String festivalId, String eventId) {
    if (_userData.favorites.containsKey(festivalId)) {
      return _userData.favorites[festivalId]!.contains(eventId);
    }
    return false;
  }

  /// Toggles an event in the favorites list and persists the change to Firebase.
  /// Also manages local notifications for mobile users.
  Future<void> toggleFavorite(String festivalId, Event event) async {
    final String eventId = event.id;
    final currentFavorites = Map<String, List<String>>.from(_userData.favorites);
    
    if (!currentFavorites.containsKey(festivalId)) {
      currentFavorites[festivalId] = [];
    }

    if (currentFavorites[festivalId]!.contains(eventId)) {
      currentFavorites[festivalId]!.remove(eventId);
      // Cancel local reminder if un-favorited
      if (!kIsWeb) {
        await NotificationService().cancelEventNotification(event);
      }
    } else {
      currentFavorites[festivalId]!.add(eventId);
      // Schedule local reminder if favorited
      if (!kIsWeb) {
        await NotificationService().scheduleEventNotification(event);
      }
    }

    _userData.favorites = currentFavorites;
    notifyListeners();

    // Persist profile to Firebase (Security: userRole is automatically excluded here)
    await authService().saveUserData(_userData);
  }

  /// Updates the user's full name and persists it to Firebase.
  Future<void> updateFullName(String name) async {
    if (_userData.fullName == name) return;
    _userData.fullName = name;
    notifyListeners();
    await authService().saveUserData(_userData);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
