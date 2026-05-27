class UserData {
  String id = "";
  String fullName = "";
  String email = "";
  String userRole = "";
  Map notifications = {};
  Map<String, List<String>> favorites = {}; // Key: Festival ID, Value: List of Event IDs
  String timestamp = "";
  String fcmtoken = "";

  UserData({
    this.id = "",
    this.fullName = "",
    this.email = "",
    this.userRole = "",
    this.notifications = const {},
    this.favorites = const {},
    this.timestamp = "",
    this.fcmtoken = "",
  });

  factory UserData.fromData(Map<String, dynamic> data) {
    Map<String, List<String>> parsedFavorites = {};
    if (data['favorites'] is Map) {
      (data['favorites'] as Map).forEach((key, value) {
        if (value is List) {
          parsedFavorites[key.toString()] = List<String>.from(value);
        }
      });
    }

    return UserData(
      id: data['id'] ?? "",
      fullName: data['fullName'] ?? "",
      email: data['email'] ?? "",
      userRole: data['userRole'] ?? "",
      notifications: data['notifications'] ?? {},
      favorites: parsedFavorites,
      timestamp: data['timestamp'] ?? "",
      fcmtoken: data['fcmtoken'] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'userRole': userRole,
      'notifications': notifications,
      'favorites': favorites,
      'timestamp': timestamp,
      'fcmtoken': fcmtoken,
    };
  }
}
