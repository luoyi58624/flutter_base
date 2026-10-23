import 'package:flutter_base/src/ui/event/dispatcher.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default drag resampling policy is enabled only for Android', () {
    expect(ElEventDispatcher.enableDragResampling, isTrue);
    expect(const ElEventConfig().dragResampling, <TargetPlatform>{
      TargetPlatform.android,
    });
  });

  test('default drag sampling builder aligns to AOSP RESAMPLE_LATENCY for all refresh rates', () {
    // 恒定 -5ms：右端点缺失由有界外推补齐，不再按刷新率放大偏移括区间。
    for (final fps in const <double>[60, 90, 94, 95, 120, 124, 125, 144, 240]) {
      expect(
        ElEventDispatcher.dragSamplingBuilder(fps),
        const Duration(milliseconds: -5),
      );
    }
  });

  test('default drag sampling builder rejects invalid refresh rates', () {
    expect(ElEventDispatcher.dragSamplingBuilder(0), isNull);
    expect(ElEventDispatcher.dragSamplingBuilder(-1), isNull);
    expect(ElEventDispatcher.dragSamplingBuilder(double.nan), isNull);
    expect(ElEventDispatcher.dragSamplingBuilder(double.infinity), isNull);
  });
}
