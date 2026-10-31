part of 'index.dart';

class ElSlideAnimation extends ElSwitcherAnimation {
  const ElSlideAnimation(
    super.show, {
    super.key,
    super.duration,
    super.curve = ElSlideAnimation.defaultCurve,
    super.reverseCurve,
    this.axisDirection = AxisDirection.down,
    required super.child,
  });
  final AxisDirection axisDirection;
  static const Curve defaultCurve = Curves.fastOutSlowIn;
  @override
  Duration get $duration => duration ?? ElSwitcherAnimation.defaultDuration;
  @override
  Widget builder(context, controller) {
    return ElSlideTransition(
      controller: controller,
      curve: curve!,
      reverseCurve: reverseCurve,
      axisDirection: axisDirection,
      child: child,
    );
  }
}

class ElSlideTransition extends HookWidget {
  const ElSlideTransition({
    super.key,
    required this.controller,
    this.curve = ElSlideAnimation.defaultCurve,
    this.reverseCurve,
    this.axisDirection = AxisDirection.down,
    this.slideTween,
    required this.child,
  });
  final AnimationController controller;
  final Curve curve;
  final Curve? reverseCurve;
  final AxisDirection axisDirection;
  final Tween<double>? slideTween;
  final Widget child;
  Tween<double> get _slideTween => Tween(begin: 0.36, end: 1.0);
  @override
  Widget build(BuildContext context) {
    final curveAnimation = useMemoized(
      () => CurvedAnimation(
        parent: controller,
        curve: curve,
        reverseCurve: reverseCurve,
      ),
      [controller, curve, reverseCurve],
    );
    useEffect(() => curveAnimation.dispose, [curveAnimation]);
    final slideAnimation = (slideTween ?? _slideTween).animate(curveAnimation);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: curveAnimation,
          child: Transform.scale(
            scaleX: axisDirection.isHorizontal ? slideAnimation.value : 1.0,
            scaleY: axisDirection.isVertical ? slideAnimation.value : 1.0,
            alignment: axisDirection.toAlignment,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// [AxisDirection] 的动画辅助判断，仅本文件使用。
extension on AxisDirection {
  bool get isHorizontal =>
      this == AxisDirection.left || this == AxisDirection.right;

  bool get isVertical =>
      this == AxisDirection.up || this == AxisDirection.down;

  /// 缩放原点：元素从起始边展开。
  Alignment get toAlignment => switch (this) {
    AxisDirection.up => Alignment.bottomCenter,
    AxisDirection.down => Alignment.topCenter,
    AxisDirection.left => Alignment.centerRight,
    AxisDirection.right => Alignment.centerLeft,
  };
}
