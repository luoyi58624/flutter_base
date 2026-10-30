import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../layout/geometry/extent_index.dart';

@immutable
class VirtualExtentState {
  const VirtualExtentState({required this.extent, required this.measured});

  /// Effective item extent currently used by the prefix-sum index.
  ///
  /// For measured rows this is the real laid-out size. For unmeasured rows this
  /// is an estimate, and it may be replaced synchronously once the row reports
  /// its actual layout size.
  final double extent;

  /// Whether [extent] came from a real child layout report.
  final bool measured;

  bool get estimated => !measured;

  @override
  bool operator ==(Object other) {
    return other is VirtualExtentState && other.extent == extent && other.measured == measured;
  }

  @override
  int get hashCode => Object.hash(extent, measured);

  @override
  String toString() => 'VirtualExtentState(extent: $extent, measured: $measured)';
}

/// Prefix-sum index for variable-size virtual scrolling.
///
/// This index is the source of truth for content coordinates. It stores exact
/// measured extents where available and deterministic estimates everywhere
/// else, then answers offset <-> item index queries in O(log n).
///
/// Important model distinction:
/// - Estimated extents are placeholders for not-yet-laid-out rows.
/// - Measured extents are synchronous Flutter layout facts.
/// - `totalExtent` is always the best current synchronous model and is updated
///   immediately when measurements arrive.
///
/// Do not treat this like browser async scrolling where the scrollbar can keep
/// an intentionally stale estimated range while content catches up later. In
/// ElView/Flutter, accuracy wins: scrollbar size/position may correct when the
/// model improves, but the mounted window and layout must be computed from the
/// current prefix model.
class VirtualExtentIndex implements LayoutExtentIndex {
  factory VirtualExtentIndex({
    required int count,
    required double estimatedExtent,
    double Function(int index)? extentBuilder,
  }) {
    return VirtualExtentIndex._(
      count: count,
      estimatedExtent: _checkedDefaultExtent(estimatedExtent),
      extentBuilder: extentBuilder,
    );
  }

  VirtualExtentIndex._({required int count, required double estimatedExtent, double Function(int index)? extentBuilder})
    : assert(count >= 0),
      assert(_isValidDefaultExtent(estimatedExtent)) {
    reset(count: count, estimatedExtent: estimatedExtent, extentBuilder: extentBuilder);
  }

  Float64List _extents = Float64List(0);
  Uint8List _measured = Uint8List(0);
  Float64List _tree = Float64List(0);
  Float64List _measuredCountTree = Float64List(0);
  bool _uniformEstimate = true;
  double _estimatedExtent = 0.0;
  double _totalExtent = 0.0;
  int _measuredCount = 0;
  double _measuredExtentTotal = 0.0;

  @override
  int get count => _extents.length;

  @override
  double get estimatedExtent => _estimatedExtent;

  @override
  double get totalExtent => _totalExtent;

  @override
  int get measuredCount => _measuredCount;

  @override
  double get measuredExtentTotal => _measuredExtentTotal;

  @override
  double? get measuredExtentAverage => _measuredCount == 0 ? null : _measuredExtentTotal / _measuredCount;

  /// 测试用：尺寸与前缀数组的实际槽数量。
  int get debugStorageSlotCount => _extents.length + _measured.length + _tree.length + _measuredCountTree.length;

  void reset({required int count, required double estimatedExtent, double Function(int index)? extentBuilder}) {
    RangeError.checkNotNegative(count, 'count');
    final safeEstimatedExtent = _checkedDefaultExtent(estimatedExtent);
    assert(count >= 0);
    assert(_isValidDefaultExtent(safeEstimatedExtent));

    if (extentBuilder == null) {
      // Uniform estimate with zero measurements: unmeasured `_extents` slots
      // are never read (`extentOf` short-circuits on `_uniformEstimate`) and
      // both Fenwick trees are all zeros, which typed-list allocation already
      // provides. Skip the O(n) resolver loop entirely.
      _estimatedExtent = safeEstimatedExtent;
      _extents = Float64List(count);
      _measured = Uint8List(count);
      _uniformEstimate = true;
      _tree = Float64List(count + 1);
      _measuredCountTree = Float64List(count + 1);
      _measuredCount = 0;
      _measuredExtentTotal = 0.0;
      _totalExtent = count * safeEstimatedExtent;
      return;
    }

    _resetFromExtentResolver(
      count: count,
      estimatedExtent: safeEstimatedExtent,
      resolveExtent: (index) => _sanitizeExtent(extentBuilder(index), safeEstimatedExtent),
      isMeasured: (_) => false,
      uniformEstimate: false,
    );
  }

