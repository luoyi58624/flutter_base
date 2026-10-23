import 'package:flutter/rendering.dart';

import '../layout/box_layout.dart';
import '../paint/decoration.dart';
import '../paint/effects.dart';
import '../paint/shape.dart';
import '../paint/transform.dart';
import '../style/index.dart';

/// 单子视图的框架宿主，样式、盒模型和绘制分别委托给独立协作者。
class ElRenderView extends RenderShiftedBox implements BoxLayoutOwner {
  /// 创建宿主时立即创建唯一引擎，动画与绘制资源仍按需创建。
  ElRenderView(ElStyle style, TextDirection direction) : super(null) {
    _engine = StyleEngine(style, direction, invalidate: _invalidate);
    boxLayout = BoxLayout(this, mutateLayout: _mutateLayout);
    if (alwaysNeedsCompositing) markNeedsCompositingBitsUpdate();
  }

  StyleEngine? _engine;
  StyleEngine get _styleEngine => _engine!;
  DecorationPainter? _decoration;
  EffectController? _effects;
  ShapeGeometry? _shape;

  ShapeGeometry _ensureShape() {
    if (_shape == null) {
      final shape = _shape = ShapeGeometry(onClipChanged: _onReclip);
      shape.updateClipper(_styleEngine.clipper);
      if (attached) shape.attach();
    }
    return _shape!;
  }

  void _syncClipper() {
    final clipper = _styleEngine.clipper;
    if (clipper != null) {
      _ensureShape().updateClipper(clipper);
    } else {
      _shape?.updateClipper(null);
      _effects?.clearPathClip();
    }
  }

  void _onReclip() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  DecorationPainter get _painter =>
      _decoration ??= DecorationPainter(_ensureShape);

  EffectController get _effect => _effects ??= EffectController(_ensureShape);

  TransformGeometry? _readTransform([Rect? paintBounds]) {
    final value = _styleEngine.transform;
    return value == null
        ? null
        : _effect.resolveTransform(
            value,
            boxLayout.boxRect,
            paintBounds ?? _untransformedPaintBounds,
          );
  }

  @override
  bool get alwaysNeedsCompositing {
    // RenderObject 父构造期间会读取此属性，此时样式引擎尚未创建。
    return _engine?.needsCompositing ?? false;
  }

  /// 本节点唯一的盒模型执行器，也是祖先几何查询的入口。
  @override
  late final BoxLayout boxLayout;

  /// 转交目标声明，字段解析和动画策略由样式引擎处理。
  void applyStyle(ElStyle style, {required TextDirection textDirection}) =>
      _styleEngine.update(style, textDirection);

  void _invalidate(int damage) {
    if (damage & StyleEngine.layout != 0) super.markNeedsLayout();
    if (damage & StyleEngine.paint != 0) markNeedsPaint();
    if (damage & StyleEngine.compositing != 0) markNeedsCompositingBitsUpdate();
    if (damage & StyleEngine.semantics != 0) {
      _syncClipper();
      if (_styleEngine.clipBehavior == Clip.none) {
        _effects?.clearClip();
      }
      markNeedsSemanticsUpdate();
    }
  }

  void _mutateLayout(VoidCallback callback) =>
      invokeLayoutCallback<BoxConstraints>((_) => callback());

  @override
  void markNeedsLayout() {
    _styleEngine.invalidateLayout();
    super.markNeedsLayout();
  }

