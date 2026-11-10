import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'geometry/axis_geometry.dart';
import 'geometry/grid_geometry.dart';
import 'geometry/list_geometry.dart';

/// List/Grid 共用的内部 Widget 协议；公开面只导出具体 View。
abstract class LayoutView extends MultiChildRenderObjectWidget {
  /// 创建全量挂载的布局 View。
  const LayoutView({super.key, super.children});

  /// 网格几何声明；列表为 null。
  GridLayoutGeometry? get gridGeometry => null;

  /// 列表几何声明；网格为 null。
  ListLayoutGeometry? get listGeometry => null;

  /// 方向跟随最近 Scrollable，独立使用时默认纵向。
  void configureRenderObject(BuildContext context, RenderLayoutView renderObject) {
    final direction = Scrollable.maybeOf(context)?.axisDirection;
    renderObject.configure(
      axis: direction == null ? Axis.vertical : axisDirectionToAxis(direction),
      reverse: false,
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      grid: gridGeometry,
      list: listGeometry,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderLayoutView renderObject) =>
      configureRenderObject(context, renderObject);
}

/// 独立布局条目的主轴顺序和物理偏移。
class LayoutParentData extends ContainerBoxParentData<RenderBox> {}

/// List/Grid 的全量布局 Render 宿主。
abstract class RenderLayoutView extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, LayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, LayoutParentData> {
  AxisGeometry _axis = const AxisGeometry(Axis.vertical);
  GridLayoutGeometry? _grid;
  ListLayoutGeometry? _list;
  Float64List _listStarts = Float64List(0);

  /// 应用 View 的共享声明和方向。
  void configure({
    required Axis axis,
    required TextDirection textDirection,
    required bool reverse,
    required GridLayoutGeometry? grid,
    required ListLayoutGeometry? list,
  }) {
    final changed =
        _axis.axis != axis ||
        _axis.textDirection != textDirection ||
        _axis.reverse != reverse ||
        _grid != grid ||
        _list != list;
    _axis = AxisGeometry(axis, textDirection: textDirection, reverse: reverse);
    _grid = grid;
    _list = list;
    if (changed) markNeedsLayout();
  }

