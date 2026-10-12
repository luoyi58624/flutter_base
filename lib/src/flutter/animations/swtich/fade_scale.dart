part of 'index.dart';

/// 从 96% 尺寸轻微放大并淡入，适合弹窗。
class ElFadeScaleAnimation extends ElSwitcherAnimation {
  /// 使用内置的中心缩放和同步透明度过渡。
  const ElFadeScaleAnimation(super.value, {super.key, required super.child});

  @override
  Widget builder(BuildContext context, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
        child: child,
      ),
    );
  }
}
