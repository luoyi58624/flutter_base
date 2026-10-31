import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

part 'fade.dart';

part 'modal.dart';

part 'collapse.dart';

part 'zoom.dart';

part 'scale.dart';

part 'slide.dart';

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

  /// 默认动画时长，供未显式指定时长的开关动画使用
  static const Duration defaultDuration = Duration(milliseconds: 200);

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

    return IgnorePointer(
      ignoring: !show,
      child: ExcludeSemantics(
        excluding: !show,
        child: builder(context, controller),
      ),
    );
  }
}
