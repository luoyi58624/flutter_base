part of 'theme.dart';

// 页面、卡片、卡片按压与分隔线各自声明，避免控件边框或通用按压色影响列表。
Map<Object, Object> _buildVars(bool dark) => Map.unmodifiable({
  if (!dark) ElTokens.$info: Color(0xff909399),
  if (!dark) ElTokens.$black: Color(0xff000000),
  if (!dark) ElTokens.$white: Color(0xffffffff),
  ElTokens.$textRegular: dark ? Color(0xffcfd3dc) : Color(0xff606266),
  ElTokens.$textPlaceholder: dark ? Color(0xff8d9095) : Color(0xffc0c4cc),
  ElTokens.$textDisabled: dark ? Color(0xff6c6e72) : Color(0xffd4d7de),
  if (!dark) ElTokens.$textOnLight: Color(0xff303133),
  if (!dark) ElTokens.$textOnDark: Color(0xffffffff),
  if (!dark) ElTokens.$shadowXs: const <BoxShadow>[],
  if (!dark) ElTokens.$overlayColorLight: Color(0xb3000000),
  if (!dark) ElTokens.$overlayColorLighter: Color(0x80000000),
  if (!dark) ElTokens.$borderWidth: 1.0,
  if (!dark) ElTokens.$radiusXs: 2.0,
  if (!dark) ElTokens.$radiusSm: 4.0,
  if (!dark) ElTokens.$radiusMd: 6.0,
  if (!dark) ElTokens.$radiusLg: 8.0,
  if (!dark) ElTokens.$radiusXl: 12.0,
  if (!dark) ElTokens.$fontFamily: '',
  if (!dark) ElTokens.$fontFamilyFallback: const <String>[],
  ElTokens.$borderColorHover: Color(dark ? 0xff7a8491 : 0xffbbbec2),
  ElTokens.$borderColorLight: Color(dark ? 0xff4a535f : 0xffe7e9ed),
  ElTokens.$borderColorLighter: Color(dark ? 0xff404750 : 0xffeef0f2),
  ElTokens.$borderColorExtraLight: Color(dark ? 0xff363b41 : 0xfff5f6f7),
  ElTokens.$borderColorDark: Color(dark ? 0xff6a7484 : 0xffcccfd3),
  ElTokens.$borderColorDarker: Color(dark ? 0xff7a8491 : 0xffbbbec2),
  ElTokens.$disabledTextColor: Color(dark ? 0xff8d9095 : 0xffc0c4cc),
  ElTokens.$disabledBgColor: Color(dark ? 0xff262727 : 0xfff5f7fa),
  ElTokens.$disabledBorderColor: Color(dark ? 0xff4a535f : 0xffe7e9ed),
  ElTokens.$selectionColor: Color(dark ? 0xff545f74 : 0xffbdccee),

  ElTokens.$bgColor: Color(dark ? 0xff121419 : 0xffeeeeee),
  ElTokens.$cardColor: Color(dark ? 0xff252931 : 0xffffffff),
  ElTokens.$cardPressColor: Color(dark ? 0xff464e5b : 0xffe0e0e0),
  ElTokens.$dividerColor: Color(dark ? 0xff596576 : 0xffe0e0e0),
  ElTokens.$fill: Color(dark ? 0xff333944 : 0xfff1f2f4),
  ElTokens.$borderColor: Color(dark ? 0xff596576 : 0xffdde0e5),
  ElTokens.$textColor: Color(dark ? 0xfff4f6fa : 0xff17191e),
  ElTokens.$textSecondary: Color(dark ? 0xffc4cbd6 : 0xff626874),
  ElTokens.$gray: Color(dark ? 0xff7c899c : 0xffbac2ce),
  ElTokens.$hover: Color(dark ? 0xff3c4350 : 0xffe9ecf0),
  ElTokens.$press: Color(dark ? 0xff464e5b : 0xffe0e4ea),
  ElTokens.$selectedBackground: Color(dark ? 0xff414956 : 0xffffffff),
  ElTokens.$success: Color(dark ? 0xffa4dfb4 : 0xff176b3c),
  ElTokens.$warning: Color(dark ? 0xfff3db82 : 0xff805500),
  ElTokens.$error: Color(dark ? 0xffffacae : 0xffb5283c),
  ElTokens.$primary: Color(dark ? 0xffaac8ff : 0xff2454c6),
  ElTokens.$primaryText: Color(dark ? 0xff000000 : 0xffffffff),
  ElTokens.$selectedShadow: List<BoxShadow>.unmodifiable(
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
  ElTokens.$shadowSm: List<BoxShadow>.unmodifiable(
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
  ElTokens.$shadowMd: List<BoxShadow>.unmodifiable(
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
  ElTokens.$shadowLg: List<BoxShadow>.unmodifiable(
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
  ElTokens.$shadowXl: List<BoxShadow>.unmodifiable(
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
  ElTokens.$overlayColor: (dark
      ? const Color(0xff000000).withValues(alpha: .62)
      : const Color(0xff0c121c).withValues(alpha: .34)),
  if (!dark) ElTokens.$overlayBackdropBlur: 4,
  if (!dark) ElTokens.$fontWeight: 400,
  if (!dark) ElTokens.$fontWeightAction: 500,
  if (!dark) ElTokens.$fontWeightSubtitle: 600,
  if (!dark) ElTokens.$fontWeightTitle: 700,
});
