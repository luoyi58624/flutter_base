part of 'index.dart';

/// 从下方沿 X 轴翻起卡片，保留实体质感和轻微透视。
class ElFlipAnimation extends ElSwitcherAnimation {
  /// 使用内置的四分之一周翻转。
  const ElFlipAnimation(super.value, {super.key, required super.child});

  @override
  Duration get $duration => const Duration(milliseconds: 240);

  @override
  Duration get $reverseDuration => const Duration(milliseconds: 160);

  @override
  Widget builder(BuildContext context, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      child: FadeTransition(
        opacity: animation.drive(const _OpacityProgress(0.04)),
        child: child,
      ),
      builder: (context, content) => Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..translateByDouble(0, 8 * (1 - animation.value), 0, 1)
          ..rotateX(-(1 - animation.value) * math.pi / 2),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}
