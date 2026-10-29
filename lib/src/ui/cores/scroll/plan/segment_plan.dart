import 'dart:typed_data';

import '../../layout/geometry/extent_index.dart';
import '../../layout/geometry/grid_geometry.dart';
import '../spec/segment_spec.dart';

/// 段计划（计划 §3.4）：item ↔ 行 ↔ 交叉轴几何的纯换算层，泛化自
/// 旧 `virtual_section_plan.dart` 的行(band)模型——static/linear 段一行一
/// item、grid 段一行 N item。无渲染副作用，供 State 与 content render 共用。
///
/// 间距模型：段与段之间恒 [outerGap]（`ElScrollView.gap`）；只有 grid 段
/// 使用自身 [GridSegment.mainAxisSpacing]。**间距不进度量模型（Fenwick）**——
/// 保住 render 锚点「模型 extent == 实测纯行高」比较，偏移在本层叠加。
final class SegmentPlan {
  /// 由段序列构建计划。[crossAxisExtent] 是交叉轴可用宽（grid 列数/行高
  /// 派生输入；首帧未知传 0，maxCrossAxisExtent 段兜底 1 列）。
  SegmentPlan(this.segments, {required this.outerGap, required this.crossAxisExtent})
    : assert(outerGap >= 0.0),
      assert(crossAxisExtent >= 0.0) {
    final length = segments.length;
    _columns = Int32List(length);
    _itemStart = Int32List(length + 1);
    _rowStart = Int32List(length + 1);
    _grids = List<ResolvedGridGeometry?>.filled(length, null);
    var items = 0;
    var rows = 0;
    var allStatic = true;
    var anyFixed = false;
    for (var s = 0; s < length; s++) {
      final segment = segments[s];
      final grid = segment is GridSegment ? segment.resolve(crossAxisExtent) : null;
      _grids[s] = grid;
      final columns = grid?.trackCount ?? 1;
      _columns[s] = columns;
      _itemStart[s] = items;
      _rowStart[s] = rows;
      items += segment.itemCount;
      rows += _rowCountOf(segment, columns);
      if (segment is! StaticSegment) allStatic = false;
      if (segment is LinearSegment && segment.fixed != null) anyFixed = true;
    }
    _itemStart[length] = items;
    _rowStart[length] = rows;
    totalItemCount = items;
    totalRowCount = rows;
    isAllStatic = allStatic;
    isAllResident = segments.every((segment) => segment.resident);
    hasFixed = anyFixed;
    // 快路径预计算：无 grid 段时行=item 全局成立（每段行数==item 数 →
    // 前缀和相同），rowOfItem/firstItemOfRow 退化为 identity——滚动热路径
    // （每行每帧的模型定位）从二分降回纯算术。
    var rowPerItem = true;
    _cumSpacingAtRowStart = Float64List(length + 1);
    var cum = 0.0;
    var seenFlowSegment = false;
    for (var s = 0; s < length; s++) {
      final segment = segments[s];
      if (segment is GridSegment) rowPerItem = false;
      final rows = _rowStart[s + 1] - _rowStart[s];
      // fixed 散 child 行对间距透明（脱离滚动流：前后成员之间保持单个
      // gap，行自身零间距贡献）。
      final isFlow = rows > 0 && !(segment is StaticSegment && segment.isFixedDeclaration);
      // gap 前缀化：非首个 flow 段在自己之前加段间距——fixed 段穿插任意
      // 位置（含末位）都不会多出一段悬空 gap（对齐旧视口基座口径）。
      if (isFlow && seenFlowSegment) cum += outerGap;
      _cumSpacingAtRowStart[s] = cum;
      if (isFlow) {
        seenFlowSegment = true;
        _lastFlowSegment = s;
        if (rows > 1) cum += (rows - 1) * internalGapOf(s);
      }
    }
    _cumSpacingAtRowStart[length] = cum;
    isRowPerItem = rowPerItem;
  }