  @override
  double extentOf(int index) {
    RangeError.checkValidIndex(index, _extents);
    if (_uniformEstimate && _measured[index] == 0) return _estimatedExtent;
    return _extents[index];
  }

  @override
  bool isMeasured(int index) {
    RangeError.checkValidIndex(index, _measured);
    return _measured[index] != 0;
  }

  VirtualExtentState stateOf(int index) {
    RangeError.checkValidIndex(index, _extents);
    return VirtualExtentState(extent: extentOf(index), measured: _measured[index] != 0);
  }

  @override
  double offsetOf(int index) {
    if (index <= 0) return 0.0;
    if (index >= count) return _totalExtent;
    if (_uniformEstimate) return _uniformPrefixSum(index);
    return _prefixSum(index);
  }

  bool updateExtent(int index, double extent) => updateMeasuredExtent(index, extent);

  @override
  bool updateMeasuredExtent(int index, double extent) {
    RangeError.checkValidIndex(index, _extents);
    if (!extent.isFinite || extent < 0.0) return false;
    final sanitized = extent;
    final wasMeasured = _measured[index] != 0;
    final oldEffective = wasMeasured ? _extents[index] : extentOf(index);
    final diff = sanitized - oldEffective;
    if (!wasMeasured) {
      _measured[index] = 1;
      _measuredCount++;
      _measuredExtentTotal += sanitized;
    } else {
      _measuredExtentTotal += sanitized - _extents[index];
    }
    _extents[index] = sanitized;
    if (_uniformEstimate) {
      final oldMeasuredExtent = wasMeasured ? oldEffective : 0.0;
      final measuredDiff = sanitized - oldMeasuredExtent;
      if (measuredDiff.abs() > precisionErrorTolerance) {
        _addTo(_tree, index, measuredDiff);
      }
      if (!wasMeasured) _addTo(_measuredCountTree, index, 1.0);
      _recomputeUniformTotal();
    } else {
      if (diff.abs() <= precisionErrorTolerance) return false;
      _add(index, diff);
      _totalExtent += diff;
    }
    return diff.abs() > precisionErrorTolerance;
  }

  /// 把 `[start, end)` 整段改为同一个实测值。
  ///
  /// 统一尺寸真变化时使用；单段入口复用 [updateMeasuredRanges]，避免
  /// 逐行 O(n log n) 点更新。返回更新前后的 [totalExtent] 差值。
  double updateMeasuredRange(int start, int end, double extent) {
    return updateMeasuredRanges(<({int start, int end, double extent})>[(start: start, end: end, extent: extent)]);
  }

  /// 批量把多个 `[start, end)` 段改为共享实测值，并只重建一次 Fenwick。
  ///
  /// 多个统一尺寸段在同一 layout pass 一起变化时使用；各段应互不重叠，
  /// 重叠输入按后写覆盖处理。返回更新前后的 [totalExtent] 差值；范围非法时
  /// 在任何写入之前抛错，避免原始数组已变而聚合树仍旧的半更新状态。
  @override
  double updateMeasuredRanges(Iterable<({int start, int end, double extent})> ranges) {
    final updates = ranges.toList(growable: false);
    for (final range in updates) {
      RangeError.checkValueInInterval(range.start, 0, count, 'start');
      RangeError.checkValueInInterval(range.end, range.start, count, 'end');
    }
    final oldTotal = _totalExtent;
    var changed = false;
    for (final range in updates) {
      final extent = range.extent;
      if (!extent.isFinite || extent < 0.0 || range.start == range.end) continue;
      for (var index = range.start; index < range.end; index++) {
        final old = extentOf(index);
        if (_measured[index] == 0 || (old - extent).abs() > precisionErrorTolerance) changed = true;
        _measured[index] = 1;
        _extents[index] = extent;
      }
    }
    if (!changed) return 0.0;
    _tree = Float64List(count + 1);
    _measuredCountTree = _uniformEstimate ? Float64List(count + 1) : Float64List(0);
    _rebuildAggregatesFromRaw();
    return _totalExtent - oldTotal;
  }

