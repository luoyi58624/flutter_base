import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 全量挂载子项并缓存自然排版，仅绘制可见内容的文档 Sliver。
///
/// 普通滚动只更新 Sliver 几何与可见范围，不遍历或重新布局全部子项。
/// 子项尺寸、结构或交叉轴约束改变时重新排版；适合需要常驻状态、
/// 跨段落选择的文档。滚动方向、物理与控制器由外层 [CustomScrollView] 提供，
/// 内边距使用 [SliverPadding]。
class ElSliverList extends MultiChildRenderObjectWidget {
  /// 创建按文档顺序排列、全量常驻的自然尺寸列表。
  const ElSliverList({
    super.key,
    required super.children,
    this.spacing = 0,
    this.center = false,
    this.stretch = false,
  }) : assert(spacing >= 0 && spacing < double.infinity);

  /// 相邻条目之间的主轴间距，末项之后不添加间隔。
  final double spacing;

  /// 是否沿交叉轴居中子项，默认按交叉轴起点排列。
  ///
  /// 子项只受交叉轴最大尺寸约束，可以保留比内容区更窄的自然尺寸。
  final bool center;

  /// 是否让子项撑满交叉轴，默认保留子项的自然尺寸。
  ///
  /// 开启后子项在交叉轴上没有余量，[center] 不再产生效果。
  final bool stretch;

  @override
  ElRenderSliverList createRenderObject(BuildContext context) => ElRenderSliverList._(spacing, center, stretch);

  @override
  void updateRenderObject(BuildContext context, ElRenderSliverList renderObject) {
    renderObject
      ..spacing = spacing
      ..center = center
      ..stretch = stretch;
  }
}

class _ListParentData extends ContainerBoxParentData<RenderBox> {
  double layoutOffset = 0;
  double extent = 0;
}

