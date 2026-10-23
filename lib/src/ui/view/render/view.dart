import 'package:flutter/rendering.dart';

import '../layout/box_layout.dart';
import '../paint/decoration.dart';
import '../style/index.dart';

/// 单子视图的框架宿主，样式、盒模型和绘制分别委托给独立协作者。
class ElRenderView extends RenderShiftedBox implements BoxLayoutOwner {
  /// 创建宿主时立即创建唯一引擎，动画与绘制资源仍按需创建。
  ElRenderView(ElStyle style, TextDirection direction) : super(null) {
    _styleEngine = StyleEngine(style, direction, invalidate: _invalidate);
    boxLayout = BoxLayout(this, mutateLayout: _mutateLayout);
  }

  late final StyleEngine _styleEngine;
  DecorationPainter? _decoration;

  /// 本节点唯一的盒模型执行器，也是祖先几何查询的入口。
  @override
  late final BoxLayout boxLayout;

  /// 本节点从构造到销毁保持不变的样式引擎。
  StyleEngine get styleEngine => _styleEngine;

  /// 转交目标声明，字段解析和动画策略由样式引擎处理。
  void applyStyle(ElStyle style, {required TextDirection textDirection}) =>
      _styleEngine.update(style, textDirection);

  void _invalidate(int damage) {
    if (damage & StyleEngine.layout != 0) super.markNeedsLayout();
    if (damage & StyleEngine.paint != 0) markNeedsPaint();
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
    _styleEngine.didLayout(boxLayout.boxSize);
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
    final color = _styleEngine.backgroundColor;
    if (color != null) {
      (_decoration ??= DecorationPainter()).paintBackground(
        context,
        boxLayout.boxRect.shift(offset),
        color,
      );
    }
    super.paint(context, offset);
  }

  @override
  bool hitTestSelf(Offset position) =>
      _styleEngine.backgroundColor != null &&
      boxLayout.boxRect.contains(position);

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
    _styleEngine.dispose();
    super.dispose();
  }
}