  /// 把一条旧实测高度退回当前估计，使内容换代后再次进入窗口时重新测量。
  @override
  bool invalidateMeasuredExtent(int index) {
    RangeError.checkValidIndex(index, _extents);
    if (_measured[index] == 0) return false;
    final oldExtent = _extents[index];
    _measured[index] = 0;
    _measuredCount--;
    _measuredExtentTotal -= oldExtent;
    _extents[index] = _estimatedExtent;
    if (_uniformEstimate) {
      _addTo(_tree, index, -oldExtent);
      _addTo(_measuredCountTree, index, -1.0);
      _recomputeUniformTotal();
    } else {
      final diff = _estimatedExtent - oldExtent;
      if (diff.abs() > precisionErrorTolerance) _add(index, diff);
      _totalExtent += diff;
    }
    return true;
  }

  bool setEstimatedExtent(double estimatedExtent, {double Function(int index)? extentBuilder}) {
    return refreshEstimatedExtents(estimatedExtent: estimatedExtent, extentBuilder: extentBuilder);
  }

  @override
  bool refreshEstimatedExtents({required double estimatedExtent, double Function(int index)? extentBuilder}) {
    final safeEstimatedExtent = _checkedDefaultExtent(estimatedExtent);
    assert(_isValidDefaultExtent(safeEstimatedExtent));
    if (extentBuilder == null) {
      final oldTotalExtent = _totalExtent;
      if (_uniformEstimate) {
        _estimatedExtent = safeEstimatedExtent;
        _recomputeUniformTotal();
      } else {
        _convertToUniformEstimate(safeEstimatedExtent);
      }
      return (oldTotalExtent - _totalExtent).abs() > precisionErrorTolerance;
    }
    if (_uniformEstimate) {
      _convertToFullEstimates(safeEstimatedExtent, extentBuilder);
      return true;
    }
    _estimatedExtent = safeEstimatedExtent;
    var changed = false;
    for (var i = 0; i < count; i++) {
      if (_measured[i] != 0) continue;
      final next = _sanitizeExtent(extentBuilder(i), safeEstimatedExtent);
      if ((next - _extents[i]).abs() <= precisionErrorTolerance) continue;
      _extents[i] = next;
      changed = true;
    }
    if (changed) _rebuildTree();
    return changed;
  }

  VirtualExtentIndex spliced({
    required int start,
    required int deleteCount,
    required int insertCount,
    required double estimatedExtent,
    double Function(int index)? extentBuilder,
  }) {
    RangeError.checkValueInInterval(start, 0, count, 'start');
    RangeError.checkValueInInterval(deleteCount, 0, count - start, 'deleteCount');
    RangeError.checkNotNegative(insertCount, 'insertCount');
    final safeEstimatedExtent = _checkedDefaultExtent(estimatedExtent);
    assert(_isValidDefaultExtent(safeEstimatedExtent));

    final next = VirtualExtentIndex(count: 0, estimatedExtent: safeEstimatedExtent);
    next._initFromSplice(
      source: this,
      start: start,
      deleteCount: deleteCount,
      insertCount: insertCount,
      estimatedExtent: safeEstimatedExtent,
      extentBuilder: extentBuilder,
    );
    return next;
  }

  /// Splice constructor body: block-copies the unchanged prefix/suffix with
  /// `setRange` instead of walking every row through resolver closures. A
  /// per-message list splice on a 100k-row chat drops from ~400k closure
  /// invocations to two memmoves plus one arithmetic aggregation pass.
  void _initFromSplice({
    required VirtualExtentIndex source,
    required int start,
    required int deleteCount,
    required int insertCount,
    required double estimatedExtent,
    required double Function(int index)? extentBuilder,
  }) {
    final nextCount = source.count - deleteCount + insertCount;
    final uniform = extentBuilder == null && estimatedExtent == source._estimatedExtent;
    _estimatedExtent = estimatedExtent;
    _uniformEstimate = uniform;
    _extents = Float64List(nextCount);
    _measured = Uint8List(nextCount);
    _tree = Float64List(nextCount + 1);
    _measuredCountTree = uniform ? Float64List(nextCount + 1) : Float64List(0);

    final oldSuffixStart = start + deleteCount;
    final newSuffixStart = start + insertCount;
    final suffixLength = source.count - oldSuffixStart;
    _extents.setRange(0, start, source._extents);
    _measured.setRange(0, start, source._measured);
    if (suffixLength > 0) {
      _extents.setRange(newSuffixStart, newSuffixStart + suffixLength, source._extents, oldSuffixStart);
      _measured.setRange(newSuffixStart, newSuffixStart + suffixLength, source._measured, oldSuffixStart);
    }

    if (!uniform) {
      // Inserted rows resolve through the builder (or flat estimate).
      for (var i = start; i < newSuffixStart; i++) {
        _extents[i] = _sanitizeExtent(extentBuilder?.call(i) ?? estimatedExtent, estimatedExtent);
      }
      // Raw slots of unmeasured rows in a uniform-estimate source are
      // placeholders; their effective extent is the source estimate, which the
      // non-uniform model reads directly from `_extents`.
      if (source._uniformEstimate) {
        final sourceEstimate = source._estimatedExtent;
        for (var i = 0; i < start; i++) {
          if (_measured[i] == 0) _extents[i] = sourceEstimate;
        }
        for (var i = newSuffixStart; i < nextCount; i++) {
          if (_measured[i] == 0) _extents[i] = sourceEstimate;
        }
      }
    }

    _rebuildAggregatesFromRaw();
  }

