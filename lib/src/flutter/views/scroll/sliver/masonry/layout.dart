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

class _MasonryTile {
  _MasonryTile(this.index, this.lane, this.start, this.end, {this.prepended = false});

  final int index;
  final int lane;
  final bool prepended;
  double start;
  double end;

  void shift(double delta) {
    start += delta;
    end += delta;
  }
}

// 只为当前连续片段建立几何：向下接最短列，向上接最高列头，未知前缀不充当已承诺的位置。
class _MasonryLayout extends SliverLayout {
  _MasonryLayout(this.spec);

  final _MasonrySpec spec;
  late ExtentIndex _extents;
  int _columns = 1;
  double _cell = 0;
  final _tiles = <int, _MasonryTile>{};
  final _measured = <int>{};
  List<ListQueue<int>> _lanes = const [];
  List<double> _heads = const [];
  List<double> _tails = const [];
  List<int?> _visibleFirst = const [];
  var _first = 0;
  var _last = -1;
  double _viewportStart = 0;
  double _rangeBias = 0;
  bool _packOrigin = false;

  double get _spacing => spec.mainAxisSpacing;

  @override
  bool sync(int count, List<Object?>? types, SliverConstraints constraints, {bool force = false}) {
    _viewportStart = constraints.scrollOffset;
    return super.sync(count, types, constraints, force: force);
  }

  @override
  void rebuild(int count, List<Object?> types, SliverConstraints constraints) {
    _columns = spec.tracks.resolve(constraints.crossAxisExtent);
    _cell = spec.tracks.extentOf(constraints.crossAxisExtent, _columns);
    _extents = ExtentIndex(extentGroups(count, types));
    _measured.clear();
    _rangeBias = 0;
    _reset(0, 0);
  }

  @override
  BoxConstraints childConstraints(SliverConstraints constraints) =>
      constraints.asBoxConstraints(crossAxisExtent: _cell);

  @override
  double get total {
    if (count == 0) return 0;
    final knownEnd = _tiles.isEmpty ? 0.0 : math.max(0.0, _tails.reduce(math.max) - _spacing);
    if (_last == count - 1) return knownEnd;
    final gaps = math.max(0.0, (count - _columns) / _columns);
    return math.max(knownEnd, _extents.total / _columns + gaps * _spacing + _rangeBias);
  }

  void _reset(int first, double origin) {
    _tiles.clear();
    _first = first;
    _last = first - 1;
    _packOrigin = false;
    _lanes = List.generate(_columns, (_) => ListQueue<int>());
    _heads = List.filled(_columns, origin);
    _tails = List.filled(_columns, origin);
    _visibleFirst = List.filled(_columns, null);
  }

  int _edgeLane(List<double> lines, {bool greatest = false}) {
    var lane = 0;
    for (var next = 1; next < _columns; next++) {
      if (greatest ? lines[next] > lines[lane] : lines[next] < lines[lane]) lane = next;
    }
    return lane;
  }

  void _append() {
    final index = ++_last;
    final lane = _edgeLane(_tails);
    final start = _tails[lane];
    final end = start + _extents.extentAt(index);
    _tiles[index] = _MasonryTile(index, lane, start, end);
    if (_lanes[lane].isEmpty) _heads[lane] = start;
    _lanes[lane].addLast(index);
    _tails[lane] = end + _spacing;
  }

  void _prepend() {
    final index = --_first;
    final lane = _edgeLane(_heads, greatest: true);
    final end = _heads[lane] - _spacing;
    final start = end - _extents.extentAt(index);
    _tiles[index] = _MasonryTile(index, lane, start, end, prepended: true);
    _lanes[lane].addFirst(index);
    _heads[lane] = start;
    if (index == 0) _packOrigin = true;
  }

  // 估值只负责找候选；未测尾部随真实列尾重新分列，不能提前固定最短列选择。
  void _repackTail() {
    final last = _last;
    while (_last >= _first && !_measured.contains(_last)) {
      final tile = _tiles.remove(_last)!;
      final lane = _lanes[tile.lane]..removeLast();
      _tails[tile.lane] = lane.isEmpty ? tile.start : _tiles[lane.last]!.end + _spacing;
      if (lane.isEmpty) _heads[tile.lane] = tile.start;
      _last--;
    }
    while (_last < last) {
      _append();
    }
  }

  // 片段均值与全局前缀估值的差只影响未访问区间，不反向推移已经显示的片段。
  void _syncRange() {
    if (_tiles.isEmpty) return;
    final tailMean = _tails.fold(0.0, (sum, value) => sum + value) / _columns;
    _rangeBias = tailMean - (_extents.prefix(_last + 1) + (_last + 1) * _spacing) / _columns;
  }

