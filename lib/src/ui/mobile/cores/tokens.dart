part of 'theme.dart';

// 默认值沿用原移动主题；暗表仅保留差异，避免覆盖基础层的通用变量。
Map<Object, Object> _buildVars(bool dark) => Map.unmodifiable({
  if (!dark) ElTheme.$fontFamily: 'Times New Roman',
  if (!dark)
    ElTheme.$fontFamilyFallback: List<String>.unmodifiable([
      'Microsoft YaHei',
      'SimSun',
    ]),
  ElTheme.$bgColor: Color(dark ? 0xff121419 : 0xfff2f3f5),
  ElTheme.$cardColor: Color(dark ? 0xff252931 : 0xffffffff),
  ElTheme.$fill: Color(dark ? 0xff333944 : 0xfff1f2f4),
  ElTheme.$borderColor: Color(dark ? 0xff596576 : 0xffdde0e5),
  ElTheme.$textColor: Color(dark ? 0xfff4f6fa : 0xff17191e),
  ElTheme.$textSecondary: Color(dark ? 0xffc4cbd6 : 0xff626874),
  ElTheme.$gray: Color(dark ? 0xff7c899c : 0xffbac2ce),
  ElTheme.$hover: Color(dark ? 0xff3c4350 : 0xffe9ecf0),
  ElTheme.$press: Color(dark ? 0xff464e5b : 0xffe0e4ea),
  ElTheme.$selectedBackground: Color(dark ? 0xff414956 : 0xffffffff),
  ElTheme.$success: Color(dark ? 0xffa4dfb4 : 0xff176b3c),
  ElTheme.$warning: Color(dark ? 0xfff3db82 : 0xff805500),
  ElTheme.$error: Color(dark ? 0xffffacae : 0xffb5283c),
  ElTheme.$primary: Color(dark ? 0xffaac8ff : 0xff2454c6),
  ElTheme.$primaryText: Color(dark ? 0xff000000 : 0xffffffff),
  ElTheme.$selectedShadow: List<BoxShadow>.unmodifiable(
    (dark
        ? [
            BoxShadow(
              color: const Color(0xff000000).withValues(alpha: 0.28),
              offset: const Offset(0, 1),
              blurRadius: 5,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xff68778c).withValues(alpha: 1),
              offset: const Offset(0, 0),
              blurRadius: 0,
              spreadRadius: 1,
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0xff121925).withValues(alpha: 0.1),
              offset: const Offset(0, 1),
              blurRadius: 4,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xff121925).withValues(alpha: 0.05),
              offset: const Offset(0, 0),
              blurRadius: 0,
              spreadRadius: 1,
            ),
          ]),
  ),
  ElTheme.$shadowSm: List<BoxShadow>.unmodifiable(
    (dark
        ? [
            BoxShadow(
              color: const Color(0xff000000).withValues(alpha: 0.32),
              offset: const Offset(0, 1),
              blurRadius: 2,
              spreadRadius: 0,
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0xff121925).withValues(alpha: 0.1),
              offset: const Offset(0, 1),
              blurRadius: 2,
              spreadRadius: 0,
            ),
          ]),
  ),
  ElTheme.$shadowMd: List<BoxShadow>.unmodifiable(
    (dark
        ? [
            BoxShadow(
              color: const Color(0xff000000).withValues(alpha: 0.16),
              offset: const Offset(0, 1),
              blurRadius: 3,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xff000000).withValues(alpha: 0.12),
              offset: const Offset(0, 4),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0xff121925).withValues(alpha: 0.045),
              offset: const Offset(0, 1),
              blurRadius: 3,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xff121925).withValues(alpha: 0.025),
              offset: const Offset(0, 4),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ]),
  ),
  ElTheme.$shadowLg: List<BoxShadow>.unmodifiable(
    (dark
        ? [
            BoxShadow(
              color: const Color(0xffffffff).withValues(alpha: 0.2),
              offset: const Offset(0, 0),
              blurRadius: 0,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: const Color(0xff000000).withValues(alpha: 0.36),
              offset: const Offset(0, 4),
              blurRadius: 12,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xff000000).withValues(alpha: 0.7),
              offset: const Offset(0, 20),
              blurRadius: 48,
              spreadRadius: -8,
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0xff121925).withValues(alpha: 0.07),
              offset: const Offset(0, 0),
              blurRadius: 0,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: const Color(0xff121925).withValues(alpha: 0.12),
              offset: const Offset(0, 4),
              blurRadius: 12,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xff121925).withValues(alpha: 0.24),
              offset: const Offset(0, 18),
              blurRadius: 44,
              spreadRadius: -8,
            ),
          ]),
  ),
  ElTheme.$shadowXl: List<BoxShadow>.unmodifiable(
    (dark
        ? [
            BoxShadow(
              color: const Color(0xffffffff).withValues(alpha: 0.22),
              offset: const Offset(0, 0),
              blurRadius: 0,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: const Color(0xff000000).withValues(alpha: 0.44),
              offset: const Offset(0, 8),
              blurRadius: 24,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xff000000).withValues(alpha: 0.82),
              offset: const Offset(0, 32),
              blurRadius: 80,
              spreadRadius: -12,
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0xff121925).withValues(alpha: 0.08),
              offset: const Offset(0, 0),
              blurRadius: 0,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: const Color(0xff121925).withValues(alpha: 0.14),
              offset: const Offset(0, 8),
              blurRadius: 24,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xff121925).withValues(alpha: 0.3),
              offset: const Offset(0, 32),
              blurRadius: 80,
              spreadRadius: -12,
            ),
          ]),
  ),
  ElTheme.$overlayColor: (dark
      ? const Color(0xff000000).withValues(alpha: .62)
      : const Color(0xff0c121c).withValues(alpha: .34)),
  if (!dark) ElTheme.$overlayBackdropBlur: 4,
  if (!dark) ElTheme.$fontWeight: 400,
  if (!dark) ElTheme.$fontWeightAction: 500,
  if (!dark) ElTheme.$fontWeightSubtitle: 600,
  if (!dark) ElTheme.$fontWeightTitle: 700,
});
