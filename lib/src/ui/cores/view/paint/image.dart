import 'package:flutter/rendering.dart';

import 'shape.dart';

/// 持有官方背景图片绘制器，图片解析、逐帧订阅和错误处理均交给 Flutter。
class BackgroundImagePainter {
  /// 共用盒圆角，并在异步图片或动画帧到达时通知宿主重绘。
  BackgroundImagePainter(this._shape, this._onChanged);

  final ShapeGeometry Function() _shape;
  final VoidCallback _onChanged;
  DecorationImage? _image;
  DecorationImagePainter? _painter;
  ImageConfiguration? _source, _configuration;

  /// 声明变化时立即解除旧订阅，新的绘制器延迟到实际绘制时创建。
  void update(DecorationImage value) {
    // 混合对象只交由官方 painter 消费，额外回调比较仅适用于直接图片声明。
    if (_image == value &&
        (value.runtimeType != DecorationImage ||
            _image?.onError == value.onError)) {
      return;
    }
    _painter?.dispose();
    _painter = null;
    _image = value;
  }

  /// 按完整图片环境与当前视觉盒绘制，空盒不创建绘制器或订阅图片流。
  void paint(
    PaintingContext context,
    Rect rect,
    DecorationImage image,
    ImageConfiguration configuration, {
    required TextDirection textDirection,
    BorderRadius? borderRadius,
  }) {
    update(image);
    if (rect.isEmpty) {
      _painter?.dispose();
      _painter = null;
      return;
    }
    if (_source != configuration ||
        _configuration?.size != rect.size ||
        _configuration?.textDirection != textDirection) {
      _source = configuration;
      _configuration = configuration.copyWith(
        size: rect.size,
        textDirection: textDirection,
      );
    }
    final painter = _painter ??= image.createPainter(_onChanged);
    final canvas = context.canvas;
    if (borderRadius == null) {
      painter.paint(canvas, rect, null, _configuration!);
      return;
    }
    // 圆角使用共享的局部形状，不为图片另建 Path 或重复解析全局位置。
    canvas.save();
    final local = rect.topLeft == Offset.zero ? rect : Offset.zero & rect.size;
    if (rect.topLeft != Offset.zero) canvas.translate(rect.left, rect.top);
    canvas.clipRRect(_shape().resolve(rect.size, borderRadius));
    painter.paint(canvas, local, null, _configuration!);
    canvas.restore();
  }

  /// 清理图片帧订阅和缓存，脱离渲染树后可由下一次绘制重新建立。
  void dispose() {
    _painter?.dispose();
    _painter = null;
    _image = null;
    _source = _configuration = null;
  }
}