  void _seed(double pixels) {
    final weighted = math.max(0.0, (pixels - _rangeBias) * _columns);
    var index = _extents.indexAt(weighted, spacing: _spacing);
    index -= index % _columns;
    if (pixels <= precisionErrorTolerance || index == 0) {
      _rangeBias = 0;
      _reset(0, 0);
    } else {
      final origin = (_extents.prefix(index) + index * _spacing) / _columns + _rangeBias;
      _reset(index, math.max(0.0, origin));
    }
  }

  void _ensure(int index) {
    if (_tiles.isEmpty) {
      final origin = (_extents.prefix(index) + index * _spacing) / _columns + _rangeBias;
      _reset(index, math.max(0.0, origin));
      _append();
    }
    while (index < _first) {
      _prepend();
    }
    while (index > _last) {
      _append();
    }
  }

  @override
  double startOf(int index) {
    if (index >= count) return total;
    _ensure(index);
    return _tiles[index]!.start;
  }

  @override
  double crossOf(int index, Size childSize, SliverConstraints constraints) {
    _ensure(index);
    return spec.tracks.offsetOf(_tiles[index]!.lane, _cell, constraints);
  }

  @override
  List<int> indicesIn(double start, double end) {
    if (count == 0 || end <= start) return const [];
    if (_tiles.isEmpty ||
        end <= _heads.reduce(math.min) ||
        start >= _tails.reduce(math.max) ||
        (_viewportStart <= precisionErrorTolerance && _first > 0)) {
      _seed(start);
    }
    while (_first > 0 && _heads.any((line) => line > start)) {
      _prepend();
    }
    while (_last < count - 1 && _tails.any((line) => line < end)) {
      _append();
    }
    _syncRange();
    final result = <int>[];
    for (final lane in _lanes) {
      var low = 0, high = lane.length;
      while (low < high) {
        final middle = (low + high) ~/ 2;
        final item = _tiles[lane.elementAt(middle)]!;
        final itemEnd = item.end;
        // 保留窗口起点的零高条目，使局部更新仍能重新测量并展开。
        if (itemEnd < start || (itemEnd == start && item.start < start)) {
          low = middle + 1;
        } else {
          high = middle;
        }
      }
      for (var offset = low; offset < lane.length; offset++) {
        final index = lane.elementAt(offset);
        if (_tiles[index]!.start >= end) break;
        result.add(index);
      }
    }
    return result..sort();
  }

  @override
  bool measure(int index, double extent) {
    final wasMeasured = _measured.contains(index);
    final changed = _extents.measure(index, extent);
    _measured.add(index);
    final tile = _tiles[index];
    if (tile == null) return changed;
    final delta = extent - (tile.end - tile.start);
    if (delta != 0) {
      final firstVisible = _visibleFirst[tile.lane];
      final beforeVisible = firstVisible == null ? tile.prepended : index < firstVisible;
      if (!wasMeasured && beforeVisible) {
        // 首次补测列头，固定它与原有后继的接缝，不能把另一列已见内容挤走。
        for (final preceding in _lanes[tile.lane]) {
          if (preceding >= index) break;
          _tiles[preceding]!.shift(-delta);
        }
        tile.start -= delta;
      } else {
        // 已测内容实际变高继续正常推移后继，保留动态图片和正文展开的布局语义。
        tile.end += delta;
        final lane = _lanes[tile.lane];
        for (var offset = lane.length - 1; offset >= 0; offset--) {
          final following = lane.elementAt(offset);
          if (following <= index) break;
          _tiles[following]!.shift(delta);
        }
      }
      final lane = _lanes[tile.lane];
      _heads[tile.lane] = _tiles[lane.first]!.start;
      _tails[tile.lane] = _tiles[lane.last]!.end + _spacing;
    }
    var moved = delta != 0;
    if (_packOrigin &&
        (_viewportStart <= precisionErrorTolerance ||
            _heads.any((line) => line > _viewportStart + precisionErrorTolerance))) {
      // 缓存提前触顶不能重排列；真实视口到列头时只重建顶部窗口，离屏后缀仍保留尺寸缓存。
      _rangeBias = 0;
      _reset(0, 0);
      do {
        _append();
      } while (_last < index);
      moved = true;
    } else if (moved || changed) {
      _repackTail();
    }
    _syncRange();
    return moved || changed;
  }

  @override
  void beginRetain() => _visibleFirst.fillRange(0, _visibleFirst.length, null);

  @override
  void retain(int index) {
    _ensure(index);
    final lane = _tiles[index]!.lane;
    _visibleFirst[lane] ??= index;
  }
}
