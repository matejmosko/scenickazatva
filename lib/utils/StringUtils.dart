class StringUtils {
  static final RegExp _htmlRegExp = RegExp(r'<[^>]*>|&[^;]+;');

  static String stripHtml(String text) {
    if (text.isEmpty) return "";
    return text.replaceAll(_htmlRegExp, ' ').trim();
  }
}
