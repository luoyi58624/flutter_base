part of 'index.dart';

/// 从右侧滑入的面板过渡，保留阴影并由外层场景决定裁剪边界。
class ElSlideAnimation extends ElSwitcherAnimation {
  /// 使用内置的连续位移和停靠节奏。
  const ElSlideAnimation(super.value, {super.key, required super.child});

  @override
  Duration get $duration => const Duration(milliseconds: 220);

  @override
  Duration get $reverseDuration => const Duration(milliseconds: 160);

  @override
  Curve get $curve => const Cubic(0, 0, 0.2, 1);

  @override
  Curve get $reverseCurve => const Cubic(0.4, 0, 1, 1);

  @override
  Widget builder(BuildContext context, Animation<double> animation) {
    return FadeTransition(
      // 只隐藏停靠点外的最后一小段，避免边界裁切破坏侧栏的完整外观。
      opacity: animation.drive(const _OpacityProgress(0.015)),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}
