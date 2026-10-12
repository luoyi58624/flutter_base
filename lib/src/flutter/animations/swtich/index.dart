import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../widgets/base.dart';

part 'collapse.dart';
part 'fade.dart';
part 'fade_scale.dart';
part 'fade_slide.dart';
part 'flip.dart';
part 'motion.dart';
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

  /// 完整入场时长，由具体效果决定。
  @protected
  Duration get $duration => const Duration(milliseconds: 200);

  /// 完整退场时长，退场比入场更短。
  @protected
  Duration get $reverseDuration => const Duration(milliseconds: 140);

  /// 入场节奏，默认先加速展开再减速停靠。
  @protected
  Curve get $curve => const _MotionCurve();

  /// 退场节奏，默认与入场使用同一形状。
  @protected
  Curve get $reverseCurve => $curve;

  /// 退场保持几何状态的时间，淡出完成后复位，零表示直接执行退场。
  @protected
  Duration get $exitHoldDuration => Duration.zero;

  /// 使用连续的位置进度构建效果。
  @protected
  Widget builder(BuildContext context, Animation<double> animation);

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(initialValue: value ? 1 : 0);
    final previous = useRef(value);
    useEffect(() {
      if (previous.value == value) return null;
      previous.value = value;
      if (!value && $exitHoldDuration > Duration.zero) {
        controller.stop();
        // 淡出期间保持尺寸，完全不可见后复位，下一次入场仍有轻微放大。
        final timer = Timer($exitHoldDuration, () => controller.value = 0);
        return timer.cancel;
      }
      final target = value ? 1.0 : 0.0;
      final distance = (target - controller.value).abs();
      if (distance == 0) {
        controller.stop();
        return null;
      }
      final interrupted = controller.isAnimating || distance < 1;
      // 反转承接当前速度，在一帧内完成制动，再按剩余距离收尾。
      _driveMotion(
        controller,
        target,
        duration: interrupted
            ? const Duration(milliseconds: 80) * math.sqrt(distance)
            : (value ? $duration : $reverseDuration),
        curve: interrupted
            ? const _MotionCurve()
            : (value ? $curve : $reverseCurve),
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

/// 透明度使用短过渡，让文字在几何变化结束前恢复清晰。
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
  _driveMotion(
    controller,
    target,
    duration: (value ? enterDuration : exitDuration) * distance,
    curve: Curves.easeOut,
  );
}

void _driveMotion(
  AnimationController controller,
  double target, {
  required Duration duration,
  required Curve curve,
}) {
  if (duration == Duration.zero) {
    controller.value = target;
    return;
  }
  final velocity = controller.isAnimating ? controller.velocity : 0.0;
  controller.animateWith(
    velocity == 0
        ? _TimedMotion(controller.value, target, duration, curve)
        : _RetargetMotion(controller.value, target, velocity, duration),
  );
}

/// 透明度先稳定，几何变换随后收尾，避免文字全程处于半透明状态。
class _OpacityProgress extends Animatable<double> {
  const _OpacityProgress(this.end);
  final double end;

  @override
  double transform(double t) => (t / end).clamp(0.0, 1.0);
}
