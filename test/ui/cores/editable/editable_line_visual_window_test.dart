import 'dart:math' as math;

import 'package:flutter_base/src/flutter/views/editable/render/editable_line_layout.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

EditableLineVisualFragment _fragment(int start, int end, String text, {int level = 0, double tabPrefix = 0.0}) =>
    EditableLineVisualFragment(
      lineStart: start,
      lineEnd: end,
      text: text,
      resolvedLevel: level,
      logicalTabPrefix: tabPrefix,
    );

void main() {
  test('纯格式控制行的 empty visual window 保留全行零宽 offset 映射', () {
    final window = EditableLineLayoutWindow.visualEmpty(lineLength: 80000, averageAdvance: 10, visualGeneration: 7);
    expect(window.isVisual, isTrue);
    expect(window.paragraphText, isEmpty);
    expect(window.totalParagraphCodeUnits, 0);
    expect(window.visualGeneration, 7);
    expect(window.visualFirstTile, 0);
    expect(window.visualEndTile, 0);
    expect(window.visualTileCount, 0);
    for (final offset in const [0, 1, 40000, 80000]) {
      expect(window.containsOffset(offset), isTrue);
      expect(window.toParagraphPosition(TextPosition(offset: offset)).offset, 0);
    }
    expect(window.toLinePosition(const TextPosition(offset: 0)).offset, 0);
    expect(window.toLinePosition(const TextPosition(offset: 0, affinity: TextAffinity.upstream)).offset, 80000);
    expect(window.paragraphRanges(0, 80000), isEmpty);
  });

  test('旧单窗口构造与映射 API 保持原语义', () {
    final window = EditableLineLayoutWindow(
      lineLength: 10,
      textStart: 3,
      text: 'abcd',
      originX: 8,
      estimatedTextWidth: 100,
      averageAdvance: 5,
      textDirection: TextDirection.ltr,
    );

    expect(window.isVisual, isFalse);
    expect(window.paragraphText, 'abcd');
    expect(window.textEnd, 7);
    expect(window.totalContentCodeUnits, 4);
    expect(window.totalParagraphCodeUnits, 4);
    expect(window.visualFragments, isEmpty);
    expect(window.fragmentContentRanges, isEmpty);
    expect(window.toParagraphPosition(const TextPosition(offset: 5)), const TextPosition(offset: 2));
    expect(window.toLinePosition(const TextPosition(offset: 2)), const TextPosition(offset: 5));
    expect(window.paragraphRange(2, 6), const TextRange(start: 0, end: 3));
    expect(window.paragraphRanges(2, 6), const [TextRange(start: 0, end: 3)]);
  });

  test('非相邻逻辑 run 按已解析的反向视觉顺序合成有界 Paragraph', () {
    final window = EditableLineLayoutWindow.visual(
      lineLength: 8,
      fragments: [_fragment(4, 6, 'CD', level: 1, tabPrefix: 40), _fragment(0, 2, 'ab')],
      estimatedTextWidth: 80,
    );

    expect(window.isVisual, isTrue);
    expect(window.textDirection, TextDirection.ltr);
    expect(window.visualFragments.map((fragment) => fragment.lineStart), [4, 0]);
    expect(window.text, 'CDab');
    expect(window.textStart, 0);
    expect(window.textEnd, 6);
    expect(window.logicalPrefixAdvance, 40);
    expect(window.totalContentCodeUnits, 4);
    expect(window.totalParagraphCodeUnits, 14);
    expect(window.fragmentContentRanges, const [TextRange(start: 3, end: 5), TextRange(start: 9, end: 11)]);
    expect(window.paragraphText.codeUnits, [
      0x202d,
      0x2066,
      0x202e,
      ...'CD'.codeUnits,
      0x202c,
      0x2069,
      0x2066,
      0x202d,
      ...'ab'.codeUnits,
      0x202c,
      0x2069,
      0x202c,
    ]);

    final painter = TextPainter(
      text: TextSpan(text: window.paragraphText, style: const TextStyle(fontSize: 14)),
      textDirection: window.textDirection,
    )..layout();
    addTearDown(painter.dispose);
    final firstBoxes = painter.getBoxesForSelection(
      TextSelection(
        baseOffset: window.fragmentContentRanges.first.start,
        extentOffset: window.fragmentContentRanges.first.end,
      ),
    );
    final secondBoxes = painter.getBoxesForSelection(
      TextSelection(
        baseOffset: window.fragmentContentRanges.last.start,
        extentOffset: window.fragmentContentRanges.last.end,
      ),
    );
    expect(firstBoxes, isNotEmpty);
    expect(secondBoxes, isNotEmpty);
    expect(
      firstBoxes.map((box) => box.left).reduce(math.min),
      lessThan(secondBoxes.map((box) => box.left).reduce(math.min)),
      reason: '外层必须保持调用方给定的最终左到右片段顺序',
    );
    expect(firstBoxes.every((box) => box.direction == TextDirection.rtl), isTrue);
    expect(secondBoxes.every((box) => box.direction == TextDirection.ltr), isTrue);
  });

  test('run seam 的同一 line offset 按 affinity 选择前后逻辑片段', () {
    final window = EditableLineLayoutWindow.visual(
      lineLength: 4,
      fragments: [_fragment(2, 4, 'cd', level: 1), _fragment(0, 2, 'ab')],
    );

    final downstream = window.toParagraphPosition(const TextPosition(offset: 2));
    final upstream = window.toParagraphPosition(const TextPosition(offset: 2, affinity: TextAffinity.upstream));
    expect(downstream, const TextPosition(offset: 3));
    expect(upstream, const TextPosition(offset: 11, affinity: TextAffinity.upstream));
    expect(window.toLinePosition(downstream), const TextPosition(offset: 2));
    expect(window.toLinePosition(upstream), const TextPosition(offset: 2, affinity: TextAffinity.upstream));
    expect(window.containsPosition(const TextPosition(offset: 2)), isTrue);
    expect(window.containsPosition(const TextPosition(offset: 2, affinity: TextAffinity.upstream)), isTrue);

    final beforeOnly = EditableLineLayoutWindow.visual(lineLength: 4, fragments: [_fragment(0, 2, 'ab')]);
    expect(beforeOnly.containsPosition(const TextPosition(offset: 2)), isFalse);
    expect(beforeOnly.containsPosition(const TextPosition(offset: 2, affinity: TextAffinity.upstream)), isTrue);
    final afterOnly = EditableLineLayoutWindow.visual(lineLength: 4, fragments: [_fragment(2, 4, 'cd', level: 1)]);
    expect(afterOnly.containsPosition(const TextPosition(offset: 2)), isTrue);
    expect(afterOnly.containsPosition(const TextPosition(offset: 2, affinity: TextAffinity.upstream)), isFalse);
  });

  test('X9 gap 与 synthetic controls 按 affinity 稳定跳到相邻真实正文', () {
    final window = EditableLineLayoutWindow.visual(
      lineLength: 6,
      fragments: [_fragment(0, 2, 'ab'), _fragment(4, 6, 'cd', level: 1)],
      zeroWidthLogicalRanges: const [TextRange(start: 2, end: 4)],
    );

    expect(
      window.toParagraphPosition(const TextPosition(offset: 3, affinity: TextAffinity.upstream)),
      const TextPosition(offset: 5, affinity: TextAffinity.upstream),
    );
    expect(window.toParagraphPosition(const TextPosition(offset: 3)), const TextPosition(offset: 9));
    expect(
      window.toLinePosition(const TextPosition(offset: 7, affinity: TextAffinity.upstream)),
      const TextPosition(offset: 2, affinity: TextAffinity.upstream),
    );
    expect(window.toLinePosition(const TextPosition(offset: 7)), const TextPosition(offset: 4));
    expect(window.toLinePosition(const TextPosition(offset: 0)), const TextPosition(offset: 0));
    expect(window.toLinePosition(TextPosition(offset: window.totalParagraphCodeUnits)), const TextPosition(offset: 6));
  });

  test('逻辑不连续的真实正文窗外区间不能冒充零宽 X9 gap', () {
    final window = EditableLineLayoutWindow.visual(
      lineLength: 6,
      fragments: [_fragment(0, 2, 'ab'), _fragment(4, 6, 'cd', level: 1)],
    );
    expect(window.containsPosition(const TextPosition(offset: 3)), isFalse);
    expect(window.containsPosition(const TextPosition(offset: 3, affinity: TextAffinity.upstream)), isFalse);
  });

  test('逻辑选区按视觉顺序拆成多段纯正文 range', () {
    final window = EditableLineLayoutWindow.visual(
      lineLength: 6,
      fragments: [_fragment(4, 6, 'CD', level: 1), _fragment(0, 2, 'ab')],
      zeroWidthLogicalRanges: const [TextRange(start: 2, end: 4)],
    );

    expect(window.paragraphRanges(1, 5), const [TextRange(start: 3, end: 4), TextRange(start: 10, end: 11)]);
    expect(window.paragraphRanges(2, 4), isEmpty, reason: 'X9 gap 不得把 synthetic controls 当成选区');
    expect(window.paragraphRanges(3, 3), isEmpty);
    expect(() => window.paragraphRange(1, 5), throwsStateError);
  });

  test('补充平面字符在双向映射和选区中始终不拆 UTF-16 代理对', () {
    final window = EditableLineLayoutWindow.visual(lineLength: 4, fragments: [_fragment(1, 3, '😀', level: 1)]);
    final content = window.fragmentContentRanges.single;

    expect(
      window.toParagraphPosition(const TextPosition(offset: 2, affinity: TextAffinity.upstream)),
      TextPosition(offset: content.start, affinity: TextAffinity.upstream),
    );
    expect(window.toParagraphPosition(const TextPosition(offset: 2)), TextPosition(offset: content.end));
    expect(
      window.toLinePosition(TextPosition(offset: content.start + 1, affinity: TextAffinity.upstream)),
      const TextPosition(offset: 1, affinity: TextAffinity.upstream),
    );
    expect(window.toLinePosition(TextPosition(offset: content.start + 1)), const TextPosition(offset: 3));
    expect(window.paragraphRanges(1, 3), [content]);
    expect(() => window.paragraphRanges(2, 3), throwsArgumentError);
  });

  test('单 tile 范围映射对 2048 个交替 control fragment 保持对数探针', () {
    const fragmentCount = 2048;
    final window = EditableLineLayoutWindow.visual(
      lineLength: fragmentCount * 2,
      fragments: [
        for (var index = 0; index < fragmentCount; index++)
          _fragment(index * 2, index * 2 + 1, 'x', level: index.isEven ? 0 : 1),
      ],
    );
    var maximumProbes = 0;
    for (var index = 0; index < fragmentCount; index++) {
      final range = window.paragraphRangeForContainedLogicalRange(index * 2, index * 2 + 1);
      expect(range, isNotNull);
      maximumProbes = math.max(maximumProbes, window.debugLastContainedRangeProbeCount);
    }
    expect(maximumProbes, lessThanOrEqualTo(12), reason: 'layout 每个 tile 不得重新线扫全部 visual fragments');
    expect(window.paragraphRangeForContainedLogicalRange(0, 3), isNull, reason: '跨 fragment 仍必须拒绝快路');
  });

  test('百个多光标窄选区不随 2048 个 visual fragments 全表扫描', () {
    const fragmentCount = 2048;
    final window = EditableLineLayoutWindow.visual(
      lineLength: fragmentCount * 2,
      fragments: [
        for (var index = 0; index < fragmentCount; index++)
          _fragment(index * 2, index * 2 + 1, 'x', level: index.isEven ? 0 : 1),
      ],
    );
    var maximumProbes = 0;
    for (var cursor = 0; cursor < 100; cursor++) {
      final offset = (cursor * 37 % fragmentCount) * 2;
      expect(window.paragraphRanges(offset, offset + 1), hasLength(1));
      maximumProbes = math.max(maximumProbes, window.debugLastContainedRangeProbeCount);
      expect(window.paragraphRangesForPainting(offset, offset + 1), hasLength(1));
      maximumProbes = math.max(maximumProbes, window.debugLastContainedRangeProbeCount);
    }
    expect(maximumProbes, lessThanOrEqualTo(12), reason: 'caret 重绘不得对每个多光标从头扫描全部 fragments');
  });

  test('invalid、重叠与超预算输入严格失败，孤立 surrogate 保留原 UTF-16 offset', () {
    expect(() => EditableLineLayoutWindow.visual(lineLength: 1, fragments: const []), throwsArgumentError);
    expect(
      () => EditableLineLayoutWindow.visual(lineLength: 2, fragments: [_fragment(0, 2, 'a')]),
      throwsArgumentError,
    );
    expect(
      () => EditableLineLayoutWindow.visual(lineLength: 5, fragments: [_fragment(2, 5, 'cde'), _fragment(0, 3, 'abc')]),
      throwsArgumentError,
    );
    final isolated = EditableLineLayoutWindow.visual(
      lineLength: 1,
      fragments: [_fragment(0, 1, String.fromCharCode(0xde00))],
    );
    expect(isolated.toLinePosition(isolated.toParagraphPosition(const TextPosition(offset: 0))).offset, 0);
    expect(
      () => EditableLineLayoutWindow.visual(
        lineLength: 2,
        fragments: [_fragment(0, 1, String.fromCharCode(0xd83d)), _fragment(1, 2, String.fromCharCode(0xde00))],
      ),
      throwsArgumentError,
    );
    expect(
      () => EditableLineLayoutWindow.visual(lineLength: 1, fragments: [_fragment(0, 1, 'a', level: 127)]),
      throwsRangeError,
    );
    expect(
      () => EditableLineLayoutWindow.visual(lineLength: 1, fragments: [_fragment(0, 1, 'a', tabPrefix: double.nan)]),
      throwsArgumentError,
    );
    expect(
      () =>
          EditableLineLayoutWindow.visual(lineLength: 2, fragments: [_fragment(0, 2, 'ab')], paragraphCodeUnitLimit: 7),
      throwsRangeError,
    );
  });
}
