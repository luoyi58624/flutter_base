import 'package:flutter/animation.dart' show Curve;

import '../animation/driver.dart';
import '../animation/field_animation.dart';

import 'package:flutter_base/src/ui/cores/view/style/style.dart';
import 'package:flutter_base/src/ui/utils/internal/benchmark_probe.dart';
import 'package:flutter_base/src/ui/utils/internal/bit_mask.dart';

import 'resolver.dart';
import 'style_spec.dart';
import '../internal/field_spec.dart';
import '../resolved/builder.dart';
import '../resolved/resolved_style.dart';

/// cascade tick 一帧的输出。
typedef CascadeTickResult = ({
  /// cascade 出的目标快照（不含动画中间值）。
  ResolvedStyle newTarget,

  /// 本帧实际生效的 committed。
  ///
  /// - 未启动动画的字段：取 newTarget 值
  /// - 已启动动画的字段：保持 oldCommitted 值（driver 在 onTick 时单独更新）
  ResolvedStyle newCommitted,

  /// 本帧相对 oldCommitted 改变的字段（不含正在动画的字段）。
  FieldMask changedMask,
});

/// cascade tick 入口。把 ElStyle + 父 ResolvedStyle + state → 新 target
/// + 同步字段动画。
class CascadeTick {
  const CascadeTick._();

  /// mount 首 commit 时 box 组内仍需 diff 的位：backdropFilter / filter——
  /// 它们从 null 变非 null 需要 `markNeedsCompositingBitsUpdate`（层结构变化，
  /// 与 layout/paint 脏位不同，新建 render 不天然携带）。
  static final FieldMask _mountCompositingBoxBits = maskOr(
    maskBit(ElTransitionField.backdropFilter.index),
    maskBit(ElTransitionField.filter.index),
  );

  /// 执行一次 cascade + sync animations。
  static CascadeTickResult tick({
    required ElStyle? style,
    required ResolvedStyle? parent,
    required ResolvedStyle oldCommitted,
    required int state,
    required StyleAnimationDriver? driver,
    Duration? forceTransitionDuration,
    Curve? forceTransitionCurve,
    FieldMask inheritedThemeAnimationMask = FieldMask.empty,
    FieldMask keyframeAnimationMask = FieldMask.empty,
    bool hostHasInheritanceConsumers = true,
  }) {
    assert(() {
      BenchmarkProbe.cascadeTickCount++;
      return true;
    }());
    final newTarget = StyleResolver.resolve(style: style, parent: parent, state: state);

    var changedMask = FieldMask.empty;
    ResolvedStyleBuilder? builder;

    final textSkip = identical(oldCommitted.inheritedText, newTarget.inheritedText);
    final boxStateSkip = identical(oldCommitted.inheritedBox, newTarget.inheritedBox);
    final boxSkip = identical(oldCommitted.box, newTarget.box);

    var iterMask = FieldMask.empty;
    if (!textSkip) iterMask = maskOr(iterMask, inheritedTextGroupMask);
    if (!boxStateSkip) iterMask = maskOr(iterMask, inheritedBoxGroupMask);
    if (!boxSkip) iterMask = maskOr(iterMask, boxGroupMask);

    if (driver != null && driver.hasActiveAnimations) {
      final identicalGroupsMask = maskAndNot(
        maskOr(maskOr(inheritedTextGroupMask, inheritedBoxGroupMask), boxGroupMask),
        iterMask,
      );
      if (identicalGroupsMask.isNotEmpty) {
        // activeFields 是稳定快照，取消动画不会修改当前遍历。
        for (final f in driver.activeFields) {
          if (maskHas(identicalGroupsMask, f.index)) {
            driver.cancelAnimation(f);
          }
        }
      }
    }

    final animate =
        driver != null ||
        forceTransitionDuration != null ||
        forceTransitionCurve != null ||
        keyframeAnimationMask.isNotEmpty;
    if (!animate && identical(oldCommitted, ResolvedStyle.initial)) {
      // 初次布局自带脏位，仅补滤镜合成与继承消费者实际需要的差异。
      iterMask = maskOr(maskAndNot(iterMask, boxGroupMask), maskAnd(iterMask, _mountCompositingBoxBits));
      if (!hostHasInheritanceConsumers) {
        iterMask = maskAndNot(iterMask, maskOr(inheritedTextGroupMask, inheritedBoxGroupMask));
      }
    }
    final transitions = animate ? _effectiveTransitions(style: style, state: state) : const <ElTransition>[];

    for (final field in iterMask.fields) {
      assert(() {
        BenchmarkProbe.cascadeFieldIterCount++;
        return true;
      }());
      final spec = fieldSpecOf(field);

      final currentVal = spec.read(oldCommitted);
      final targetVal = spec.read(newTarget);

      if (_valuesEqual(currentVal, targetVal)) {
        driver?.cancelAnimation(field);
        continue;
      }

      if (!animate) {
        changedMask = maskSetBit(changedMask, field.index);
        continue;
      }

      // keyframe 动画钉住：字段由 keyframe runner 每帧直写 committed，普通
      // cascade 不接管——保持旧值（runner 紧随其后重采样）、不启动 transition、
      // 不进 changedMask（CSS：animation 层压过 normal 层，动画驱动的变化
      // 不触发 transition）。
      if (maskHas(keyframeAnimationMask, field.index)) {
        driver?.cancelAnimation(field);
        spec.write(builder ??= ResolvedStyleBuilder.fromExisting(newTarget), currentVal);
        continue;
      }

      final runningAnim = driver?.animationOf(field);
      // 祖先 theme driver 已经给出本帧采样值：本节点只提交该采样，不能再套
      // 自己的 transition。否则每一帧都会用本地 duration/curve 从头启动，形成
      // currentColor 逐层变慢。只取消命中的字段，其他本地动画保持原时间线。
      if (maskHas(inheritedThemeAnimationMask, field.index)) {
        driver?.cancelAnimation(field);
        changedMask = maskSetBit(changedMask, field.index);
        continue;
      }
      if (runningAnim != null && _valuesEqual(runningAnim.to, targetVal)) {
        spec.write(builder ??= ResolvedStyleBuilder.fromExisting(newTarget), currentVal);
        continue;
      }

      ElTransition? transition;
      for (var i = transitions.length - 1; i >= 0; i--) {
        if (transitions[i].covers(field)) {
          transition = transitions[i];
          break;
        }
      }

      // duration=0 + delay=0 等价于无 transition：立即生效，避免驱动一帧 0-duration 动画
      final isZeroDuration =
          transition != null && transition.duration == Duration.zero && transition.delay == Duration.zero;

      final forceDur = forceTransitionDuration;
      final forceCur = forceTransitionCurve;
      final hasForce = forceDur != null && forceCur != null;
      final effectiveTransition = hasForce || transition != null;

      if (effectiveTransition && !spec.isDiscrete && driver != null && (hasForce || !isZeroDuration)) {
        // 启动动画 → committed 通常保持旧声明；仅 auto 长度必须钉在快照后的
        // t=0 值，避免 builder 已带入其他新样式时重新按 auto 布局而跳帧。
        final animation = FieldAnimation(
          field: field,
          from: currentVal,
          to: targetVal,
          duration: hasForce ? forceDur : transition!.duration,
          curve: hasForce ? forceCur : transition!.curve,
          delay: hasForce ? Duration.zero : transition!.delay,
          isThemeMode: hasForce,
        );
        driver.startAnimation(animation);
        final pinsAutoLengthSnapshot =
            currentVal == null && (field == ElTransitionField.width || field == ElTransitionField.height);
        spec.write(
          builder ??= ResolvedStyleBuilder.fromExisting(newTarget),
          pinsAutoLengthSnapshot ? animation.currentValue() : currentVal,
        );
      } else {
        // 立即写新值
        driver?.cancelAnimation(field);
        changedMask = maskSetBit(changedMask, field.index);
      }
    }

    return (
      newTarget: newTarget,
      newCommitted: builder == null ? newTarget : builder.build(),
      changedMask: changedMask,
    );
  }

