import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../layout/geometry/extent_index.dart';
import '../../layout/geometry/list_geometry.dart';
import '../spec/segment_spec.dart';
import '../virtual/virtual_extent_index.dart';
import 'segment_diff.dart';
import 'segment_plan.dart';

/// 按布局段分配的尺寸索引，固定 Grid/List 只保存算术参数。
final class SegmentExtentIndex implements LayoutExtentIndex {
  /// 创建完整段索引；只有变尺寸段分配逐行前缀数组。
  SegmentExtentIndex(this.plan, {double? estimatedExtent})
    : _estimatedExtent = estimatedExtent ?? 0,
      _hasEstimate = estimatedExtent != null {
    _records = [for (var i = 0; i < plan.segments.length; i++) _ExtentRecord(plan, i, _estimatedExtent)];
    _rebuildTotals();
  }

  SegmentExtentIndex._pending(this.plan, this._estimatedExtent, this._hasEstimate) {
    _records = [
      for (var i = 0; i < plan.segments.length; i++) _ExtentRecord(plan, i, estimatedExtent, allocate: false),
    ];
  }

  /// 当前段计划。
  final SegmentPlan plan;
  late List<_ExtentRecord> _records;
  late VirtualExtentIndex _totals;
  double _estimatedExtent;
  bool _hasEstimate;

  /// 是否已有实测样本产生的估算；未知尺寸的零占位不能用于选取挂载窗口。
  bool get hasEstimate => _hasEstimate;
  int _measuredCount = 0;
  double _measuredTotal = 0;
  int _variableMeasuredCount = 0;
  double _variableMeasuredTotal = 0;

  void _rebuildTotals() {
    _totals = VirtualExtentIndex(
      count: _records.length,
      estimatedExtent: _estimatedExtent,
      extentBuilder: (index) => _records[index].totalExtent,
    );
    _measuredCount = 0;
    _measuredTotal = 0;
    _variableMeasuredCount = 0;
    _variableMeasuredTotal = 0;
    for (final record in _records) {
      _measuredCount += record.measuredCount;
      _measuredTotal += record.measuredTotal;
      if (record.isVariable) {
        _variableMeasuredCount += record.measuredCount;
        _variableMeasuredTotal += record.measuredTotal;
      }
    }
  }

  void _changed(int section, int oldCount, double oldMeasured) {
    final record = _records[section];
    _totals.updateMeasuredExtent(section, record.totalExtent);
    _measuredCount += record.measuredCount - oldCount;
    _measuredTotal += record.measuredTotal - oldMeasured;
    if (record.isVariable) {
      _variableMeasuredCount += record.measuredCount - oldCount;
      _variableMeasuredTotal += record.measuredTotal - oldMeasured;
    }
  }

  /// 固定段的测量结果一次发布，不展开成逐行写入。
  double updateFixedSizes(int section, {double? itemExtent, double? separatorExtent}) {
    final record = _records[section];
    assert(record.variable == null);
    final before = totalExtent;
    final oldCount = record.measuredCount;
    final oldMeasured = record.measuredTotal;
    if (itemExtent != null) {
      record.itemExtent = itemExtent;
      record.itemKnown = true;
    }
    if (separatorExtent != null) {
      record.separatorExtent = separatorExtent;
      record.separatorKnown = true;
    }
    _changed(section, oldCount, oldMeasured);
    return totalExtent - before;
  }

