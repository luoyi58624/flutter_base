part of 'index.dart';

/// 轻移上升并淡入，适合通知和浮动提示。
class ElFadeSlideAnimation extends ElSwitcherAnimation {
  /// 使用内置的 12 逻辑像素位移和同步透明度过渡。
  const ElFadeSlideAnimation(super.value, {super.key, required super.child});

  @override
  Widget builder(BuildContext context, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      child: FadeTransition(opacity: animation, child: child),
      builder: (context, content) => Transform.translate(
        offset: Offset(0, 12 * (1 - animation.value)),
        child: content,
      ),
    );
  }
}
