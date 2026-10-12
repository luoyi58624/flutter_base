part of 'index.dart';

/// 轻微放大并淡入，退场仅淡出，适合弹窗。
class ElFadeScaleAnimation extends ElSwitcherAnimation {
  /// 使用内置的中心缩放和短时显隐过渡。
  const ElFadeScaleAnimation(super.value, {super.key, required super.child});

  @override
  SpringDescription get $motion => _feedbackMotion;

  @override
  Tolerance get $motionTolerance => _feedbackTolerance;

  @override
  bool get $fadeOutOnly => true;

  @override
  Widget builder(BuildContext context, AnimationController animation) {
    final opacity = _useOpacity(value);
    useEffect(() {
      void reset(AnimationStatus status) {
        // 完全淡出后复位；中途再打开会先移除此监听，继续当前几何运动。
        if (!value && status == AnimationStatus.dismissed) animation.value = 0;
      }

      opacity.addStatusListener(reset);
      if (!value &&
          opacity.status == AnimationStatus.dismissed &&
          (animation.value != 0 || animation.isAnimating)) {
        animation.value = 0;
      }
      return () => opacity.removeStatusListener(reset);
    }, [value, opacity, animation]);
    return FadeTransition(
      opacity: opacity,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
        child: child,
      ),
    );
  }
}
