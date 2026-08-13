class Location {
  String id;
  String displayName;
  String description;
  String address;
  String city;
  String longitude;
  String latitude;
  String icon;
  String color;
  String photo;

  Location(
      {this.id = "",
      this.displayName = "",
      this.description = "",
      this.address = "",
      this.longitude = "",
        this.city = "",
      this.latitude = "",
      this.icon = "0xe88a",
        this.color = "333333FF",
      this.photo = ""});

  Location.fromData(Map<String, dynamic> data)
      : id = data['id'],
        displayName = data['displayName'] ?? "",
        description = data['description'] ?? "",
        address = data['address'] ?? "",
        city = data['city'] ?? "",
        longitude = data['longitude'] ?? "",
        latitude = data['latitude'] ?? "",
        icon = data['icon'] ?? "0xe88a",
        color = data['color'] ?? "",
        photo = data['photo'] ?? "";

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'description': description,
      'address': address,
      'city': city,
      'longitude': longitude,
      'latitude': latitude,
      'icon': icon,
      'color': color,
      'photo': photo
    };
  }
}
