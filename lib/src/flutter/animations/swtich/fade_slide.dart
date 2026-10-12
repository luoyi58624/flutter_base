part of 'index.dart';

/// 轻移上升并淡入，适合通知和浮动提示。
class ElFadeSlideAnimation extends ElSwitcherAnimation {
  /// 使用内置的 16 逻辑像素位移，先显露文字再完成位移。
  const ElFadeSlideAnimation(super.value, {super.key, required super.child});

  @override
  Duration get $duration => const Duration(milliseconds: 180);

  @override
  Duration get $reverseDuration => const Duration(milliseconds: 100);

  @override
  Curve get $curve => Curves.easeOutCubic;

  @override
  Curve get $reverseCurve => Curves.easeInCubic;

  @override
  Widget builder(BuildContext context, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      child: FadeTransition(opacity: _useOpacity(value), child: child),
      builder: (context, content) => Transform.translate(
        offset: Offset(0, 16 * (1 - animation.value)),
        child: content,
      ),
    );
  }
}
