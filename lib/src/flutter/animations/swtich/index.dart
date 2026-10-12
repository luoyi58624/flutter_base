import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../widgets/base.dart';

part 'collapse.dart';
part 'fade.dart';
part 'fade_scale.dart';
part 'fade_slide.dart';
part 'flip.dart';
part 'reveal.dart';
part 'scale.dart';
part 'slide.dart';

/// 用布尔值控制进出场，初次挂载直接呈现目标状态。
abstract class ElSwitcherAnimation extends HookWidget {
  /// 创建使用内置动效的显示开关。
  const ElSwitcherAnimation(this.value, {super.key, required this.child});

  /// 是否显示内容。
  final bool value;

  /// 动画内容，默认保留其状态。
  final Widget child;

  /// 弹簧的感知时长，由具体效果决定。
  @protected
  Duration get $duration => const Duration(milliseconds: 180);

  /// 入场回弹量，默认不回弹，退场和中途反转始终使用临界阻尼。
  @protected
  double get $bounce => 0;

  /// 是否仅执行短时透明度过渡。
  @protected
  bool get $opacityOnly => false;

  /// 使用连续的位置进度构建效果。
  @protected
  Widget builder(BuildContext context, Animation<double> animation);

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      initialValue: value ? 1 : 0,
      upperBound: $bounce > 0 ? 1.1 : 1,
      keys: [$bounce > 0, $opacityOnly],
    );
    final spring = useMemoized(
      () => SpringDescription.withDurationAndBounce(
        duration: $duration,
        bounce: $bounce,
      ),
      [$duration, $bounce],
    );
    final exitSpring = useMemoized(
      () => SpringDescription.withDurationAndBounce(duration: $duration),
      [$duration],
    );
    final retargetSpring = useMemoized(
      () => SpringDescription.withDurationAndBounce(duration: $duration * 0.5),
      [$duration],
    );
    final previous = useRef(value);
    useEffect(() {
      if (previous.value == value) return null;
      previous.value = value;
      if ($opacityOnly) {
        _driveOpacity(controller, value, enterDuration: $duration);
        return null;
      }
      final target = value ? 1.0 : 0.0;
      if (controller.value == target && controller.velocity == 0) {
        controller.stop();
        return null;
      }
      // 连续反转加快回正，继承当前位置和速度，迅速转向且不产生回弹。
      controller.animateWith(
        SpringSimulation(
          controller.isAnimating
              ? retargetSpring
              : (value ? spring : exitSpring),
          controller.value,
          target,
          controller.velocity,
          snapToEnd: true,
          tolerance: const Tolerance(distance: 0.001, velocity: 0.035),
        ),
      );
      return null;
    }, [value]);
    return IgnorePointer(
      ignoring: !value,
      child: ExcludeSemantics(
        excluding: !value,
        child: builder(context, controller.view),
      ),
    );
  }
}

/// 透明度使用短过渡，避免文字跟着几何弹簧长时间处于半透明状态。
Animation<double> _useOpacity(
  bool value, {
  Duration enterDuration = const Duration(milliseconds: 90),
  Duration exitDuration = const Duration(milliseconds: 75),
}) {
  final controller = useAnimationController(initialValue: value ? 1 : 0);
  useEffect(() {
    _driveOpacity(
      controller,
      value,
      enterDuration: enterDuration,
      exitDuration: exitDuration,
    );
    return null;
  }, [value]);
  return controller.view;
}

void _driveOpacity(
  AnimationController controller,
  bool value, {
  required Duration enterDuration,
  Duration exitDuration = const Duration(milliseconds: 90),
}) {
  final target = value ? 1.0 : 0.0;
  final distance = (target - controller.value).abs();
  if (distance == 0) {
    controller.stop();
    return;
  }
  controller.animateTo(
    target,
    duration: (value ? enterDuration : exitDuration) * distance,
    curve: Curves.easeOut,
  );
}

/// 透明度先稳定，几何变换随后收尾，避免文字全程处于半透明状态。
class _OpacityProgress extends Animatable<double> {
  const _OpacityProgress(this.end);
  final double end;

  @override
  double transform(double t) => (t / end).clamp(0.0, 1.0);
}
