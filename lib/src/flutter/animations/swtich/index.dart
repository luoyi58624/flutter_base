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

  /// 几何运动使用稳定的弹簧响应，反转时仅改变目标。
  @protected
  SpringDescription get $motion => _spatialMotion;

  /// 运动的停靠精度。
  @protected
  Tolerance get $motionTolerance => _spatialTolerance;

  /// 退场是否仅淡出，几何继续完成当前的入场动作。
  @protected
  bool get $fadeOutOnly => false;

  /// 使用连续的运动进度构建效果。
  @protected
  Widget builder(BuildContext context, AnimationController animation);

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(initialValue: value ? 1 : 0);
    final previous = useRef(value);
    useEffect(() {
      if (previous.value == value) return null;
      previous.value = value;
      if (!value && $fadeOutOnly) return null;
      _driveMotion(controller, value, $motion, $motionTolerance);
      return null;
    }, [value]);
    return IgnorePointer(
      ignoring: !value,
      child: ExcludeSemantics(
        excluding: !value,
        child: builder(context, controller),
      ),
    );
  }
}

/// 透明度响应比几何更快，且沿用同一套连续切换机制。
AnimationController _useOpacity(bool value) {
  final controller = useAnimationController(initialValue: value ? 1 : 0);
  final previous = useRef(value);
  useEffect(() {
    if (previous.value == value) return null;
    previous.value = value;
    _driveMotion(controller, value, _effectsMotion, _effectsTolerance);
    return null;
  }, [value]);
  return controller;
}

/// 仅在停靠点外的极短区间隐藏内容，保留主体质感。
class _OpacityProgress extends Animatable<double> {
  const _OpacityProgress(this.end);
  final double end;

  @override
  double transform(double t) => (t / end).clamp(0.0, 1.0);
}
