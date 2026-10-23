import 'package:flutter/rendering.dart';

/// 缓存绘制与命中共用的局部形状，位置与颜色不参与几何缓存。
class ShapeGeometry {
  /// 按需接收路径变化通知；未启用自定义裁剪时不监听或创建路径。
  // ignore: prefer_initializing_formals
  ShapeGeometry({VoidCallback? onClipChanged}) : _onClipChanged = onClipChanged;

  final VoidCallback? _onClipChanged;
  Size? _size;
  BorderRadius? _radius;
  RRect? _rrect;
  CustomClipper<Path>? _clipper;
  Size? _clipSize, _approximateSize;
  Path? _path;
  Rect? _approximate;
  bool _attached = false;

  /// 替换当前启用的委托，等价形状保留缓存并迁移通知监听。
  void updateClipper(CustomClipper<Path>? value) {
    final previous = _clipper;
    if (previous == value) return;
    final changed =
        previous == null ||
        value == null ||
        previous.runtimeType != value.runtimeType ||
        value.shouldReclip(previous);
    if (_attached) previous?.removeListener(_reclip);
    _clipper = value;
    if (_attached) value?.addListener(_reclip);
    if (changed) _reclip();
  }

  /// 返回当前视觉盒的局部路径，仅在启用自定义裁剪时调用。
  Path clip(Size size) {
    assert(_clipper != null);
    if (_clipSize != size) {
      _clipSize = size;
      _path = null;
    }
    return _path ??= _clipper!.getClip(size);
  }

  /// 返回当前视觉盒的近似语义裁剪，独立查询不改变实际路径缓存。
  Rect approximateClip(Size size) {
    assert(_clipper != null);
    if (_approximateSize != size) {
      _approximateSize = size;
      _approximate = null;
    }
    return _approximate ??= _clipper!.getApproximateClipRect(size);
  }

  void _reclip() {
    _clipSize = _approximateSize = null;
    _path = null;
    _approximate = null;
    _onClipChanged?.call();
  }

  /// 挂载后恢复监听并刷新形状，补偿脱离渲染树期间遗漏的通知。
  void attach() {
    if (_attached) return;
    _attached = true;
    final clipper = _clipper;
    if (clipper == null) return;
    clipper.addListener(_reclip);
    _reclip();
  }

  /// 脱离渲染树期间停止监听，缓存于重新挂载时统一失效。
  void detach() {
    if (!_attached) return;
    _clipper?.removeListener(_reclip);
    _attached = false;
  }

  /// 解除通知监听并释放委托和几何，不再通知已销毁的宿主。
  void dispose() {
    detach();
    _clipper = null;
    _clipSize = _approximateSize = null;
    _path = null;
    _approximate = null;
    _size = null;
    _radius = null;
    _rrect = null;
  }

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
