part of 'index.dart';

/// 沿阅读方向揭示内容，始终保留完整的布局占位。
class ElRevealAnimation extends ElSwitcherAnimation {
  /// 使用内置的水平裁剪过渡。
  const ElRevealAnimation(super.value, {super.key, required super.child});

  @override
  Duration get $duration => const Duration(milliseconds: 180);

  @override
  Widget builder(BuildContext context, Animation<double> animation) {
    return ClipRect(
      clipper: _RevealClipper(
        animation,
        Directionality.maybeOf(context) ?? TextDirection.ltr,
      ),
      child: child,
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  _RevealClipper(this.animation, this.direction) : super(reclip: animation);

  final Animation<double> animation;
  final TextDirection direction;

  @override
  Rect getClip(Size size) {
    final width = size.width * animation.value.clamp(0.0, 1.0);
    return Rect.fromLTWH(
      direction == TextDirection.rtl ? size.width - width : 0,
      0,
      width,
      size.height,
    );
  }

  @override
  bool shouldReclip(_RevealClipper oldClipper) =>
      oldClipper.animation != animation || oldClipper.direction != direction;
}
