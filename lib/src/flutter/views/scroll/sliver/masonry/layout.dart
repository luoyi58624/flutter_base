part of 'index.dart';

class _MasonrySpec extends SliverLayoutSpec {
  const _MasonrySpec(this.tracks, this.mainAxisSpacing)
    : assert(mainAxisSpacing >= 0 && mainAxisSpacing < double.infinity);

  final SliverTracks tracks;
  final double mainAxisSpacing;

  @override
  SliverLayout createLayout() => _MasonryLayout(this);

  @override
  bool operator ==(Object other) =>
      other is _MasonrySpec && tracks == other.tracks && mainAxisSpacing == other.mainAxisSpacing;

  @override
  int get hashCode => Object.hash(tracks, mainAxisSpacing);
}

// 沿最短列放置：位置按序号顺序惰性生成，各列单独二分可见区间，极高卡片不会扩大挂载范围。
class _MasonryLayout extends SliverLayout {
  _MasonryLayout(this.spec);

  final _MasonrySpec spec;
  late ExtentIndex _extents;
  int _columns = 1;
  double _cell = 0;
  final _starts = <double>[];
  final _ends = <double>[];
  final _assigned = <int>[];
  List<List<int>> _lanes = const [];
  List<double> _lines = const [];
  // 已显示过的条目固定在原来的列，上方内容变化时不左右跳动。
  final _committed = <int, int>{};

  double get _spacing => spec.mainAxisSpacing;

  @override
  void rebuild(int count, List<Object?> types, SliverConstraints constraints) {
    _columns = spec.tracks.resolve(constraints.crossAxisExtent);
    _cell = spec.tracks.extentOf(constraints.crossAxisExtent, _columns);
    _extents = ExtentIndex(extentGroups(count, types));
    _starts.clear();
    _ends.clear();
    _assigned.clear();
    _committed.clear();
    _lanes = List.generate(_columns, (_) => <int>[]);
    _lines = List.filled(_columns, 0.0);
  }

  @override
  BoxConstraints childConstraints(SliverConstraints constraints) =>
      constraints.asBoxConstraints(crossAxisExtent: _cell);

  @override
  double get total {
    if (count == 0) return 0;
    final knownEnd = math.max(0.0, _lines.reduce(math.max) - _spacing);
    if (_starts.length == count) return knownEnd;
    // 已生成前缀沿用现有几何，尚未生成的后缀才使用最新估值，避免到尾部时范围突变。
    final placed = _lines.fold(0.0, (sum, line) => sum + line) - _starts.length * _spacing;
    final estimated = placed + _extents.total - _extents.prefix(_starts.length);
    final gaps = math.max(0.0, (count - _columns) / _columns);
    return math.max(knownEnd, estimated / _columns + gaps * _spacing);
  }

  void _append() {
    final index = _starts.length;
    var lane = _committed[index] ?? -1;
    if (lane < 0) {
      lane = 0;
      for (var next = 1; next < _columns; next++) {
        if (_lines[next] < _lines[lane]) lane = next;
      }
    }
    final start = _lines[lane];
    final end = start + _extents.extentAt(index);
    _starts.add(start);
    _ends.add(end);
    _assigned.add(lane);
    _lanes[lane].add(index);
    _lines[lane] = end + _spacing;
  }

  void _ensure(int index) {
    while (_starts.length <= index && _starts.length < count) {
      _append();
    }
  }

  @override
  double startOf(int index) {
    if (index >= count) return total;
    _ensure(index);
    return _starts[index];
  }

  @override
  double crossOf(int index, Size childSize, SliverConstraints constraints) {
    _ensure(index);
    return spec.tracks.offsetOf(_assigned[index], _cell, constraints);
  }

  @override
  List<int> indicesIn(double start, double end) {
    if (count == 0 || end <= start) return const [];
    while (_starts.length < count && _lines.any((line) => line < end)) {
      _append();
    }
    final result = <int>[];
    for (final lane in _lanes) {
      var low = 0, high = lane.length;
      while (low < high) {
        final middle = (low + high) ~/ 2;
        final index = lane[middle];
        final itemEnd = _ends[index];
        // 保留窗口起点的零高条目，使局部更新仍能重新测量并展开。
        if (itemEnd < start || (itemEnd == start && _starts[index] < start)) {
          low = middle + 1;
        } else {
          high = middle;
        }
      }
      for (var offset = low; offset < lane.length; offset++) {
        final index = lane[offset];
        if (_starts[index] >= end) break;
        result.add(index);
      }
    }
    return result..sort();
  }

  @override
  bool measure(int index, double extent) {
    final changed = _extents.measure(index, extent);
    // 类型估值更新只供后续推算，不回溯改写已建立的几何；
    // 已放置的条目比对缓存尺寸，变化时作废它之后的位置。
    final moved = index < _starts.length ? _ends[index] != _starts[index] + extent : changed;
    if (moved && index < _starts.length) {
      _starts.length = index;
      _ends.length = index;
      _assigned.length = index;
      for (var lane = 0; lane < _columns; lane++) {
        final positions = _lanes[lane];
        while (positions.isNotEmpty && positions.last >= index) {
          positions.removeLast();
        }
        _lines[lane] = positions.isEmpty ? 0 : _ends[positions.last] + _spacing;
      }
    }
    return moved;
  }

  @override
  void retain(int index) {
    _ensure(index);
    _committed[index] = _assigned[index];
  }
}
