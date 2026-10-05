import 'package:html/dom.dart';
import 'package:html/parser.dart';

/// Converts KLAS editor HTML to text while keeping paragraphs and list items.
String? bodyText(String? html) {
  if (html == null) return null;
  final buffer = StringBuffer();
  void visit(Node node, {bool preformatted = false}) {
    if (node is Text) {
      buffer.write(
        preformatted
            ? node.data.replaceAll(RegExp(r'\r\n?'), '\n')
            : node.data.replaceAll(RegExp(r'\s+'), ' '),
      );
      return;
    }
    if (node is Element) {
      final tag = node.localName;
      if (const {'script', 'style', 'template'}.contains(tag)) return;
      if (tag == 'br') {
        buffer.writeln();
        return;
      }
      final block = const {
        'p',
        'div',
        'section',
        'article',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'ul',
        'ol',
        'li',
        'tr',
        'pre',
        'blockquote',
      }.contains(tag);
      if (block) buffer.writeln();
      if (tag == 'li') buffer.write('- ');
      for (final child in node.nodes) {
        visit(child, preformatted: preformatted || tag == 'pre');
      }
      if (tag == 'a') {
        final href = node.attributes['href'];
        if (href != null && href.trim().isNotEmpty && href != node.text) {
          buffer.write(' ($href)');
        }
      }
      if (tag == 'td' || tag == 'th') buffer.write(' | ');
      if (block) buffer.writeln();
      return;
    }
    for (final child in node.nodes) {
      visit(child, preformatted: preformatted);
    }
  }

  final fragment = parseFragment(html);
  visit(fragment, preformatted: fragment.nodes.every((node) => node is Text));
  return buffer
      .toString()
      .replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]'), '')
      .split('\n')
      .map((line) => line.replaceAll('\u00a0', ' ').trimRight())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
