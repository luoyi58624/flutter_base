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

  /// 使用连续的位置进度构建效果。
  @protected
  Widget builder(BuildContext context, Animation<double> animation);

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(initialValue: value ? 1 : 0);
    final spring = useMemoized(
      () => SpringDescription.withDurationAndBounce(duration: $duration),
    );
    final retargetSpring = useMemoized(
      () => SpringDescription.withDurationAndBounce(duration: $duration * 0.5),
    );
    final previous = useRef(value);
    useEffect(() {
      if (previous.value == value) return null;
      previous.value = value;
      final target = value ? 1.0 : 0.0;
      if (controller.value == target && controller.velocity == 0) {
        controller.stop();
        return null;
      }
      // 连续反转加快回正，继承当前位置和速度，迅速转向且不产生回弹。
      controller.animateWith(
        SpringSimulation(
          controller.isAnimating ? retargetSpring : spring,
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

/// 透明度先稳定，几何变换随后收尾，避免文字全程处于半透明状态。
class _OpacityProgress extends Animatable<double> {
  const _OpacityProgress(this.end);
  final double end;

  @override
  double transform(double t) => (t / end).clamp(0.0, 1.0);
}