  /// 直接成员切换 flow/positioned 后原位刷新间距前缀，保持段和索引身份。
  void refreshPositionedSpacing() {
    var cumulative = 0.0;
    var seenFlow = false;
    _lastFlowSegment = -1;
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final rows = _rowStart[index + 1] - _rowStart[index];
      final flow = rows > 0 && !(segment is StaticSegment && segment.isFixedDeclaration);
      if (flow && seenFlow) cumulative += outerGap;
      _cumSpacingAtRowStart[index] = cumulative;
      if (flow) {
        seenFlow = true;
        _lastFlowSegment = index;
        if (rows > 1) cumulative += (rows - 1) * internalGapOf(index);
      }
    }
    _cumSpacingAtRowStart[segments.length] = cumulative;
  }

  /// 段序列（解构产物，见 segment_resolver）。
  final List<SegmentSpec> segments;

  /// 段与段之间的主轴间距（`ElScrollView.gap`）。
  final double outerGap;

  /// 交叉轴可用宽。
  final double crossAxisExtent;

  /// 扁平 item 总数（滚动体系对外的唯一 index 空间）。
  late final int totalItemCount;

  /// 全局行总数（Fenwick 的 count）。
  late final int totalRowCount;

  /// 全部段皆散 child：简单管线快路径判据（无 virtual 段 → 走一次性布局）。
  late final bool isAllStatic;

  /// 所有条目常驻时滚动只更新呈现，不重排布局。
  late final bool isAllResident;

  /// 是否存在按首条真实数据测量尺寸的列表段。
  late final bool hasFixed;

  /// 无 grid 段（行=item 全局 identity）：坐标热路径快判据。
  late final bool isRowPerItem;

  late final List<ResolvedGridGeometry?> _grids;
  late final Int32List _columns;
  late final Int32List _itemStart;
  late final Int32List _rowStart;

  /// 每段行起点处的累计间距（构造期预计算；查询 = 定段 + 段内乘法）。
  late final Float64List _cumSpacingAtRowStart;

  /// 最后一个 flow 段（有行且非 fixed 声明）的段号；-1 = 无 flow 段。
  /// 段尾间距判定用：其后再无 flow 段 → 无段间距（fixed 段透明）。
  int _lastFlowSegment = -1;

  static int _rowCountOf(SegmentSpec segment, int columns) {
    final count = segment.itemCount;
    if (count == 0) return 0;
    if (segment is GridSegment) return (count + columns - 1) ~/ columns;
    return count;
  }

  /// 已解析网格几何，非网格段为空。
  ResolvedGridGeometry? gridAt(int segmentIndex) => _grids[segmentIndex];

  /// 段的全局 item 起点。
  int itemStartOf(int segmentIndex) => _itemStart[segmentIndex];

  /// 段的全局行起点。
  int rowStartOf(int segmentIndex) => _rowStart[segmentIndex];

  /// 段的行数。
  int rowCountOf(int segmentIndex) => _rowStart[segmentIndex + 1] - _rowStart[segmentIndex];

  /// 当前段之前的间距前缀，空段也保留正确的段边界。
  double spacingBeforeSegment(int segmentIndex) => _cumSpacingAtRowStart[segmentIndex];

  /// 段的解析列数（grid 段为按 [crossAxisExtent] 解析后的列数，其余恒 1）。
  int columnsOf(int segmentIndex) => _columns[segmentIndex];

  /// 二分定位 item 所属段。
  int segmentOfItem(int item) => _binarySearch(_itemStart, item);

  /// 二分定位 row 所属段。
  int segmentOfRow(int row) => _binarySearch(_rowStart, row);

  int _binarySearch(Int32List starts, int value) {
    var lo = 0;
    var hi = segments.length;
    while (lo + 1 < hi) {
      final mid = (lo + hi) >> 1;
      if (starts[mid] <= value) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// 全局 item index → 全局行号。
  int rowOfItem(int item) {
    if (isRowPerItem) return item;
    final s = segmentOfItem(item);
    final local = item - _itemStart[s];
    final localRow = segments[s] is GridSegment ? local ~/ _columns[s] : local;
    return _rowStart[s] + localRow;
  }

  /// 全局 item index → 行内列号（0-based；非 grid 恒 0）。
  int columnOfItem(int item) {
    if (isRowPerItem) return 0;
    final s = segmentOfItem(item);
    return segments[s] is GridSegment ? (item - _itemStart[s]) % _columns[s] : 0;
  }

  /// 全局行号 → 该行首个 item 的全局 index。
  int firstItemOfRow(int row) {
    if (isRowPerItem) return row;
    final s = segmentOfRow(row);
    final localRow = row - _rowStart[s];
    final columns = segments[s] is GridSegment ? _columns[s] : 1;
    return _itemStart[s] + localRow * columns;
  }

  /// 全局行号 → 该行 item 数（grid 末行可能不满列）。
  int itemsInRow(int row) {
    final s = segmentOfRow(row);
    final segment = segments[s];
    if (segment is! GridSegment) return 1;
    final columns = _columns[s];
    final localRow = row - _rowStart[s];
    final remaining = segment.itemCount - localRow * columns;
    return remaining < columns ? remaining : columns;
  }

  /// 全局行号的固定行高；null = 需实测/估算。linear 段取首条实测的统一尺寸
  /// 当前值，grid 段按几何派生，static 段恒实测。
  double? fixedExtentOfRow(int row) {
    final s = segmentOfRow(row);
    final segment = segments[s];
    return switch (segment) {
      GridSegment() => _grids[s]!.cellMainExtent,
      LinearSegment() => segment.fixedExtentAt(row - _rowStart[s]),
      // fixed 声明脱离滚动流：行高恒 0（种子即终值，估算永不掺入）。
      StaticSegment() => segment.isFixedDeclaration ? 0.0 : null,
    };
  }

  /// 段内相邻行的主轴间距。
  double internalGapOf(int segmentIndex) {
    return switch (segments[segmentIndex]) {
      LinearSegment(:final geometry) => geometry.gap,
      GridSegment(:final mainAxisSpacing) => mainAxisSpacing,
      StaticSegment() => 0.0,
    };
  }

  /// 全局行号后继的主轴间距：段内行间用段自身间距，段与段边界（本段末行）
  /// 用 [outerGap]，全内容最末行后继为 0。
  double spacingAfterRow(int row) {
    if (row < 0 || row >= totalRowCount) return 0.0;
    final s = segmentOfRow(row);
    final segment = segments[s];
    if (segment is StaticSegment && segment.isFixedDeclaration) return 0.0;
    final isLastRowOfSegment = row == _rowStart[s + 1] - 1;
    if (!isLastRowOfSegment) return internalGapOf(s);
    // 段尾边界：其后还有 flow 段才有段间距（fixed 段透明，末 flow 段之后
    // 不产生悬空 gap——与构造期前缀化记账一致）。
    return s < _lastFlowSegment ? outerGap : 0.0;
  }

  /// 全局行 [row] 之前累计的主轴间距总和。预计算表 + 段内乘法：单段时
  /// 二分深度 0，热路径接近纯算术。
  double cumulativeSpacingBeforeRow(int row) {
    if (row <= 0) return 0.0;
    if (row >= totalRowCount) return _cumSpacingAtRowStart.last;
    final s = segmentOfRow(row);
    return _cumSpacingAtRowStart[s] + (row - _rowStart[s]) * internalGapOf(s);
  }

  /// 全部行间距总和（totalExtent 用）。
  double totalSpacing() => totalRowCount <= 1 ? 0.0 : cumulativeSpacingBeforeRow(totalRowCount - 1);

  /// 把 layout-space 的 content 偏移（已去 padding，含行间距）折回「纯行高
  /// 空间」（Fenwick 记账空间，无间距）。O(段数 + log 段行数)，绝不逐行。
  /// 命中行内容区 → 减去累计间距；落在行/段间的间距缝里 → 钉到缝前那一行
  /// 行尾，保证外层 `indexAt(gap: 0)` 命中该行而非误进下一行。
  double contentOffsetToRowSpace(double content, LayoutExtentIndex extentIndex) {
    if (content <= 0) return 0.0;
    var spacingBefore = 0.0;
    var seenFlowSegment = false;
    for (var s = 0; s < segments.length; s++) {
      final segment = segments[s];
      final segRowStart = _rowStart[s];
      final segRowEnd = _rowStart[s + 1];
      final segRows = segRowEnd - segRowStart;
      if (segRows == 0) continue;
      // fixed 段脱离滚动流：零高零间距，layout-space 折算完全透明。
      if (segment is StaticSegment && segment.isFixedDeclaration) continue;
      final segFenwickStart = extentIndex.offsetOf(segRowStart);
      // gap 前缀化：flow 段边界缝在段前。落在缝里 → 钉到前一 flow 段末行
      // 行尾（Fenwick 连续，中间 fixed 行零高，即本段纯行高起点）。
      if (seenFlowSegment) {
        if (content < segFenwickStart + spacingBefore + outerGap) {
          return segFenwickStart;
        }
        spacingBefore += outerGap;
      }
      seenFlowSegment = true;
      final segRowSpacing = internalGapOf(s);
      final segInternalSpacing = (segRows - 1) * segRowSpacing;
      final segPureHeight = extentIndex.offsetOf(segRowEnd) - segFenwickStart;
      final segLayoutStart = segFenwickStart + spacingBefore;
      final segLayoutEnd = segLayoutStart + segPureHeight + segInternalSpacing;
      if (content < segLayoutEnd) {
        // 命中此段：段内二分定位 local 行（段内间距均匀 = segRowSpacing）。
        final localLayout = content - segLayoutStart;
        var lo = 0;
        var hi = segRows;
        while (lo + 1 < hi) {
          final mid = (lo + hi) >> 1;
          final midStart = (extentIndex.offsetOf(segRowStart + mid) - segFenwickStart) + mid * segRowSpacing;
          if (midStart <= localLayout) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        final loGlobalRow = segRowStart + lo;
        final loRowPureEnd = extentIndex.offsetOf(loGlobalRow) + extentIndex.extentOf(loGlobalRow);
        final folded = content - spacingBefore - lo * segRowSpacing;
        return folded > loRowPureEnd ? loRowPureEnd : folded;
      }
      spacingBefore += segInternalSpacing;
    }
    return extentIndex.totalExtent;
  }

  /// 交叉轴几何：给定全局 item，返回该 cell 的 (leading 偏移, 宽度)。
  /// 非 grid 段铺满可用宽（P0 交叉轴口径：loose 约束、起点 0）。
  ({double cross, double extent}) cellCrossGeometry(int item) {
    final s = segmentOfItem(item);
    final segment = segments[s];
    if (segment is! GridSegment) return (cross: 0.0, extent: crossAxisExtent);
    final columns = _columns[s];
    final column = (item - _itemStart[s]) % columns;
    final cellExtent = _grids[s]!.cellCrossExtent;
    return (cross: column * (cellExtent + segment.crossAxisSpacing), extent: cellExtent < 0.0 ? 0.0 : cellExtent);
  }
}
