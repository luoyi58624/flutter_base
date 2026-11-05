import 'package:characters/characters.dart';
import 'package:flutter_base/src/flutter/views/editable/render/bidi/long_line_bidi_index.dart';
import 'package:flutter_base/src/flutter/views/editable/render/bidi/long_line_visual_index.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LongLineVisualIndex tiles', () {
    test('按 visual run 排列，RTL run 内 tile 反向', () {
      final index = _build('abcאבגdef', targetTileCodeUnits: 2);

      expect(index.tiles.map((tile) => (tile.start, tile.end, tile.level)), <(int, int, int)>[
        (0, 2, 0),
        (2, 3, 0),
        (5, 6, 1),
        (3, 5, 1),
        (6, 8, 0),
        (8, 9, 0),
      ]);
      expect(index.tiles.map((tile) => tile.visualIndex), orderedEquals(<int>[0, 1, 2, 3, 4, 5]));
      expect(index.tiles.map((tile) => tile.paintRunIndex), orderedEquals(<int>[0, 0, 1, 1, 2, 2]));
    });

    test('超长 odd-level run 的多个 tile 按视觉顺序反转', () {
      final text = List<String>.filled(5000, 'א').join();
      final index = _build(text);

      expect(index.tiles, hasLength(2));
      expect((index.tiles[0].start, index.tiles[0].end, index.tiles[0].level), (4096, 5000, 1));
      expect((index.tiles[1].start, index.tiles[1].end, index.tiles[1].level), (0, 4096, 1));
    });

    test('tile seam 不拆 surrogate pair 或 combining sequence', () {
      const text = '😀e\u0301xyz';
      final index = _build(text, targetTileCodeUnits: 3);

      expect(index.tiles.first.start, 0);
      expect(index.tiles.first.end, 4);
      for (final tile in index.tiles) {
        expect(CharacterRange.at(text, tile.start).isEmpty, isTrue, reason: 'start=${tile.start} 必须是字素边界');
        expect(CharacterRange.at(text, tile.end).isEmpty, isTrue, reason: 'end=${tile.end} 必须是字素边界');
      }
      expect(index.tiles.map((tile) => tile.length).reduce((left, right) => left + right), text.length);
    });

    test('resolved level 变化也不得拆开 Prepend extended grapheme', () {
      const text = '\u0600A';
      final index = _build(text, targetTileCodeUnits: 1);

      expect(CharacterRange.at(text, 1).isEmpty, isFalse);
      expect(index.bidiIndex.levels, <int>[2, 0]);
      expect(index.tiles, hasLength(1));
      expect((index.tiles.single.start, index.tiles.single.end), (0, 2));
    });

    test('RI、Indic conjunct 与 ZWJ clusters 都是不可拆分的 tile 原子', () {
      for (final text in <String>['🇺🇸', 'क्‍ष', '👩‍👩‍👧‍👦']) {
        final index = _build(text, targetTileCodeUnits: 1);

        expect(index.tiles, hasLength(1), reason: '$text 必须保持单一 extended grapheme');
        expect((index.tiles.single.start, index.tiles.single.end), (0, text.length));
      }
    });

    test('显式方向格式 gap 不生成 tile，空文本合法', () {
      const text = 'a\u202Ab\u202Cc';
      final index = _build(text, targetTileCodeUnits: 1);
      final covered = <int>{
        for (final tile in index.tiles)
          for (var offset = tile.start; offset < tile.end; offset++) offset,
      };

      expect(covered, <int>{0, 2, 4});
      expect(index.tiles.fold<int>(0, (sum, tile) => sum + tile.length), index.bidiIndex.visualCodeUnitLength);

      final empty = _build('');
      expect(empty.tiles, isEmpty);
      expect(empty.totalExtent, 0);
      expect(empty.locateOffset(0, affinity: TextAffinity.downstream), isNull);
      expect(empty.locateX(0), isNull);
      expect(empty.selectViewport(viewportStart: 0, viewportEnd: 100, guard: 20, maxCodeUnits: 100).isEmpty, isTrue);
    });

    test('emoji ZWJ sequence 保留为同一个 grapheme-safe tile', () {
      const text = 'x👩‍👩‍👧‍👦y';
      final index = _build(text, targetTileCodeUnits: 1);
      final familyStart = 1;
      final familyEnd = text.length - 1;
      final familyTiles = index.tiles
          .where((tile) => tile.start < familyEnd && tile.end > familyStart)
          .toList(growable: false);

      expect(familyTiles, hasLength(1));
      expect((familyTiles.single.start, familyTiles.single.end), (familyStart, familyEnd));
      for (var offset = 0; offset < text.length; offset++) {
        if (text.codeUnitAt(offset) != 0x200d) continue;
        expect(
          index.tiles.any((tile) => tile.start <= offset && offset < tile.end),
          isTrue,
          reason: 'ZWJ offset=$offset 必须留给 shaping',
        );
      }
    });

    test('Arabic ZWNJ/ZWJ 与两侧字母保留在同一个 paint fragment', () {
      for (final joiner in <String>['\u200c', '\u200d']) {
        final text = 'ا$joinerب';
        final index = _build(text);

        expect(index.tiles, hasLength(1));
        expect((index.tiles.single.start, index.tiles.single.end), (0, text.length));
        expect(index.tiles.single.level.isOdd, isTrue);
      }
    });

    test('SHY、ZWSP 与 WJ 等普通 BN 全部保留进 paint tiles', () {
      const text = 'a\u00adb\u200bc\u2060d';
      final index = _build(text, targetTileCodeUnits: 1);
      final covered = <int>{
        for (final tile in index.tiles)
          for (var offset = tile.start; offset < tile.end; offset++) offset,
      };

      expect(covered, <int>{for (var offset = 0; offset < text.length; offset++) offset});
      expect(index.tiles.fold<int>(0, (sum, tile) => sum + tile.length), text.length);
      expect(index.bidiIndex.visualCodeUnitLength, text.length - 3, reason: 'bidi X9 map 仍可排除 BN，paint 层独立保留');
    });

    test('未闭合与成对 isolate、RLO/PDF 始终投影为逻辑 gap', () {
      final fixtures = <(String, Set<int>)>[
        ('a\u2066b', <int>{1}),
        ('a\u2067b', <int>{1}),
        ('a\u2068b', <int>{1}),
        ('a\u2069b', <int>{1}),
        ('a\u2066b\u2069c', <int>{1, 3}),
        ('a\u202eb\u202cc', <int>{1, 3}),
      ];
      for (final (text, formattingOffsets) in fixtures) {
        final index = _build(text, targetTileCodeUnits: 1);
        final covered = <int>{
          for (final tile in index.tiles)
            for (var offset = tile.start; offset < tile.end; offset++) offset,
        };
        for (final offset in formattingOffsets) {
          expect(covered, isNot(contains(offset)), reason: '$text 的格式控制 offset=$offset 不得进入 paint tile');
        }
        expect(covered.length, text.length - formattingOffsets.length);
      }
    });

    test('paint-run L2 顺序等于完整 bidi 视觉序过滤格式控制后的顺序', () {
      const text = 'a\u2067אב12\u2069c';
      final formattingOffsets = <int>{1, text.length - 2};
      final index = _build(text, targetTileCodeUnits: 1);
      final expected = index.bidiIndex.visualToLogical
          .take(index.bidiIndex.visualCodeUnitLength)
          .where((offset) => !formattingOffsets.contains(offset));
      final actual = <int>[
        for (final tile in index.tiles)
          if (tile.isRtl)
            for (var offset = tile.end - 1; offset >= tile.start; offset--) offset
          else
            for (var offset = tile.start; offset < tile.end; offset++) offset,
      ];

      expect(actual, orderedEquals(expected));
    });
  });

  group('LongLineVisualIndex widths', () {
    test('单项与批量实测宽度以 O(log T) 更新所有后继前缀', () {
      final index = _build('abcdef', targetTileCodeUnits: 2);

      expect(index.tiles, hasLength(3));
      expect(index.totalExtent, 60);
      expect(<double>[for (var i = 0; i < 3; i++) index.startXOf(i)], <double>[0, 20, 40]);
      expect(index.isMeasured(1), isFalse);

      index.reportMeasuredWidth(1, 50);
      expect(index.totalExtent, 90);
      expect(<double>[for (var i = 0; i < 3; i++) index.startXOf(i)], <double>[0, 20, 70]);
      expect(index.isMeasured(1), isTrue);

      index.reportMeasuredWidths(<int, double>{0: 12, 2: 8});
      expect(index.totalExtent, 70);
      expect(<double>[for (var i = 0; i < 3; i++) index.startXOf(i)], <double>[0, 12, 62]);
      expect(<double>[for (var i = 0; i < 3; i++) index.endXOf(i)], <double>[12, 62, 70]);
      expect(<double>[for (var i = 0; i < 3; i++) index.widthOf(i)], <double>[12, 50, 8]);
    });

    test('批量回填先完整校验，非法项不会留下部分写入', () {
      final index = _build('abcdef', targetTileCodeUnits: 2);

      expect(() => index.reportMeasuredWidths(<int, double>{0: 12, 99: 8}), throwsRangeError);
      expect(index.totalExtent, 60);
      expect(index.isMeasured(0), isFalse);
      expect(() => index.reportMeasuredWidth(0, -1), throwsArgumentError);
      expect(() => index.reportMeasuredWidth(0, double.nan), throwsArgumentError);
      expect(() => index.reportMeasuredWidth(0, double.infinity), throwsArgumentError);
      expect(index.totalExtent, 60);
    });

    test('非均匀估值原子更新未测 tile，已测宽与 measured 身份严格保留', () {
      final index = _build('abcdef', targetTileCodeUnits: 2)..reportMeasuredWidth(1, 50);

      index.updateUnmeasuredWidths(<int, double>{0: 7, 1: 999, 2: 13});
      expect(<double>[for (var tile = 0; tile < 3; tile++) index.widthOf(tile)], <double>[7, 50, 13]);
      expect(<double>[for (var tile = 0; tile < 3; tile++) index.startXOf(tile)], <double>[0, 7, 57]);
      expect(index.totalExtent, 70);
      expect(<bool>[for (var tile = 0; tile < 3; tile++) index.isMeasured(tile)], <bool>[false, true, false]);

      expect(() => index.updateUnmeasuredWidths(<int, double>{0: 8, 99: 1}), throwsRangeError);
      expect(() => index.updateUnmeasuredWidths(<int, double>{0: 8, 1: double.nan}), throwsArgumentError);
      expect(<double>[for (var tile = 0; tile < 3; tile++) index.widthOf(tile)], <double>[7, 50, 13]);
    });

    test('十万 tiles 的小批非均匀估值只做 K 次 Fenwick delta，平均值更新才允许单次全树重建', () {
      final index = _build('a' * 100000, targetTileCodeUnits: 1);
      final initialAdds = index.debugWidthTreeAddCount;
      final initialRebuilds = index.debugWidthTreeRebuildCount;

      index.updateUnmeasuredWidths(<int, double>{1: 7, 50000: 9, 99998: 11});
      expect(index.debugWidthTreeAddCount - initialAdds, 3);
      expect(index.debugWidthTreeRebuildCount, initialRebuilds, reason: '小批 K 项更新禁止每帧 O(T) rebuild');
      expect(index.totalExtent, closeTo(999997, 0.001));

      index.updateUnmeasuredAverageAdvance(5);
      expect(index.debugWidthTreeAddCount - initialAdds, 3, reason: '全量平均更新不得先构造巨 Map 再逐项 add');
      expect(index.debugWidthTreeRebuildCount - initialRebuilds, 1);
      expect(index.totalExtent, closeTo(500000, 0.001));
    });

    test('平均 advance 以 O(T) 重估全部未测 tile 并同步 Fenwick', () {
      final index = _build('abcdef', targetTileCodeUnits: 2)..reportMeasuredWidth(1, 50);

      index.updateUnmeasuredAverageAdvance(5);
      expect(index.averageAdvance, 5);
      expect(<double>[for (var tile = 0; tile < 3; tile++) index.widthOf(tile)], <double>[10, 50, 10]);
      expect(<double>[for (var tile = 0; tile < 3; tile++) index.startXOf(tile)], <double>[0, 10, 60]);
      expect(index.totalExtent, 70);
      expect(index.isMeasured(1), isTrue);
      expect(() => index.updateUnmeasuredAverageAdvance(0), throwsArgumentError);
      expect(index.averageAdvance, 5);
      expect(index.totalExtent, 70);
    });

    test('零宽实测 tile 仍保持有限、稳定的 seam 命中', () {
      final index = _build('abcd', targetTileCodeUnits: 2)..reportMeasuredWidth(0, 0);

      expect(index.totalExtent, 20);
      final downstream = index.locateX(0)!;
      final upstream = index.locateX(0, affinity: TextAffinity.upstream)!;
      expect(downstream.tileIndex, 1);
      expect(downstream.estimatedOffset, 2);
      expect(upstream.tileIndex, 0);
      expect(upstream.estimatedOffset, 0);
      expect(downstream.visualX.isFinite, isTrue);
      expect(upstream.visualX.isFinite, isTrue);
    });
  });

  group('LongLineVisualIndex offset/x mapping', () {
    test('LTR tile seam 以 affinity 稳定选择逻辑前后候选', () {
      final index = _build('abcdef', targetTileCodeUnits: 2);

      final upstream = index.locateOffset(2, affinity: TextAffinity.upstream)!;
      final downstream = index.locateOffset(2, affinity: TextAffinity.downstream)!;
      expect((upstream.tileIndex, upstream.offset, upstream.visualX), (0, 2, 20));
      expect((downstream.tileIndex, downstream.offset, downstream.visualX), (1, 2, 20));

      final hitUpstream = index.locateX(20, affinity: TextAffinity.upstream)!;
      final hitDownstream = index.locateX(20, affinity: TextAffinity.downstream)!;
      expect((hitUpstream.tileIndex, hitUpstream.estimatedOffset), (0, 2));
      expect((hitDownstream.tileIndex, hitDownstream.estimatedOffset), (1, 2));
    });

    test('同一 RTL run 的 4096 tile seam 两个 affinity 共用同一视觉 x', () {
      final index = _build('א' * 9000, baseDirection: LongLineBidiBaseDirection.rtl);
      final upstream = index.locateOffset(4096, affinity: TextAffinity.upstream)!;
      final downstream = index.locateOffset(4096, affinity: TextAffinity.downstream)!;
      expect(upstream.tileIndex, isNot(downstream.tileIndex));
      expect(upstream.visualX, closeTo(downstream.visualX, 0.001));
      final hitUpstream = index.locateX(upstream.visualX, affinity: TextAffinity.upstream)!;
      final hitDownstream = index.locateX(downstream.visualX, affinity: TextAffinity.downstream)!;
      expect(hitUpstream.tileIndex, downstream.tileIndex, reason: 'RTL 逻辑后片段位于 seam 的视觉左侧');
      expect(hitDownstream.tileIndex, upstream.tileIndex, reason: 'RTL 逻辑前片段位于 seam 的视觉右侧');
      expect(hitUpstream.estimatedOffset, 4096);
      expect(hitDownstream.estimatedOffset, 4096);
    });

    test('bidi run seam 的同一逻辑 offset 暴露两处视觉 caret', () {
      final index = _build('aאב');

      final upstream = index.locateOffset(1, affinity: TextAffinity.upstream)!;
      final downstream = index.locateOffset(1, affinity: TextAffinity.downstream)!;
      expect(upstream.offset, 1);
      expect(downstream.offset, 1);
      expect(upstream.tileIndex, isNot(downstream.tileIndex));
      expect(upstream.visualX, isNot(downstream.visualX));
      expect((upstream.visualX - downstream.visualX).abs(), 20);
    });

    test('方向格式 gap 按 affinity 投到相邻可见边界', () {
      final index = _build('a\u202Ab\u202Cc', targetTileCodeUnits: 1);

      final after = index.locateOffset(1, affinity: TextAffinity.downstream)!;
      final before = index.locateOffset(1, affinity: TextAffinity.upstream)!;
      expect((after.offset, index.tiles[after.tileIndex].start), (2, 2));
      expect((before.offset, index.tiles[before.tileIndex].end), (1, 1));

      final afterSecond = index.locateOffset(3, affinity: TextAffinity.downstream)!;
      final beforeSecond = index.locateOffset(3, affinity: TextAffinity.upstream)!;
      expect((afterSecond.offset, index.tiles[afterSecond.tileIndex].start), (4, 4));
      expect((beforeSecond.offset, index.tiles[beforeSecond.tileIndex].end), (3, 3));
    });

    test('tile 内 x 双向估算会吸附到 grapheme 边界', () {
      const text = '😀e\u0301xy';
      final index = _build(text, targetTileCodeUnits: 4);

      final middleEmoji = index.locateX(10)!;
      expect(middleEmoji.estimatedOffset, 2);
      expect(CharacterRange.at(text, middleEmoji.estimatedOffset).isEmpty, isTrue);

      final caret = index.locateOffset(4, affinity: TextAffinity.downstream)!;
      expect(caret.offset, 4);
      expect(caret.visualX, 40);
      expect(index.locateX(caret.visualX)!.estimatedOffset, 4);
    });

    test('超出范围的有限 x 钳制，非法 offset/x 严格拒绝', () {
      final index = _build('abcd', targetTileCodeUnits: 2);

      expect(index.locateX(-100)!.estimatedOffset, 0);
      expect(index.locateX(100)!.estimatedOffset, 4);
      expect(() => index.locateOffset(-1, affinity: TextAffinity.downstream), throwsRangeError);
      expect(() => index.locateOffset(5, affinity: TextAffinity.downstream), throwsRangeError);
      expect(() => index.locateX(double.nan), throwsArgumentError);
      expect(() => index.locateX(double.infinity), throwsArgumentError);
    });
  });

  group('LongLineVisualIndex viewport', () {
    test('返回连续视觉片段并严格遵守 code-unit 硬预算', () {
      final index = _build('abcdefghijklmnopqrst', targetTileCodeUnits: 2);
      final window = index.selectViewport(viewportStart: 60, viewportEnd: 100, guard: 20, maxCodeUnits: 6);

      expect(window.tileCount, 3);
      expect(window.codeUnits, 6);
      expect(window.firstTile, inInclusiveRange(2, 4));
      expect(window.endTile, window.firstTile + 3);
      expect(window.startX, index.startXOf(window.firstTile));
      expect(window.endX, index.endXOf(window.endTile - 1));
      expect(window.startX, lessThanOrEqualTo(80));
      expect(window.endX, greaterThanOrEqualTo(80));
    });

    test('单 tile 超预算、完全在 extent 外和空行都返回空窗口', () {
      final index = _build('abcdefgh', targetTileCodeUnits: 2);

      expect(index.selectViewport(viewportStart: 0, viewportEnd: 40, guard: 0, maxCodeUnits: 1).isEmpty, isTrue);
      expect(index.selectViewport(viewportStart: 100, viewportEnd: 120, guard: 10, maxCodeUnits: 100).isEmpty, isTrue);
    });

    test('零宽 viewport 位于 tile seam 时仍选择确定的单一 anchor', () {
      final index = _build('abcdef', targetTileCodeUnits: 2);
      final window = index.selectViewport(viewportStart: 20, viewportEnd: 20, guard: 0, maxCodeUnits: 2);

      expect(window.tileCount, 1);
      expect(window.codeUnits, 2);
      expect(window.firstTile, 1);
    });

    test('viewport 参数与预算严格校验', () {
      final index = _build('abcd');

      expect(
        () => index.selectViewport(viewportStart: 2, viewportEnd: 1, guard: 0, maxCodeUnits: 1),
        throwsArgumentError,
      );
      expect(
        () => index.selectViewport(viewportStart: double.nan, viewportEnd: 1, guard: 0, maxCodeUnits: 1),
        throwsArgumentError,
      );
      expect(
        () => index.selectViewport(viewportStart: 0, viewportEnd: double.infinity, guard: 0, maxCodeUnits: 1),
        throwsArgumentError,
      );
      expect(
        () => index.selectViewport(viewportStart: 0, viewportEnd: 1, guard: -1, maxCodeUnits: 1),
        throwsArgumentError,
      );
      expect(() => index.selectViewport(viewportStart: 0, viewportEnd: 1, guard: 0, maxCodeUnits: 0), throwsRangeError);
    });
  });

  group('LongLineVisualIndex validation', () {
    test('构造参数与 bidi UTF-16 identity 严格校验', () {
      final bidi = LongLineBidiIndex.resolve('x', baseDirection: LongLineBidiBaseDirection.ltr);

      expect(() => _build('x', averageAdvance: 0), throwsArgumentError);
      expect(() => _build('x', averageAdvance: -1), throwsArgumentError);
      expect(() => _build('x', averageAdvance: double.nan), throwsArgumentError);
      expect(() => _build('x', averageAdvance: double.infinity), throwsArgumentError);
      expect(() => _build('x', targetTileCodeUnits: 0), throwsRangeError);
      expect(() => LongLineVisualIndex(text: 'xx', bidiIndex: bidi, averageAdvance: 10), throwsArgumentError);
    });

    test('tile index 查询严格拒绝越界', () {
      final index = _build('x');

      expect(() => index.widthOf(-1), throwsRangeError);
      expect(() => index.startXOf(1), throwsRangeError);
      expect(() => index.endXOf(1), throwsRangeError);
      expect(() => index.isMeasured(1), throwsRangeError);
    });
  });
}

LongLineVisualIndex _build(
  String text, {
  double averageAdvance = 10,
  int targetTileCodeUnits = LongLineVisualIndex.defaultTargetTileCodeUnits,
  LongLineBidiBaseDirection baseDirection = LongLineBidiBaseDirection.ltr,
}) => LongLineVisualIndex(
  text: text,
  bidiIndex: LongLineBidiIndex.resolve(text, baseDirection: baseDirection),
  averageAdvance: averageAdvance,
  targetTileCodeUnits: targetTileCodeUnits,
);
