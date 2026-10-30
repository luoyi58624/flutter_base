import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('帧率统计按窗口结算并忽略重复时间戳', () {
    final counter = ElFpsCounter();
    expect(counter.addBatch([0, 500000, 1000000]), isNull);
    expect(counter.addBatch([1000000, 1000001]), 2);
    counter.reset();
    expect(counter.addBatch([0, 1000000, 1000001]), 1);
  });

  test('帧率报告按给定刷新率计算掉帧和卡顿', () {
    final recorder = ElFpsRecorder(expectedRefreshRate: 100);
    recorder.addFrames([0, 10000, 30000, 30000]);
    final report = recorder.report();
    expect(report.frameCount, 3);
    expect(report.averageFps, closeTo(66.6667, 0.001));
    expect(report.droppedFrames, 1);
    expect(report.jankFrames, 1);
    expect(report.worstInterval, Duration(milliseconds: 20));
    recorder.reset();
    expect(recorder.frameCount, 0);
  });
}
