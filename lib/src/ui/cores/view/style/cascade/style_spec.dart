import 'package:flutter_base/src/ui/utils/internal/bit_mask.dart';
import '../state/view_state.dart';
import '../style.dart';
import '../internal/field_spec.dart';

/// 单层声明的稀疏字段表与位图，挂载和后续级联共用。
final class StyleSpec {
  /// 编译当前层非空声明。
  StyleSpec(ElStyle style) {
    for (final entry in fieldSpecs.entries) {
      final value = entry.value.declaration(style);
      if (value == null) continue;
      values[entry.key] = value;
      declaredMask = maskSetBit(declaredMask, entry.key.index);
    }
  }

  /// 按字段保存声明原值。
  final values = <ElTransitionField, Object?>{};

  /// 当前层显式声明的字段位图。
  FieldMask declaredMask = FieldMask.empty;
}

final _specs = Expando<StyleSpec>();
StyleSpec specOf(ElStyle style) => _specs[style] ??= StyleSpec(style);

/// 状态优先级从低到高；所有变体扫描与属性级联共用此表。
final List<(ElStyle? Function(ElStyle), ViewState)> selfVariantEntries = [
  ((s) => s.xs, ViewState.xs),
  ((s) => s.sm, ViewState.sm),
  ((s) => s.md, ViewState.md),
  ((s) => s.lg, ViewState.lg),
  ((s) => s.xl, ViewState.xl),
  ((s) => s.onHover, ViewState.hover),
  ((s) => s.onTap, ViewState.tap),
  ((s) => s.onFocusWithin, ViewState.focusWithin),
  ((s) => s.onFocus, ViewState.focus),
  ((s) => s.onFocusVisible, ViewState.focusVisible),
  ((s) => s.onDark, ViewState.dark),
  ((s) => s.onDisabled, ViewState.disabled),
];

final Expando<_VariantScan> _scans = Expando<_VariantScan>('elStyleVariants');

class _VariantScan {
  int states = 0;
  bool transitions = false;
  bool animations = false;
  final variants = <(ElStyle, int, int)>[];
}

_VariantScan _scan(ElStyle style) {
  final cached = _scans[style];
  if (cached != null) return cached;
  final result = _VariantScan()
    ..transitions = style.transitions != null
    ..animations = style.animations != null;
  // index=-1 先展开根声明，再按层处理追加项，保留同层的父节点与状态声明顺序。
  for (var index = -1; index < result.variants.length; index++) {
    final (current, conditions, depth) = index < 0 ? (style, 0, 0) : result.variants[index];
    assert(depth < 8, 'ElStyle 嵌套变体不能超过八层。');
    for (final (read, state) in selfVariantEntries) {
      final variant = read(current);
      if (variant == null) continue;
      result.states |= 1 << state.index;
      result.transitions |= variant.transitions != null;
      result.animations |= variant.animations != null;
      final mask = conditions | (1 << state.index);
      result.variants.add((variant, mask, depth + 1));
    }
  }

  _scans[style] = result;
  return result;
}

/// 整棵变体树需要跟踪的状态位。
int variantStatesMaskOf(ElStyle? style) => style == null ? 0 : _scan(style).states;

/// 顶层声明或状态变体是否可能配置过渡。
bool mayDeclareTransitionsOf(ElStyle? style) => style != null && _scan(style).transitions;

/// 顶层声明或状态变体是否可能配置关键帧动画。
bool mayDeclareAnimationsOf(ElStyle? style) => style != null && _scan(style).animations;

/// 当前激活变体覆写的字段与过渡声明，用于判断能否直接差量更新。
(FieldMask, bool) activeSelfVariantContribution(ElStyle style, int stateBits) {
  var declared = FieldMask.empty;
  var transitions = false;
  for (final variant in activeVariantsOf(style, stateBits)) {
    declared = maskOr(declared, specOf(variant).declaredMask);
    transitions |= variant.transitions?.isNotEmpty ?? false;
  }
  return (declared, transitions);
}

/// 祖先主题采样不能覆盖当前激活变体自己的声明。
FieldMask activeVariantDeclaredMask(ElStyle? style, int stateBits) =>
    style == null ? FieldMask.empty : activeSelfVariantContribution(style, stateBits).$1;

/// 返回完整命中的状态组合，组合越具体优先级越高，同层遵循状态声明顺序。
Iterable<ElStyle> activeVariantsOf(ElStyle style, int stateBits) sync* {
  final scan = _scan(style);
  if ((stateBits & scan.states) == 0) return;
  for (final (variant, conditions, _) in scan.variants) {
    if ((stateBits & conditions) == conditions) yield variant;
  }
}
