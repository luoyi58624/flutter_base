import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../style/index.dart';
import 'shape.dart';

/// 按需缓存阴影局部几何，颜色与盒子位置变化只更新绘制参数。
class ShadowPainter {
  /// 与其他盒装饰共用规范圆角。
  ShadowPainter(this._shape);

  final ShapeGeometry Function() _shape;
  final List<_ShadowGeometry?> _items = [];

  /// 将可见外阴影及其模糊外溢合入盒子的绘制范围。
  static Rect bounds(Rect rect, List<ElBoxShadow> shadows) {
    var result = rect;
    for (final shadow in shadows) {
      if (shadow.inset || shadow.color.a <= 0) continue;
      final shape = rect.shift(shadow.offset).inflate(shadow.spreadRadius);
      if (shape.isEmpty) continue;
      result = result.expandToInclude(shape.inflate(shadow.blurSigma * 3));
    }
    return result;
  }

  /// 按声明顺序绘制外阴影，阴影不受盒子自身的内容裁剪影响。
  void paintOuter(
    Canvas canvas,
    Rect rect,
    List<ElBoxShadow> shadows, {
    BorderRadius? borderRadius,
  }) => _paint(canvas, rect, shadows, borderRadius, inner: false);

  /// 按声明顺序绘制内阴影，已由外层裁剪时避免重复圆角抗锯齿。
  void paintInner(
    Canvas canvas,
    Rect rect,
    List<ElBoxShadow> shadows, {
    BorderRadius? borderRadius,
    bool clipped = false,
  }) => _paint(
    canvas,
    rect,
    shadows,
    borderRadius,
    inner: true,
    clipped: clipped,
  );

  void _paint(
    Canvas canvas,
    Rect rect,
    List<ElBoxShadow> shadows,
    BorderRadius? radius, {
    required bool inner,
    bool clipped = false,
  }) {
    if (_items.length > shadows.length) _items.length = shadows.length;
    var started = false;
    final save = rect.topLeft != Offset.zero || (inner && !clipped);
    for (var i = 0; i < shadows.length; i++) {
      final shadow = shadows[i];
      if (shadow.inset != inner || shadow.color.a <= 0) continue;
      while (_items.length <= i) {
        _items.add(null);
      }
      final item = _items[i] ??= _ShadowGeometry();
      final key = (
        rect.size,
        radius,
        shadow.offset,
        shadow.spreadRadius,
        inner,
        inner ? shadow.blurRadius : 0.0,
      );
      if (item.key != key) {
        item.key = key;
        final base = radius == null
            ? RRect.fromRectAndRadius(Offset.zero & rect.size, Radius.zero)
            : _shape().resolve(rect.size, radius);
        item.geometry = _geometry(base, shadow, inner);
      }
      final geometry = item.geometry;
      if (geometry == null) continue;
      if (!started) {
        started = true;
        if (save) canvas.save();
        if (rect.topLeft != Offset.zero) canvas.translate(rect.left, rect.top);
        if (inner && !clipped) {
          if (radius == null) {
            canvas.clipRect(Offset.zero & rect.size);
          } else {
            canvas.clipRRect(_shape().resolve(rect.size, radius));
          }
        }
      }
      final paintKey = (
        shadow.blurRadius,
        shadow.blurStyle,
        debugDisableShadows,
      );
      if (item.paintKey != paintKey) {
        item.paintKey = paintKey;
        item.paint = shadow.toPaint();
      }
      final paint = item.paint!..color = shadow.color;
      if (geometry is Path) {
        canvas.drawPath(geometry, paint);
      } else {
        canvas.drawRRect(geometry as RRect, paint);
      }
    }
    if (started && save) canvas.restore();
  }

  Object? _geometry(RRect base, ElBoxShadow shadow, bool inner) {
    final spread = shadow.spreadRadius;
    final shifted = base.shift(shadow.offset);
    final x = inner ? math.min(spread, base.width / 2) : -spread;
    final y = inner ? math.min(spread, base.height / 2) : -spread;
    final rect = Rect.fromLTRB(
      shifted.left + x,
      shifted.top + y,
      shifted.right - x,
      shifted.bottom - y,
    );
    if (rect.isEmpty && !inner) return null;
    Radius corner(double rx, double ry) =>
        Radius.elliptical(math.max(0, rx - x), math.max(0, ry - y));
    final shape = rect.isEmpty
        ? null
        : RRect.fromRectAndCorners(
            rect,
            topLeft: corner(base.tlRadiusX, base.tlRadiusY),
            topRight: corner(base.trRadiusX, base.trRadiusY),
            bottomLeft: corner(base.blRadiusX, base.blRadiusY),
            bottomRight: corner(base.brRadiusX, base.brRadiusY),
          ).scaleRadii();
    if (!inner) return shape;
    // 有限补集覆盖三倍 sigma，避免大偏移、大负 spread 时漏掉模糊来源。
    final cover = base.outerRect
        .expandToInclude(rect)
        .inflate(shadow.blurSigma * 3 + 1);
    final path = Path()..fillType = PathFillType.evenOdd;
    path.addRect(cover);
    if (shape != null) path.addRRect(shape);
    return path;
  }
}

class _ShadowGeometry {
  Object? key, paintKey, geometry;
  Paint? paint;
}
