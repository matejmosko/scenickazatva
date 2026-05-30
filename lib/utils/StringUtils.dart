class StringUtils {
  static final RegExp _htmlRegExp = RegExp(r'<[^>]*>|&[^;]+;');

  static String stripHtml(String text) {
    if (text.isEmpty) return "";
    return text.replaceAll(_htmlRegExp, ' ').trim();
  }

  static String removeDiacritics(String text) {
    var withDia = 'áäčďéěíĺľňóôőöŕšťúůűüýžÁÄČĎÉĚÍĹĽŇÓÔŐÖŔŠŤÚŮŰÜÝŽ';
    var withoutDia = 'aacdeeillnoooorstuuuuuyzAACDEEILLNOOOORSTUUUUUYZ';
    for (int i = 0; i < withDia.length; i++) {
      text = text.replaceAll(withDia[i], withoutDia[i]);
    }
    return text;
  }
}
