import 'package:flutter/rendering.dart';

/// 缓存绘制与命中共用的局部形状，位置与颜色不参与几何缓存。
class ShapeGeometry {
  Size? _size;
  BorderRadius? _radius;
  RRect? _rrect;

  /// 按实际尺寸统一缩放过大的圆角，返回以原点为起点的圆角矩形。
  RRect resolve(Size size, BorderRadius radius) {
    if (_size != size || _radius != radius) {
      _size = size;
      _radius = radius;
      _rrect = radius.toRRect(Offset.zero & size).scaleRadii();
    }
    return _rrect!;
  }

  /// 将局部形状放到视觉盒的位置，供绘制与裁剪共用。
  RRect positioned(Rect rect, BorderRadius radius) {
    final shape = resolve(rect.size, radius);
    return rect.left == 0 && rect.top == 0 ? shape : shape.shift(rect.topLeft);
  }
}
