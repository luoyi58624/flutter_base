part of 'sliver.dart';

class _EagerGrid extends _EagerSliver implements ElSliverGrid, ElSliverMasonry {
  const _EagerGrid({
    super.key,
    required super.children,
    required this.crossAxisCount,
    super.addRepaintBoundaries,
    super.addSemanticIndexes,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
  }) : masonry = false,
       assert(crossAxisCount > 0),
       assert(mainAxisSpacing >= 0 && mainAxisSpacing < double.infinity),
       assert(crossAxisSpacing >= 0 && crossAxisSpacing < double.infinity);

  const _EagerGrid.masonry({
    super.key,
    required super.children,
    required this.crossAxisCount,
    super.addRepaintBoundaries,
    super.addSemanticIndexes,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
  }) : masonry = true,
       assert(crossAxisCount > 0),
       assert(mainAxisSpacing >= 0 && mainAxisSpacing < double.infinity),
       assert(crossAxisSpacing >= 0 && crossAxisSpacing < double.infinity);

  @override
  final int crossAxisCount;
  @override
  final double mainAxisSpacing;
  @override
  final double crossAxisSpacing;
  final bool masonry;

  @override
  int get itemCount => children.length;

  @override
  ElRenderSliverGrid createRenderObject(BuildContext context) => ElRenderSliverGrid._(this);

  @override
  void updateRenderObject(BuildContext context, ElRenderSliverGrid renderObject) => renderObject._configure(this);
}

/// 缓存全量网格几何，各列二分查询可见内容。
class ElRenderSliverGrid extends ElRenderSliverList {
  ElRenderSliverGrid._(_EagerGrid widget) : _configuration = widget, super._(widget.mainAxisSpacing, false, true);

  _EagerGrid _configuration;
  List<List<int>> _lanes = [];
  double _cellExtent = 0;

  void _configure(_EagerGrid widget) {
    final old = _configuration;
    _configuration = widget;
    if (old.crossAxisCount != widget.crossAxisCount ||
        old.masonry != widget.masonry ||
        old.mainAxisSpacing != widget.mainAxisSpacing ||
        old.crossAxisSpacing != widget.crossAxisSpacing) {
      _spacing = widget.mainAxisSpacing;
      markNeedsLayout();
    }
  }

  @override
  void performLayout() {
    final columns = _configuration.crossAxisCount;
    _cellExtent = math.max(
      0,
      (constraints.crossAxisExtent - (columns - 1) * _configuration.crossAxisSpacing) / columns,
    );
    final box = constraints.asBoxConstraints(crossAxisExtent: _cellExtent);
    if (_contentNeedsLayout || _contentAxis != constraints.axis || _contentConstraints != box) _layoutContent(box);
    geometry = SliverGeometry(
      scrollExtent: _contentExtent,
      paintExtent: calculatePaintOffset(constraints, from: 0, to: _contentExtent),
      cacheExtent: calculateCacheOffset(constraints, from: 0, to: _contentExtent),
      maxPaintExtent: _contentExtent,
      hasVisualOverflow: constraints.scrollOffset > 0 || _contentExtent > constraints.remainingPaintExtent,
    );
  }

  @override
  void _layoutContent(BoxConstraints childConstraints) {
    _children.clear();
    _starts.clear();
    _ends.clear();
    final columns = _configuration.crossAxisCount;
    _lanes = List.generate(columns, (_) => <int>[]);
    final lines = List.filled(columns, 0.0);
    var rowStart = 0.0;
    var rowExtent = 0.0;
    var child = firstChild;
    _contentExtent = 0;
    while (child != null) {
      final index = _children.length;
      var lane = index % columns;
      if (_configuration.masonry) {
        lane = 0;
        for (var next = 1; next < columns; next++) {
          if (lines[next] < lines[lane]) lane = next;
        }
      } else if (lane == 0 && index > 0) {
        rowStart += rowExtent + _spacing;
        rowExtent = 0;
      }
      child.layout(childConstraints, parentUsesSize: true);
      final extent = constraints.axis == Axis.vertical ? child.size.height : child.size.width;
      final start = _configuration.masonry ? lines[lane] : rowStart;
      final data = child.parentData! as _ListParentData;
      data
        ..layoutOffset = start
        ..extent = extent
        ..offset = Offset(lane.toDouble(), 0);
      _children.add(child);
      _starts.add(start);
      _ends.add(start + extent);
      _lanes[lane].add(index);
      lines[lane] = start + extent + _spacing;
      rowExtent = math.max(rowExtent, extent);
      _contentExtent = math.max(_contentExtent, start + extent);
      child = childAfter(child);
    }
    _contentConstraints = childConstraints;
    _contentAxis = constraints.axis;
    _contentNeedsLayout = false;
  }

  Iterable<RenderBox> _visibleChildren() sync* {
    if (geometry?.visible != true) return;
    final start = constraints.scrollOffset;
    final end = start + geometry!.paintExtent;
    for (final lane in _lanes) {
      var low = 0, high = lane.length;
      while (low < high) {
        final middle = (low + high) ~/ 2;
        if (_ends[lane[middle]] <= start) {
          low = middle + 1;
        } else {
          high = middle;
        }
      }
      for (var i = low; i < lane.length && _starts[lane[i]] < end; i++) {
        final child = _children[lane[i]];
        if (paintsChild(child)) yield child;
      }
    }
  }

  @override
  double childCrossAxisPosition(RenderBox child) {
    final lane = (child.parentData! as _ListParentData).offset.dx;
    final cross = lane * (_cellExtent + _configuration.crossAxisSpacing);
    return axisDirectionIsReversed(constraints.crossAxisDirection)
        ? constraints.crossAxisExtent - cross - _cellExtent
        : cross;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in _visibleChildren()) {
      context.paintChild(child, offset + _paintOffset(child));
    }
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    for (final child in _visibleChildren()) {
      if (hitTestBoxChild(
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
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    for (final child in _visibleChildren()) {
      visitor(child);
    }
  }
}
