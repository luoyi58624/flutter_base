import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../selection/common/selection_core.dart';
import '../inline_content.dart';

/// 一次出现对应独立组件状态；文本前后缀未变时保留身份和实测尺寸。
class InlineContentSlot {
  InlineContentSlot(this.match, this.builder, {InlineContentSlot? previous})
    : _widget = previous != null && identical(previous.builder, builder) ? previous._widget : null,
      identity = previous?.identity ?? Object(),
      measuredSize = previous?.measuredSize;

  final InlineContentMatch match;
  final WidgetBuilder builder;
  InlineContentWidget? _widget;
  InlineContentWidget get widget => _widget ??= InlineContentWidget(builder);
  Size? measuredSize;
  final Object identity;
}

/// 在行的局部组件树内执行构建器，使祖先 ElView 样式自然继承。
class InlineContentWidget extends StatelessWidget {
  const InlineContentWidget(this.builder, {super.key});
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => SelectionTextBlock(child: builder(context));
}

/// 原文 UTF-16 与 Paragraph 的单占位符坐标之间的有序索引。
class InlineTextProjection {
  InlineTextProjection(
    this.source,
    InlineContent content, {
    TextRange composing = TextRange.empty,
    List<TextRange> excluded = const [],
    InlineTextProjection? previous,
  }) {
    var prefix = 0;
    var suffix = 0;
    if (previous != null) {
      final old = previous.source;
      while (prefix < old.length && prefix < source.length && old.codeUnitAt(prefix) == source.codeUnitAt(prefix)) {
        prefix++;
      }
      while (suffix < old.length - prefix &&
          suffix < source.length - prefix &&
          old.codeUnitAt(old.length - suffix - 1) == source.codeUnitAt(source.length - suffix - 1)) {
        suffix++;
      }
    }
    final retained = <int, InlineContentSlot>{};
    if (previous != null) {
      for (final slot in previous.slots) {
        final match = slot.match;
        if (match.end <= prefix) {
          retained[match.start] = slot;
        } else if (match.start >= previous.source.length - suffix) {
          retained[match.start + source.length - previous.source.length] = slot;
        }
      }
    }
    var removed = 0;
    for (final match in content.matcher.matches(source)) {
      if (composing.isValid && !composing.isCollapsed && composing.start < match.end && composing.end > match.start) {
        continue;
      }
      if (excluded.any((range) => range.start < match.end && range.end > match.start)) continue;
      final builder = content.builders[match.token]!;
      final old = retained[match.start];
      slots.add(
        InlineContentSlot(match, builder, previous: old != null && old.match.token == match.token ? old : null),
      );
      _displayStarts.add(match.start - removed);
      removed += match.end - match.start - 1;
    }
  }

  final String source;
  final List<InlineContentSlot> slots = [];
  final List<int> _displayStarts = [];
  Object identityAt(int index) => slots[index].identity;
  Widget widgetAt(int index) => slots[index].widget;

  int _lastStartAtOrBefore(int offset, {required bool display}) {
    var lo = 0;
    var hi = slots.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      final start = display ? _displayStarts[mid] : slots[mid].match.start;
      if (start <= offset) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo - 1;
  }

  int toDisplay(int offset, {bool trailing = false}) {
    final i = _lastStartAtOrBefore(offset, display: false);
    if (i < 0) return offset;
    final match = slots[i].match;
    if (offset < match.end) return _displayStarts[i] + (offset > match.start && trailing ? 1 : 0);
    return _displayStarts[i] + 1 + offset - match.end;
  }

  int toSource(int offset) {
    final i = _lastStartAtOrBefore(offset, display: true);
    if (i < 0) return offset;
    final match = slots[i].match;
    return offset == _displayStarts[i] ? match.start : match.end + offset - _displayStarts[i] - 1;
  }

  InlineSpan buildSpan(InlineSpan sourceSpan) {
    var offset = 0;
    var index = 0;
    InlineSpan visit(InlineSpan span) {
      if (span is! TextSpan) return span;
      final children = <InlineSpan>[];
      final text = span.text ?? '';
      final end = offset + text.length;
      while (offset < end) {
        while (index < slots.length && slots[index].match.end <= offset) {
          index++;
        }
        if (index >= slots.length || slots[index].match.start >= end) {
          children.add(TextSpan(text: text.substring(text.length - (end - offset))));
          offset = end;
          break;
        }
        final match = slots[index].match;
        if (offset < match.start) {
          children.add(TextSpan(text: text.substring(text.length - (end - offset), text.length - (end - match.start))));
          offset = match.start;
        }
        if (offset == match.start) {
          children.add(WidgetSpan(child: widgetAt(index), alignment: .baseline, baseline: .alphabetic));
        }
        offset = match.end < end ? match.end : end;
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        children.add(visit(child));
      }
      return TextSpan(style: span.style, children: children);
    }

    return visit(sourceSpan);
  }
}

/// 对调用方继续暴露原文坐标，内部 Paragraph 使用折叠后的占位符坐标。
class InlineTextPainter extends TextPainter {
  InlineTextPainter(this.projection);
  InlineTextProjection projection;

  TextPosition _display(TextPosition value) => TextPosition(
    offset: projection.toDisplay(value.offset, trailing: value.affinity == .downstream),
    affinity: value.affinity,
  );
  TextPosition _source(TextPosition value) =>
      TextPosition(offset: projection.toSource(value.offset), affinity: value.affinity);
  TextRange _range(TextRange value) =>
      value.isValid ? TextRange(start: projection.toSource(value.start), end: projection.toSource(value.end)) : value;

  @override
  Offset getOffsetForCaret(TextPosition position, Rect caretPrototype) =>
      super.getOffsetForCaret(_display(position), caretPrototype);
  @override
  double getFullHeightForCaret(TextPosition position, Rect caretPrototype) =>
      super.getFullHeightForCaret(_display(position), caretPrototype);
  @override
  TextPosition getPositionForOffset(Offset offset) => _source(super.getPositionForOffset(offset));
  @override
  List<ui.TextBox> getBoxesForSelection(
    TextSelection selection, {
    ui.BoxHeightStyle boxHeightStyle = .tight,
    ui.BoxWidthStyle boxWidthStyle = .tight,
  }) => super.getBoxesForSelection(
    TextSelection(
      baseOffset: projection.toDisplay(selection.start),
      extentOffset: projection.toDisplay(selection.end, trailing: true),
    ),
    boxHeightStyle: boxHeightStyle,
    boxWidthStyle: boxWidthStyle,
  );
  @override
  TextRange getWordBoundary(TextPosition position) => _range(super.getWordBoundary(_display(position)));
  @override
  TextRange getLineBoundary(TextPosition position) => _range(super.getLineBoundary(_display(position)));
  @override
  int? getOffsetAfter(int offset) {
    final result = super.getOffsetAfter(projection.toDisplay(offset));
    return result == null ? null : projection.toSource(result);
  }

  @override
  int? getOffsetBefore(int offset) {
    final result = super.getOffsetBefore(projection.toDisplay(offset, trailing: true));
    return result == null ? null : projection.toSource(result);
  }

  @override
  ui.GlyphInfo? getClosestGlyphForOffset(Offset offset) {
    final glyph = super.getClosestGlyphForOffset(offset);
    return glyph == null
        ? null
        : ui.GlyphInfo(
            glyph.graphemeClusterLayoutBounds,
            _range(glyph.graphemeClusterCodeUnitRange),
            glyph.writingDirection,
          );
  }
}