  /// Rebuilds trees, totals, and measured counters from `_extents`/`_measured`
  /// with pure array arithmetic (no closures, no per-row bounds helpers).
  void _rebuildAggregatesFromRaw() {
    var measuredCount = 0;
    var measuredExtentTotal = 0.0;
    if (_uniformEstimate) {
      for (var i = 0; i < count; i++) {
        if (_measured[i] == 0) continue;
        final extent = _extents[i];
        measuredCount++;
        measuredExtentTotal += extent;
        _tree[i + 1] = extent;
        _measuredCountTree[i + 1] = 1.0;
      }
      _measuredCount = measuredCount;
      _measuredExtentTotal = measuredExtentTotal;
      _recomputeUniformTotal();
      _buildTreeFromRawValues(_tree);
      _buildTreeFromRawValues(_measuredCountTree);
    } else {
      var totalExtent = 0.0;
      for (var i = 0; i < count; i++) {
        final extent = _extents[i];
        _tree[i + 1] = extent;
        totalExtent += extent;
        if (_measured[i] != 0) {
          measuredCount++;
          measuredExtentTotal += extent;
        }
      }
      _measuredCount = measuredCount;
      _measuredExtentTotal = measuredExtentTotal;
      _totalExtent = totalExtent;
      _buildTreeFromRawValues(_tree);
    }
  }

  VirtualExtentIndex remappedMeasured({
    required int count,
    required double estimatedExtent,
    required int? Function(int newIndex) oldIndexForNewIndex,
    double Function(int index)? extentBuilder,
  }) {
    RangeError.checkNotNegative(count, 'count');
    final safeEstimatedExtent = _checkedDefaultExtent(estimatedExtent);
    assert(count >= 0);
    assert(_isValidDefaultExtent(safeEstimatedExtent));
    final next = VirtualExtentIndex(count: 0, estimatedExtent: safeEstimatedExtent);
    next._resetFromExtentResolver(
      count: count,
      estimatedExtent: safeEstimatedExtent,
      resolveExtent: (newIndex) {
        final oldIndex = oldIndexForNewIndex(newIndex);
        if (oldIndex != null && oldIndex >= 0 && oldIndex < this.count) {
          return extentOf(oldIndex);
        }
        return _sanitizeExtent(extentBuilder?.call(newIndex) ?? safeEstimatedExtent, safeEstimatedExtent);
      },
      isMeasured: (newIndex) {
        final oldIndex = oldIndexForNewIndex(newIndex);
        return oldIndex != null && oldIndex >= 0 && oldIndex < this.count && _measured[oldIndex] != 0;
      },
      uniformEstimate: extentBuilder == null && safeEstimatedExtent == _estimatedExtent,
    );

    return next;
  }

  /// First item whose end is after [position].
  ///
  /// Returns [count] when [position] is at or beyond the content end.
  ///
  /// [gap] folds a fixed inter-item main-axis gap into the descent: item i's
  /// end becomes `prefix(i + 1) + i * gap`, and a position inside the gap
  /// after item i belongs to item i + 1 — the same layout-space semantics the
  /// scroll view uses, at O(log n) instead of an O(log²n) outer binary search.
  @override
  int indexAt(double position, {double gap = 0.0}) {
    if (count == 0 || position < 0.0) return 0;
    if (position >= _totalExtent + (count - 1) * gap) return count;
    return _firstPrefixGreaterThan(position, gap);
  }

