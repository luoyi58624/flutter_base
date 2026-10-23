import 'package:flutter/rendering.dart';

import 'shape.dart';

/// 按需执行盒裁剪和整组透明度，复用形状与图层，不参与样式解析。
class EffectController {
  /// 创建实际使用的效果执行器，形状由装饰与裁剪共享。
  EffectController(this._shape);

  final ShapeGeometry Function() _shape;
  LayerHandle<ContainerLayer>? _clip;
  LayerHandle<OpacityLayer>? _opacity;

  /// 对整个绘制组统一合成，不将透明度分别叠加到重叠的装饰与 child。
  void paintOpacity(
    PaintingContext context,
    Offset offset,
    int alpha,
    PaintingContextCallback painter,
  ) {
    final handle = _opacity ??= LayerHandle<OpacityLayer>();
    handle.layer = context.pushOpacity(
      offset,
      alpha,
      painter,
      oldLayer: handle.layer,
    );
  }

  /// 回到完全不透明或完全透明时释放透明度层。
  void clearOpacity() => _opacity?.layer = null;

  /// 停用裁剪时只释放裁剪层，保留独立的透明度层。
  void clearClip() => _clip?.layer = null;

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
    final handle = _clip ??= LayerHandle<ContainerLayer>();
    final old = handle.layer;
    if (radius == null) {
      handle.layer = context.pushClipRect(
        needsCompositing,
        offset,
        rect,
        painter,
        clipBehavior: clipBehavior,
        oldLayer: old is ClipRectLayer ? old : null,
      );
    } else {
      handle.layer = context.pushClipRRect(
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
  void dispose() {
    clearClip();
    clearOpacity();
  }
}
