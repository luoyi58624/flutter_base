/// 布局位置索引协议；固定几何与变尺寸实现共享同一查询口径。
abstract interface class LayoutExtentIndex {
  /// 条目或带的数量。
  int get count;

  /// 尚未测量的变尺寸行的估计值。
  double get estimatedExtent;

  /// 当前完整尺寸，不包含段外间距。
  double get totalExtent;

  /// 已有精确尺寸的行数，包含算术确定的固定行。
  int get measuredCount;

  /// 精确行的尺寸总和。
  double get measuredExtentTotal;

  /// 精确行的平均尺寸。
  double? get measuredExtentAverage;

  /// 返回一行的当前尺寸。
  double extentOf(int index);

  /// 当前行是否已有精确尺寸。
  bool isMeasured(int index);

  /// 返回 index 之前的尺寸和。
  double offsetOf(int index);

  /// 用实际尺寸更新一行，返回总尺寸是否变化。
  bool updateMeasuredExtent(int index, double extent);

  /// 批量更新范围，用于纯变尺寸索引。
  double updateMeasuredRanges(Iterable<({int start, int end, double extent})> ranges);

  /// 使一条真实测量失效。
  bool invalidateMeasuredExtent(int index);

  /// 刷新未测行的估计值。
  bool refreshEstimatedExtents({required double estimatedExtent, double Function(int index)? extentBuilder});

  /// 查找末端超过 position 的第一行。
  int indexAt(double position, {double gap = 0});

  /// 查找起点不早于 position 的第一行。
  int firstIndexWithStartAtOrAfter(double position, {double gap = 0});
}