  @override
  void performLayout() {
    boxLayout.beginLayout();
    final values = _styleEngine.prepareLayout(constraints, boxLayout);
    size = boxLayout.perform(constraints, values);
    _styleEngine.didLayout(boxLayout.boxSize, values);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => boxLayout.dryLayout(
    constraints,
    _styleEngine.readLayout(constraints, boxLayout),
  );

  double _intrinsic(bool horizontal, double extent, bool minimum) {
    final constraints = horizontal
        ? BoxConstraints(maxHeight: extent)
        : BoxConstraints(maxWidth: extent);
    return boxLayout.intrinsic(
      horizontal,
      extent,
      minimum,
      _styleEngine.readLayout(constraints, boxLayout),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _intrinsic(true, height, true);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _intrinsic(true, height, false);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsic(false, width, true);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsic(false, width, false);

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => boxLayout.dryBaseline(
    constraints,
    baseline,
    _styleEngine.readLayout(constraints, boxLayout),
  );

  @override
  void paint(PaintingContext context, Offset offset) {
    final alpha = _styleEngine.opacityAlpha;
    if (alpha == 0) {
      _effects?.clearOpacity();
      _effects?.clearTransform();
      _effects?.clearFilter();
      _effects?.clearBackdrop();
      _effects?.clearPathClip();
      // 隐藏期间移除装饰也应解除资源持有，无需等待下一次可见帧。
      final decoration = _decoration;
      if (decoration != null) {
        if (_styleEngine.gradient == null) decoration.clearGradient();
        if (_styleEngine.boxShadow == null) decoration.clearShadows();
        if (_styleEngine.outline == null) decoration.clearOutline();
      }
      return;
    }
    final transform = _readTransform();
    if (transform == null) {
      _effects?.clearTransform();
      _paintPathClip(context, offset);
    } else {
      _effect.paintTransform(
        context,
        offset,
        transform,
        needsCompositing: needsCompositing,
        painter: _paintPathClip,
      );
    }
  }

  void _paintPathClip(PaintingContext context, Offset offset) {
    if (_styleEngine.clipper == null) {
      _effects?.clearPathClip();
      _paintOpacity(context, offset);
      return;
    }
    final rect = boxLayout.boxRect;
    _effect.paintPathClip(
      context,
      offset,
      rect: rect,
      path: _ensureShape().clip(rect.size),
      // 背景合成层本身已隔离整组，额外保存透明层会截断背景输入。
      clipBehavior:
          _styleEngine.backdropFilter != null &&
              _styleEngine.pathClipBehavior == Clip.antiAliasWithSaveLayer
          ? Clip.antiAlias
          : _styleEngine.pathClipBehavior,
      needsCompositing: needsCompositing,
      painter: _paintOpacity,
    );
  }

  void _paintOpacity(PaintingContext context, Offset offset) {
    final alpha = _styleEngine.opacityAlpha;
    if (alpha < 255) {
      _effect.paintOpacity(context, offset, alpha, _paintEffects);
    } else {
      _effects?.clearOpacity();
      _paintEffects(context, offset);
    }
  }

  void _paintEffects(PaintingContext context, Offset offset) {
    final backdrop = _styleEngine.backdropFilter;
    final filter = _styleEngine.filter;
    if (backdrop != null) {
      final rect = boxLayout.boxRect;
      _effect.paintBackdrop(
        context,
        offset,
        backdrop,
        rect: rect,
        radius: _styleEngine.borderRadius,
        path: _styleEngine.clipper == null
            ? null
            : _ensureShape().clip(rect.size),
        foregroundFilter: filter,
        painter: _paintBox,
      );
      return;
    }
    _effects?.clearBackdrop();
    if (filter != null) {
      _effect.paintFilter(context, offset, filter, painter: _paintBox);
    } else {
      _effects?.clearFilter();
      _paintBox(context, offset);
    }
  }

  void _paintBox(PaintingContext context, Offset offset) {
    final shadows = _styleEngine.boxShadow;
    if (shadows != null) {
      _painter.paintShadows(
        context,
        boxLayout.boxRect.shift(offset),
        shadows,
        inset: false,
        borderRadius: _styleEngine.borderRadius,
      );
    } else {
      _decoration?.clearShadows();
    }
    if (_styleEngine.clipper == null &&
        _styleEngine.clipBehavior != Clip.none &&
        (child != null ||
            _styleEngine.backgroundColor != null ||
            _styleEngine.gradient != null ||
            _styleEngine.hasInnerShadow)) {
      _effect.paint(
        context,
        offset,
        rect: boxLayout.boxRect,
        radius: _styleEngine.borderRadius,
        clipBehavior: _styleEngine.clipBehavior,
        needsCompositing: needsCompositing,
        painter: _paintContents,
      );
    } else {
      _effects?.clearClip();
      _paintContents(context, offset);
    }
    final border = _styleEngine.border;
    if (border != null) {
      _painter.paintBorder(
        context,
        boxLayout.boxRect.shift(offset),
        border,
        borderRadius: _styleEngine.borderRadius,
      );
    }
    final outline = _styleEngine.outline;
    if (outline != null) {
      _painter.paintOutline(
        context,
        boxLayout.boxRect.shift(offset),
        outline,
        borderRadius: _styleEngine.borderRadius,
      );
    } else {
      _decoration?.clearOutline();
    }
  }

  @override
  Rect get paintBounds {
    final bounds = _untransformedPaintBounds;
    return _readTransform(bounds)?.mapBounds(bounds) ?? bounds;
  }

  Rect get _untransformedPaintBounds {
    final border = _styleEngine.border;
    var bounds = super.paintBounds;
    final shadows = _styleEngine.boxShadow;
    if (shadows != null) {
      bounds = bounds.expandToInclude(
        _painter.shadowBounds(boxLayout.boxRect, shadows),
      );
    }
    if (border != null) {
      bounds = bounds.expandToInclude(
        _painter.borderBounds(
          boxLayout.boxRect,
          border,
          borderRadius: _styleEngine.borderRadius,
        ),
      );
    }
    final outline = _styleEngine.outline;
    if (outline != null) {
      bounds = bounds.expandToInclude(
        _painter.outlineBounds(boxLayout.boxRect, outline),
      );
    }
    bounds = EffectController.filterBounds(bounds, _styleEngine.filter);
    if (_styleEngine.clipper != null) {
      final rect = boxLayout.boxRect;
      bounds = bounds.intersect(
        _ensureShape().clip(rect.size).getBounds().shift(rect.topLeft),
      );
    }
    return bounds;
  }

  void _paintContents(PaintingContext context, Offset offset) {
    final color = _styleEngine.backgroundColor;
    if (color != null) {
      _painter.paintBackground(
        context,
        boxLayout.boxRect.shift(offset),
        color,
        // 已有外层裁剪时画矩形，避免圆角边缘重复抗锯齿。
        borderRadius: _styleEngine.clipBehavior == Clip.none
            ? _styleEngine.borderRadius
            : null,
      );
    }
    final gradient = _styleEngine.gradient;
    if (gradient != null) {
      _painter.paintGradient(
        context,
        boxLayout.boxRect.shift(offset),
        gradient,
        _styleEngine.direction,
        borderRadius: _styleEngine.clipBehavior == Clip.none
            ? _styleEngine.borderRadius
            : null,
      );
    } else {
      _decoration?.clearGradient();
    }
    final shadows = _styleEngine.boxShadow;
    if (shadows != null) {
      _painter.paintShadows(
        context,
        boxLayout.boxRect.shift(offset),
        shadows,
        inset: true,
        borderRadius: _styleEngine.borderRadius,
        clipped:
            _styleEngine.clipper == null &&
            _styleEngine.clipBehavior != Clip.none,
      );
    }
    super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_styleEngine.opacityAlpha == 0) return false;
    final transform = _readTransform();
    if (transform == null) return _hitTestClipped(result, position);
    if (!transform.valid) return false;
    return result.addWithPaintTransform(
      transform: transform.matrix,
      position: position,
      hitTest: _hitTestClipped,
    );
  }

  bool _hitTestClipped(BoxHitTestResult result, Offset position) {
    if (_styleEngine.clipper != null) {
      final rect = boxLayout.boxRect;
      if (!_ensureShape().clip(rect.size).contains(position - rect.topLeft)) {
        return false;
      }
    }
    return super.hitTest(result, position: position);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final geometry = _readTransform();
    if (geometry != null) transform.multiply(geometry.matrix);
    super.applyPaintTransform(child, transform);
  }

  @override
  Rect get semanticBounds =>
      _readTransform()?.mapBounds(super.semanticBounds) ?? super.semanticBounds;

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_readTransform()?.valid ?? true) {
      super.visitChildrenForSemantics(visitor);
    }
  }

