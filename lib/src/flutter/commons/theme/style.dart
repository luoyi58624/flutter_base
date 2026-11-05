import '../../views/view/style/style.dart';

/// 提取样式及其变体中的变量声明。
ElStyle? themeVarsOf(ElStyle? style) {
  if (style == null) return null;
  final result = ElStyle(
    vars: style.vars,
    xs: themeVarsOf(style.xs),
    sm: themeVarsOf(style.sm),
    md: themeVarsOf(style.md),
    lg: themeVarsOf(style.lg),
    xl: themeVarsOf(style.xl),
    onHover: themeVarsOf(style.onHover),
    onTap: themeVarsOf(style.onTap),
    onFocus: themeVarsOf(style.onFocus),
    onFocusWithin: themeVarsOf(style.onFocusWithin),
    onFocusVisible: themeVarsOf(style.onFocusVisible),
    onDisabled: themeVarsOf(style.onDisabled),
    onDark: themeVarsOf(style.onDark),
  );
  // 不携带变量的条件分支不需要额外的交互状态宿主。
  return result == const ElStyle() ? null : result;
}
