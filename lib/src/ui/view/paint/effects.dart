import 'package:flutter/rendering.dart';

import '../style/resolved/filter.dart';
import '../style/resolved/transform.dart';
import 'filter.dart';
import 'shape.dart';
import 'transform.dart';

/// 按需执行变换、滤镜、裁剪和透明度，各效果独立复用资源。
class EffectController {
  /// 创建实际使用的效果执行器，形状由装饰与裁剪共享。
  EffectController(this._shape);

  final ShapeGeometry Function() _shape;
  LayerHandle<ContainerLayer>? _clip;
  LayerHandle<OpacityLayer>? _opacity;
  LayerHandle<TransformLayer>? _transformLayer;
  LayerHandle<ImageFilterLayer>? _filterLayer;
  LayerHandle<BackdropFilterLayer>? _backdropLayer;
  LayerHandle<BackdropFilterLayer>? _backdropFinalLayer;
  LayerHandle<ClipPathLayer>? _pathClip;
  FilterResource? _filter, _backdrop, _backdropForeground;
  Paint? _backdropMask, _backdropWhite;
  TransformGeometry? _transform;

  /// 模糊向盒外扩张三倍 sigma 并向外取整，颜色滤镜不改变绘制范围。
  static Rect filterBounds(Rect rect, FilterStyle? style) {
    if (style == null || rect.isEmpty) return rect;
    final x = (style.blurX * 3).ceilToDouble();
    final y = (style.blurY * 3).ceilToDouble();
    return x == 0 && y == 0
        ? rect
        : Rect.fromLTRB(
            rect.left - x,
            rect.top - y,
            rect.right + x,
            rect.bottom + y,
          );
  }

  /// 对完整前景应用一次自身滤镜，不重复叠加位置偏移。
  void paintFilter(
    PaintingContext context,
    Offset offset,
    FilterStyle style, {
    required PaintingContextCallback painter,
  }) {
    final filter = (_filter ??= FilterResource()).resolve(style);
    if (filter == null) {
      clearFilter();
      painter(context, offset);
      return;
    }
    final handle = _filterLayer ??= LayerHandle<ImageFilterLayer>();
    final layer = handle.layer ??= ImageFilterLayer();
    layer.imageFilter = filter;
    context.pushLayer(layer, painter, offset);
  }

  /// 停用自身滤镜时释放其原生滤镜与图层。
  void clearFilter() {
    _filter = null;
    _filterLayer?.layer = null;
  }

  /// 将过滤背景限制在视觉形状内，再绘制完整前景，由同一组承接透明度。
  void paintBackdrop(
    PaintingContext context,
    Offset offset,
    FilterStyle style, {
    required Rect rect,
    required PaintingContextCallback painter,
    BorderRadius? radius,
    Path? path,
    FilterStyle? foregroundFilter,
  }) {
    if (rect.isEmpty) {
      clearBackdrop();
      if (foregroundFilter == null) {
        painter(context, offset);
      } else {
        paintFilter(context, offset, foregroundFilter, painter: painter);
      }
      return;
    }
    final filter = (_backdrop ??= FilterResource()).resolve(style);
    if (filter == null) {
      clearBackdrop();
      if (foregroundFilter == null) {
        painter(context, offset);
      } else {
        paintFilter(context, offset, foregroundFilter, painter: painter);
      }
      return;
    }
    clearFilter();
    final handle = _backdropLayer ??= LayerHandle<BackdropFilterLayer>();
    final layer = handle.layer ??= BackdropFilterLayer();
    layer.filter = filter;
    final selfFilter = foregroundFilter == null
        ? null
        : (_backdropForeground ??= FilterResource()).resolve(foregroundFilter);
    if (selfFilter == null) _clearBackdropForeground();
    context.pushLayer(layer, (inner, innerOffset) {
      _maskBackdrop(inner, rect.shift(innerOffset), radius, path);
      painter(inner, innerOffset);
      if (selfFilter != null) {
        // 在已经含玻璃和前景的组内完成滤镜，避免外层 filter 隔离背景来源。
        final finalHandle = _backdropFinalLayer ??=
            LayerHandle<BackdropFilterLayer>();
        final finalLayer = finalHandle.layer ??= BackdropFilterLayer(
          blendMode: BlendMode.src,
        );
        finalLayer.filter = selfFilter;
        inner.addLayer(finalLayer);
      }
    }, offset);
  }

  void _maskBackdrop(
    PaintingContext context,
    Rect rect,
    BorderRadius? radius,
    Path? path,
  ) {
    final canvas = context.canvas;
    // null 边界保留实际设备裁剪，不能用自身 size 清除祖先视口中的背景副本。
    canvas.saveLayer(
      null,
      _backdropMask ??= Paint()..blendMode = BlendMode.dstIn,
    );
    final white = _backdropWhite ??= Paint()..color = const Color(0xffffffff);
    if (path != null) {
      canvas.save();
      // 自定义路径可以放行前景溢出，背景采样输出仍只保留视觉盒内部分。
      canvas.clipRect(rect);
      canvas.translate(rect.left, rect.top);
      canvas.drawPath(path, white);
      canvas.restore();
    } else if (radius != null) {
      canvas.drawRRect(_shape().positioned(rect, radius), white);
    } else {
      canvas.drawRect(rect, white);
    }
    canvas.restore();
  }

  void _clearBackdropForeground() {
    _backdropForeground = null;
    _backdropFinalLayer?.layer = null;
  }

  /// 停用背景采样时释放滤镜、组图层与背景遮罩。
  void clearBackdrop() {
    _backdrop = null;
    _backdropLayer?.layer = null;
    _backdropMask = null;
    _backdropWhite = null;
    _clearBackdropForeground();
  }

  /// 按视觉盒局部路径裁剪整个绘制组，与普通内容圆角裁剪独立复用图层。
  void paintPathClip(
    PaintingContext context,
    Offset offset, {
    required Rect rect,
    required Path path,
    required Clip clipBehavior,
    required bool needsCompositing,
    required PaintingContextCallback painter,
  }) {
    if (clipBehavior == Clip.none) {
      clearPathClip();
      painter(context, offset);
      return;
    }
    final handle = needsCompositing
        ? (_pathClip ??= LayerHandle<ClipPathLayer>())
        : _pathClip;
    final layer = context.pushClipPath(
      needsCompositing,
      offset,
      rect,
      _positionPath(path, rect),
      painter,
      clipBehavior: clipBehavior,
      oldLayer: handle?.layer,
    );
    if (handle != null) handle.layer = layer;
  }

  Path _positionPath(Path path, Rect rect) =>
      rect.topLeft == Offset.zero ? path : path.shift(rect.topLeft);

  /// 停用自定义路径裁剪时释放其图层，不改变其他效果。
  void clearPathClip() => _pathClip?.layer = null;

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
    clearFilter();
    clearBackdrop();
    clearPathClip();
    clearClip();
    clearOpacity();
  }
}