  /// 结构更新按段保留尺寸；固定段的追加和重排不遍历业务条目。
  SegmentExtentIndex reconfigured(SegmentPlan nextPlan, {Map<int, Map<int, int>> keyedRows = const {}}) {
    final next = SegmentExtentIndex._pending(nextPlan, estimatedExtent, hasEstimate);
    final diff = SegmentListDiff.compute(plan.segments, nextPlan.segments);
    for (final pairing in diff.pairings) {
      final oldSection = pairing.oldIndex;
      final newSection = pairing.newIndex;
      if (oldSection == null || newSection == null || pairing.change is SegmentRebuilt) continue;
      final old = _records[oldSection];
      final target = next._records[newSection];
      if (old.variable == null || !target.isVariable) continue;
      final change = pairing.change;
      if (change is SegmentUnchanged) {
        target.variable = old.variable;
      } else if (change is SegmentItemsSpliced) {
        final keyed = keyedRows[newSection];
        if (keyed != null || change.oldLocalForNewLocal != null) {
          target.variable = old.variable!.remappedMeasured(
            count: target.count,
            estimatedExtent: estimatedExtent,
            oldIndexForNewIndex: (index) {
              if (keyed != null) {
                final row = keyed[nextPlan.rowStartOf(newSection) + index];
                return row == null ? null : row - plan.rowStartOf(oldSection);
              }
              if (index < change.localStart) return index;
              if (index < change.localStart + change.insertCount) return change.oldLocalForNewLocal![index];
              return index - change.insertCount + change.deleteCount;
            },
          );
        } else {
          target.variable = old.variable!.spliced(
            start: change.localStart,
            deleteCount: change.deleteCount,
            insertCount: change.insertCount,
            estimatedExtent: estimatedExtent,
          );
        }
      }
    }
    for (final record in next._records) {
      if (record.isVariable) {
        record.variable ??= VirtualExtentIndex(count: record.count, estimatedExtent: estimatedExtent);
      }
    }
    next._rebuildTotals();
    // 全零样本不能推断后来新增的内容；重新实测可避免零总长令新行永远无法进入窗口。
    if (next.estimatedExtent == 0 && next.measuredCount < next.count) next._hasEstimate = false;
    return next;
  }

  @override
  int get count => plan.totalRowCount;
  @override
  double get estimatedExtent => _estimatedExtent;
  @override
  double get totalExtent => _totals.totalExtent;
  @override
  int get measuredCount => _measuredCount;
  @override
  double get measuredExtentTotal => _measuredTotal;
  @override
  double? get measuredExtentAverage =>
      _variableMeasuredCount == 0 ? null : _variableMeasuredTotal / _variableMeasuredCount;

  /// 测试用：尺寸数组槽数量，固定段不应随 itemCount 增长。
  int get debugStorageSlotCount =>
      _totals.debugStorageSlotCount +
      _records.fold(0, (sum, record) => sum + (record.variable?.debugStorageSlotCount ?? 0));

  @override
  double extentOf(int index) {
    RangeError.checkValueInInterval(index, 0, count - 1, 'index');
    final section = plan.segmentOfRow(index);
    return _records[section].extentOf(index - plan.rowStartOf(section));
  }

  @override
  bool isMeasured(int index) {
    RangeError.checkValueInInterval(index, 0, count - 1, 'index');
    final section = plan.segmentOfRow(index);
    return _records[section].isMeasured(index - plan.rowStartOf(section));
  }

  @override
  double offsetOf(int index) {
    if (index <= 0) return 0;
    if (index >= count) return totalExtent;
    final section = plan.segmentOfRow(index);
    return _totals.offsetOf(section) + _records[section].offsetOf(index - plan.rowStartOf(section));
  }

  @override
  bool updateMeasuredExtent(int index, double extent) {
    if (!extent.isFinite || extent < 0) return false;
    final section = plan.segmentOfRow(index);
    final record = _records[section];
    if (record.variable == null) return false;
    final oldCount = record.measuredCount;
    final oldMeasured = record.measuredTotal;
    final changed = record.variable!.updateMeasuredExtent(index - plan.rowStartOf(section), extent);
    _changed(section, oldCount, oldMeasured);
    return changed;
  }

