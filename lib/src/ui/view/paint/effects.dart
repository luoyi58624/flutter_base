import 'package:flutter/rendering.dart';

import 'shape.dart';

/// 按需执行盒裁剪，复用形状和合成图层，不参与样式解析。
class EffectController {
  /// 创建实际使用的裁剪执行器，形状由装饰与裁剪共享。
  EffectController(this._shape);

  final ShapeGeometry Function() _shape;
  final _layer = LayerHandle<ContainerLayer>();

  /// 按本地盒几何裁剪，框架决定使用画布还是合成图层。
  void paint(
    PaintingContext context,
    Offset offset, {
    required Rect rect,
    required BorderRadius? radius,
    required Clip clipBehavior,
    required bool needsCompositing,
    required PaintingContextCallback painter,
  }) {
    final old = _layer.layer;
    if (radius == null) {
      _layer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        rect,
        painter,
        clipBehavior: clipBehavior,
        oldLayer: old is ClipRectLayer ? old : null,
      );
    } else {
      _layer.layer = context.pushClipRRect(
        needsCompositing,
        offset,
        rect,
        _shape().positioned(rect, radius),
        painter,
        clipBehavior: clipBehavior,
        oldLayer: old is ClipRRectLayer ? old : null,
      );
    }
  }

  /// 让裁剪后的子内容仅在同一有效形状内命中。
  bool contains(Rect rect, Offset position, BorderRadius? radius) =>
      rect.contains(position) &&
      (radius == null ||
          _shape()
              .resolve(rect.size, radius)
              .contains(position - rect.topLeft));

  /// 停用或销毁裁剪时释放合成图层的持有权。
  void dispose() => _layer.layer = null;
}
