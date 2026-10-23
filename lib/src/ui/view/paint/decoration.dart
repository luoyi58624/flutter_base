import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'shape.dart';

/// 按需持有盒装饰资源，简单背景不构造路径或合成图层。
class DecorationPainter {
  /// 创建装饰执行器，可与裁剪执行器按需共用同一局部形状。
  DecorationPainter({ShapeGeometry Function()? shape}) : _createShape = shape;

  final ShapeGeometry Function()? _createShape;
  Paint? _background;
  ShapeGeometry? _shape;

  ShapeGeometry get _geometry =>
      _shape ??= _createShape?.call() ?? ShapeGeometry();

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
      context.canvas.drawRRect(_rrect(rect, borderRadius), paint);
    }
  }

  RRect _rrect(Rect rect, BorderRadius radius) =>
      _geometry.resolve(rect.size, radius).shift(rect.topLeft);

  /// 使用绘制时同一规范形状判断背景命中，外边距与全局位置不影响缓存。
  bool contains(Rect rect, Offset position, {BorderRadius? borderRadius}) {
    if (!rect.contains(position)) return false;
    return borderRadius == null ||
        _geometry
            .resolve(rect.size, borderRadius)
            .contains(position - rect.topLeft);
  }

  /// 测试观察是否因实际消费圆角创建形状。
  @visibleForTesting
  bool get debugShapeCreated => _shape != null;

  /// 测试观察形状缓存的实际重建次数。
  @visibleForTesting
  int get debugShapeBuildCount => _shape?.debugBuildCount ?? 0;
}