  @override
  double updateMeasuredRanges(Iterable<({int start, int end, double extent})> ranges) {
    final before = totalExtent;
    final updates = ranges.toList(growable: false);
    for (final range in updates) {
      RangeError.checkValueInInterval(range.start, 0, count, 'start');
      RangeError.checkValueInInterval(range.end, range.start, count, 'end');
    }
    for (final range in updates) {
      var row = range.start;
      while (row < range.end) {
        final section = plan.segmentOfRow(row);
        final record = _records[section];
        final start = plan.rowStartOf(section);
        final end = math.min(range.end, start + record.count);
        final oldCount = record.measuredCount;
        final oldMeasured = record.measuredTotal;
        record.variable?.updateMeasuredRange(row - start, end - start, range.extent);
        _changed(section, oldCount, oldMeasured);
        row = end;
      }
    }
    return totalExtent - before;
  }

  @override
  bool invalidateMeasuredExtent(int index) {
    final section = plan.segmentOfRow(index);
    final record = _records[section];
    if (record.variable == null) return false;
    final oldCount = record.measuredCount;
    final oldMeasured = record.measuredTotal;
    final changed = record.variable!.invalidateMeasuredExtent(index - plan.rowStartOf(section));
    _changed(section, oldCount, oldMeasured);
    return changed;
  }

  @override
  bool refreshEstimatedExtents({required double estimatedExtent, double Function(int index)? extentBuilder}) {
    _hasEstimate = true;
    _estimatedExtent = estimatedExtent;
    var changed = false;
    for (var i = 0; i < _records.length; i++) {
      final record = _records[i];
      final before = record.totalExtent;
      final oldCount = record.measuredCount;
      final oldMeasured = record.measuredTotal;
      if (record.variable != null) {
        record.variable!.refreshEstimatedExtents(estimatedExtent: estimatedExtent);
      } else {
        if (!record.itemKnown) record.itemExtent = estimatedExtent;
        if (!record.separatorKnown) record.separatorExtent = estimatedExtent;
      }
      _changed(i, oldCount, oldMeasured);
      changed = changed || (before - record.totalExtent).abs() > precisionErrorTolerance;
    }
    return changed;
  }

  /// 含段间距的内容位置直接定位行，固定段只做除法，变尺寸段只下降一次前缀树。
  int rowAtContentOffset(double position, {bool startAtOrAfter = false}) {
    if (count == 0 || position < 0 || startAtOrAfter && position == 0) return 0;
    if (position >= totalExtent + plan.totalSpacing()) return count;
    var low = 0;
    var high = _records.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      final record = _records[middle];
      final end =
          _totals.offsetOf(middle) +
          plan.spacingBeforeSegment(middle) +
          record.totalExtent +
          math.max(0, record.count - 1) * plan.internalGapOf(middle);
      if (startAtOrAfter ? end < position - precisionErrorTolerance : end <= position + precisionErrorTolerance) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    if (low == _records.length) return count;
    final start = plan.rowStartOf(low);
    final local = position - _totals.offsetOf(low) - plan.spacingBeforeSegment(low);
    final gap = plan.internalGapOf(low);
    return start + (startAtOrAfter ? _records[low].firstStartAt(local, gap) : _records[low].indexAt(local, gap));
  }

