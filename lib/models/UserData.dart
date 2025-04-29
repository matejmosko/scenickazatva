class UserData {
  String id = "";
  String fullName = "";
  String email = "";
  String userRole = "";
  late Map? notifications;
  String timestamp = "";
  String fcmtoken = "";

  UserData(
      {this.id = "",
      this.fullName = "",
      this.email = "",
      this.userRole = "",
      this.notifications,
      this.timestamp = "",
      this.fcmtoken = ""});

  UserData.fromData(Map<String, dynamic> data)
      : id = data['id'] ?? "",
        fullName = data['fullName'] ?? "",
        email = data['email'] ?? "",
        userRole = data['userRole'] ?? "",
        notifications = data['notifications'] ?? {},
        timestamp = data['timestamp'] ?? "",
        fcmtoken = data['fcmtoken'] ?? "";

  factory UserData.fromJson(Map<String, dynamic> json) {

    return UserData(
        id: json['id'] ?? "",
        fullName: json['fullName'] ?? "",
        email: json['email'] ?? "",
        userRole: json['userRole'] ?? "",
        notifications: json['notifications'] ?? {},
        timestamp: json['timestamp'] ?? "",
        fcmtoken: json['fcmtoken'] ?? ""
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'userRole': userRole,
      'notifications': notifications,
      'timestamp': timestamp,
      'fcmtoken': fcmtoken
    };
  }
}
