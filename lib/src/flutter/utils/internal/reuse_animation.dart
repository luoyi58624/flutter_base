import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/widgets.dart';

/// 仅在单个驻留子树换绑到另一条记录时跳过状态过渡，不改变持续动画或系统动态设置。
@internal
class ReuseAnimationState {
  bool _rebinding = false;

  /// 同步完成换绑、构建和布局，异常退出时也恢复该子树的正常过渡。
  T runRebind<T>(T Function() action) {
    final previous = _rebinding;
    _rebinding = true;
    try {
      return action();
    } finally {
      _rebinding = previous;
    }
  }
}

/// 为驻留条目提供局部换绑状态，状态变化不通知静态后代重建。
@internal
class ReuseAnimationScope extends InheritedWidget {
  /// 包裹一个可复用子树。
  const ReuseAnimationScope({super.key, required this.state, required super.child});

  /// 当前条目的同步换绑状态。
  final ReuseAnimationState state;

  /// 在实际消费过渡时读取，其他条目即使同处一个 buildScope 也不会受影响。
  static bool skippingTransitionsOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ReuseAnimationScope>()?.state._rebinding ?? false;

  @override
  bool updateShouldNotify(ReuseAnimationScope oldWidget) => false;
}