  /// 具体布局类型提供自己的 ParentData。
  LayoutParentData createParentData();
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! LayoutParentData) child.parentData = createParentData();
  }

  double _crossLimit(BoxConstraints value) => _axis.axis == Axis.vertical ? value.maxWidth : value.maxHeight;

  @override
  void performLayout() {
    if (_grid != null) {
      _layoutGrid();
    } else {
      _layoutList();
    }
  }

  void _layoutGrid() {
    final grid = _grid!.resolve(axis: _axis.axis, crossExtent: _crossLimit(constraints), itemCount: childCount);
    final cell = grid.cellSize;
    final childConstraints = BoxConstraints.tight(cell);
    var child = firstChild;
    var index = 0;
    while (child != null) {
      child.layout(childConstraints, parentUsesSize: true);
      final data = child.parentData! as LayoutParentData;
      data.offset = _axis.offset(
        grid.mainStart(index),
        grid.crossStart(index),
        mainExtent: grid.mainExtent,
        crossExtent: grid.crossExtent,
        childSize: cell,
      );
      child = data.nextSibling;
      index++;
    }
    size = constraints.constrain(grid.size);
  }

  void _layoutList() {
    final list = _list!;
    final crossLimit = _crossLimit(constraints);
    final stretch = list.crossAxisAlignment == CrossAxisAlignment.stretch && crossLimit.isFinite;
    final natural = _axis.axis == Axis.vertical
        ? BoxConstraints(minWidth: stretch ? crossLimit : 0, maxWidth: crossLimit)
        : BoxConstraints(minHeight: stretch ? crossLimit : 0, maxHeight: crossLimit);
    if (!list.fixedSize && _listStarts.length != childCount) _listStarts = Float64List(childCount);
    if (list.fixedSize && _listStarts.isNotEmpty) _listStarts = Float64List(0);
    var main = 0.0;
    var cross = 0.0;
    double? fixed;
    var child = firstChild;
    var index = 0;
    while (child != null) {
      var value = natural;
      if (fixed != null) {
        value = _axis.axis == Axis.vertical
            ? natural.copyWith(minHeight: fixed, maxHeight: fixed)
            : natural.copyWith(minWidth: fixed, maxWidth: fixed);
      }
      child.layout(value, parentUsesSize: true);
      final extent = _axis.mainOf(child.size);
      if (list.fixedSize) fixed ??= extent;
      if (!list.fixedSize) _listStarts[index] = main;
      main += extent + (index + 1 < childCount ? list.gap : 0);
      cross = math.max(cross, _axis.crossOf(child.size));
      child = (child.parentData! as LayoutParentData).nextSibling;
      index++;
    }
    final fixedLayout = list.fixedSize ? FixedListGeometry(childCount, fixed ?? 0) : null;
    if (fixedLayout != null) main = fixedLayout.extentWithGap(list.gap);
    if (crossLimit.isFinite) cross = crossLimit;
    size = constraints.constrain(_axis.size(main, cross));
    child = firstChild;
    index = 0;
    while (child != null) {
      final data = child.parentData! as LayoutParentData;
      final start = fixedLayout != null ? fixedLayout.offsetOf(index) + index * list.gap : _listStarts[index];
      data.offset = _axis.offset(
        start,
        list.crossStart(cross, _axis.crossOf(child.size)),
        mainExtent: main,
        crossExtent: cross,
        childSize: child.size,
      );
      child = data.nextSibling;
      index++;
    }
  }

  double _intrinsic(bool width, bool minimum, double extent) {
    final mainAxis = width == (_axis.axis == Axis.horizontal);
    if (_grid != null) {
      if (mainAxis) return _grid!.resolve(axis: _axis.axis, crossExtent: extent, itemCount: childCount).mainExtent;
      final grid = _grid!;
      final count = grid.crossAxisCount ?? 1;
      final gap = _axis.axis == Axis.vertical ? grid.columnGap : grid.rowGap;
      final double cell;
      if (grid.itemWidth != null) {
        cell = _axis.axis == Axis.vertical ? grid.itemWidth! : grid.itemWidth! / grid.aspectRatio;
      } else if (grid.mainAxisExtent != null) {
        cell = _axis.axis == Axis.vertical
            ? grid.mainAxisExtent! * grid.aspectRatio
            : grid.mainAxisExtent! / grid.aspectRatio;
      } else {
        cell = grid.minCrossAxisExtent ?? grid.maxCrossAxisExtent ?? 0;
      }
      return count * cell + math.max(0, count - 1) * gap;
    }
    double result = 0;
    var child = firstChild;
    while (child != null) {
      final value = width
          ? minimum
                ? child.getMinIntrinsicWidth(extent)
                : child.getMaxIntrinsicWidth(extent)
          : minimum
          ? child.getMinIntrinsicHeight(extent)
          : child.getMaxIntrinsicHeight(extent);
      if (mainAxis && _list!.fixedSize) return ListLayoutGeometry.fixedExtent(childCount, value, _list!.gap);
      result = mainAxis ? result + value : math.max(result, value);
      child = (child.parentData! as LayoutParentData).nextSibling;
    }
    return result + (mainAxis ? math.max(0, childCount - 1) * _list!.gap : 0);
  }

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsic(true, true, height);
  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsic(true, false, height);
  @override
  double computeMinIntrinsicHeight(double width) => _intrinsic(false, true, width);
  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsic(false, false, width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (_grid != null) {
      return constraints.constrain(
        _grid!.resolve(axis: _axis.axis, crossExtent: _crossLimit(constraints), itemCount: childCount).size,
      );
    }
    final list = _list!;
    final crossLimit = _crossLimit(constraints);
    final stretch = crossLimit.isFinite && list.crossAxisAlignment == CrossAxisAlignment.stretch;
    final childConstraints = _axis.axis == Axis.vertical
        ? BoxConstraints(minWidth: stretch ? crossLimit : 0, maxWidth: crossLimit)
        : BoxConstraints(minHeight: stretch ? crossLimit : 0, maxHeight: crossLimit);
    if (list.fixedSize && crossLimit.isFinite) {
      final extent = firstChild == null ? 0.0 : _axis.mainOf(firstChild!.getDryLayout(childConstraints));
      return constraints.constrain(
        _axis.size(ListLayoutGeometry.fixedExtent(childCount, extent, list.gap), crossLimit),
      );
    }
    var main = 0.0;
    var cross = 0.0;
    var count = 0;
    double? fixed;
    var child = firstChild;
    while (child != null) {
      final childSize = child.getDryLayout(childConstraints);
      fixed ??= _axis.mainOf(childSize);
      main += list.fixedSize ? fixed : _axis.mainOf(childSize);
      cross = math.max(cross, _axis.crossOf(childSize));
      count++;
      child = (child.parentData! as LayoutParentData).nextSibling;
    }
    return constraints.constrain(
      _axis.size(main + math.max(0, count - 1) * list.gap, crossLimit.isFinite ? crossLimit : cross),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = (child.parentData! as LayoutParentData).offset;
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }
}
