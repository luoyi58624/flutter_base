import 'package:flutter/foundation.dart' show internal;

/// 仅由 assert 分支写入的内核工作量探针，不参与生产模式调度。
@internal
abstract final class RecyclerWorkProbe {
  /// 完整可见窗口布局次数。
  static int fullLayouts = 0;

  /// 仅更新既有条目偏移的次数。
  static int translatedLayouts = 0;

  /// 进入条目准备和布局检查的次数，包含预算拒绝的尝试。
  static int itemLayoutVisits = 0;

  /// 高度索引前缀查询次数。
  static int prefixQueries = 0;

  /// 网格分组和行高类型索引的重建次数，不应随普通滚动递增。
  static int gridGeometryBuilds = 0;

  /// 布局入口的同步墙钟微秒，不包含后续独立绘制和测试 pump 调度。
  static int layoutMicroseconds = 0;

  /// 读取当前计数，放在计时区间外使用。
  static Map<String, int> snapshot() => {
    'full_layouts': fullLayouts,
    'translated_layouts': translatedLayouts,
    'item_layout_visits': itemLayoutVisits,
    'prefix_queries': prefixQueries,
    'grid_geometry_builds': gridGeometryBuilds,
    'layout_microseconds': layoutMicroseconds,
  };

  /// 清空不同场景之间的计数。
  static void reset() {
    fullLayouts = translatedLayouts = itemLayoutVisits = prefixQueries = gridGeometryBuilds = layoutMicroseconds = 0;
  }
}
