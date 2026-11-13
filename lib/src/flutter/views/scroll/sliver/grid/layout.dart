part of 'index.dart';

class _GridSpec extends SliverLayoutSpec {
  const _GridSpec(this.tracks, this.mainAxisSpacing, this.mainAxisExtent, this.aspectRatio)
    : assert(mainAxisSpacing >= 0 && mainAxisSpacing < double.infinity),
      assert(mainAxisExtent == null || mainAxisExtent >= 0 && mainAxisExtent < double.infinity),
      assert(aspectRatio == null || aspectRatio > 0 && aspectRatio < double.infinity);

  final SliverTracks tracks;
  final double mainAxisSpacing;
  final double? mainAxisExtent;
  final double? aspectRatio;

  @override
  SliverLayout createLayout() =>
      mainAxisExtent == null && aspectRatio == null ? _NaturalGridLayout(this) : _FixedGridLayout(this);

  @override
  bool operator ==(Object other) =>
      other is _GridSpec &&
      tracks == other.tracks &&
      mainAxisSpacing == other.mainAxisSpacing &&
      mainAxisExtent == other.mainAxisExtent &&
      aspectRatio == other.aspectRatio;

  @override
  int get hashCode => Object.hash(tracks, mainAxisSpacing, mainAxisExtent, aspectRatio);
}

abstract class _GridLayout extends SliverLayout {
  _GridLayout(this.spec);

  final _GridSpec spec;
  int _columns = 1;
  double _cell = 0;

  @override
  bool get orderedPositions => true;

  int get rowCount => (count + _columns - 1) ~/ _columns;

  double rowStart(int row);

  void _resolveTracks(SliverConstraints constraints) {
    // itemWidth 是物理宽度：横向滚动时交叉轴是高度，按宽高比换算后再取行数。
    final target = switch (spec.tracks.itemExtent) {
      final width? when constraints.axis == Axis.horizontal => width / (spec.aspectRatio ?? 1),
      final width => width,
    };
    _columns = spec.tracks.resolve(constraints.crossAxisExtent, itemExtent: target);
    _cell = spec.tracks.extentOf(constraints.crossAxisExtent, _columns);
  }

  @override
  double startOf(int index) => index >= count ? total : rowStart(index ~/ _columns);

  @override
  double crossOf(int index, Size childSize, SliverConstraints constraints) =>
      spec.tracks.offsetOf(index % _columns, _cell, constraints);

  @override
  (int, int) unitOf(int index) {
    final first = index - index % _columns;
    return (first, math.min(count, first + _columns));
  }

  List<int> _rows(int first, int last) {
    final start = first * _columns;
    final end = math.min(count, (last + 1) * _columns);
    return List<int>.generate(math.max(0, end - start), (offset) => start + offset, growable: false);
  }
}

// 每行以最高条目定行高：条目按列宽紧约束自然测量，行高进入尺寸索引。
class _NaturalGridLayout extends _GridLayout {
  _NaturalGridLayout(super.spec);

  late ExtentIndex _rowExtents;
  // 每个条目最近一次实测，负值表示未测。
  late Float64List _sizes;

  @override
  void rebuild(int count, List<Object?> types, SliverConstraints constraints) {
    _resolveTracks(constraints);
    _sizes = Float64List(count)..fillRange(0, count, -1);
    final rows = rowCount;
    if (types.isEmpty) {
      _rowExtents = ExtentIndex(List<int>.filled(rows, 0));
      return;
    }
    // 行的估值按所含条目类型的组合分组；整数键与次序无关，碰撞只影响估值。
    final items = extentGroups(count, types);
    final groups = <int, int>{};
    _rowExtents = ExtentIndex(
      List<int>.generate(rows, (row) {
        var sum = 0;
        var squares = 0;
        final end = math.min(count, (row + 1) * _columns);
        for (var index = row * _columns; index < end; index++) {
          final group = items[index] + 1;
          sum += group;
          squares += group * group;
        }
        return groups.putIfAbsent(sum * 1000003 + squares, () => groups.length);
      }, growable: false),
    );
  }

  @override
  BoxConstraints childConstraints(SliverConstraints constraints) =>
      constraints.asBoxConstraints(crossAxisExtent: _cell);

  @override
  double get total => rowCount == 0 ? 0 : _rowExtents.total + (rowCount - 1) * spec.mainAxisSpacing;

  @override
  double rowStart(int row) => _rowExtents.prefix(row) + row * spec.mainAxisSpacing;

  @override
  List<int> indicesIn(double start, double end) {
    if (count == 0) return const [];
    // 同一起点优先保留最早的零高行，使局部通知仍能让该行展开。
    final first = start <= 0 ? 0 : _rowExtents.indexAt(start, spacing: spec.mainAxisSpacing, preferFirst: true);
    final last = _rowExtents.indexAt(end - precisionErrorTolerance, spacing: spec.mainAxisSpacing);
    return _rows(first, math.max(first, last));
  }

  @override
  bool measure(int index, double extent) {
    _sizes[index] = extent;
    final (first, end) = unitOf(index);
    // 行内条目按序测量，到行尾才提交行高，半行状态不会触发锚点修正。
    if (index != end - 1) return false;
    var row = 0.0;
    for (var i = first; i < end; i++) {
      row = math.max(row, _sizes[i]);
    }
    return _rowExtents.measure(first ~/ _columns, row);
  }
}

// 格尺寸由 mainAxisExtent 或 aspectRatio 直接给出：位置是纯算术，不测量、不保存任何逐项数据。
class _FixedGridLayout extends _GridLayout {
  _FixedGridLayout(super.spec);

  double _main = 0;

  double get _stride => _main + spec.mainAxisSpacing;

  @override
  bool get usesEstimates => false;

  @override
  void rebuild(int count, List<Object?> types, SliverConstraints constraints) {
    _resolveTracks(constraints);
    _main =
        spec.mainAxisExtent ??
        (constraints.axis == Axis.vertical ? _cell / spec.aspectRatio! : _cell * spec.aspectRatio!);
  }

  @override
  BoxConstraints childConstraints(SliverConstraints constraints) =>
      BoxConstraints.tight(constraints.axis == Axis.vertical ? Size(_cell, _main) : Size(_main, _cell));

  @override
  double get total => rowCount == 0 ? 0 : rowCount * _main + (rowCount - 1) * spec.mainAxisSpacing;

  @override
  double rowStart(int row) => row * _stride;

  @override
  List<int> indicesIn(double start, double end) {
    if (count == 0) return const [];
    final last = rowCount - 1;
    if (_stride <= 0) return _rows(0, last);
    final first = (start / _stride).floor().clamp(0, last);
    return _rows(first, ((end - precisionErrorTolerance) / _stride).floor().clamp(first, last));
  }

  @override
  bool measure(int index, double extent) => false;
}