  int _sectionAt(double position, double gap) {
    if (gap == 0) return _totals.indexAt(position);
    var low = 0;
    var high = _records.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      final endRow = plan.rowStartOf(middle) + _records[middle].count;
      final end = _totals.offsetOf(middle + 1) + endRow * gap;
      if (end <= position) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  @override
  int indexAt(double position, {double gap = 0}) {
    if (count == 0 || position < 0) return 0;
    if (position >= totalExtent + (count - 1) * gap) return count;
    final section = _sectionAt(position, gap);
    if (section >= _records.length) return count;
    final start = plan.rowStartOf(section);
    final index = _records[section].indexAt(position - _totals.offsetOf(section) - start * gap, gap);
    return (start + index).clamp(0, count);
  }

  @override
  int firstIndexWithStartAtOrAfter(double position, {double gap = 0}) {
    if (position <= 0 || count == 0) return 0;
    if (position >= totalExtent + (count - 1) * gap) return count;
    if (_records.length == 1) return _records.single.firstStartAt(position, gap);
    if (gap == 0) {
      final after = _totals.firstIndexWithStartAtOrAfter(position);
      final section = math.max(0, after - 1);
      return plan.rowStartOf(section) + _records[section].firstStartAt(position - _totals.offsetOf(section), gap);
    }
    final section = _sectionAt(position, gap);
    if (section >= _records.length) return count;
    final start = plan.rowStartOf(section);
    return start + _records[section].firstStartAt(position - _totals.offsetOf(section) - start * gap, gap);
  }
}

final class _ExtentRecord {
  _ExtentRecord(SegmentPlan plan, int section, double estimate, {bool allocate = true})
    : count = plan.rowCountOf(section) {
    final segment = plan.segments[section];
    if (segment is GridSegment) {
      itemExtent = plan.gridAt(section)!.cellMainExtent;
      itemKnown = true;
    } else if (segment is LinearSegment && segment.fixed != null) {
      final fixed = segment.fixed!;
      stride = fixed.itemStride;
      itemExtent = fixed.extent ?? estimate;
      itemKnown = fixed.extent != null;
      separatorExtent = fixed.separatorExtent ?? estimate;
      separatorKnown = fixed.separatorExtent != null;
    } else {
      isVariable = true;
      if (allocate) {
        variable = VirtualExtentIndex(count: count, estimatedExtent: estimate);
        if (segment is StaticSegment && segment.isFixedDeclaration) variable!.updateMeasuredExtent(0, 0);
      }
    }
  }

  final int count;
  VirtualExtentIndex? variable;
  bool isVariable = false;
  int stride = 1;
  FixedListGeometry? _fixed;
  FixedListGeometry get fixed =>
      _fixed ??= FixedListGeometry(count, itemExtent, separatorExtent: separatorExtent, stride: stride);
  double _itemExtent = 0;
  double get itemExtent => _itemExtent;
  set itemExtent(double value) {
    _itemExtent = value;
    _fixed = null;
  }

  double _separatorExtent = 0;
  double get separatorExtent => _separatorExtent;
  set separatorExtent(double value) {
    _separatorExtent = value;
    _fixed = null;
  }

  bool itemKnown = false;
  bool separatorKnown = false;
  int get itemCount => stride == 1 ? count : (count + 1) ~/ 2;
  int get separatorCount => stride == 1 ? 0 : count ~/ 2;
  double get totalExtent => variable?.totalExtent ?? fixed.totalExtent;
  int get measuredCount =>
      variable?.measuredCount ?? (itemKnown ? itemCount : 0) + (separatorKnown ? separatorCount : 0);
  double get measuredTotal =>
      variable?.measuredExtentTotal ??
      (itemKnown ? itemCount * itemExtent : 0) + (separatorKnown ? separatorCount * separatorExtent : 0);
  double extentOf(int index) => variable?.extentOf(index) ?? fixed.extentOf(index);
  bool isMeasured(int index) =>
      variable?.isMeasured(index) ?? (stride == 2 && index.isOdd ? separatorKnown : itemKnown);
  double offsetOf(int index) => variable?.offsetOf(index) ?? fixed.offsetOf(index);

  int indexAt(double position, double gap) => variable?.indexAt(position, gap: gap) ?? fixed.indexAt(position, gap);

  int firstStartAt(double position, double gap) {
    if (variable != null) {
      // 全局段尾可能仍接着下一段，零尺寸尾行不能被局部的内容终点守卫跳过。
      if (position > 0 && count > 0 && position >= variable!.totalExtent + (count - 1) * gap) {
        var low = 0;
        var high = count;
        while (low < high) {
          final middle = low + ((high - low) >> 1);
          if (variable!.offsetOf(middle) + middle * gap < position - precisionErrorTolerance) {
            low = middle + 1;
          } else {
            high = middle;
          }
        }
        return low;
      }
      return variable!.firstIndexWithStartAtOrAfter(position, gap: gap);
    }
    return fixed.firstStartAt(position, gap);
  }
}
