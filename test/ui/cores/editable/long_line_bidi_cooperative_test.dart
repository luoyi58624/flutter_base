import 'package:flutter_base/src/flutter/views/editable/render/bidi/long_line_bidi_index.dart';
import 'package:flutter_base/src/flutter/views/editable/render/bidi/long_line_cooperative_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cooperative UAX #9 与同步解析逐字段一致', () async {
    final samples = <String>[
      '',
      'abc אבג 123 العربية',
      'a\u202e(אב 12)\u202cb',
      'a\u2067RTL \u2066left\u2069 ١٢\u2069z',
      'A👩‍👩‍👧‍👦\u200cالعربية\u200dB',
      String.fromCharCodes(<int>[0x41, 0xd83d, 0x42, 0xdc00, 0x5d0, 0x43]),
      '${'abc אבג (١٢) '.padRight(257, 'x')}\u2029${'العربية 123 [xyz] '.padRight(513, 'א')}',
    ];

    for (final direction in LongLineBidiBaseDirection.values) {
      for (final text in samples) {
        final expected = LongLineBidiIndex.resolve(text, baseDirection: direction);
        final actual = await LongLineBidiIndex.resolveCooperatively(text, baseDirection: direction);
        _expectSameIndex(actual, expected);
      }
    }
  });

  test('所有长循环都受 64 work-unit 连续预算约束并真实让步', () async {
    final probe = LongLineCooperativeProbe();
    var callbackCount = 0;
    final scheduler = LongLineCooperativeScheduler(
      maxWorkUnitsBeforeYield: 64,
      probe: probe,
      yieldCallback: () async {
        callbackCount++;
        await Future<void>.delayed(Duration.zero);
      },
    );
    final unit = 'abc אבג \u202e(١٢)\u202c \u2067RTL\u2069 👩‍👩‍👧‍👦 العربية\u200c';
    final text = List<String>.filled(kIsWeb ? 20 : 200, unit).join();
    final expected = LongLineBidiIndex.resolve(text, baseDirection: LongLineBidiBaseDirection.ltr);

    final actual = await LongLineBidiIndex.resolveCooperatively(
      text,
      baseDirection: LongLineBidiBaseDirection.ltr,
      scheduler: scheduler,
    );
    scheduler.finish();

    _expectSameIndex(actual, expected);
    expect(callbackCount, greaterThan(10));
    expect(probe.yieldCount, callbackCount);
    expect(probe.maximumContinuousWorkUnits, lessThanOrEqualTo(64));
    expect(probe.staleReservationDiscardedWorkUnits, greaterThan(0));
    expect(probe.uninterruptibleBytesByPhase['bidi.allocate.decoded-code-points'], actual.atomCount * 4);
    expect(probe.uninterruptibleBytesByPhase['bidi.allocate.decoded-starts'], actual.atomCount * 4);
    expect(probe.uninterruptibleBytesByPhase['bidi.allocate.core-types'], actual.atomCount);
    expect(probe.uninterruptibleBytesByPhase['bidi.allocate.core-match-pdi'], actual.atomCount * 4);
    expect(probe.uninterruptibleBytesByPhase['bidi.allocate.result-visual-to-logical'], text.length * 4);
    expect(probe.uninterruptibleBytesByPhase, isNot(contains('bidi.allocate.core-arrays')));
    expect(
      probe.workUnitsByPhase.keys,
      containsAll(<String>{
        'bidi.decode.count',
        'bidi.decode.write',
        'bidi.explicit',
        'bidi.w1',
        'bidi.w7',
        'bidi.brackets.scan',
        'bidi.implicit',
        'bidi.l2.collect',
        'bidi.result.offset-maps',
      }),
    );
  });

  test('非法 cooperative 预算在任何解析前拒绝', () {
    expect(
      () => LongLineCooperativeScheduler(
        maxWorkUnitsBeforeYield: LongLineCooperativeScheduler.minimumMaxWorkUnitsBeforeYield - 1,
      ),
      throwsRangeError,
    );
  });

  test('取消在下一次让步边界立即停止，后续 work 与 yield 不再增长', () async {
    final probe = LongLineCooperativeProbe();
    var cancelled = false;
    var callbacks = 0;
    final scheduler = LongLineCooperativeScheduler(
      maxWorkUnitsBeforeYield: 64,
      probe: probe,
      isCancelled: () => cancelled,
      yieldCallback: () async {
        callbacks++;
        if (callbacks == 4) cancelled = true;
        await Future<void>.delayed(Duration.zero);
      },
    );
    final text = List<String>.filled(500, 'abc אבג العربية ١٢ ').join();

    await expectLater(
      LongLineBidiIndex.resolveCooperatively(text, baseDirection: LongLineBidiBaseDirection.ltr, scheduler: scheduler),
      throwsA(isA<LongLineCooperativeCancelledException>()),
    );
    final workAtCancellation = probe.totalWorkUnits;
    final yieldsAtCancellation = probe.yieldCount;
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(probe.cancellationCount, greaterThan(0));
    expect(probe.totalWorkUnits, workAtCancellation);
    expect(probe.yieldCount, yieldsAtCancellation);
  });

  test('不可中断分配与 String 物化不伪装成受预算 work，并前后让步', () async {
    final probe = LongLineCooperativeProbe();
    var callbacks = 0;
    final scheduler = LongLineCooperativeScheduler(probe: probe, yieldCallback: () async => callbacks++);
    final chunk = List<String>.filled(1000, 'x').join();

    final value = await scheduler.runUninterruptible<String>(
      codeUnits: 120000,
      phase: 'test.materialize',
      materialization: true,
      operation: () => List<String>.filled(120, chunk).join(),
    );

    expect(value, hasLength(120000));
    expect(callbacks, 2);
    expect(probe.totalWorkUnits, 0);
    expect(probe.maximumContinuousWorkUnits, 0);
    expect(probe.largestUninterruptibleMaterializationCodeUnits, 120000);
    expect(probe.largestUninterruptibleMaterializationBytes, 240000);
    expect(probe.uninterruptibleCodeUnitsByPhase['test.materialize'], 120000);
    expect(probe.uninterruptibleBytesByPhase['test.materialize'], 240000);
  });

  test('嵌套 reserve 一旦让步就使外层旧额度失效并显式计入 probe', () async {
    final probe = LongLineCooperativeProbe();
    final scheduler = LongLineCooperativeScheduler(
      maxWorkUnitsBeforeYield: 64,
      probe: probe,
      yieldCallback: () async {},
    );
    expect(scheduler.reserve(48, phase: 'outer'), isNull);
    final outerEpoch = scheduler.reservationEpoch;
    final innerYield = scheduler.reserve(32, phase: 'inner');
    expect(innerYield, isNotNull);
    await innerYield!;

    expect(scheduler.discardReservationIfStale(outerEpoch, 24), isTrue);
    expect(probe.staleReservationDiscardedWorkUnits, 24);
    expect(probe.maximumContinuousWorkUnits, lessThanOrEqualTo(64));
  });

  test('取消发生在单个 core typed-array 后时，后续数组不会成组分配', () async {
    final probe = LongLineCooperativeProbe();
    var cancelled = false;
    final scheduler = LongLineCooperativeScheduler(
      maxWorkUnitsBeforeYield: 64,
      probe: probe,
      isCancelled: () => cancelled,
      yieldCallback: () async {
        if (probe.uninterruptibleBytesByPhase.containsKey('bidi.allocate.core-match-pdi')) cancelled = true;
      },
    );
    final text = List<String>.filled(1000, 'abc אבג العربية').join();

    await expectLater(
      LongLineBidiIndex.resolveCooperatively(text, baseDirection: LongLineBidiBaseDirection.ltr, scheduler: scheduler),
      throwsA(isA<LongLineCooperativeCancelledException>()),
    );

    expect(probe.uninterruptibleBytesByPhase, contains('bidi.allocate.core-match-pdi'));
    expect(probe.uninterruptibleBytesByPhase, isNot(contains('bidi.allocate.core-match-initiator')));
    expect(probe.cancellationCount, greaterThan(0));
  });
}

void _expectSameIndex(LongLineBidiIndex actual, LongLineBidiIndex expected) {
  expect(actual.paragraphLevel, expected.paragraphLevel);
  expect(actual.atomCount, expected.atomCount);
  expect(actual.visualCodeUnitLength, expected.visualCodeUnitLength);
  _expectTypedData(actual.levels, expected.levels);
  _expectTypedData(actual.x9Removed, expected.x9Removed);
  _expectTypedData(actual.visualRunOrder, expected.visualRunOrder);
  _expectTypedData(actual.visualToLogical, expected.visualToLogical);
  _expectTypedData(actual.logicalToVisual, expected.logicalToVisual);
  expect(actual.logicalRuns.length, expected.logicalRuns.length);
  for (var index = 0; index < expected.logicalRuns.length; index++) {
    final actualRun = actual.logicalRuns[index];
    final expectedRun = expected.logicalRuns[index];
    expect(
      (actualRun.start, actualRun.end, actualRun.level, actualRun.removed),
      (expectedRun.start, expectedRun.end, expectedRun.level, expectedRun.removed),
      reason: 'logical run $index',
    );
  }
}

void _expectTypedData(List<int> actual, List<int> expected) {
  expect(actual, orderedEquals(expected));
}