  /// First item whose start is at or after [position].
  ///
  /// [gap] folds a fixed inter-item gap into the descent: item i's start
  /// becomes `prefix(i) + i * gap`.
  @override
  int firstIndexWithStartAtOrAfter(double position, {double gap = 0.0}) {
    if (count == 0 || position <= 0.0) return 0;
    if (position >= _totalExtent + (count - 1) * gap) return count;
    return _firstPrefixGreaterThanOrEqualTo(position, gap);
  }

  double _sanitizeExtent(double value, double fallback) {
    if (!value.isFinite || value < 0.0) return fallback;
    return value;
  }

  static bool _isValidDefaultExtent(double value) => value.isFinite && value >= 0.0;

  static double _checkedDefaultExtent(double value) {
    if (_isValidDefaultExtent(value)) return value;
    throw ArgumentError.value(value, 'estimatedExtent', 'must be finite and non-negative');
  }

  void _resetFromExtentResolver({
    required int count,
    required double estimatedExtent,
    required double Function(int index) resolveExtent,
    required bool Function(int index) isMeasured,
    required bool uniformEstimate,
  }) {
    _estimatedExtent = estimatedExtent;
    _extents = Float64List(count);
    _measured = Uint8List(count);
    _uniformEstimate = uniformEstimate;
    _tree = Float64List(count + 1);
    _measuredCountTree = uniformEstimate ? Float64List(count + 1) : Float64List(0);
    _totalExtent = 0.0;
    _measuredCount = 0;
    _measuredExtentTotal = 0.0;

    for (var i = 0; i < count; i++) {
      final extent = resolveExtent(i);
      final measured = isMeasured(i);
      _extents[i] = measured || !uniformEstimate ? extent : estimatedExtent;
      if (measured) {
        _measured[i] = 1;
        _measuredCount++;
        _measuredExtentTotal += extent;
        _tree[i + 1] = extent;
        if (uniformEstimate) _measuredCountTree[i + 1] = 1.0;
      } else if (!uniformEstimate) {
        _tree[i + 1] = extent;
      }
      if (!uniformEstimate) _totalExtent += extent;
    }
    if (uniformEstimate) {
      _recomputeUniformTotal();
      _buildTreeFromRawValues(_tree);
      _buildTreeFromRawValues(_measuredCountTree);
    } else {
      _buildTreeFromRawValues(_tree);
    }
  }

  void _rebuildTree() {
    _tree = Float64List(count + 1);
    _totalExtent = 0.0;
    for (var i = 0; i < count; i++) {
      final extent = _extents[i];
      _tree[i + 1] = extent;
      _totalExtent += extent;
    }
    _buildTreeFromRawValues(_tree);
  }

  void _convertToUniformEstimate(double estimatedExtent) {
    _uniformEstimate = true;
    _estimatedExtent = estimatedExtent;
    _tree = Float64List(count + 1);
    _measuredCountTree = Float64List(count + 1);
    _measuredCount = 0;
    _measuredExtentTotal = 0.0;
    for (var i = 0; i < count; i++) {
      if (_measured[i] == 0) {
        _extents[i] = estimatedExtent;
        continue;
      }
      final extent = _extents[i];
      _measuredCount++;
      _measuredExtentTotal += extent;
      _tree[i + 1] = extent;
      _measuredCountTree[i + 1] = 1.0;
    }
    _recomputeUniformTotal();
    _buildTreeFromRawValues(_tree);
    _buildTreeFromRawValues(_measuredCountTree);
  }

  void _convertToFullEstimates(double estimatedExtent, double Function(int index) extentBuilder) {
    _uniformEstimate = false;
    _estimatedExtent = estimatedExtent;
    _tree = Float64List(count + 1);
    _measuredCountTree = Float64List(0);
    _totalExtent = 0.0;
    _measuredCount = 0;
    _measuredExtentTotal = 0.0;
    for (var i = 0; i < count; i++) {
      if (_measured[i] != 0) {
        final extent = _extents[i];
        _measuredCount++;
        _measuredExtentTotal += extent;
        _tree[i + 1] = extent;
        _totalExtent += extent;
        continue;
      }
      final extent = _sanitizeExtent(extentBuilder(i), estimatedExtent);
      _extents[i] = extent;
      _tree[i + 1] = extent;
      _totalExtent += extent;
    }
    _buildTreeFromRawValues(_tree);
  }

