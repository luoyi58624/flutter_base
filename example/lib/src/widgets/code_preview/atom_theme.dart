import 'package:flutter/widgets.dart';
import 'package:highlight/highlight_core.dart' show Highlight, Node;
import 'package:highlight/languages/dart.dart' show dart;

/// 代码岛沿用旧预览器的 Atom One Dark 背景。
const codeBackground = Color(0xff282c34);

/// 未命中语法规则的代码正文色。
const codeForeground = Color(0xffabb2bf);

/// 代码区沿用旧预览器的字号、行高和 Consolas 字体。
const codeTextStyle = TextStyle(
  fontFamily: 'Consolas',
  fontFamilyFallback: ['Consolas', 'Noto Sans SC', 'monospace'],
  fontSize: 14,
  height: 1.7,
  color: codeForeground,
);

final _highlight = Highlight()..registerLanguage('dart', dart);
final _identifier = RegExp(r'[a-zA-Z_$][a-zA-Z0-9_$]*');

/// 将只读源码转成旧预览器配色的文本片段，保留全部原始空白。
TextSpan codeSpan(String code, String language) {
  if (language.toLowerCase() != 'dart') return TextSpan(text: code);
  final nodes = _highlight.parse(code, language: 'dart').nodes;
  return TextSpan(children: nodes?.map(_span).toList() ?? [TextSpan(text: code)]);
}

TextSpan _span(Node node, [bool colorIdentifiers = true]) {
  if (node.className == null && node.value != null) {
    return colorIdentifiers ? TextSpan(children: _identifiers(node.value!)) : TextSpan(text: node.value);
  }
  final colorChildren =
      node.className == 'subst' || (colorIdentifiers && !['string', 'comment', 'doctag'].contains(node.className));
  return TextSpan(
    text: node.value,
    style: TextStyle(color: _color(node)),
    children: node.children?.map((child) => _span(child, colorChildren)).toList(),
  );
}

// 基础 Dart 语法未标注自定义 Widget 与命名参数，补上旧预览器的类型色与属性色。
List<InlineSpan> _identifiers(String text) {
  final spans = <InlineSpan>[];
  var offset = 0;
  for (final match in _identifier.allMatches(text)) {
    if (match.start > offset) spans.add(TextSpan(text: text.substring(offset, match.start)));
    final word = match.group(0)!;
    var next = match.end;
    while (next < text.length && [9, 10, 13, 32].contains(text.codeUnitAt(next))) {
      next++;
    }
    final following = next < text.length ? text[next] : '';
    final first = word.codeUnitAt(0);
    final color = first >= 65 && first <= 90
        ? Color(0xffe5c07b)
        : following == ':' || following == '('
        ? Color(0xff61afef)
        : null;
    spans.add(
      TextSpan(
        text: word,
        style: TextStyle(color: color),
      ),
    );
    offset = match.end;
  }
  if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
  return spans;
}

Color? _color(Node node) => switch (node.className) {
  'comment' || 'doctag' => Color(0xff5c6370),
  'keyword' when ['true', 'false', 'null', 'this', 'super'].contains(node.value) => Color(0xff56b6c2),
  'keyword' || 'meta' => Color(0xffc678dd),
  'type' || 'built_in' || 'class' => Color(0xffe5c07b),
  'string' => Color(0xff98c379),
  'number' => Color(0xffd19a66),
  'literal' || 'symbol' => Color(0xff56b6c2),
  'function' || 'title' || 'attr' => Color(0xff61afef),
  'variable' => Color(0xffe06c75),
  'subst' => codeForeground,
  _ => null,
};
