import 'package:flutter/rendering.dart';

import 'shape.dart';

/// 按需持有盒装饰资源，简单背景不构造路径或合成图层。
class DecorationPainter {
  /// 创建装饰执行器，可与裁剪执行器按需共用同一局部形状。
  DecorationPainter(this._shape);

  final ShapeGeometry Function() _shape;
  Paint? _background;

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
