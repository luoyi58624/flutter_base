import '../../../../utils/internal/bit_mask.dart';
import '../internal/field_spec.dart';
import '../state/view_state.dart';
import '../style.dart';

/// 单层声明的稀疏字段表与位图，挂载和后续级联共用。
final class StyleSpec {
  /// 编译当前层非空声明。
  StyleSpec(ElStyle style) {
    validateStyleConfiguration(style);
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

final _validatedConfigurations = Expando<bool>('elStyleConfiguration');
final _validatedVariants = Expando<bool>('elStyleVariantConfiguration');

/// 校验高级配置只出现在基础声明，所有变体分支在使用前统一检查。
void validateStyleConfiguration(ElStyle style, {bool variant = false}) {
  if (variant && style.textOptions != null) {
    throw ArgumentError('ElStyle.textOptions 只能配置在基础样式，不能用于状态、断点、选区、starting 或关键帧变体。');
  }
  final cache = variant ? _validatedVariants : _validatedConfigurations;
  if (cache[style] == true) return;
  for (final (read, _) in selfVariantEntries) {
    final nested = read(style);
    if (nested != null) validateStyleConfiguration(nested, variant: true);
  }
  final selection = style.onSelection;
  if (selection != null) validateStyleConfiguration(selection, variant: true);
  final starting = style.starting;
  if (starting != null) validateStyleConfiguration(starting, variant: true);
  for (final animation in style.animation ?? const <ElAnimation>[]) {
    for (final frame in animation.keyframes.values) {
      validateStyleConfiguration(frame, variant: true);
    }
  }
  cache[style] = true;
}

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
  bool vars = false;
  final variants = <(ElStyle, int, int)>[];
}

_VariantScan _scan(ElStyle style) {
  validateStyleConfiguration(style);
  final cached = _scans[style];
  if (cached != null) return cached;
  final result = _VariantScan()
    ..transitions = style.transition != null
    ..animations = style.animation != null;
  // index=-1 先展开根声明，再按层处理追加项，保留同层的父节点与状态声明顺序。
  for (var index = -1; index < result.variants.length; index++) {
    final (current, conditions, depth) = index < 0 ? (style, 0, 0) : result.variants[index];
    assert(depth < 8, 'ElStyle 嵌套变体不能超过八层。');
    for (final (read, state) in selfVariantEntries) {
      final variant = read(current);
      if (variant == null) continue;
      result.states |= 1 << state.index;
      result.transitions |= variant.transition != null;
      result.animations |= variant.animation != null;
      result.vars |= variant.vars?.isNotEmpty ?? false;
      final mask = conditions | (1 << state.index);
      result.variants.add((variant, mask, depth + 1));
    }
  }

  _scans[style] = result;
  return result;
}

/// 整棵变体树需要跟踪的状态位。
int variantStatesMaskOf(ElStyle? style) => style == null ? 0 : _scan(style).states;

/// 声明树是否通过焦点变体显式要求当前节点可聚焦。
bool hasFocusableVariantOf(ElStyle? style) =>
    (variantStatesMaskOf(style) & ((1 << ViewState.focus.index) | (1 << ViewState.focusVisible.index))) != 0;

/// 顶层声明或状态变体是否可能配置过渡。
bool mayDeclareTransitionsOf(ElStyle? style) => style != null && _scan(style).transitions;

/// 顶层声明或状态变体是否可能配置关键帧动画。
bool mayDeclareAnimationsOf(ElStyle? style) => style != null && _scan(style).animations;

/// 变体树声明变量时，继承更新回退完整级联以保留变体贡献。
bool hasVariantVarsOf(ElStyle? style) => style != null && _scan(style).vars;

/// 当前激活变体覆写的字段；祖先主题采样不能覆盖这些声明。
FieldMask activeVariantDeclaredMask(ElStyle? style, int stateBits) {
  if (style == null) return FieldMask.empty;
  var declared = FieldMask.empty;
  for (final variant in activeVariantsOf(style, stateBits)) {
    declared = maskOr(declared, specOf(variant).declaredMask);
  }
  return declared;
}

/// 返回完整命中的状态组合，组合越具体优先级越高，同层遵循状态声明顺序。
Iterable<ElStyle> activeVariantsOf(ElStyle style, int stateBits) sync* {
  final scan = _scan(style);
  if ((stateBits & scan.states) == 0) return;
  for (final (variant, conditions, _) in scan.variants) {
    if ((stateBits & conditions) == conditions) yield variant;
  }
}
