import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scenickazatva_app/models/UserData.dart';
import 'package:scenickazatva_app/models/Event.dart';
import 'package:scenickazatva_app/requests/FirestoreService.dart';
import 'package:scenickazatva_app/requests/NotificationService.dart';

class UserProvider extends ChangeNotifier {
  UserData _userData = UserData();
  StreamSubscription<User?>? _authSubscription;
  bool _loading = true;

  UserProvider() {
    _initAuthListener();
  }

  UserData get userData => _userData;
  bool get loading => _loading;

  void _initAuthListener() {
    _authSubscription = FirebaseAuth.instance.idTokenChanges().listen((user) async {
      if (user != null) {
        _loading = true;
        notifyListeners();
        
        _userData = await authService().getUserData(user);
        
        _loading = false;
        notifyListeners();
      } else {
        _userData = UserData();
        notifyListeners();
      }
    });
  }

  bool isFavorite(String festivalId, String eventId) {
    if (_userData.favorites.containsKey(festivalId)) {
      return _userData.favorites[festivalId]!.contains(eventId);
    }
    return false;
  }

  Future<void> toggleFavorite(String festivalId, Event event) async {
    final String eventId = event.id;
    final currentFavorites = Map<String, List<String>>.from(_userData.favorites);
    
    if (!currentFavorites.containsKey(festivalId)) {
      currentFavorites[festivalId] = [];
    }

    if (currentFavorites[festivalId]!.contains(eventId)) {
      currentFavorites[festivalId]!.remove(eventId);
      if (!kIsWeb) {
        await NotificationService().cancelEventNotification(event);
      }
    } else {
      currentFavorites[festivalId]!.add(eventId);
      if (!kIsWeb) {
        await NotificationService().scheduleEventNotification(event);
      }
    }

    _userData.favorites = currentFavorites;
    notifyListeners();

    // Persist to Firebase
    await authService().saveUserData(_userData);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
