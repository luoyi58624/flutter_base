import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// 弹层进退场动画：挂载后进场，所在弹层关闭时先退场再移除；不在弹层中时直接显示终态。
class ElOverlayTransition extends HookWidget {
  /// 时长与曲线由品牌决定，builder 按进度构建外观。
  const ElOverlayTransition({super.key, required this.duration, this.reverseDuration, required this.builder});

  /// 进场时长。
  final Duration duration;

  /// 退场时长，省略时与进场相同。
  final Duration? reverseDuration;

  /// 按 0 到 1 的进度构建外观；拿到的是控制器本身，跟手拖动等交互可直接改写进度。
  final Widget Function(BuildContext context, AnimationController animation) builder;

  @override
  Widget build(BuildContext context) {
    final transitions = context.getInheritedWidgetOfExactType<_Scope>()?.transitions;
    final controller = useAnimationController(
      duration: duration,
      reverseDuration: reverseDuration,
      initialValue: transitions == null ? 1 : 0,
    );
    useEffect(() {
      if (transitions == null) return null;
      transitions._controllers.add(controller);
      controller.forward();
      return () => transitions._controllers.remove(controller);
    }, [transitions]);
    return builder(context, controller);
  }
}

/// 一次挂载内登记的进退场动画，弹层关闭时等它们全部退场。
@internal
final class OverlayTransitions {
  final _controllers = <AnimationController>{};

  /// 让内容中的 ElOverlayTransition 登记到这里。
  Widget wrap(Widget child) => _Scope(transitions: this, child: child);

  /// 从当前进度退场到底还需的最长时长，拖动关闭等已归零的动画不再占用时间。
  Duration get remaining => _controllers.fold(Duration.zero, (longest, controller) {
    final remaining = (controller.reverseDuration ?? controller.duration ?? Duration.zero) * controller.value;
    return remaining > longest ? remaining : longest;
  });

  /// 播放全部退场；动画所在组件先被卸载时直接结束。
  Future<void> reverse() => Future.wait([
    for (final controller in _controllers.toList()) controller.reverse().orCancel.onError<TickerCanceled>((_, _) {}),
  ]);
}

class _Scope extends InheritedWidget {
  const _Scope({required this.transitions, required super.child});

  final OverlayTransitions transitions;

  @override
  bool updateShouldNotify(_Scope oldWidget) => !identical(transitions, oldWidget.transitions);
}
