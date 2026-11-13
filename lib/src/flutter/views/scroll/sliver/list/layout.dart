part of 'index.dart';

class _ListSpec extends SliverLayoutSpec {
  const _ListSpec(this.spacing, this.center, this.stretch) : assert(spacing >= 0 && spacing < double.infinity);

  final double spacing;
  final bool center;
  final bool stretch;

  @override
  SliverLayout createLayout() => _ListLayout(this);

  @override
  bool operator ==(Object other) =>
      other is _ListSpec && spacing == other.spacing && center == other.center && stretch == other.stretch;

  @override
  int get hashCode => Object.hash(spacing, center, stretch);
}

// 一维排列：位置即尺寸前缀和加间距，条目后的间距归它所有。
class _ListLayout extends SliverLayout {
  _ListLayout(this.spec);

  final _ListSpec spec;
  late ExtentIndex _extents;

  @override
  bool get orderedPositions => true;

  @override
  void rebuild(int count, List<Object?> types, SliverConstraints constraints) =>
      _extents = ExtentIndex(extentGroups(count, types));

  // 只约束交叉轴，主轴尺寸交给条目自身。
  @override
  BoxConstraints childConstraints(SliverConstraints constraints) {
    final cross = constraints.crossAxisExtent;
    final min = spec.stretch ? cross : 0.0;
    return constraints.axis == Axis.vertical
        ? BoxConstraints(minWidth: min, maxWidth: cross)
        : BoxConstraints(minHeight: min, maxHeight: cross);
  }

  @override
  double get total => _extents.total + math.max(0, count - 1) * spec.spacing;

  @override
  double startOf(int index) => _extents.prefix(index) + index * spec.spacing;

  @override
  double crossOf(int index, Size childSize, SliverConstraints constraints) {
    final extent = constraints.axis == Axis.vertical ? childSize.width : childSize.height;
    final remaining = math.max(0.0, constraints.crossAxisExtent - extent);
    if (spec.center) return remaining / 2;
    return axisDirectionIsReversed(constraints.crossAxisDirection) ? remaining : 0;
  }

  @override
  List<int> indicesIn(double start, double end) {
    if (count == 0) return const [];
    final first = start <= 0 ? 0 : _extents.indexAt(start, spacing: spec.spacing, preferFirst: true);
    final last = math.max(first, _extents.indexAt(end - precisionErrorTolerance, spacing: spec.spacing));
    return List<int>.generate(last - first + 1, (offset) => first + offset, growable: false);
  }

  @override
  bool measure(int index, double extent) => _extents.measure(index, extent);

  // 远跳到未测区域时按估值取首个条目作锚点，补测缓存区上方的条目不会推走视口内容。
  @override
  int? anchorAt(double pixels) => _extents.indexAt(pixels, spacing: spec.spacing);
}
