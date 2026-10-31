import '../flutter/views/view/style/style.dart';

/// 变量宿主只承载声明和条件，实际样式留给内层根应用一次。
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