  @override
  bool hitTestSelf(Offset position) =>
      (_styleEngine.backgroundColor != null ||
          _styleEngine.border != null ||
          _styleEngine.gradient != null) &&
      _painter.contains(
        boxLayout.boxRect,
        position,
        borderRadius: _styleEngine.borderRadius,
      );

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      child != null &&
      (_styleEngine.clipper != null ||
          _styleEngine.clipBehavior == Clip.none ||
          _effect.contains(
            boxLayout.boxRect,
            position,
            _styleEngine.borderRadius,
          )) &&
      super.hitTestChildren(result, position: position);

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    final rect = boxLayout.boxRect;
    final Rect clip;
    if (_styleEngine.clipper != null) {
      clip = _ensureShape().approximateClip(rect.size).shift(rect.topLeft);
    } else {
      if (_styleEngine.clipBehavior == Clip.none) return null;
      clip = rect;
    }
    return _readTransform()?.mapBounds(clip) ?? clip;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _syncClipper();
    _shape?.attach();
    markNeedsLayout();
  }

  @override
  void detach() {
    boxLayout.detach();
    _shape?.detach();
    super.detach();
  }

  @override
  void dispose() {
    boxLayout.dispose();
    _decoration?.clearOutline();
    _decoration?.clearGradient();
    _decoration?.clearShadows();
    _effects?.dispose();
    _shape?.dispose();
    _styleEngine.dispose();
    super.dispose();
  }
}
