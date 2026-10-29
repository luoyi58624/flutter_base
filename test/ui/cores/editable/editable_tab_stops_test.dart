import 'package:flutter_base/src/ui/cores/editable/render/editable_tab_stops.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

double _advance(TextPainter painter, int length) {
  final start = painter.getOffsetForCaret(const TextPosition(offset: 0), Rect.zero).dx;
  final end = painter.getOffsetForCaret(TextPosition(offset: length), Rect.zero).dx;
  return (end - start).abs();
}

void main() {
  test('tabSize 改变真实 tab stop 宽度但不改变 UTF-16 坐标', () {
    const style = TextStyle(fontFamily: 'monospace', fontSize: 10);
    TextPainter painterFor(String text, int tabSize) {
      final painter = TextPainter(
        text: applyEditableTabStops(
          TextSpan(text: text, style: style),
          tabSize: tabSize,
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter;
    }

    final four = painterFor('a\tb', 4);
    final two = painterFor('a\tb', 2);
    addTearDown(four.dispose);
    addTearDown(two.dispose);

    expect(four.text!.toPlainText(), 'a\tb');
    expect(four.width, 50);
    expect(two.width, 30);
    expect(four.getOffsetForCaret(const TextPosition(offset: 2), Rect.zero).dx, 40);
    expect(two.getOffsetForCaret(const TextPosition(offset: 2), Rect.zero).dx, 20);
  });

  test('连续 tab、富 span 与已有 letterSpacing 都按下一 tab stop 对齐', () {
    const style = TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: 2);
    final painter = TextPainter(
      text: applyEditableTabStops(
        const TextSpan(
          style: style,
          children: [
            TextSpan(text: 'ab'),
            TextSpan(
              text: '\t\t',
              style: TextStyle(color: Color(0xff000000)),
            ),
          ],
        ),
        tabSize: 4,
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(painter.dispose);

    final unit = TextPainter(
      text: const TextSpan(text: ' ', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(unit.dispose);
    expect(painter.text!.toPlainText(), 'ab\t\t');
    final origin = painter.getOffsetForCaret(const TextPosition(offset: 0), Rect.zero).dx;
    final first = painter.getOffsetForCaret(const TextPosition(offset: 3), Rect.zero).dx;
    final second = painter.getOffsetForCaret(const TextPosition(offset: 4), Rect.zero).dx;
    expect(first - origin, closeTo(_advance(unit, 1) * 4, 0.01));
    expect(second, greaterThan(first));
  });

  test('combining grapheme 前的 tab 依据真实 advance 而非 rune 数', () {
    const style = TextStyle(fontFamily: 'monospace', fontSize: 10);
    final painter = TextPainter(
      text: applyEditableTabStops(
        const TextSpan(text: 'e\u0301\tz', style: style),
        tabSize: 4,
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(painter.dispose);
    final space = TextPainter(
      text: const TextSpan(text: ' ', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(space.dispose);

    expect(
      painter.getOffsetForCaret(const TextPosition(offset: 3), Rect.zero).dx,
      closeTo(_advance(space, 1) * 4, 0.01),
    );
  });

  test('比例 advance 与富 span 样式切换后仍落到当前 tab 样式的下一 stop', () {
    const base = TextStyle(fontSize: 11, letterSpacing: 0.7);
    const prefixStyle = TextStyle(fontSize: 17, letterSpacing: 2.3);
    const tabStyle = TextStyle(fontSize: 9, letterSpacing: 0.2);
    final effectivePrefix = base.merge(prefixStyle);
    final effectiveTab = base.merge(tabStyle);
    final prefix = TextPainter(
      text: TextSpan(text: 'Wi', style: effectivePrefix),
      textDirection: TextDirection.ltr,
    )..layout();
    final space = TextPainter(
      text: TextSpan(text: ' ', style: effectiveTab),
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(prefix.dispose);
    addTearDown(space.dispose);
    final stopExtent = _advance(space, 1) * 4;
    final prefixAdvance = _advance(prefix, 2);
    final expected = ((prefixAdvance + stopExtent * 1e-6) / stopExtent).floor() * stopExtent + stopExtent;

    final painter = TextPainter(
      text: applyEditableTabStops(
        const TextSpan(
          style: base,
          children: [
            TextSpan(text: 'Wi', style: prefixStyle),
            TextSpan(text: '\tZ', style: tabStyle),
          ],
        ),
        tabSize: 4,
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(painter.dispose);

    final origin = painter.getOffsetForCaret(const TextPosition(offset: 0), Rect.zero).dx;
    final actual = painter.getOffsetForCaret(const TextPosition(offset: 3), Rect.zero).dx;
    expect(actual - origin, closeTo(expected, 0.01));
  });

  test('行尾 tab 的 upstream / downstream caret 都落在同一 stop', () {
    const style = TextStyle(fontFamily: 'monospace', fontSize: 10);
    final painter = TextPainter(
      text: applyEditableTabStops(
        const TextSpan(text: 'a\t', style: style),
        tabSize: 4,
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(painter.dispose);
    final origin = painter.getOffsetForCaret(const TextPosition(offset: 0), Rect.zero).dx;
    final downstream = painter.getOffsetForCaret(const TextPosition(offset: 2), Rect.zero).dx - origin;
    final upstream =
        painter.getOffsetForCaret(const TextPosition(offset: 2, affinity: TextAffinity.upstream), Rect.zero).dx -
        origin;

    expect(downstream, closeTo(40, 0.01));
    expect(upstream, closeTo(downstream, 0.01));
  });

  test('拆分 tab span 时保留 semanticsLabel 与 semanticsIdentifier', () {
    const source = TextSpan(
      text: 'a\tb',
      style: TextStyle(fontSize: 10),
      semanticsLabel: 'tabbed value',
      semanticsIdentifier: 'editable-line',
    );
    final transformed =
        applyEditableTabStops(source, tabSize: 4, textDirection: TextDirection.ltr, textScaler: TextScaler.noScaling)
            as TextSpan;

    final descendants = transformed.children!.whereType<TextSpan>();
    expect(descendants.any((span) => span.semanticsLabel == source.semanticsLabel), isTrue);
    expect(descendants.any((span) => span.semanticsIdentifier == source.semanticsIdentifier), isTrue);
    expect(transformed.toPlainText(includeSemanticsLabels: false), 'a\tb');
    expect(transformed.toPlainText(), 'tabbed value');
  });
}
