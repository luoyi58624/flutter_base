part of 'index.dart';

/// 绕 Y 轴翻转入场，带轻微透视并尽早恢复内容清晰度。
class ElFlipAnimation extends ElSwitcherAnimation {
  /// 使用内置的四分之一周翻转。
  const ElFlipAnimation(super.value, {super.key, required super.child});

  @override
  Duration get $duration => const Duration(milliseconds: 240);

  @override
  Widget builder(BuildContext context, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      child: FadeTransition(
        opacity: animation.drive(const _OpacityProgress(0.25)),
        child: child,
      ),
      builder: (context, content) => Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY((1 - animation.value) * math.pi / 2),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}
