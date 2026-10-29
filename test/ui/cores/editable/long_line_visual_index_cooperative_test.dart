import 'package:flutter_base/src/ui/cores/editable/render/bidi/long_line_bidi_index.dart';
import 'package:flutter_base/src/ui/cores/editable/render/bidi/long_line_cooperative_scheduler.dart';
import 'package:flutter_base/src/ui/cores/editable/render/bidi/long_line_visual_index.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cooperative visual index 与同步 tile、方向 gap 和几何逐项一致', () async {
    final samples = <String>[
      'abc אבג 123 العربية',
      'a\u202e(אב 12)\u202cb',
      'A👩‍👩‍👧‍👦\u200cالعربية\u200dB',
      '🇨🇳🇺🇳 क्‍ष क्ष',
      String.fromCharCodes(<int>[0x41, 0xd83d, 0x42, 0xdc00, 0x5d0, 0x43]),
    ];
    for (final direction in LongLineBidiBaseDirection.values) {
      for (final text in samples) {
        final bidi = LongLineBidiIndex.resolve(text, baseDirection: direction);
        final expected = LongLineVisualIndex(text: text, bidiIndex: bidi, averageAdvance: 7.25, targetTileCodeUnits: 4);
        final actual = await LongLineVisualIndex.createCooperatively(
          text: text,
          bidiIndex: bidi,
          averageAdvance: 7.25,
          targetTileCodeUnits: 4,
        );
        _expectSameVisualIndex(actual, expected);
      }
    }
  });

  test('超长单 grapheme 仍不拆分且扫描受 64 work-unit 预算约束', () async {
    final text = 'a${List<String>.filled(kIsWeb ? 1000 : 20000, '\u0301').join()}';
    final bidi = LongLineBidiIndex.resolve(text, baseDirection: LongLineBidiBaseDirection.ltr);
    final probe = LongLineCooperativeProbe();
    var callbacks = 0;
    final scheduler = LongLineCooperativeScheduler(
      maxWorkUnitsBeforeYield: 64,
      probe: probe,
      yieldCallback: () async {
        callbacks++;
        await Future<void>.delayed(Duration.zero);
      },
    );

    final actual = await LongLineVisualIndex.createCooperatively(
      text: text,
      bidiIndex: bidi,
      averageAdvance: 1,
      targetTileCodeUnits: 32,
      scheduler: scheduler,
    );
    scheduler.finish();

    expect(actual.tiles, hasLength(1));
    expect(actual.tiles.single.length, text.length);
    expect(callbacks, greaterThan(10));
    expect(probe.yieldCount, callbacks);
    expect(probe.maximumContinuousWorkUnits, lessThanOrEqualTo(64));
    expect(probe.largestUninterruptibleAllocationCodeUnits, greaterThanOrEqualTo(text.length));
    expect(
      probe.workUnitsByPhase.keys,
      containsAll(<String>{
        'visual.paint.decode',
        'visual.grapheme',
        'visual.paint.runs-count',
        'visual.paint.runs-fill',
        'visual.tiles.grapheme-forward',
        'visual.width-index',
      }),
    );
  });

  test('极端 level/X9 交替与 targetTile=1 使用定长 runs、cores、result 存储', () async {
    const unit = 'a\u202e\u202cא\u2060';
    final text = List<String>.filled(2000, unit).join();
    final bidi = LongLineBidiIndex.resolve(text, baseDirection: LongLineBidiBaseDirection.ltr);
    final expected = LongLineVisualIndex(text: text, bidiIndex: bidi, averageAdvance: 1, targetTileCodeUnits: 1);
    final probe = LongLineCooperativeProbe();
    final scheduler = LongLineCooperativeScheduler(
      maxWorkUnitsBeforeYield: 64,
      probe: probe,
      yieldCallback: () async {},
    );

    final actual = await LongLineVisualIndex.createCooperatively(
      text: text,
      bidiIndex: bidi,
      averageAdvance: 1,
      targetTileCodeUnits: 1,
      scheduler: scheduler,
    );
    scheduler.finish();

    _expectSameVisualIndex(actual, expected);
    expect(probe.uninterruptibleBytesByPhase['visual.allocate.paint-runs'], greaterThan(24));
    expect(probe.uninterruptibleBytesByPhase['visual.allocate.tile-result-list'], 24 + actual.tiles.length * 8);
    expect(probe.uninterruptibleBytesByPhase['visual.allocate.tile-core-starts'], actual.tiles.length * 4);
    expect(probe.maximumContinuousWorkUnits, lessThanOrEqualTo(64));
  });

  test('取消发生在定长 paint-run 分配后时，不再进入 tile core/result 分配', () async {
    final text = List<String>.filled(1000, 'a\u202e\u202cא').join();
    final bidi = LongLineBidiIndex.resolve(text, baseDirection: LongLineBidiBaseDirection.ltr);
    final probe = LongLineCooperativeProbe();
    var cancelled = false;
    final scheduler = LongLineCooperativeScheduler(
      maxWorkUnitsBeforeYield: 64,
      probe: probe,
      isCancelled: () => cancelled,
      yieldCallback: () async {
        if (probe.uninterruptibleBytesByPhase.containsKey('visual.allocate.paint-runs')) cancelled = true;
      },
    );

    await expectLater(
      LongLineVisualIndex.createCooperatively(
        text: text,
        bidiIndex: bidi,
        averageAdvance: 1,
        targetTileCodeUnits: 1,
        scheduler: scheduler,
      ),
      throwsA(isA<LongLineCooperativeCancelledException>()),
    );

    expect(probe.uninterruptibleBytesByPhase, contains('visual.allocate.paint-runs'));
    expect(probe.uninterruptibleBytesByPhase, isNot(contains('visual.allocate.tile-core-starts')));
    expect(probe.cancellationCount, greaterThan(0));
  });

  test('单一 ASCII run + targetTile=1 的首遍 tile 计数每 64 项强制让步', () async {
    final text = List<String>.filled(4096, 'a').join();
    final bidi = LongLineBidiIndex.resolve(text, baseDirection: LongLineBidiBaseDirection.ltr);
    final probe = LongLineCooperativeProbe();
    var callbacks = 0;
    final scheduler = LongLineCooperativeScheduler(
      maxWorkUnitsBeforeYield: 64,
      probe: probe,
      yieldCallback: () async => callbacks++,
    );

    final visual = await LongLineVisualIndex.createCooperatively(
      text: text,
      bidiIndex: bidi,
      averageAdvance: 1,
      targetTileCodeUnits: 1,
      scheduler: scheduler,
    );
    scheduler.finish();

    expect(visual.tiles, hasLength(text.length));
    expect(probe.workUnitsByPhase['visual.tiles.count'], text.length);
    expect(callbacks, greaterThan(text.length ~/ 64));
    expect(probe.maximumContinuousWorkUnits, lessThanOrEqualTo(64));
  });

  test('单一 ASCII run 可在首遍 tile 计数中途取消', () async {
    final text = List<String>.filled(4096, 'a').join();
    final bidi = LongLineBidiIndex.resolve(text, baseDirection: LongLineBidiBaseDirection.ltr);
    final probe = LongLineCooperativeProbe();
    var cancelled = false;
    final scheduler = LongLineCooperativeScheduler(
      maxWorkUnitsBeforeYield: 64,
      probe: probe,
      isCancelled: () => cancelled,
      yieldCallback: () async {
        if ((probe.workUnitsByPhase['visual.tiles.count'] ?? 0) >= 64) cancelled = true;
      },
    );

    await expectLater(
      LongLineVisualIndex.createCooperatively(
        text: text,
        bidiIndex: bidi,
        averageAdvance: 1,
        targetTileCodeUnits: 1,
        scheduler: scheduler,
      ),
      throwsA(isA<LongLineCooperativeCancelledException>()),
    );

    final counted = probe.workUnitsByPhase['visual.tiles.count'] ?? 0;
    expect(counted, inInclusiveRange(64, 192));
    expect(counted, lessThan(text.length));
    expect(probe.uninterruptibleBytesByPhase, isNot(contains('visual.allocate.tile-core-starts')));
    expect(probe.cancellationCount, greaterThan(0));
  });
}

