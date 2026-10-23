import 'package:flutter/rendering.dart';

import '../style/resolved/transform.dart';
import 'shape.dart';
import 'transform.dart';

/// 按需执行变换、盒裁剪和整组透明度，复用几何与图层。
class EffectController {
  /// 创建实际使用的效果执行器，形状由装饰与裁剪共享。
  EffectController(this._shape);

  final ShapeGeometry Function() _shape;
  LayerHandle<ContainerLayer>? _clip;
  LayerHandle<OpacityLayer>? _opacity;
  LayerHandle<TransformLayer>? _transformLayer;
  TransformGeometry? _transform;

  /// 在真实使用变换时解析盒原点和投影边界，供各消费入口共享。
  TransformGeometry resolveTransform(
    TransformStyle style,
    Rect box,
    Rect paintBounds,
  ) => (_transform ??= TransformGeometry())..resolve(style, box, paintBounds);

  /// 停用变换时释放其几何与图层，不影响裁剪和透明度。
  void clearTransform() {
    _transform = null;
    _transformLayer?.layer = null;
  }

  /// 包裹完整绘制组，纯平移直接调整偏移，其余交由框架选择画布或图层。
  void paintTransform(
    PaintingContext context,
    Offset offset,
    TransformGeometry geometry, {
    required bool needsCompositing,
    required PaintingContextCallback painter,
  }) {
    if (!geometry.valid) {
      _transformLayer?.layer = null;
      return;
    }
    final translation = geometry.translation;
    if (translation != null) {
      _transformLayer?.layer = null;
      painter(context, offset + translation);
      return;
    }
    final handle = needsCompositing
        ? (_transformLayer ??= LayerHandle<TransformLayer>())
        : _transformLayer;
    final layer = context.pushTransform(
      needsCompositing,
      offset,
      geometry.matrix,
      painter,
      oldLayer: handle?.layer,
    );
    if (handle != null) handle.layer = layer;
  }

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

  /// 销毁效果时释放变换几何与各合成图层的持有权。
  void dispose() {
    clearTransform();
    clearClip();
    clearOpacity();
  }
}
