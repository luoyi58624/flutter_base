import 'dart:typed_data';

import 'package:flutter_base/src/flutter/views/editable/render/bidi/long_line_bidi_index.dart';
import 'package:flutter_base/src/flutter/views/editable/render/bidi/unicode_bidi_data.g.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _ints(Iterable<int> values) => values.toList(growable: false);

String _visualText(String logical, LongLineBidiIndex index) {
  return String.fromCharCodes([
    for (var visual = 0; visual < index.visualCodeUnitLength; visual++)
      logical.codeUnitAt(index.visualToLogical[visual]),
  ]);
}

String _repeat(String value, int count) => List<String>.filled(count, value).join();

int _maxInt(int left, int right) => left > right ? left : right;

void _expectVisibleRoundTrip(LongLineBidiIndex index) {
  for (var logical = 0; logical < index.utf16Length; logical++) {
    final visual = index.logicalToVisual[logical];
    if (index.x9Removed[logical] != 0) {
      expect(visual, -1, reason: 'X9 logical unit $logical');
    } else {
      expect(visual, inInclusiveRange(0, index.visualCodeUnitLength - 1));
      expect(index.visualToLogical[visual], logical);
    }
  }
  for (var visual = index.visualCodeUnitLength; visual < index.utf16Length; visual++) {
    expect(index.visualToLogical[visual], -1, reason: '无效视觉尾槽 $visual');
  }
}

