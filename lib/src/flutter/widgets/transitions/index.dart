import '../../hooks/simple_hooks.dart';
import '../../obs/index.dart';
import '../base.dart';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

part 'fade.dart';

part 'collapse.dart';

/// 开关动画
abstract class ElSwitcherAnimation extends HookWidget {
  const ElSwitcherAnimation(
    this.show, {
    super.key,
    this.duration,
    this.curve,
    this.reverseCurve,
    required this.child,
  });

  final bool show;
  final Duration? duration;
  final Curve? curve;
  final Curve? reverseCurve;
  final Widget child;

  @protected
  Duration get $duration => duration ?? Duration.zero;

  @protected
  Curve get $curve => curve ?? Curves.linear;

  Widget builder(BuildContext context, AnimationController controller);

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: $duration,
      initialValue: show ? 1 : 0,
    );

    useEffect(() {
      show ? controller.forward() : controller.reverse();
      return;
    }, [show]);

    return builder(context, controller);
  }
}