/// 缓存完整文档的自然尺寸，并将可见部分接入官方 Sliver 协议。
class ElRenderSliverList extends RenderSliver
    with ContainerRenderObjectMixin<RenderBox, _ListParentData>, RenderSliverHelpers {
  ElRenderSliverList._(this._spacing, this._center, this._stretch);

  double _spacing;
  bool _center;
  bool _stretch;
  bool _contentNeedsLayout = true;
  Axis? _contentAxis;
  BoxConstraints? _contentConstraints;
  double _contentExtent = 0;
  final _children = <RenderBox>[];
  final _starts = <double>[];
  final _ends = <double>[];

  /// 相邻条目之间的主轴间距。
  double get spacing => _spacing;
  set spacing(double value) {
    assert(value >= 0 && value.isFinite);
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  /// 是否沿交叉轴居中子项。
  bool get center => _center;
  set center(bool value) {
    if (_center == value) return;
    _center = value;
    // 交叉轴位置按当前配置计算，居中变化不影响内容尺寸。
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  /// 是否让子项撑满交叉轴。
  bool get stretch => _stretch;
  set stretch(bool value) {
    if (_stretch == value) return;
    _stretch = value;
    markNeedsLayout();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ListParentData) child.parentData = _ListParentData();
  }

  @override
  void markNeedsLayout() {
    // 子项尺寸与结构变化需要更新文档；视口滚动仅传入新 SliverConstraints，
    // 不经过这里，因此不能用每次 performLayout 都重排全部内容的方式处理。
    _contentNeedsLayout = true;
    super.markNeedsLayout();
  }

  void _layoutContent(BoxConstraints childConstraints) {
    _children.clear();
    _starts.clear();
    _ends.clear();
    var flow = 0.0;
    var child = firstChild;
    while (child != null) {
      if (_children.isNotEmpty) flow += _spacing;
      child.layout(childConstraints, parentUsesSize: true);
      final extent = constraints.axis == Axis.vertical ? child.size.height : child.size.width;
      final data = child.parentData! as _ListParentData;
      data
        ..layoutOffset = flow
        ..extent = extent;
      _children.add(child);
      _starts.add(flow);
      flow += extent;
      _ends.add(flow);
      child = childAfter(child);
    }
    _contentExtent = flow;
    _contentAxis = constraints.axis;
    _contentConstraints = childConstraints;
    _contentNeedsLayout = false;
  }

  @override
  void performLayout() {
    final cross = constraints.crossAxisExtent;
    final minCross = _stretch ? cross : 0.0;
    final childConstraints = constraints.axis == Axis.vertical
        ? BoxConstraints(minWidth: minCross, maxWidth: cross)
        : BoxConstraints(minHeight: minCross, maxHeight: cross);
    if (_contentNeedsLayout || _contentAxis != constraints.axis || _contentConstraints != childConstraints) {
      _layoutContent(childConstraints);
    }

    geometry = SliverGeometry(
      scrollExtent: _contentExtent,
      paintExtent: calculatePaintOffset(constraints, from: 0, to: _contentExtent),
      cacheExtent: calculateCacheOffset(constraints, from: 0, to: _contentExtent),
      maxPaintExtent: _contentExtent,
      hasVisualOverflow: constraints.scrollOffset > 0 || _contentExtent > constraints.remainingPaintExtent,
    );
  }

  (int, int) _visibleRange() {
    if (_children.isEmpty || geometry?.visible != true) return (0, 0);
    final start = constraints.scrollOffset;
    final end = start + geometry!.paintExtent;
    var low = 0;
    var high = _ends.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (_ends[middle] <= start) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final first = low;
    high = _starts.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (_starts[middle] < end) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return (first, low);
  }

  @override
  double childMainAxisPosition(RenderBox child) =>
      (child.parentData! as _ListParentData).layoutOffset - constraints.scrollOffset;

  @override
  double childCrossAxisPosition(RenderBox child) {
    final extent = constraints.axis == Axis.vertical ? child.size.width : child.size.height;
    final remaining = math.max(0.0, constraints.crossAxisExtent - extent);
    if (_center) return remaining / 2;
    return axisDirectionIsReversed(constraints.crossAxisDirection) ? remaining : 0;
  }

  @override
  double childScrollOffset(RenderObject child) => (child.parentData! as _ListParentData).layoutOffset;

  Offset _paintOffset(RenderBox child) {
    final data = child.parentData! as _ListParentData;
    final logical = data.layoutOffset - constraints.scrollOffset;
    final direction = applyGrowthDirectionToAxisDirection(constraints.axisDirection, constraints.growthDirection);
    final main = axisDirectionIsReversed(direction) ? geometry!.paintExtent - logical - data.extent : logical;
    final cross = childCrossAxisPosition(child);
    return constraints.axis == Axis.vertical ? Offset(cross, main) : Offset(main, cross);
  }

  @override
  bool paintsChild(RenderObject child) {
    if (geometry?.visible != true) return false;
    final data = child.parentData! as _ListParentData;
    return data.extent > 0 &&
        data.layoutOffset < constraints.scrollOffset + geometry!.paintExtent &&
        data.layoutOffset + data.extent > constraints.scrollOffset;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final (start, end) = _visibleRange();
    for (var index = start; index < end; index++) {
      final child = _children[index];
      if (paintsChild(child)) context.paintChild(child, offset + _paintOffset(child));
    }
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    final (start, end) = _visibleRange();
    for (var index = end - 1; index >= start; index--) {
      final child = _children[index];
      if (paintsChild(child) &&
          hitTestBoxChild(
            BoxHitTestResult.wrap(result),
            child,
            mainAxisPosition: mainAxisPosition,
            crossAxisPosition: crossAxisPosition,
          )) {
        return true;
      }
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    // 离屏子项也保留真实变换，官方 ensureVisible 与选择自动滚动需要它。
    final offset = _paintOffset(child);
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final (start, end) = _visibleRange();
    for (var index = start; index < end; index++) {
      final child = _children[index];
      if (paintsChild(child)) visitor(child);
    }
  }

  @override
  Rect? describeSemanticsClip(RenderObject? child) => geometry == null ? null : paintBounds;

  @override
  void dispose() {
    _children.clear();
    _starts.clear();
    _ends.clear();
    super.dispose();
  }
}
