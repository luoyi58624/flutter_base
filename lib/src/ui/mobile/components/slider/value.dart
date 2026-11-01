import 'dart:math' as math;

import 'package:flutter_base/ui.dart';

/// 沿用 Web sliderScale：刻度只负责展示，取整从 min 起算，中点选择后一档。
class SliderScale {
  /// 清洗区间、步长与刻度，抽稀绘制点不改变合法值集合。
  SliderScale(double lower, double upper, double? increment, Object marks) {
    min = lower.isFinite ? lower : 0;
    max = upper.isFinite ? math.max(min, upper) : math.max(min, 100);
    step = increment == null
        ? null
        : increment.isFinite && increment > 0
        ? increment
        : 1;
    if (marks is List<ElSliderMark>) {
      final unique = <double, ElSliderMark>{};
      for (final mark in marks) {
        if (mark.value.isFinite && mark.value >= min && mark.value <= max) unique[mark.value] = mark;
      }
      points = unique.values.toList()..sort((a, b) => a.value.compareTo(b.value));
    } else if (marks == true && step != null && max > min && ((max - min) / step!).isFinite) {
      final count = ((max - min) / step! + 1e-9).floorToDouble();
      final stride = math.max(1.0, (count / 1000).ceilToDouble());
      for (var i = 0.0; i <= count; i += stride) {
        points.add(ElSliderMark(value: _clean(min + i * step!)));
      }
      final end = _clean(min + count * step!);
      if (points.isEmpty || points.last.value != end) points.add(ElSliderMark(value: end));
    }
  }

  /// 有效下界。
  late final double min;

  /// 有效上界。
  late final double max;

  /// null 表示仅从显式刻度选择。
  late final double? step;

  /// 有序、去重且数量受控的展示刻度。
  List<ElSliderMark> points = [];

  /// 区间退化或显式选择集合为空时不可交互。
  bool get disabled => max <= min || !(max - min).isFinite || step == null && points.isEmpty;

  /// 将输入限制到有效区间，非有限值回退至下界。
  double clamp(double value) => (value.isFinite ? value : min).clamp(min, max);

  /// 连续位置映射，不经过步长取整。
  double ratio(double value) => disabled ? 0 : (clamp(value) - min) / (max - min);

  /// 将业务值按相邻合法值的中点吸附。
  double normalize(double raw) {
    if (!(max - min).isFinite) return min;
    final value = clamp(raw);
    if (step == null) {
      var nearest = points.isEmpty ? min : points.first.value;
      for (final point in points) {
        if ((point.value - value).abs() <= (nearest - value).abs()) nearest = point.value;
      }
      return nearest;
    }
    if (!((value - min) / step!).isFinite) return value;
    final last = ((max - min) / step! + 1e-9).floorToDouble();
    return clamp(_clean(min + math.min(last, ((value - min) / step!).roundToDouble()) * step!));
  }

  /// 键盘与无障碍共用的相邻合法值。
  double adjacent(double value, bool increase) {
    if (step != null) return normalize(value + (increase ? step! : -step!));
    final ordered = increase ? points : points.reversed;
    for (final point in ordered) {
      if (increase ? point.value > value : point.value < value) return point.value;
    }
    return value;
  }
}

double _clean(double value) => value.isFinite ? double.parse(value.toStringAsPrecision(15)) : value;
