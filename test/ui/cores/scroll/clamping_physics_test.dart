import 'dart:math' as math;

import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

FixedScrollMetrics _metrics(double devicePixelRatio) => FixedScrollMetrics(
  minScrollExtent: 0,
  maxScrollExtent: 10000,
  pixels: 5000,
  viewportDimension: 600,
  axisDirection: AxisDirection.down,
  devicePixelRatio: devicePixelRatio,
);

void main() {
  test('默认低于 10 停止，等于 10 仍可进入惯性，且不随像素比变化', () {
    final physics = ElClampingScrollPhysics();
    for (final ratio in [1.0, 3.0]) {
      final metrics = _metrics(ratio);
      for (final velocity in [-9.9, 0.0, 9.9]) {
        expect(physics.createBallisticSimulation(metrics, velocity), isNull);
      }
      for (final velocity in [-10.0, 10.0]) {
        final simulation = physics.createBallisticSimulation(metrics, velocity);
        expect(simulation, isNotNull);
        expect(simulation!.isDone(0), isFalse);
      }
    }
  });

  test('已启动的正反向惯性在速度降至配置阈值以下时结束', () {
    for (final threshold in [5.0, 10.0]) {
      final physics = ElClampingScrollPhysics(stopVelocity: threshold);
      final metrics = _metrics(3);
      final crossingTime = math.log(threshold / 100) / math.log(0.135);
      for (final velocity in [-100.0, 100.0]) {
        final simulation = physics.createBallisticSimulation(metrics, velocity)!;
        expect(simulation.dx(crossingTime - 0.001).abs(), greaterThan(threshold));
        expect(simulation.isDone(crossingTime - 0.001), isFalse);
        expect(simulation.dx(crossingTime + 0.001).abs(), lessThan(threshold));
        expect(simulation.isDone(crossingTime + 0.001), isTrue);
      }
    }
  });

  test('合成物理链保留停止速度，低速续接沿用同一阈值', () {
    final physics = ElClampingScrollPhysics(stopVelocity: 5).applyTo(AlwaysScrollableScrollPhysics());
    final metrics = _metrics(1);
    expect(physics.createBallisticSimulation(metrics, 4.9), isNull);
    expect(physics.createBallisticSimulation(metrics, 5), isNotNull);
    expect(physics.createBallisticSimulation(metrics, 7), isNotNull);
  });
}
