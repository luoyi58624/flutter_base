part of 'index.dart';

/// 从 80% 尺寸放大入场，透明度先稳定，适合弹窗。
class ElFadeScaleAnimation extends ElSwitcherAnimation {
  /// 使用内置的中心缩放和短时显隐过渡。
  const ElFadeScaleAnimation(super.value, {super.key, required super.child});

  @override
  Widget builder(BuildContext context, Animation<double> animation) {
    return FadeTransition(
      opacity: _useOpacity(
        value,
        enterDuration: const Duration(milliseconds: 60),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
        child: child,
      ),
    );
  }
}
