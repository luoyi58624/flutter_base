import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// CSS 语义的线性渐变：固定 [angle] 角度，渲染方向与盒子宽高比无关，
/// 对齐 `linear-gradient(<angle>, ...)`。
class ElLinearGradient extends Gradient {
  /// 创建 CSS 语义线性渐变。[colors] 至少两色；[stops] 非 null 时长度须与
  /// [colors] 一致（0..1，对应 CSS 的百分比 stop）。
  const ElLinearGradient({
    required this.angle,
    required super.colors,
    super.stops,
    this.tileMode = TileMode.clamp,
    super.transform,
  });

  /// CSS 现代语法角度（度）：0 指上、顺时针增长。
  final double angle;

  /// 渐变线两端之外的平铺方式（对齐 [LinearGradient.tileMode]）。
  final TileMode tileMode;

  /// 按 CSS 规则解析渐变线两端点（拆出来供几何单测，不必采样像素）。
  ({Offset begin, Offset end}) resolvePoints(Rect rect) {
    final rad = angle * math.pi / 180;
    // 屏幕坐标 y 向下：0deg 指上 = (0, -1)，顺时针增长
    final dir = Offset(math.sin(rad), -math.cos(rad));
    final length = rect.width * dir.dx.abs() + rect.height * dir.dy.abs();
    final half = dir * (length / 2);
    return (begin: rect.center - half, end: rect.center + half);
  }

  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) {
    assert(colors.length >= 2, 'colors 至少两色');
    assert(stops == null || stops!.length == colors.length, 'stops 长度须与 colors 一致');
    final (:begin, :end) = resolvePoints(rect);
    // 空矩形端点重合，引擎拒绝零长渐变线；退化为任意 1px 线（反正不可见）
    final safeEnd = begin == end ? begin + const Offset(1, 0) : end;
    return ui.Gradient.linear(
      begin,
      safeEnd,
      colors,
      _resolvedStops,
      tileMode,
      transform?.transform(rect, textDirection: textDirection)?.storage,
    );
  }

  /// stops 缺省时按 CSS 规则均匀铺满 0..1。
  List<double> get _resolvedStops => stops ?? [for (var i = 0; i < colors.length; i++) i / (colors.length - 1)];

  @override
  ElLinearGradient scale(double factor) => ElLinearGradient(
    angle: angle,
    colors: [for (final c in colors) Color.lerp(null, c, factor)!],
    stops: stops,
    tileMode: tileMode,
    transform: transform,
  );

  @override
  ElLinearGradient withOpacity(double opacity) => ElLinearGradient(
    angle: angle,
    colors: [for (final c in colors) c.withValues(alpha: opacity)],
    stops: stops,
    tileMode: tileMode,
    transform: transform,
  );

  @override
  Gradient? lerpFrom(Gradient? a, double t) => (a == null || a is ElLinearGradient)
      ? ElLinearGradient.lerp(a as ElLinearGradient?, this, t)
      : super.lerpFrom(a, t);

  @override
  Gradient? lerpTo(Gradient? b, double t) => (b == null || b is ElLinearGradient)
      ? ElLinearGradient.lerp(this, b as ElLinearGradient?, t)
      : super.lerpTo(b, t);

  /// 两个 [ElLinearGradient] 间插值；null 端按 CSS 口径向透明版渐隐
  /// （[scale] 折算 alpha），色数不等时不逐段插值、中点切换。
  static ElLinearGradient? lerp(ElLinearGradient? a, ElLinearGradient? b, double t) {
    if (a == null && b == null) return null;
    if (a == null) return b!.scale(t);
    if (b == null) return a.scale(1 - t);
    if (a.colors.length != b.colors.length) return t < 0.5 ? a : b;
    return ElLinearGradient(
      angle: ui.lerpDouble(a.angle, b.angle, t)!,
      colors: [for (var i = 0; i < a.colors.length; i++) Color.lerp(a.colors[i], b.colors[i], t)!],
      stops: [for (var i = 0; i < a.colors.length; i++) ui.lerpDouble(a._resolvedStops[i], b._resolvedStops[i], t)!],
      tileMode: t < 0.5 ? a.tileMode : b.tileMode,
      transform: t < 0.5 ? a.transform : b.transform,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ElLinearGradient &&
        other.angle == angle &&
        other.tileMode == tileMode &&
        other.transform == transform &&
        listEquals(other.colors, colors) &&
        listEquals(other.stops, stops);
  }

  @override
  int get hashCode =>
      Object.hash(angle, tileMode, transform, Object.hashAll(colors), stops == null ? null : Object.hashAll(stops!));

  @override
  String toString() => 'ElLinearGradient(angle: $angle, colors: $colors, stops: $stops, tileMode: $tileMode)';
}