  /// 动画 tick 时批量更新所有字段 — 单次 builder + 单次 build。
  ///
  /// N 个活跃动画只需 1 个 Box 拷贝（vs 旧逐字段 N 次拷贝）。返回的
  /// [changedMask] 不含未实际变化的字段（diff-safe）。全部等值时不分配
  /// builder（lazy alloc）。
  static (ResolvedStyle, FieldMask) writeFieldsFromAnimation({
    required ResolvedStyle oldCommitted,
    required Map<ElTransitionField, Object?> fieldValues,
  }) {
    ResolvedStyleBuilder? builder;
    var changed = FieldMask.empty;
    for (final entry in fieldValues.entries) {
      final spec = fieldSpecOf(entry.key);
      final old = spec.read(oldCommitted);
      if (_valuesEqual(old, entry.value)) continue;
      builder ??= ResolvedStyleBuilder.fromExisting(oldCommitted);
      spec.write(builder, entry.value);
      changed = maskSetBit(changed, entry.key.index);
    }
    if (builder == null) return (oldCommitted, changed);
    return (builder.build(), changed);
  }

  static bool _valuesEqual(Object? a, Object? b) => identical(a, b) || a == b;

  /// 按 cascade 优先级算 effective transitions。
  static List<ElTransition> _effectiveTransitions({required ElStyle? style, required int state}) =>
      _effectiveVariantList(style: style, state: state, read: _readTransitions) ?? const <ElTransition>[];

  /// 按 cascade 优先级算 effective animations（CSS `animation-*` longhand
  /// 覆盖语义，取值链与 [_effectiveTransitions] 完全同构：变体声明的表整表
  /// 替换 base 表）。keyframe runner 每次 cascade 用它对齐声明。
  static List<ElAnimation> effectiveAnimations({required ElStyle? style, required int state}) =>
      _effectiveVariantList(style: style, state: state, read: _readAnimations) ?? const <ElAnimation>[];

  static List<ElTransition>? _readTransitions(ElStyle s) => s.transitions;
  static List<ElAnimation>? _readAnimations(ElStyle s) => s.animations;

  /// longhand 列表字段（transitions / animations）的统一变体覆盖链。
  static List<T>? _effectiveVariantList<T>({
    required ElStyle? style,
    required int state,
    required List<T>? Function(ElStyle) read,
  }) {
    if (style == null) return null;

    var result = read(style);
    if ((state & variantStatesMaskOf(style)) != 0) {
      for (final variant in activeVariantsOf(style, state)) {
        result = read(variant) ?? result;
      }
    }
    return result;
  }

  /// 找到覆盖某字段的**effective** transition（含变体 longhand 覆盖语义）。
  static ElTransition? firstCoveringTransition({
    required ElStyle? style,
    required int state,
    required ElTransitionField field,
  }) {
    final transitions = _effectiveTransitions(style: style, state: state);
    for (var i = transitions.length - 1; i >= 0; i--) {
      if (transitions[i].covers(field)) return transitions[i];
    }
    return null;
  }
}
