import 'package:flutter/rendering.dart';

import '../layout/box_layout.dart';
import '../paint/decoration.dart';
import '../paint/effects.dart';
import '../paint/shape.dart';
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

  ShapeGeometry _ensureShape() => _shape ??= ShapeGeometry();

  DecorationPainter get _painter =>
      _decoration ??= DecorationPainter(_ensureShape);

  EffectController get _effect => _effects ??= EffectController(_ensureShape);

  @override
  bool get alwaysNeedsCompositing {
    // RenderObject 父构造期间会读取此属性，此时样式引擎尚未创建。
    final alpha = _engine?.opacityAlpha ?? 255;
    return alpha > 0 && alpha < 255;
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
      // 隐藏期间移除装饰也应解除资源持有，无需等待下一次可见帧。
      final decoration = _decoration;
      if (decoration != null) {
        if (_styleEngine.gradient == null) decoration.clearGradient();
        if (_styleEngine.boxShadow == null) decoration.clearShadows();
        if (_styleEngine.outline == null) decoration.clearOutline();
      }
      return;
    }
    if (alpha < 255) {
      _effect.paintOpacity(context, offset, alpha, _paintBox);
    } else {
      _effects?.clearOpacity();
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
    if (_styleEngine.clipBehavior != Clip.none &&
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
    return outline == null
        ? bounds
        : bounds.expandToInclude(
            _painter.outlineBounds(boxLayout.boxRect, outline),
          );
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
        clipped: _styleEngine.clipBehavior != Clip.none,
      );
    }
    super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      _styleEngine.opacityAlpha != 0 &&
      super.hitTest(result, position: position);

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
      (_styleEngine.clipBehavior == Clip.none ||
          _effect.contains(
            boxLayout.boxRect,
            position,
            _styleEngine.borderRadius,
          )) &&
      super.hitTestChildren(result, position: position);

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _styleEngine.clipBehavior == Clip.none ? null : boxLayout.boxRect;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    markNeedsLayout();
  }

  @override
  void detach() {
    boxLayout.detach();
    super.detach();
  }

  @override
  void dispose() {
    boxLayout.dispose();
    _decoration?.clearOutline();
    _decoration?.clearGradient();
    _decoration?.clearShadows();
    _effects?.dispose();
    _styleEngine.dispose();
    super.dispose();
  }
}
