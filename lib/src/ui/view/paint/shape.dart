import 'package:flutter/rendering.dart';

/// 缓存绘制与命中共用的局部形状，位置与颜色不参与几何缓存。
class ShapeGeometry {
  Size? _size;
  BorderRadius? _radius;
  RRect? _rrect;
  int _buildCount = 0;

  /// 按实际尺寸统一缩放过大的圆角，返回以原点为起点的圆角矩形。
  RRect resolve(Size size, BorderRadius radius) {
    if (_size != size || _radius != radius) {
      _size = size;
      _radius = radius;
      _rrect = radius.toRRect(Offset.zero & size).scaleRadii();
      assert(() {
        _buildCount++;
        return true;
      }());
    }
    return _rrect!;
  }

  /// 测试观察实际几何生成次数，仅在 assert 启用时计数。
  int get debugBuildCount => _buildCount;
}
