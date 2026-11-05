import 'dart:ui' show FrameTiming;

import 'package:example/src/utils/frame_timing_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

FrameTiming _frame(int timestamp, {int ui = 1000, int raster = 2000, int overhead = 500}) => FrameTiming(
  vsyncStart: timestamp,
  buildStart: timestamp + overhead,
  buildFinish: timestamp + overhead + ui,
  rasterStart: timestamp + overhead + ui,
  rasterFinish: timestamp + overhead + ui + raster,
  rasterFinishWallTime: 0,
);

Map<String, Object?> _metric(Map<String, Object?> report, String name) => report[name]! as Map<String, Object?>;

Map<String, Object> _threshold(Map<String, Object?> metric, String name) => metric[name]! as Map<String, Object>;

void main() {
  test('统计采用最近秩分位数并分别保留管线阶段和超预算计数', () {
    final report = summarizeFrameTimings(
      timings: [
        for (final (index, ui) in [5000, 10000, 15000, 20000, 20001].indexed) _frame(index * 10000, ui: ui),
      ],
      startUs: 0,
      endUs: 50000,
      refreshRate: 100,
      metadata: {'page': 'test', 'window_kind': 'active'},
    );
    final ui = _metric(report, 'ui');
    expect(report['frame_count'], 5);
    expect(ui['p50_ms'], 15);
    expect(ui['p90_ms'], 20.001);
    expect(ui['p99_ms'], 20.001);
    expect(_threshold(ui, 'above_B'), {'count': 3, 'ratio': .6});
    expect(_threshold(ui, 'above_1_5B'), {'count': 2, 'ratio': .4});
    expect(_threshold(ui, 'above_2B'), {'count': 1, 'ratio': .2});
    expect(_metric(report, 'raster')['p50_ms'], 2);
    expect(_metric(report, 'vsync_overhead')['p50_ms'], .5);
    expect(_metric(report, 'total_span')['max_ms'], 22.501);
    expect(report['is_screen_presentation_timing'], isFalse);
  });

  test('显式窗口包含起点排除终点，乱序排序且重复帧只统计一次', () {
    final report = summarizeFrameTimings(
      timings: [_frame(30000), _frame(10000), _frame(9999), _frame(20000), _frame(10000), _frame(40000)],
      startUs: 10000,
      endUs: 40000,
      refreshRate: 100,
    );
    expect(report['frame_count'], 3);
    expect(_metric(report, 'vsync_interval')['sample_count'], 2);
    expect((report['raw_frames']! as List).map((v) => (v as Map)['vsync_start_us']), [10000, 20000, 30000]);
  });

  test('活动窗口中的超过100ms停顿完整进入分位数和超预算比例', () {
    final report = summarizeFrameTimings(
      timings: [_frame(0), _frame(10000), _frame(310000), _frame(320000)],
      startUs: 0,
      endUs: 400000,
      refreshRate: 100,
    );
    final intervals = _metric(report, 'vsync_interval');
    expect(intervals['sample_count'], 3);
    expect(intervals['max_ms'], 300);
    expect(intervals['p99_ms'], 300);
    expect(intervals['intervals_over_100ms'], 1);
    expect(_threshold(intervals, 'above_1_5B')['count'], 1);
  });

  test('静止窗口零帧和单帧没有伪造间隔，静止帧数独立输出', () {
    final empty = summarizeFrameTimings(
      timings: [],
      startUs: 0,
      endUs: 2000000,
      refreshRate: 120,
      metadata: {'window_kind': 'stationary'},
    );
    expect(empty['frame_count'], 0);
    expect(empty['stationary_frame_count'], 0);
    expect(_metric(empty, 'ui')['p99_ms'], 0);
    expect(_threshold(_metric(empty, 'ui'), 'above_B')['ratio'], 0);
    final single = summarizeFrameTimings(timings: [_frame(0)], startUs: 0, endUs: 1, refreshRate: 120);
    expect(_metric(single, 'vsync_interval')['sample_count'], 0);
    expect(single['stationary_frame_count'], isNull);
  });

  test('拒绝非法窗口和刷新率', () {
    expect(() => summarizeFrameTimings(timings: [], startUs: 2, endUs: 1, refreshRate: 60), throwsArgumentError);
    for (final rate in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => summarizeFrameTimings(timings: [], startUs: 0, endUs: 1, refreshRate: rate), throwsArgumentError);
    }
  });

  testWidgets('准备期不订阅，窗口开始不通知界面，尾批送达后才解除订阅', (tester) async {
    var now = 1000;
    final recorder = FrameTimingRecorder(
      binding: tester.binding,
      nowUs: () => now,
      drainDuration: Duration(milliseconds: 20),
    );
    addTearDown(recorder.dispose);
    var notifications = 0;
    recorder.addListener(() => notifications++);
    recorder.start(
      refreshRate: 100,
      metadata: {'stage': 'B'},
      delay: Duration(milliseconds: 10),
      duration: Duration(milliseconds: 40),
    );
    expect(recorder.phase, FrameRecordingPhase.waiting);
    expect(recorder.isSubscribed, isFalse);
    expect(notifications, 1);
    await tester.pump(Duration(milliseconds: 10));
    expect(recorder.phase, FrameRecordingPhase.recording);
    expect(recorder.isSubscribed, isTrue);
    expect(notifications, 1, reason: '采样开始不能额外刷新界面，干扰静止窗口');
    tester.binding.platformDispatcher.onReportTimings!([_frame(1000), _frame(11000)]);
    now = 41000;
    await tester.pump(Duration(milliseconds: 40));
    expect(recorder.phase, FrameRecordingPhase.draining);
    expect(recorder.isSubscribed, isTrue);
    // 窗口已经封口，晚送达的窗口内帧仍需保留，终点帧不能混入。
    tester.binding.platformDispatcher.onReportTimings!([_frame(31000), _frame(41000), _frame(500)]);
    await tester.pump(Duration(milliseconds: 20));
    expect(recorder.phase, FrameRecordingPhase.complete);
    expect(recorder.isSubscribed, isFalse);
    expect(recorder.report!['frame_count'], 3);
    expect(_metric(recorder.report!, 'vsync_interval')['max_ms'], 20);
  });

  testWidgets('提前结束按实际终点筛选且不会重复订阅，完成后可开始新任务', (tester) async {
    var now = 1000;
    final recorder = FrameTimingRecorder(binding: tester.binding, nowUs: () => now, drainDuration: Duration.zero);
    addTearDown(recorder.dispose);
    recorder.start(refreshRate: 60, metadata: {}, delay: Duration.zero);
    expect(() => recorder.start(refreshRate: 60, metadata: {}), throwsStateError);
    now = 11000;
    recorder.stop();
    recorder.stop();
    tester.binding.platformDispatcher.onReportTimings!([_frame(1000), _frame(10999), _frame(11000)]);
    // 显式推进零时长假时钟，执行 Timer(Duration.zero) 的排空回调。
    await tester.pump(Duration.zero);
    expect(recorder.report!['frame_count'], 2);
    expect((recorder.report!['window']! as Map)['end_us_exclusive'], 11000);
    recorder.start(refreshRate: 120, metadata: {}, delay: Duration(seconds: 1));
    expect(recorder.report, isNull);
    recorder.stop();
    await tester.pump(Duration(seconds: 1));
    expect(recorder.phase, FrameRecordingPhase.idle);
    expect(recorder.isSubscribed, isFalse);
  });

  testWidgets('释放时取消准备任务与在途订阅，不留下计时器', (tester) async {
    final waiting = FrameTimingRecorder(binding: tester.binding);
    waiting.start(refreshRate: 60, metadata: {});
    waiting.dispose();
    await tester.pump(Duration(seconds: 3));
    expect(waiting.isSubscribed, isFalse);
    final recording = FrameTimingRecorder(binding: tester.binding);
    recording.start(refreshRate: 60, metadata: {}, delay: Duration.zero);
    expect(recording.isSubscribed, isTrue);
    recording.dispose();
    expect(recording.isSubscribed, isFalse);
    await tester.pump(Duration(seconds: 11));
    expect(() => recording.start(refreshRate: 60, metadata: {}), throwsStateError);
  });
}