  void _recomputeUniformTotal() {
    _totalExtent = _measuredExtentTotal + (count - _measuredCount) * _estimatedExtent;
  }

  void _buildTreeFromRawValues(Float64List tree) {
    if (count == 0) return;
    for (var treeIndex = 1; treeIndex < tree.length; treeIndex++) {
      final parent = treeIndex + (treeIndex & -treeIndex);
      if (parent < tree.length) {
        tree[parent] += tree[treeIndex];
      }
    }
  }

  void _add(int index, double delta) {
    _addTo(_tree, index, delta);
  }

  void _addTo(Float64List tree, int index, double delta) {
    var treeIndex = index + 1;
    while (treeIndex < tree.length) {
      tree[treeIndex] += delta;
      treeIndex += treeIndex & -treeIndex;
    }
  }

  double _prefixSum(int length) {
    var treeIndex = math.min(length, count);
    var result = 0.0;
    while (treeIndex > 0) {
      result += _tree[treeIndex];
      treeIndex -= treeIndex & -treeIndex;
    }
    return result;
  }

  double _prefixSumIn(Float64List tree, int length) {
    var treeIndex = math.min(length, count);
    var result = 0.0;
    while (treeIndex > 0) {
      result += tree[treeIndex];
      treeIndex -= treeIndex & -treeIndex;
    }
    return result;
  }

  double _uniformPrefixSum(int length) {
    final safeLength = math.min(length, count);
    final measuredExtent = _prefixSumIn(_tree, safeLength);
    final measuredCount = _prefixSumIn(_measuredCountTree, safeLength);
    return measuredExtent + (safeLength - measuredCount) * _estimatedExtent;
  }

  // Gap accounting inside the descents: the gap contribution is linear in the
  // probed boundary, so it never enters the accumulated extent sums — it is
  // recomputed from `next` at each probe. Strict (end-of-item) queries test
  // item next-1's end → (next - 1) * gap; start-of-item queries test item
  // next's start → next * gap.

  int _firstPrefixGreaterThan(double position, double gap) {
    if (_uniformEstimate) return _firstUniformPrefix(position, gap, strict: true);
    var index = 0;
    var bit = _highestPowerOfTwoAtMost(count);
    var sum = 0.0;

    // Same float tolerance as the uniform descent so boundary queries agree
    // across estimate-mode conversions.
    while (bit != 0) {
      final next = index + bit;
      if (next <= count && sum + _tree[next] + (next - 1) * gap <= position + precisionErrorTolerance) {
        index = next;
        sum += _tree[next];
      }
      bit >>= 1;
    }

    return index.clamp(0, count).toInt();
  }

  int _firstPrefixGreaterThanOrEqualTo(double position, double gap) {
    if (_uniformEstimate) return _firstUniformPrefix(position, gap, strict: false);
    var index = 0;
    var bit = _highestPowerOfTwoAtMost(count);
    var sum = 0.0;

    while (bit != 0) {
      final next = index + bit;
      if (next <= count && sum + _tree[next] + next * gap < position - precisionErrorTolerance) {
        index = next;
        sum += _tree[next];
      }
      bit >>= 1;
    }

    return (index + 1).clamp(0, count).toInt();
  }

  int _firstUniformPrefix(double position, double gap, {required bool strict}) {
    var index = 0;
    var bit = _highestPowerOfTwoAtMost(count);
    var measuredExtentSum = 0.0;
    var measuredCountSum = 0.0;

    while (bit != 0) {
      final next = index + bit;
      if (next <= count) {
        final nextMeasuredExtent = measuredExtentSum + _tree[next];
        final nextMeasuredCount = measuredCountSum + _measuredCountTree[next];
        final gapCount = strict ? next - 1 : next;
        final nextPrefix = nextMeasuredExtent + (next - nextMeasuredCount) * _estimatedExtent + gapCount * gap;
        final beforeTarget = strict
            ? nextPrefix <= position + precisionErrorTolerance
            : nextPrefix < position - precisionErrorTolerance;
        if (beforeTarget) {
          index = next;
          measuredExtentSum = nextMeasuredExtent;
          measuredCountSum = nextMeasuredCount;
        }
      }
      bit >>= 1;
    }

    return (strict ? index : index + 1).clamp(0, count).toInt();
  }

  int _highestPowerOfTwoAtMost(int value) {
    var result = 1;
    while ((result << 1) <= value) {
      result <<= 1;
    }
    return result;
  }
}
