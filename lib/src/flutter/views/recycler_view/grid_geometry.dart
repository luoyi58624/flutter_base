part of 'index.dart';

// 普通跨度直接算术定位，只有自定义跨列规则才保存分组映射。
class _GridRows {
  _GridRows(this.extents, this.spanCount, this.lookup) {
    assert(() {
      RecyclerWorkProbe.gridGeometryBuilds++;
      return true;
    }());
    if (lookup is! _DefaultSpanSizeLookup) {
      var span = 0, row = 0;
      _starts.add(0);
      for (var position = 0; position < count; position++) {
        final size = lookup._checkedSpanSize(position, spanCount);
        if (span + size > spanCount) {
          span = 0;
          row++;
          _starts.add(position);
        }
        _rowFor.add(row);
        _spanFor.add(span);
        _sizes.add(size);
        span += size;
        if (span == spanCount && position + 1 < count) {
          span = 0;
          row++;
          _starts.add(position + 1);
        }
      }
      _starts.add(count);
    }
    rows = RecyclerExtentIndex.groups(List.generate(rowCount, _typeForRow));
  }

  final RecyclerExtentIndex extents;
  int get count => extents.length;
  final int spanCount;
  final SpanSizeLookup lookup;
  final _starts = <int>[];
  final _rowFor = <int>[];
  final _spanFor = <int>[];
  final _sizes = <int>[];
  final _rowTypes = <String, int>{};
  late final RecyclerExtentIndex rows;
  bool get uniform => lookup is _DefaultSpanSizeLookup;
  int get rowCount => count == 0
      ? 0
      : uniform
      ? (count + spanCount - 1) ~/ spanCount
      : _starts.length - 1;
  int rowFor(int position) => uniform ? position ~/ spanCount : _rowFor[position];
  int firstInRow(int row) => uniform ? row * spanCount : _starts[row];
  int endInRow(int row) => uniform ? math.min(count, (row + 1) * spanCount) : _starts[row + 1];
  int spanFor(int position) => uniform ? position % spanCount : _spanFor[position];
  int sizeFor(int position) => uniform ? 1 : _sizes[position];
  double startAt(int position) => position >= count ? rows.total : rows.prefix(rowFor(position));

  int _typeForRow(int row) {
    // 行高只向相同条目类型、相同跨度的行传播，横幅不能充当普通格子的样本。
    final cells = <(int, int)>{
      for (var position = firstInRow(row); position < endInRow(row); position++)
        (extents.typeAt(position), sizeFor(position)),
    }.toList()..sort((a, b) => a.$1 == b.$1 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1));
    final signature = cells.map((cell) => '${cell.$1}:${cell.$2}').join(',');
    return _rowTypes.putIfAbsent(signature, () => _rowTypes.length);
  }

  void invalidate(int start, int count) {
    if (count == 0 || this.count == 0) return;
    final first = rowFor(start);
    final last = rowFor(math.min(this.count - 1, start + count - 1));
    rows.invalidate(first, last - first + 1, _typeForRow);
  }
}

// 每列维护单调的结束位置，窗口查询只二分各列，不扫描已访问的整段数据。
class _StaggeredSpans {
  _StaggeredSpans(this.extents, this.spanCount, {this.itemCrossExtent, this.itemExtentBuilder})
    : _lanes = List.generate(spanCount, (_) => <int>[]),
      _lines = List.filled(spanCount, 0.0);
  final RecyclerExtentIndex extents;
  final int spanCount;
  final double? itemCrossExtent;
  final double Function(int, double)? itemExtentBuilder;
  final _starts = <double>[];
  final _ends = <double>[];
  final _spans = <int>[];
  // 只保留呈现过的列，远跳时推算出的未显示条目仍可重新分配。
  final _committedSpans = <int, int>{};
  final List<List<int>> _lanes;
  final List<double> _lines;
  int get count => extents.length;
  bool get hasExactExtents => itemExtentBuilder != null;

  double get total {
    // 已知尺寸时一次算出最末列的真实位置，滑块比例随后不随经过的条目变化。
    if (hasExactExtents) {
      ensurePosition(count - 1);
      return _lines.reduce(math.max);
    }
    return math.max(_lines.reduce(math.max), extents.total / spanCount);
  }

  void _append() {
    final position = _starts.length;
    final builder = itemExtentBuilder;
    double extent;
    if (builder == null) {
      extent = extents.extentAt(position);
    } else {
      extent = builder(position, itemCrossExtent!);
      if (!extent.isFinite || extent < 0) {
        throw StateError('位置 $position 的精确主轴尺寸必须是有限的非负数。');
      }
    }
    final committedSpan = _committedSpans[position];
    var lane = committedSpan ?? 0;
    if (committedSpan == null) {
      for (var index = 1; index < spanCount; index++) {
        if (_lines[index] < _lines[lane]) lane = index;
      }
    }
    final start = _lines[lane];
    final end = start + extent;
    _starts.add(start);
    _ends.add(end);
    _spans.add(lane);
    _lanes[lane].add(position);
    _lines[lane] = end;
  }

  void ensurePosition(int position) {
    while (_starts.length <= position && _starts.length < count) {
      _append();
    }
  }

  void _ensurePixels(double end) {
    while (_starts.length < count && _lines.any((line) => line < end)) {
      _append();
    }
  }

  double startAt(int position) {
    if (position >= count) return total;
    ensurePosition(position);
    return _starts[position];
  }

  int spanFor(int position) {
    ensurePosition(position);
    return _spans[position];
  }

  double? exactExtentAt(int position) {
    if (!hasExactExtents) return null;
    ensurePosition(position);
    return _ends[position] - _starts[position];
  }

  List<int> visible(double start, double end) {
    _ensurePixels(end);
    final result = <int>[];
    for (final positions in _lanes) {
      var low = 0, high = positions.length;
      while (low < high) {
        final middle = (low + high) ~/ 2;
        if (_ends[positions[middle]] <= start) {
          low = middle + 1;
        } else {
          high = middle;
        }
      }
      for (var index = low; index < positions.length; index++) {
        final position = positions[index];
        if (_starts[position] >= end) break;
        result.add(position);
      }
    }
    return result..sort();
  }

  bool measure(int position, double extent) {
    if (hasExactExtents) return false;
    final firstOfType = !extents.hasTypeEstimate(extents.typeAt(position));
    final changed = extents.measure(position, extent);
    if (changed) invalidateFrom(firstOfType ? 0 : position);
    return changed;
  }

  void retainSpan(int position, int span) {
    if (!hasExactExtents) _committedSpans[position] = span;
  }

  void invalidateFrom(int position, {bool discardAssignments = false}) {
    if (discardAssignments) _committedSpans.removeWhere((index, _) => index >= position);
    if (position >= _starts.length) return;
    _starts.removeRange(position, _starts.length);
    _ends.removeRange(position, _ends.length);
    _spans.removeRange(position, _spans.length);
    for (var lane = 0; lane < spanCount; lane++) {
      final positions = _lanes[lane];
      while (positions.isNotEmpty && positions.last >= position) {
        positions.removeLast();
      }
      _lines[lane] = positions.isEmpty ? 0 : _ends[positions.last];
    }
  }
}