void main() {
  test('空串返回显式 base 与全部合法空结构', () {
    final ltr = LongLineBidiIndex.resolve('', baseDirection: LongLineBidiBaseDirection.ltr);
    final rtl = LongLineBidiIndex.resolve('', baseDirection: LongLineBidiBaseDirection.rtl);

    expect(ltr.paragraphLevel, 0);
    expect(rtl.paragraphLevel, 1);
    for (final value in [ltr, rtl]) {
      expect(value.atomCount, 0);
      expect(value.visualCodeUnitLength, 0);
      expect(value.levels, isEmpty);
      expect(value.x9Removed, isEmpty);
      expect(value.logicalRuns, isEmpty);
      expect(value.visualRunOrder, isEmpty);
      expect(value.visualToLogical, isEmpty);
      expect(value.logicalToVisual, isEmpty);
    }
  });

  test('mixed Hebrew、数字与 bracket 的 L1 levels、L2 runs 和 offset map 对齐 oracle', () {
    const text = 'abc אבג 123 (דה)';
    final value = LongLineBidiIndex.resolve(text, baseDirection: LongLineBidiBaseDirection.ltr);

    expect(_ints(value.levels), [0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 1, 1, 1, 1, 1]);
    expect(_ints(value.visualToLogical), [0, 1, 2, 3, 15, 14, 13, 12, 11, 8, 9, 10, 7, 6, 5, 4]);
    expect(_ints(value.logicalToVisual), [0, 1, 2, 3, 15, 14, 13, 12, 9, 10, 11, 8, 7, 6, 5, 4]);
    expect(_visualText(text, value), 'abc )הד( 123 גבא');
    expect(_ints(value.visualRunOrder), [0, 3, 2, 1]);
    expect(value.logicalRuns.map((run) => (run.start, run.end, run.level, run.removed)), [
      (0, 4, 0, false),
      (4, 8, 1, false),
      (8, 11, 2, false),
      (11, 16, 1, false),
    ]);
    _expectVisibleRoundTrip(value);
  });

  test('RLO/PDF 执行 override、X9 与 removed offset 哨兵，run order 不包含 removed', () {
    const text = 'abc\u202e12\u202cdef';
    final value = LongLineBidiIndex.resolve(text, baseDirection: LongLineBidiBaseDirection.ltr);

    expect(_ints(value.levels), [0, 0, 0, 0, 1, 1, 0, 0, 0, 0]);
    expect(_ints(value.x9Removed), [0, 0, 0, 1, 0, 0, 1, 0, 0, 0]);
    expect(_ints(value.visualToLogical), [0, 1, 2, 5, 4, 7, 8, 9, -1, -1]);
    expect(_ints(value.logicalToVisual), [0, 1, 2, -1, 4, 3, -1, 5, 6, 7]);
    expect(_visualText(text, value), 'abc21def');
    expect(_ints(value.visualRunOrder), [0, 2, 4]);
    _expectVisibleRoundTrip(value);
  });

  test('LRI/RLI/FSI/PDI 跨 level-run 串联为完整 isolating run sequence', () {
    const text = 'L\u2068x\u2067אב\u2069y\u2069R';
    final value = LongLineBidiIndex.resolve(text, baseDirection: LongLineBidiBaseDirection.ltr);

    expect(_ints(value.levels), [0, 0, 2, 2, 3, 3, 2, 2, 0, 0]);
    expect(_ints(value.visualToLogical), [0, 1, 2, 3, 5, 4, 6, 7, 8, 9]);
    expect(_visualText(text, value), 'L\u2068x\u2067בא\u2069y\u2069R');
    expect(value.x9Removed, everyElement(0));
    _expectVisibleRoundTrip(value);
  });

  test('125 显式深度后 overflow embeddings 有界，PDF 全部结清回到 base', () {
    final text = '${_repeat('\u202b', 130)}A${_repeat('\u202c', 130)}Z';
    final value = LongLineBidiIndex.resolve(text, baseDirection: LongLineBidiBaseDirection.ltr);

    expect(value.levels[130], 126, reason: 'level 125 中的 L 按 I2 到达规范允许的 126');
    expect(value.levels.last, 0);
    expect(value.levels.reduce(_maxInt), 126);
    expect(value.x9Removed.take(130), everyElement(1));
    expect(value.x9Removed.skip(131).take(130), everyElement(1));
    expect(value.visualCodeUnitLength, 2);
    expect(_visualText(text, value), 'AZ');
    _expectVisibleRoundTrip(value);
  });

  test('BD16 第64个 opening 丢弃同一 IRS 中 overflow 前已经形成的 pair', () {
    const prefix = 'א(א)';
    final withinCapacity = LongLineBidiIndex.resolve(
      '$prefix${_repeat('(', 63)}',
      baseDirection: LongLineBidiBaseDirection.ltr,
    );
    final overflow = LongLineBidiIndex.resolve(
      '$prefix${_repeat('(', 64)}',
      baseDirection: LongLineBidiBaseDirection.ltr,
    );

    expect(withinCapacity.levels[3], 1, reason: '先证明前置 pair 在 N0 下解析为 R');
    expect(overflow.levels[3], 0, reason: '第64个 opening 必须让整份 pair list 失效，而不是保留旧 pair');
  });

  test('supplementary RTL scalar 的 surrogate levels 相同且视觉槽保持 high→low 原子', () {
    final text = 'A${String.fromCharCode(0x1e900)}B';
    final value = LongLineBidiIndex.resolve(text, baseDirection: LongLineBidiBaseDirection.rtl);

    expect(text.length, 4);
    expect(value.atomCount, 3);
    expect(_ints(value.levels), [2, 1, 1, 2]);
    expect(_ints(value.visualToLogical), [3, 1, 2, 0]);
    expect(_ints(value.logicalToVisual), [3, 1, 2, 0]);
    expect(value.visualToLogical[2], value.visualToLogical[1] + 1);
    expect(text.codeUnitAt(value.visualToLogical[1]), inInclusiveRange(0xd800, 0xdbff));
    expect(text.codeUnitAt(value.visualToLogical[2]), inInclusiveRange(0xdc00, 0xdfff));
    _expectVisibleRoundTrip(value);
  });

  test('孤立 surrogate 按单宽 U+FFFD 分类但保留原 UTF-16 offset', () {
    final text = String.fromCharCodes([0x41, 0xd800, 0x05d0]);
    final value = LongLineBidiIndex.resolve(text, baseDirection: LongLineBidiBaseDirection.ltr);

    expect(value.atomCount, 3);
    expect(value.levels, hasLength(3));
    expect(value.visualToLogical.where((offset) => offset >= 0).toSet(), {0, 1, 2});
    _expectVisibleRoundTrip(value);
  });

  test('types-only oracle 暴露官方 BidiTest 所需 levels、removed、L2 order 与 P2/P3', () {
    final types = Uint8List.fromList([UnicodeBidiClass.l.index, UnicodeBidiClass.r.index, UnicodeBidiClass.en.index]);
    final value = resolveLongLineBidiTypesForTesting(types, paragraphLevel: 0);

    expect(_ints(value.levels), [0, 1, 2]);
    expect(_ints(value.removed), [0, 0, 0]);
    expect(_ints(value.visualOrder), [0, 2, 1]);
    expect(
      baseLevelForTypesForTesting(
        Uint8List.fromList([
          UnicodeBidiClass.fsi.index,
          UnicodeBidiClass.r.index,
          UnicodeBidiClass.pdi.index,
          UnicodeBidiClass.l.index,
        ]),
      ),
      0,
    );
    expect(
      baseLevelForTypesForTesting(
        Uint8List.fromList([
          UnicodeBidiClass.fsi.index,
          UnicodeBidiClass.l.index,
          UnicodeBidiClass.pdi.index,
          UnicodeBidiClass.r.index,
        ]),
      ),
      1,
    );
  });
}
