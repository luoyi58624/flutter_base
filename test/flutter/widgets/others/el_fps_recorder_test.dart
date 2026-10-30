import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// ElFpsRecorder / ElFpsReport 纯逻辑单测：录一段出报告的口径验证。
void main() {
  const us = 1000000;

  /// 生成从 [startUs] 开始、间隔 [intervalUs] 的 n 个时间戳。
  List<int> frames(int startUs, int intervalUs, int n) => [for (var i = 0; i < n; i++) startUs + i * intervalUs];

  group('ElFpsRecorder', () {
    test('稳定 120Hz 三秒：均值≈120、每秒序列贴满、零掉帧零卡顿', () {
      // 362 帧：末帧跨过第 3 个整秒边界，3 个桶全部结算（锚定帧不计数）。
      final recorder = ElFpsRecorder()..addFrames(frames(0, us ~/ 120, 362));
      final report = recorder.report();
      expect(report.frameCount, 362);
      expect(report.averageFps, closeTo(120, 1));
      expect(report.refreshRate, closeTo(120, 1));
      expect(report.secondRates.length, 3);
      expect(report.minSecondFps, closeTo(120, 1));
      expect(report.droppedFrames, 0);
      expect(report.jankFrames, 0);
    });

    test('间歇性掉帧：每 15 帧一次双倍间隔，掉帧数如实、每秒序列矮一截', () {
      const interval = us ~/ 120;
      // 900 帧节奏：每第 15 帧占 2 个 vsync 槽（模拟一次超预算 CPU 帧）。
      final ts = <int>[0];
      for (var i = 1; i < 900; i++) {
        ts.add(ts.last + (i % 15 == 0 ? interval * 2 : interval));
      }
      final recorder = ElFpsRecorder(expectedRefreshRate: 120)..addFrames(ts);
      final report = recorder.report();
      // 899 个间隔里每 15 个一个长间隔 → 59 次掉帧/卡顿。
      expect(report.droppedFrames, 59);
      expect(report.jankFrames, 59);
      expect(report.worstInterval.inMicroseconds, interval * 2);
      // 每一整秒都混入若干长间隔 → 每秒帧率低于 120 但不塌方。
      expect(report.secondRates, isNotEmpty);
      expect(report.maxSecondFps, lessThan(120));
      expect(report.minSecondFps, greaterThan(100));
      // 未指定刷新率时中位间隔也能推出 120Hz（多数帧正常）。
      final inferred = (ElFpsRecorder()..addFrames(ts)).report();
      expect(inferred.refreshRate, closeTo(120, 1));
      expect(inferred.droppedFrames, 59);
    });

    test('不足 1 秒：每秒序列为空但均值/掉帧照常结算', () {
      final recorder = ElFpsRecorder(expectedRefreshRate: 60)..addFrames(frames(0, us ~/ 60, 30));
      final report = recorder.report();
      expect(report.secondRates, isEmpty);
      expect(report.minSecondFps, 0);
      expect(report.averageFps, closeTo(60, 1));
      expect(report.droppedFrames, 0);
    });

    test('乱序/重复时间戳丢弃，续录后报告增量更新', () {
      final recorder = ElFpsRecorder(expectedRefreshRate: 60);
      // 62 帧跨过第 1 个整秒边界结算 1 桶；重复帧混在尾部应被丢弃。
      final first = frames(0, us ~/ 60, 62);
      recorder.addFrames([...first, first[10], first[30]]);
      expect(recorder.frameCount, 62);
      final r1 = recorder.report();
      expect(r1.secondRates.length, 1);
      recorder.addFrames(frames(62 * (us ~/ 60), us ~/ 60, 61));
      final r2 = recorder.report();
      expect(r2.frameCount, 123);
      expect(r2.secondRates.length, 2);
    });

    test('空/单帧不崩，reset 清空数据', () {
      final recorder = ElFpsRecorder();
      expect(recorder.report().averageFps, 0);
      recorder.addFrames(const [100]);
      expect(recorder.report().frameCount, 1);
      expect(recorder.report().elapsed, Duration.zero);
      recorder.reset();
      expect(recorder.frameCount, 0);
    });

    testWidgets('attach/detach 幂等，不向引擎重复挂回调', (tester) async {
      final recorder = ElFpsRecorder()
        ..attach()
        ..attach();
      recorder.detach();
      recorder.detach();
      // 测试绑定不产 FrameTiming，只验证订阅生命周期不崩、无数据即空报告。
      expect(recorder.report().frameCount, 0);
    });
  });
}
