import 'package:flutter/foundation.dart' show internal, visibleForTesting;

/// 无头测试专用时钟接缝，生产模式不读取这些回调，也不通过公共入口导出。
@internal
abstract final class RecyclerTestClock {
  /// 替代准备耗时的单调时钟，单位为微秒。
  @visibleForTesting
  static int Function()? nowMicroseconds;

  /// 替代扣除安全余量后的剩余预算，参数为当前刷新率对应的单帧微秒数。
  @visibleForTesting
  static int Function(int intervalUs)? remainingBudgetMicroseconds;

  /// 清除测试覆盖，避免不同用例共用假时钟。
  @visibleForTesting
  static void reset() {
    nowMicroseconds = null;
    remainingBudgetMicroseconds = null;
  }
}
