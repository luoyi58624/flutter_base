part of 'index.dart';

class _GridParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _GridParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _GridParentData> {
  AxisGeometry _axis = const AxisGeometry(Axis.vertical);
  GridLayoutGeometry _grid = const GridLayoutGeometry();

  void configure(Axis axis, TextDirection direction, GridLayoutGeometry grid) {
    if (_axis.axis == axis && _axis.textDirection == direction && _grid == grid) return;
    _axis = AxisGeometry(axis, textDirection: direction);
    _grid = grid;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _GridParentData) child.parentData = _GridParentData();
  }

  double _crossLimit(BoxConstraints value) => _axis.axis == Axis.vertical ? value.maxWidth : value.maxHeight;

  @override
  void performLayout() => _layoutGrid();

  void _layoutGrid() {
    final grid = _grid.resolve(axis: _axis.axis, crossExtent: _crossLimit(constraints), itemCount: childCount);
    final cell = grid.cellSize;
    final childConstraints = BoxConstraints.tight(cell);
    var child = firstChild;
    var index = 0;
    while (child != null) {
      child.layout(childConstraints, parentUsesSize: true);
      final data = child.parentData! as _GridParentData;
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

  double _intrinsic(bool width, double extent) {
    final mainAxis = width == (_axis.axis == Axis.horizontal);
    if (mainAxis) return _grid.resolve(axis: _axis.axis, crossExtent: extent, itemCount: childCount).mainExtent;
    final grid = _grid;
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

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsic(true, height);
  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsic(true, height);
  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsic(false, width);
  @override
  double computeMinIntrinsicHeight(double width) => _intrinsic(false, width);
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(
    _grid.resolve(axis: _axis.axis, crossExtent: _crossLimit(constraints), itemCount: childCount).size,
  );

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = (child.parentData! as _GridParentData).offset;
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }
}
