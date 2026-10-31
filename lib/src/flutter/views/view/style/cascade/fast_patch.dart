import 'package:flutter_base/src/flutter/utils/internal/benchmark_probe.dart';
import 'package:flutter_base/src/flutter/utils/internal/bit_mask.dart';

import '../internal/field_spec.dart';
import '../resolved/resolved_style.dart';
import '../resolved/builder.dart';
import '../style.dart';
import 'style_spec.dart';
import 'tick.dart';

/// 无动画及优先级冲突时直接更新字段，其他情况交回完整级联。
class CascadeFastPatch {
  const CascadeFastPatch._();

  /// 基础字段变化不影响激活变体时，可保留现有结果直接写入差异。
  static CascadeTickResult? tryPatch({
    required ElStyle? oldStyle,
    required ElStyle? newStyle,
    required ResolvedStyle oldTarget,
    required ResolvedStyle? parent,
    required int state,
    required bool hasActiveAnimations,
  }) {
    if (oldStyle == null || newStyle == null || identical(oldStyle, newStyle) || hasActiveAnimations) return null;
    for (final (read, _) in selfVariantEntries) {
      if (!identical(read(oldStyle), read(newStyle))) return null;
    }
    if (!identical(oldStyle.vars, newStyle.vars) ||
        !identical(oldStyle.transition, newStyle.transition) ||
        !identical(oldStyle.animation, newStyle.animation) ||
        (newStyle.transition?.isNotEmpty ?? false)) {
      return null;
    }
    final (activeFields, activeTransitions) = activeSelfVariantContribution(newStyle, state);
    if (activeTransitions) return null;
    final builder = ResolvedStyleBuilder.fromExisting(oldTarget);
    var dirtyMask = FieldMask.empty;
    final inherited = parent ?? ResolvedStyle.initial;
    for (final entry in fieldSpecs.entries) {
      final spec = entry.value;
      final value = spec.declaration(newStyle);
      if (spec.declaration(oldStyle) == value) continue;
      spec.write(builder, value ?? (spec.isInherited ? spec.read(inherited) : null));
      dirtyMask = maskSetBit(dirtyMask, entry.key.index);
    }
    if (dirtyMask.isEmpty || maskAnd(dirtyMask, activeFields).isNotEmpty) {
      assert(() {
        BenchmarkProbe.fastPatchMissCount++;
        return true;
      }());
      return null;
    }
    assert(() {
      BenchmarkProbe.fastPatchHitCount++;
      return true;
    }());
    final target = builder.build();
    return (newTarget: target, newCommitted: target, changedMask: dirtyMask);
  }

  /// 继承变化只更新未被当前变体覆盖的字段，并尽量继续共享父级字段组。
  static CascadeTickResult? tryInheritPatch({
    required ElStyle? style,
    required ResolvedStyle oldTarget,
    required ResolvedStyle? newParent,
    required ResolvedStyle? oldParent,
    required int state,
    required FieldMask changedMask,
    required bool hasActiveAnimations,
  }) {
    if (changedMask.isEmpty || newParent == null || identical(newParent, oldTarget) || hasActiveAnimations) {
      return null;
    }
    if (maskAndNot(changedMask, inheritedFieldsMask).isNotEmpty) return null;
    if (style != null) {
      final (active, transitions) = activeSelfVariantContribution(style, state);
      if (transitions || maskAnd(changedMask, active).isNotEmpty || (style.transition?.isNotEmpty ?? false)) {
        return null;
      }
      // 新父表合并基础声明无法保留激活变体的变量，沿用旧实现的回退门。
      if (activeVariantsOf(style, state).any((variant) => variant.vars?.isNotEmpty ?? false)) return null;
    }
    if (oldParent != null) {
      final declared = style == null ? FieldMask.empty : specOf(style).declaredMask;
      final textChanged = maskAnd(changedMask, inheritedTextGroupMask).isNotEmpty;
      final boxChanged = maskAnd(changedMask, inheritedBoxGroupMask).isNotEmpty;
      final borrowText =
          !textChanged ||
          (identical(oldTarget.inheritedText, oldParent.inheritedText) &&
              maskAnd(declared, inheritedTextGroupMask).isEmpty);
      final borrowBox =
          !boxChanged ||
          (identical(oldTarget.inheritedBox, oldParent.inheritedBox) &&
              maskAnd(declared, inheritedBoxGroupMask).isEmpty);
      if (borrowText && borrowBox) {
        final target = oldTarget.copyWith(
          inheritedText: textChanged
              ? InheritedText.fromInheritedParent(newParent.inheritedText)
              : oldTarget.inheritedText,
          inheritedBox: boxChanged ? newParent.inheritedBox : oldTarget.inheritedBox,
          inheritedVars: newParent.inheritedVars.merge(style?.vars).stabilize(oldTarget.inheritedVars),
        );
        assert(() {
          BenchmarkProbe.inheritBorrowHitCount++;
          return true;
        }());
        return (newTarget: target, newCommitted: target, changedMask: changedMask);
      }
    }
    final builder = ResolvedStyleBuilder.fromExisting(oldTarget);
    builder.adoptVars(newParent.inheritedVars.merge(style?.vars).stabilize(oldTarget.inheritedVars));
    for (final field in changedMask.fields) {
      final spec = fieldSpecOf(field);
      spec.write(builder, spec.read(newParent));
    }
    final target = builder.build();
    return (newTarget: target, newCommitted: target, changedMask: changedMask);
  }
}
