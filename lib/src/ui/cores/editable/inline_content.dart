import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import 'controller.dart';

/// 一次原文匹配，区间使用调用方的 UTF-16 坐标。
@immutable
class InlineContentMatch {
  const InlineContentMatch(this.start, this.end, this.token);
  final int start;
  final int end;
  final String token;
}

/// 不可变 token 表；构建器换代可复用只依赖 token 的匹配树。
class InlineContent {
  InlineContent(this.builders, {InlineContent? previous})
    : matcher = previous != null && _sameKeys(previous.builders, builders)
          ? previous.matcher
          : InlineContentMatcher(builders.keys);

  final Map<String, WidgetBuilder> builders;
  final InlineContentMatcher matcher;

  static final _models = Expando<InlineContent>();

  /// 同一不可变表在共享视口间复用匹配器。
  static InlineContent of(Map<String, WidgetBuilder> builders, {InlineContent? previous}) =>
      _models[builders] ??= InlineContent(builders, previous: previous);

  static bool _sameKeys(Map<String, WidgetBuilder> a, Map<String, WidgetBuilder> b) =>
      a.length == b.length && a.keys.every(b.containsKey);

  /// 通常的分隔符 token 只读取端点附近；存在跨起点重叠时按整行消歧。
  InlineContentMatch? containing(ElEditableController controller, int offset, {TextRange? composing}) {
    if (offset <= 0 || offset >= controller.length || matcher.maxLength < 2) return null;
    final line = controller.lineRange(controller.lineAtOffset(offset));
    if (offset == line.start || offset == line.end) return null;
    final start = matcher.hasOverlaps ? line.start : math.max(line.start, offset - matcher.maxLength + 1);
    final end = matcher.hasOverlaps ? line.end : math.min(line.end, offset + matcher.maxLength - 1);
    final text = controller.getText(start, end);
    for (final match in matcher.matches(text)) {
      final a = start + match.start;
      final b = start + match.end;
      if (a >= offset) return null;
      if (b <= offset) continue;
      final composition = composing ?? controller.composing;
      if (composition.isValid && !composition.isCollapsed && composition.start < b && composition.end > a) {
        return null;
      }
      return InlineContentMatch(a, b, match.token);
    }
    return null;
  }
}

class _TokenNode {
  final Map<int, _TokenNode> next = {};
  String? token;
}

/// 左端优先、同起点最长匹配；没有逐 token 扫全文的乘法成本。
class InlineContentMatcher {
  InlineContentMatcher(Iterable<String> tokens) {
    assert(() {
      debugCompileCount++;
      return true;
    }());
    final values = tokens.toList(growable: false);
    for (final token in values) {
      if (token.isEmpty || token.contains('\n') || token.contains('\r')) {
        throw ArgumentError.value(token, 'inlineContent', 'token 必须为非空单行文字');
      }
      maxLength = math.max(maxLength, token.length);
      var node = _root;
      for (final code in token.codeUnits) {
        node = node.next.putIfAbsent(code, _TokenNode.new);
      }
      node.token = token;
    }
    _singleStart = _root.next.length == 1 ? String.fromCharCode(_root.next.keys.single) : null;
    outer:
    for (final token in values) {
      for (var start = 1; start < token.length; start++) {
        var node = _root;
        for (var i = start; i < token.length; i++) {
          final next = node.next[token.codeUnitAt(i)];
          if (next == null) break;
          node = next;
          if (node.token != null || i == token.length - 1) {
            hasOverlaps = true;
            break outer;
          }
        }
      }
    }
  }

  final _root = _TokenNode();
  String? _singleStart;
  int maxLength = 0;
  bool hasOverlaps = false;

  @visibleForTesting
  static int debugCompileCount = 0;
  @visibleForTesting
  static int debugScannedCodeUnits = 0;

  Iterable<InlineContentMatch> matches(String text) sync* {
    assert(() {
      debugScannedCodeUnits += text.length;
      return true;
    }());
    var offset = 0;
    while (offset < text.length) {
      if (_singleStart != null) {
        offset = text.indexOf(_singleStart!, offset);
        if (offset < 0) return;
      }
      var node = _root;
      String? token;
      var end = offset;
      for (var i = offset; i < text.length; i++) {
        final next = node.next[text.codeUnitAt(i)];
        if (next == null) break;
        node = next;
        if (node.token != null) {
          token = node.token;
          end = i + 1;
        }
      }
      if (token == null) {
        offset++;
      } else {
        yield InlineContentMatch(offset, end, token);
        offset = end;
      }
    }
  }

  /// bidi 分析把 token 视为一个中性字素，仍保持每个原文 UTF-16 坐标。
  String neutralize(String text, {required int start, required int end}) {
    StringBuffer? result;
    var offset = start;
    for (final match in matches(text)) {
      if (match.end <= start) continue;
      if (match.start >= end) break;
      result ??= StringBuffer();
      final a = math.max(match.start, start);
      final b = math.min(match.end, end);
      result.write(text.substring(offset, a));
      if (a == match.start) result.write('\uFFFC');
      result.write('\u0300' * (b - a - (a == match.start ? 1 : 0)));
      offset = b;
    }
    if (result == null) return text.substring(start, end);
    result.write(text.substring(offset, end));
    return result.toString();
  }
}
