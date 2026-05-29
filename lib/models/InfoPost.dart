class InfoPost {
  String id = "";
  String title = "";
  String description = "";
  String image = "";
  int icon = 0;

  InfoPost(
      {this.id = "",
      this.title = "",
      this.description = "",
      this.image = "",
      this.icon = 0,
      });

  InfoPost.fromJson(Map<String, dynamic> json) {
    id = json['id'] ?? "";
    title = json['title'] ?? "";
    description = json['description'] ?? "";
    icon = json['icon'] is int ? json['icon'] : (int.tryParse(json['icon']?.toString() ?? "0") ?? 0);
    image = json['image'] ?? "";
  }

  InfoPost copy() {
    return InfoPost(
      id: id,
      title: title,
      description: description,
      image: image,
      icon: icon,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['title'] = this.title;
    data['description'] = this.description;
    data['icon'] = this.icon;
    data['image'] = this.image;
    return data;
  }
}