void _expectSameVisualIndex(LongLineVisualIndex actual, LongLineVisualIndex expected) {
  expect(actual.text, expected.text);
  expect(actual.averageAdvance, expected.averageAdvance);
  expect(actual.targetTileCodeUnits, expected.targetTileCodeUnits);
  expect(actual.totalExtent, expected.totalExtent);
  expect(actual.tiles.length, expected.tiles.length);
  for (var index = 0; index < expected.tiles.length; index++) {
    final actualTile = actual.tiles[index];
    final expectedTile = expected.tiles[index];
    expect(
      (
        actualTile.visualIndex,
        actualTile.paintRunIndex,
        actualTile.start,
        actualTile.end,
        actualTile.level,
        actual.widthOf(index),
        actual.startXOf(index),
        actual.endXOf(index),
      ),
      (
        expectedTile.visualIndex,
        expectedTile.paintRunIndex,
        expectedTile.start,
        expectedTile.end,
        expectedTile.level,
        expected.widthOf(index),
        expected.startXOf(index),
        expected.endXOf(index),
      ),
      reason: 'visual tile $index',
    );
  }
  for (var offset = 0; offset <= expected.text.length; offset++) {
    for (final affinity in TextAffinity.values) {
      final actualCaret = actual.locateOffset(offset, affinity: affinity);
      final expectedCaret = expected.locateOffset(offset, affinity: affinity);
      expect(
        actualCaret == null
            ? null
            : (
                actualCaret.tileIndex,
                actualCaret.requestedOffset,
                actualCaret.offset,
                actualCaret.localX,
                actualCaret.visualX,
              ),
        expectedCaret == null
            ? null
            : (
                expectedCaret.tileIndex,
                expectedCaret.requestedOffset,
                expectedCaret.offset,
                expectedCaret.localX,
                expectedCaret.visualX,
              ),
        reason: 'offset=$offset affinity=$affinity',
      );
    }
    if (offset < expected.text.length) {
      expect(
        actual.hasPaintRetainedInRange(offset, offset + 1),
        expected.hasPaintRetainedInRange(offset, offset + 1),
        reason: 'paint-retained offset=$offset',
      );
    }
  }
}
