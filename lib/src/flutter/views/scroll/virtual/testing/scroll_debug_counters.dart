// 滚动管线的白盒调试计数器，只承载现有测试观测面。
// ignore_for_file: prefer_initializing_formals

part of '../virtual_pipeline.dart';

// Debug 自动观测；profile/release 基准须显式传 --dart-define=EL_UI_SCROLL_DEBUG_COUNTERS=true。
const bool _scrollDebugCountersEnabled = kDebugMode || bool.fromEnvironment('EL_UI_SCROLL_DEBUG_COUNTERS');

/// 滚动管线的真实观测计数，仅在 debug 或显式启用编译期观测时分配。
class ElVirtualScrollDebugCounters {
  /// 真实布局遍历的业务条目数量；稳态常驻段应整段跳过。
  int debugLayoutChildVisitCount = 0;

  /// 绘制候选访问量，固定几何必须只访问可见窗口。
  int debugPaintCandidateVisitCount = 0;

  /// 宿主 State 的 build 次数。
  int debugBuildCount = 0;

  /// 宿主推入当前度量索引的读取器，测试读取已测量行数。
  int Function()? debugMeasuredItemCountProvider;

  /// 最近一次配置更新扫描子项变更范围的次数。
  int debugLastChildChangeSpanScanCount = 0;

  /// 最近一次配置更新重建高度索引的次数。
  int debugLastExtentIndexResetCount = 0;

  /// 视口向宿主提交实测高度的批次数。
  int debugItemExtentReportBatchCount = 0;

  /// 单批实测高度报告包含的最大行数。
  int debugMaxItemExtentReportBatchSize = 0;

  /// 宿主应用实测高度变化的次数。
  int debugApplyItemExtentsChangedCount = 0;

  /// 同时挂载的业务成员数量峰值，不含滚动条。
  int debugMaxMountedChildCount = 0;

  /// 视口完成子项挂载对账的次数。
  int debugContentReconcileCount = 0;

  /// 宿主推送挂载快照的次数。
  int debugContentSnapshotUpdateCount = 0;

  /// 宿主重算可见范围的次数。
  int debugVisibleRangeRecomputeCount = 0;

  /// 宿主派发可见性通知的次数。
  int debugVisibilityDispatchCount = 0;

  /// 构建完整成员快照的次数，范围回调不应承担这项成本。
  int debugItemSnapshotBuildCount = 0;

  /// 刷新几何与定位角色检测访问的子项数，纯虚拟列表应为零。
  int debugRefreshGeometryChildVisitCount = 0;

  /// 最近一次挂载对账调用业务子项 updateChild 的次数。
  int debugLastContentReconcileUpdateChildCount = 0;

  /// 最近一次挂载对账直接保留业务子项 Element 的数量。
  int debugLastContentReconcileReuseChildCount = 0;

  /// 最近一次挂载对账移动业务子项 slot 的次数。
  int debugLastContentReconcileSlotMoveCount = 0;

  /// 增量 reconcile 快路径命中次数（含常驻多区间形态）。
  int debugContentIncrementalReconcileCount = 0;

  /// 读取当前高度索引已实测的行数。
  int get debugMeasuredItemCount => debugMeasuredItemCountProvider?.call() ?? 0;

  /// 配置更新开始时复位本轮扫描与索引重建计数。
  void beginDidUpdate() {
    debugLastChildChangeSpanScanCount = 0;
    debugLastExtentIndexResetCount = 0;
  }

  /// 记录一次子项变更范围扫描。
  void recordChildChangeSpanScan() {
    debugLastChildChangeSpanScanCount++;
  }

  /// 记录一次高度索引重建。
  void recordExtentIndexReset() {
    debugLastExtentIndexResetCount++;
  }

  /// 记录实测高度报告批次及其行数峰值。
  void recordItemExtentReportBatch(int size) {
    debugItemExtentReportBatchCount++;
    if (size > debugMaxItemExtentReportBatchSize) {
      debugMaxItemExtentReportBatchSize = size;
    }
  }

  /// 记录一次宿主实测高度应用。
  void recordApplyItemExtentsChanged() {
    debugApplyItemExtentsChangedCount++;
  }

  /// 接收当前业务成员挂载量并更新峰值。
  void recordMountedChildCount(int count) {
    if (count > debugMaxMountedChildCount) {
      debugMaxMountedChildCount = count;
    }
  }

  /// 接收本次挂载对账的更新、复用与 slot 移动统计。
  void recordContentReconcile({
    required int updateChildCount,
    required int reuseChildCount,
    required int slotMoveCount,
  }) {
    debugContentReconcileCount++;
    debugLastContentReconcileUpdateChildCount = updateChildCount;
    debugLastContentReconcileReuseChildCount = reuseChildCount;
    debugLastContentReconcileSlotMoveCount = slotMoveCount;
  }

  /// 记录一次宿主挂载快照推送。
  void recordContentSnapshotUpdate() {
    debugContentSnapshotUpdateCount++;
  }

  /// 记录一次可见范围重算。
  void recordVisibleRangeRecompute() {
    debugVisibleRangeRecomputeCount++;
  }
}
