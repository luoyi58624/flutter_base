part of 'index.dart';

/// 轻微放大并淡入，退场仅淡出，适合弹窗。
class ElFadeScaleAnimation extends ElSwitcherAnimation {
  /// 使用内置的中心缩放和短时显隐过渡。
  const ElFadeScaleAnimation(super.value, {super.key, required super.child});

  @override
  Duration get $duration => const Duration(milliseconds: 180);

  @override
  Curve get $curve => Curves.easeOutCubic;

  @override
  Duration get $exitHoldDuration => const Duration(milliseconds: 70);

  @override
  Widget builder(BuildContext context, Animation<double> animation) {
    return FadeTransition(
      opacity: _useOpacity(
        value,
        enterDuration: const Duration(milliseconds: 90),
        exitDuration: $exitHoldDuration,
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
        child: child,
      ),
    );
  }
}
