import 'package:flutter/rendering.dart';

import 'border.dart';
import 'outline.dart';
import 'shape.dart';
import 'shadow.dart';
import '../style/index.dart';
import '../style/resolved/outline.dart';

/// 按需持有盒装饰资源，简单背景不构造路径或合成图层。
class DecorationPainter {
  /// 创建装饰执行器，可与裁剪执行器按需共用同一局部形状。
  DecorationPainter(this._shape);

  final ShapeGeometry Function() _shape;
  Paint? _background;
  BorderPainter? _border;
  OutlinePainter? _outline;
  ShadowPainter? _shadow;
  Paint? _gradient;
  Object? _gradientKey;

  /// 在背景之前绘制外阴影，在背景与 child 之间绘制内阴影。
  void paintShadows(
    PaintingContext context,
    Rect rect,
    List<ElBoxShadow> shadows, {
    required bool inset,
    BorderRadius? borderRadius,
    bool clipped = false,
  }) {
    if (!shadows.any((shadow) => shadow.inset == inset && shadow.color.a > 0)) {
      return;
    }
    final painter = _shadow ??= ShadowPainter(_shape);
    if (inset) {
      painter.paintInner(
        context.canvas,
        rect,
        shadows,
        borderRadius: borderRadius,
        clipped: clipped,
      );
    } else {
      painter.paintOuter(
        context.canvas,
        rect,
        shadows,
        borderRadius: borderRadius,
      );
    }
  }

  /// 外阴影只扩大绘制范围，不改变布局或命中范围。
  Rect shadowBounds(Rect rect, List<ElBoxShadow> shadows) =>
      ShadowPainter.bounds(rect, shadows);

  /// 阴影退出后释放其画笔与局部几何持有。
  void clearShadows() => _shadow = null;

  /// 渐变覆盖背景色；shader 仅在渐变、尺寸或方向变化时重新创建。
  void paintGradient(
    PaintingContext context,
    Rect rect,
    Gradient gradient,
    TextDirection direction, {
    BorderRadius? borderRadius,
  }) {
    if (rect.isEmpty) return;
    final local = Offset.zero & rect.size;
    final key = (gradient, rect.size, direction);
    final paint = _gradient ??= Paint();
    if (_gradientKey != key) {
      _gradientKey = key;
      paint.shader = gradient.createShader(local, textDirection: direction);
    }
    final canvas = context.canvas;
    final shifted = rect.topLeft != Offset.zero;
    if (shifted) {
      canvas.save();
      canvas.translate(rect.left, rect.top);
    }
    if (borderRadius == null) {
      canvas.drawRect(local, paint);
    } else {
      canvas.drawRRect(_shape().resolve(rect.size, borderRadius), paint);
    }
    if (shifted) canvas.restore();
  }

  /// 渐变退出后解除 shader 的持有。
  void clearGradient() {
    _gradient = null;
    _gradientKey = null;
  }

  /// 按需绘制位于边框之上的轮廓。
  void paintOutline(
    PaintingContext context,
    Rect rect,
    OutlineStyle outline, {
    BorderRadius? borderRadius,
  }) => (_outline ??= OutlinePainter(
    _shape,
  )).paint(context.canvas, rect, outline, borderRadius: borderRadius);

  /// 不创建绘制资源，计算轮廓可能扩大的可见范围。
  Rect outlineBounds(Rect rect, OutlineStyle outline) =>
      OutlinePainter.bounds(rect, outline);

  /// 轮廓退出后解除对旧画笔、几何和 shader 的持有。
  void clearOutline() => _outline = null;

  /// 按需绘制覆盖在盒与内容之上的边框。
  void paintBorder(
    PaintingContext context,
    Rect rect,
    Border border, {
    BorderRadius? borderRadius,
  }) {
    (_border ??= BorderPainter(
      _shape,
    )).paint(context.canvas, rect, border, borderRadius: borderRadius);
  }

  /// 不依赖绘制资源，计算边框可能伸出盒外的范围。
  Rect borderBounds(Rect rect, Border border, {BorderRadius? borderRadius}) =>
      BorderPainter.bounds(rect, border, borderRadius: borderRadius);

  /// 绘制已解析的背景；无圆角直接画矩形，有圆角才创建局部形状。
  void paintBackground(
    PaintingContext context,
    Rect rect,
    Color color, {
    BorderRadius? borderRadius,
  }) {
    final paint = (_background ??= Paint())..color = color;
    if (borderRadius == null || rect.isEmpty) {
      context.canvas.drawRect(rect, paint);
    } else {
      context.canvas.drawRRect(_shape().positioned(rect, borderRadius), paint);
    }
  }

  /// 使用绘制时同一规范形状判断背景命中，外边距与全局位置不影响缓存。
  bool contains(Rect rect, Offset position, {BorderRadius? borderRadius}) {
    if (!rect.contains(position)) return false;
    return borderRadius == null ||
        _shape()
            .resolve(rect.size, borderRadius)
            .contains(position - rect.topLeft);
  }
}
