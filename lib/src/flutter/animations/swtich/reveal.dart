part of 'index.dart';

/// 从中心向外揭示内容，始终保留完整的布局占位。
class ElRevealAnimation extends ElSwitcherAnimation {
  /// 使用内置的圆形显露过渡。
  const ElRevealAnimation(super.value, {super.key, required super.child});

  @override
  Widget builder(BuildContext context, Animation<double> animation) {
    return ClipPath(clipper: _RevealClipper(animation), child: child);
  }
}

class _RevealClipper extends CustomClipper<Path> {
  _RevealClipper(this.animation) : super(reclip: animation);

  final Animation<double> animation;

  @override
  Path getClip(Size size) {
    final center = size.center(Offset.zero);
    final radius = center.distance * animation.value.clamp(0.0, 1.0);
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(_RevealClipper oldClipper) =>
      oldClipper.animation != animation;
}
