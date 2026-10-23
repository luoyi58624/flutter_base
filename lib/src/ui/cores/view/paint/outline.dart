import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../style/resolved/outline.dart';
import 'shape.dart';

/// 复用旧版轮廓外推规则，按需缓存中心线与渐变资源。
class OutlinePainter {
  /// 与背景、边框共享当前盒的规范圆角。
  OutlinePainter(this._shape);

  final ShapeGeometry Function() _shape;
  Object? _geometryKey, _shaderKey;
  Object? _geometry;
  Rect _strokeRect = Rect.zero;
  Paint? _paint, _layerPaint;
  Shader? _shader;

  /// 返回轮廓实际外缘；中心线塌缩时保留原盒范围。
  static Rect bounds(Rect rect, OutlineStyle outline) {
    final center = rect.inflate(outline.offset + outline.width / 2);
    return center.isEmpty
        ? rect
        : rect.expandToInclude(center.inflate(outline.width / 2));
  }

  /// 在内容和边框之后描边，位置变化只平移，不重建几何或 shader。
  void paint(
    Canvas canvas,
    Rect rect,
    OutlineStyle outline, {
    BorderRadius? borderRadius,
  }) {
    final key = (rect.size, borderRadius, outline.width, outline.offset);
    if (_geometryKey != key) {
      _geometryKey = key;
      final distance = outline.offset + outline.width / 2;
      _strokeRect = (Offset.zero & rect.size).inflate(distance);
      _geometry = _strokeRect.isEmpty
          ? null
          : borderRadius == null
          ? _strokeRect
          : _extrude(
              _shape().resolve(rect.size, borderRadius),
              _strokeRect,
              distance,
            );
    }
    final geometry = _geometry;
    if (geometry == null) {
      _paint?.shader = null;
      _shader = null;
      _shaderKey = null;
      return;
    }
    final paint = (_paint ??= Paint()..style = PaintingStyle.stroke)
      ..strokeWidth = outline.width;
    final gradient = outline.gradient;
    final hasGradient =
        gradient != null &&
        outline.gradientOpacity > 0 &&
        gradient.colors.any((color) => color.a > 0);
    final hasColor = outline.color.a > 0;
    if (!hasGradient) {
      _shaderKey = null;
      _shader = null;
    } else {
      final shaderKey = (gradient, _strokeRect, outline.direction);
      if (_shaderKey != shaderKey) {
        _shaderKey = shaderKey;
        _shader = gradient.createShader(
          _strokeRect,
          textDirection: outline.direction,
        );
      }
    }
    final shifted = rect.topLeft != Offset.zero;
    if (shifted) {
      canvas.save();
      canvas.translate(rect.left, rect.top);
    }
    final blend = hasGradient && hasColor;
    if (blend) {
      // 渐变覆盖外仍需保留纯色贡献；预乘相加避免普通 source-over 叠深。
      canvas.saveLayer(
        bounds(Offset.zero & rect.size, outline).inflate(1),
        _layerPaint ??= Paint(),
      );
      paint.blendMode = BlendMode.plus;
    }
    if (hasGradient) {
      paint
        ..shader = _shader
        ..color = const Color(0xFF000000)
            .withValues(alpha: outline.gradientOpacity);
      _draw(canvas, geometry, paint);
    }
    if (hasColor) {
      paint
        ..shader = null
        ..color = outline.color;
      _draw(canvas, geometry, paint);
    }
    if (blend) {
      canvas.restore();
      paint.blendMode = BlendMode.srcOver;
    }
    if (shifted) canvas.restore();
  }

  static void _draw(Canvas canvas, Object geometry, Paint paint) {
    if (geometry is RRect) {
      canvas.drawRRect(geometry, paint);
    } else {
      canvas.drawRect(geometry as Rect, paint);
    }
  }

  // 旧版自适应外推抑制小圆角膨胀，内收过大时按轴归零，方角始终保持方角。
  static RRect _extrude(RRect base, Rect center, double distance) {
    double shift(double radius) => radius <= 0
        ? 0
        : math.max(
            0,
            radius + distance * radius / (radius + distance.abs() / 2),
          );
    Radius corner(Radius value) =>
        Radius.elliptical(shift(value.x), shift(value.y));
    return RRect.fromRectAndCorners(
      center,
      topLeft: corner(base.tlRadius),
      topRight: corner(base.trRadius),
      bottomLeft: corner(base.blRadius),
      bottomRight: corner(base.brRadius),
    ).scaleRadii();
  }
}
