import 'package:wordpress_client/wordpress_client.dart';

extension FeaturedImage on Post{
  String featuredImageSourceUrl(){
      return castOrElse((this["_embedded"]["wp:featuredmedia"][0]["source_url"] != null) ? this["_embedded"]["wp:featuredmedia"][0]["source_url"]: "");
  }
}