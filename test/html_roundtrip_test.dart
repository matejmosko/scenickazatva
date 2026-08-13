import 'package:flutter_test/flutter_test.dart';
import 'package:scenickazatva_app/utils/HtmlUtils.dart';

/// Round-trips stored HTML through the editor conversion (HTML → Delta →
/// HTML) to prove that formatting survives save/load cycles.
String roundTrip(String html) => HtmlUtils.deltaDocumentToHtml(
    HtmlUtils.htmlToDeltaDocument(html));

void main() {
  test('preserves bold, italic and underline', () {
    final out = roundTrip('<p><strong>tučný</strong> a '
        '<em>kurzíva</em> a <u>podčiarknuté</u></p>');
    expect(out, contains('<strong>'));
    expect(out, contains('tučný'));
    expect(out, contains('<em>'));
    expect(out, contains('kurzíva'));
    expect(out, contains('<u>'));
    expect(out, contains('podčiarknuté'));
  });

  test('preserves headings', () {
    final out = roundTrip('<h1>Nadpis 1</h1><h2>Nadpis 2</h2><h3>Nadpis 3</h3>');
    expect(out, contains('<h1>'));
    expect(out, contains('Nadpis 1'));
    expect(out, contains('<h2>'));
    expect(out, contains('Nadpis 2'));
    expect(out, contains('<h3>'));
    expect(out, contains('Nadpis 3'));
  });

  test('preserves ordered and unordered lists', () {
    final out = roundTrip(
        '<ol><li>prvý</li><li>druhý</li></ol><ul><li>a</li><li>b</li></ul>');
    expect(out, contains('<ol>'));
    expect(out, contains('prvý'));
    expect(out, contains('druhý'));
    expect(out, contains('<ul>'));
    expect(out, contains('a'));
    expect(out, contains('b'));
  });

  test('preserves links', () {
    final out = roundTrip(
        '<p><a href="https://javisko.sk">javisko</a></p>');
    expect(out, contains('https://javisko.sk'));
    expect(out, contains('javisko'));
  });

  test('preserves images', () {
    final out = roundTrip(
        '<p><img src="gs://scenickazatva-343517.appspot.com/festivals/zatva/images/1_rich.png"></p>');
    expect(out, contains('gs://scenickazatva-343517.appspot.com/festivals/zatva/images/1_rich.png'));
  });

  test('drops no content on a second round trip', () {
    const html = '<h2>Úvod</h2><p>Toto je <strong>dôležitý</strong> text '
        's <a href="https://javisko.sk">odkazom</a>.</p>'
        '<ul><li>bod 1</li><li>bod 2</li></ul>';
    final once = roundTrip(html);
    final twice = roundTrip(once);
    expect(twice, contains('Úvod'));
    expect(twice, contains('dôležitý'));
    expect(twice, contains('javisko.sk'));
    expect(twice, contains('bod 1'));
    expect(twice, contains('bod 2'));
  });

  test('invalid HTML falls back to plain text instead of blank content', () {
    final doc = HtmlUtils.htmlToDeltaDocument('<broken>tag>&<novalid');
    final text = doc.toPlainText().replaceAll('\n', '').trim();
    expect(text, isNotEmpty);
  });
}
