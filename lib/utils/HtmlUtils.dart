import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';

/// Shared conversion between Quill Delta and the HTML stored in RTDB.
class HtmlUtils {
  HtmlUtils._();

  /// Converts stored HTML into a Quill [Document] for the editor.
  ///
  /// Falls back to plain text (strip tags) when the HTML cannot be parsed so
  /// that content is never silently dropped on load.
  static Document htmlToDeltaDocument(String html) {
    if (html.trim().isEmpty) return Document();
    try {
      final delta = HtmlToDelta().convert(html, transformTableAsEmbed: false);
      return Document.fromDelta(delta);
    } catch (e) {
      AppLog.warn('HtmlUtils: HTML→Delta conversion failed: $e');
      final plain = html.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      final doc = Document();
      if (plain.isNotEmpty) doc.insert(0, plain);
      return doc;
    }
  }

  /// Converts the editor's [Document] back into HTML for storage.
  static String deltaDocumentToHtml(Document doc) {
    final delta = doc.toDelta().toJson();
    final converter = QuillDeltaToHtmlConverter(
      List.castFrom(delta),
      ConverterOptions.forEmail(),
    );
    return converter.convert();
  }
}
