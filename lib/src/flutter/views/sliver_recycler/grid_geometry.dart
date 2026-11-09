part of 'sliver_recycler.dart';

// 行高与间距分别累计，零高行不会把同类型的未知行估成仅剩间距。
class _RecyclerGridRows {
  _RecyclerGridRows(this.itemExtents, this.crossAxisCount, this.mainAxisSpacing) {
    final types = <String, int>{};
    _rows = RecyclerExtentIndex.groups(
      List.generate(rowCount, (row) {
        final cells = [for (var index = firstInRow(row); index < endInRow(row); index++) itemExtents.typeAt(index)]
          ..sort();
        final signature = cells.join(',');
        return types.putIfAbsent(signature, () => types.length);
      }),
    );
  }

  final RecyclerExtentIndex itemExtents;
  final int crossAxisCount;
  final double mainAxisSpacing;
  late final RecyclerExtentIndex _rows;

  int get count => itemExtents.length;
  int get rowCount => (count + crossAxisCount - 1) ~/ crossAxisCount;
  int rowFor(int index) => index ~/ crossAxisCount;
  int firstInRow(int row) => row * crossAxisCount;
  int endInRow(int row) => math.min(count, (row + 1) * crossAxisCount);

  double get total => rowCount == 0 ? 0 : _rows.total + (rowCount - 1) * mainAxisSpacing;

  double rowStart(int row) => _rows.prefix(row) + row * mainAxisSpacing;

  double startAt(int index) => index >= count ? total : rowStart(rowFor(index));

  int rowAt(double pixels) {
    if (rowCount == 0) return 0;
    var low = 0, high = rowCount;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (rowStart(middle) < pixels) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    // 同一起点优先保留最早的零高行，使局部通知仍能让该行展开。
    if (low < rowCount && rowStart(low) == pixels) return low;
    return math.max(0, low - 1);
  }

  bool measureRow(int row, double extent) => _rows.measure(row, extent);
}

// 位置只保存几何数据；每列单独二分可见区间，极高卡片不会扩大挂载范围。
class _RecyclerMasonry {
  _RecyclerMasonry(this.itemExtents, this.crossAxisCount, this.mainAxisSpacing)
    : _lanes = List.generate(crossAxisCount, (_) => <int>[]),
      _lines = List.filled(crossAxisCount, 0.0);

  final RecyclerExtentIndex itemExtents;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final _starts = <double>[];
  final _ends = <double>[];
  final _assignedLanes = <int>[];
  final List<List<int>> _lanes;
  final List<double> _lines;
  final _committedLanes = <int, int>{};

  int get count => itemExtents.length;

  double get total {
    if (count == 0) return 0;
    final knownEnd = math.max(0.0, _lines.reduce(math.max) - mainAxisSpacing);
    if (_starts.length == count) return knownEnd;
    // 已生成前缀沿用现有几何，尚未生成后缀才使用最新估值，避免到尾部时范围突变。
    final placedExtent = _lines.fold(0.0, (sum, line) => sum + line) - _starts.length * mainAxisSpacing;
    final estimatedExtent = placedExtent + itemExtents.total - itemExtents.prefix(_starts.length);
    final estimatedGaps = math.max(0.0, (count - crossAxisCount) / crossAxisCount);
    return math.max(knownEnd, estimatedExtent / crossAxisCount + estimatedGaps * mainAxisSpacing);
  }

  void _append() {
    final index = _starts.length;
    final committed = _committedLanes[index];
    var lane = committed ?? 0;
    if (committed == null) {
      for (var next = 1; next < crossAxisCount; next++) {
        if (_lines[next] < _lines[lane]) lane = next;
      }
    }
    final start = _lines[lane];
    final end = start + itemExtents.extentAt(index);
    _starts.add(start);
    _ends.add(end);
    _assignedLanes.add(lane);
    _lanes[lane].add(index);
    _lines[lane] = end + mainAxisSpacing;
  }

  void ensurePosition(int index) {
    while (_starts.length <= index && _starts.length < count) {
      _append();
    }
  }

  void _ensurePixels(double end) {
    while (_starts.length < count && _lines.any((line) => line < end)) {
      _append();
    }
  }

  double startAt(int index) {
    if (index >= count) return total;
    ensurePosition(index);
    return _starts[index];
  }

  int laneAt(int index) {
    ensurePosition(index);
    return _assignedLanes[index];
  }

  List<int> visible(double start, double end) {
    if (count == 0 || end <= start) return [];
    _ensurePixels(end);
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

  bool measure(int index, double extent) {
    final changed = itemExtents.measure(index, extent);
    // 类型估值更新供后续推算使用，不回溯改写此前已建立的几何。
    // 索引中的估值可能已变，仍须比对本条缓存尺寸，实际补测时再更新它之后的位置。
    final placementChanged = index < _starts.length ? _ends[index] != _starts[index] + extent : changed;
    if (placementChanged) _invalidateFrom(index);
    return placementChanged;
  }

  void retainLane(int index, int lane) => _committedLanes[index] = lane;

  void _invalidateFrom(int index) {
    if (index >= _starts.length) return;
    _starts.removeRange(index, _starts.length);
    _ends.removeRange(index, _ends.length);
    _assignedLanes.removeRange(index, _assignedLanes.length);
    for (var lane = 0; lane < crossAxisCount; lane++) {
      final positions = _lanes[lane];
      while (positions.isNotEmpty && positions.last >= index) {
        positions.removeLast();
      }
      _lines[lane] = positions.isEmpty ? 0 : _ends[positions.last] + mainAxisSpacing;
    }
  }
}
