/// 参照：D:/project/html/my-ui/packages/core/my-ui.css:10-149、443-581、1596-1760、3657-3855、4103-4153。
/// 全局 token 与首批组件变量均使用实际类型，CSS px 对应 Flutter 逻辑像素。
library;

import 'package:flutter/widgets.dart';

const _absent = Object();

/// my-ui 全局明暗 token；未声明的组件变量回退到对应 CSS 默认值。
@immutable
class MyThemeData {
  /// 按 brightness 选取完整默认色板，再应用显式覆写。
  MyThemeData({
    this.brightness = Brightness.light,
    this.fontFamily = 'Times New Roman',
    List<String> fontFamilyFallback = const ['Microsoft YaHei', 'SimSun'],
    Color? background,
    Color? cardBackground,
    Color? fill,
    Color? border,
    Color? text,
    Color? textSecondary,
    Color? gray,
    Color? hover,
    Color? press,
    Color? selectedBackground,
    Color? success,
    Color? warning,
    Color? danger,
    Color? primary,
    Color? primaryText,
    List<BoxShadow>? selectedShadow,
    List<BoxShadow>? smallShadow,
    List<BoxShadow>? shadow,
    List<BoxShadow>? popupShadow,
    List<BoxShadow>? modalShadow,
    Color? overlayBackground,
    double? overlayBackdropBlur,
    double? fontWeight,
    double? fontWeightAction,
    double? fontWeightSubtitle,
    double? fontWeightTitle,
    this.tagColor,
    this.switchThumbBackground,
    this.cardRadius,
    this.cardPadding,
    this.cardHeaderGap,
    this.cardPressScale,
    this.cardPressBackground,
    this.cardHoverBackground,
    this.dividerColor,
    this.dividerSpacing,
    this.dividerHeight,
    this.progressColor,
    this.progressTrack,
    this.progressBufferColor,
    this.progressThickness,
    this.progressSize,
  }) : fontFamilyFallback = List.unmodifiable(fontFamilyFallback),
       background =
           background ??
           Color(brightness == Brightness.dark ? 0xff121419 : 0xfff2f3f5),
       cardBackground =
           cardBackground ??
           Color(brightness == Brightness.dark ? 0xff252931 : 0xffffffff),
       fill =
           fill ??
           Color(brightness == Brightness.dark ? 0xff333944 : 0xfff1f2f4),
       border =
           border ??
           Color(brightness == Brightness.dark ? 0xff596576 : 0xffdde0e5),
       text =
           text ??
           Color(brightness == Brightness.dark ? 0xfff4f6fa : 0xff17191e),
       textSecondary =
           textSecondary ??
           Color(brightness == Brightness.dark ? 0xffc4cbd6 : 0xff626874),
       gray =
           gray ??
           Color(brightness == Brightness.dark ? 0xff7c899c : 0xffbac2ce),
       hover =
           hover ??
           Color(brightness == Brightness.dark ? 0xff3c4350 : 0xffe9ecf0),
       press =
           press ??
           Color(brightness == Brightness.dark ? 0xff464e5b : 0xffe0e4ea),
       selectedBackground =
           selectedBackground ??
           Color(brightness == Brightness.dark ? 0xff414956 : 0xffffffff),
       success =
           success ??
           Color(brightness == Brightness.dark ? 0xffa4dfb4 : 0xff176b3c),
       warning =
           warning ??
           Color(brightness == Brightness.dark ? 0xfff3db82 : 0xff805500),
       danger =
           danger ??
           Color(brightness == Brightness.dark ? 0xffffacae : 0xffb5283c),
       primary =
           primary ??
           Color(brightness == Brightness.dark ? 0xffaac8ff : 0xff2454c6),
       primaryText =
           primaryText ??
           Color(brightness == Brightness.dark ? 0xff000000 : 0xffffffff),
       selectedShadow = List.unmodifiable(
         selectedShadow ??
             (brightness == Brightness.dark
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
       smallShadow = List.unmodifiable(
         smallShadow ??
             (brightness == Brightness.dark
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
       shadow = List.unmodifiable(
         shadow ??
             (brightness == Brightness.dark
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
       popupShadow = List.unmodifiable(
         popupShadow ??
             (brightness == Brightness.dark
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
       modalShadow = List.unmodifiable(
         modalShadow ??
             (brightness == Brightness.dark
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
       overlayBackground =
           overlayBackground ??
           (brightness == Brightness.dark
               ? const Color(0xff000000).withValues(alpha: .62)
               : const Color(0xff0c121c).withValues(alpha: .34)),
       overlayBackdropBlur = overlayBackdropBlur ?? 4,
       fontWeight = fontWeight ?? 400,
       fontWeightAction = fontWeightAction ?? 500,
       fontWeightSubtitle = fontWeightSubtitle ?? 600,
       fontWeightTitle = fontWeightTitle ?? 700;

  /// 当前主题的明暗轴。
  final Brightness brightness;

  /// 页面背景。
  final Color background;

  /// 卡片背景。
  final Color cardBackground;

  /// 控件填充。
  final Color fill;

  /// 边界色。
  final Color border;

  /// 正文色。
  final Color text;

  /// 次要文字色。
  final Color textSecondary;

  /// 未选中轨道色。
  final Color gray;

  /// 悬停背景。
  final Color hover;

  /// 按压背景。
  final Color press;

  /// 选中底板。
  final Color selectedBackground;

  /// 成功色。
  final Color success;

  /// 警告色。
  final Color warning;

  /// 危险色。
  final Color danger;

  /// 主题主色。
  final Color primary;

  /// 主色背景上的文字色。
  final Color primaryText;

  /// selectedShadow 阴影。
  final List<BoxShadow> selectedShadow;

  /// smallShadow 阴影。
  final List<BoxShadow> smallShadow;

  /// shadow 阴影。
  final List<BoxShadow> shadow;

  /// popupShadow 阴影。
  final List<BoxShadow> popupShadow;

  /// modalShadow 阴影。
  final List<BoxShadow> modalShadow;

  /// 模态遮罩色。
  final Color overlayBackground;

  /// 模态背景模糊半径。
  final double overlayBackdropBlur;

  /// 复刻同机 Web 的主体字体；宿主须提供该字体，子树可显式覆写。
  final String fontFamily;

  /// 主字体缺字时依次回退，默认中文使用 Microsoft YaHei、其次 SimSun。
  final List<String> fontFamilyFallback;

  /// 正文字重。
  final double fontWeight;

  /// 操作字重。
  final double fontWeightAction;

  /// 小标题字重。
  final double fontWeightSubtitle;

  /// 大标题字重。
  final double fontWeightTitle;

  /// 展示标签的 --tag-color。
  final Color? tagColor;

  /// 开关的 --switch-thumb-background。
  final Color? switchThumbBackground;

  /// 卡片的 --card-radius。
  final double? cardRadius;

  /// 卡片的 --card-padding，不含边框。
  final EdgeInsetsGeometry? cardPadding;

  /// 卡片的 --card-header-gap。
  final double? cardHeaderGap;

  /// 卡片的 --card-press-scale。
  final double? cardPressScale;

  /// 卡片的 --card-press-background。
  final Color? cardPressBackground;

  /// 卡片的 --card-hover-background。
  final Color? cardHoverBackground;

  /// 分割线的 --divider-color。
  final Color? dividerColor;

  /// 分割线的 --divider-spacing。
  final double? dividerSpacing;

  /// 分割线的 --divider-height。
  final double? dividerHeight;

  /// 进度的 --progress-color。
  final Color? progressColor;

  /// 进度的 --progress-track。
  final Color? progressTrack;

  /// 进度的 --progress-buffer-color。
  final Color? progressBufferColor;

  /// 进度的 --progress-thickness。
  final double? progressThickness;

  /// 进度的 --progress-size。
  final double? progressSize;

  /// 省略字段保留原值，组件变量显式传 null 可清除覆写。
  MyThemeData copyWith({
    String? fontFamily,
    List<String>? fontFamilyFallback,
    Color? background,
    Color? cardBackground,
    Color? fill,
    Color? border,
    Color? text,
    Color? textSecondary,
    Color? gray,
    Color? hover,
    Color? press,
    Color? selectedBackground,
    Color? success,
    Color? warning,
    Color? danger,
    Color? primary,
    Color? primaryText,
    List<BoxShadow>? selectedShadow,
    List<BoxShadow>? smallShadow,
    List<BoxShadow>? shadow,
    List<BoxShadow>? popupShadow,
    List<BoxShadow>? modalShadow,
    Color? overlayBackground,
    double? overlayBackdropBlur,
    double? fontWeight,
    double? fontWeightAction,
    double? fontWeightSubtitle,
    double? fontWeightTitle,
    Object? tagColor = _absent,
    Object? switchThumbBackground = _absent,
    Object? cardRadius = _absent,
    Object? cardPadding = _absent,
    Object? cardHeaderGap = _absent,
    Object? cardPressScale = _absent,
    Object? cardPressBackground = _absent,
    Object? cardHoverBackground = _absent,
    Object? dividerColor = _absent,
    Object? dividerSpacing = _absent,
    Object? dividerHeight = _absent,
    Object? progressColor = _absent,
    Object? progressTrack = _absent,
    Object? progressBufferColor = _absent,
    Object? progressThickness = _absent,
    Object? progressSize = _absent,
  }) => MyThemeData(
    brightness: brightness,
    fontFamily: fontFamily ?? this.fontFamily,
    fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
    background: background ?? this.background,
    cardBackground: cardBackground ?? this.cardBackground,
    fill: fill ?? this.fill,
    border: border ?? this.border,
    text: text ?? this.text,
    textSecondary: textSecondary ?? this.textSecondary,
    gray: gray ?? this.gray,
    hover: hover ?? this.hover,
    press: press ?? this.press,
    selectedBackground: selectedBackground ?? this.selectedBackground,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    primary: primary ?? this.primary,
    primaryText: primaryText ?? this.primaryText,
    selectedShadow: selectedShadow ?? this.selectedShadow,
    smallShadow: smallShadow ?? this.smallShadow,
    shadow: shadow ?? this.shadow,
    popupShadow: popupShadow ?? this.popupShadow,
    modalShadow: modalShadow ?? this.modalShadow,
    overlayBackground: overlayBackground ?? this.overlayBackground,
    overlayBackdropBlur: overlayBackdropBlur ?? this.overlayBackdropBlur,
    fontWeight: fontWeight ?? this.fontWeight,
    fontWeightAction: fontWeightAction ?? this.fontWeightAction,
    fontWeightSubtitle: fontWeightSubtitle ?? this.fontWeightSubtitle,
    fontWeightTitle: fontWeightTitle ?? this.fontWeightTitle,
    tagColor: identical(tagColor, _absent) ? this.tagColor : tagColor as Color?,
    switchThumbBackground: identical(switchThumbBackground, _absent)
        ? this.switchThumbBackground
        : switchThumbBackground as Color?,
    cardRadius: identical(cardRadius, _absent)
        ? this.cardRadius
        : (cardRadius as num?)?.toDouble(),
    cardPadding: identical(cardPadding, _absent)
        ? this.cardPadding
        : cardPadding as EdgeInsetsGeometry?,
    cardHeaderGap: identical(cardHeaderGap, _absent)
        ? this.cardHeaderGap
        : (cardHeaderGap as num?)?.toDouble(),
    cardPressScale: identical(cardPressScale, _absent)
        ? this.cardPressScale
        : (cardPressScale as num?)?.toDouble(),
    cardPressBackground: identical(cardPressBackground, _absent)
        ? this.cardPressBackground
        : cardPressBackground as Color?,
    cardHoverBackground: identical(cardHoverBackground, _absent)
        ? this.cardHoverBackground
        : cardHoverBackground as Color?,
    dividerColor: identical(dividerColor, _absent)
        ? this.dividerColor
        : dividerColor as Color?,
    dividerSpacing: identical(dividerSpacing, _absent)
        ? this.dividerSpacing
        : (dividerSpacing as num?)?.toDouble(),
    dividerHeight: identical(dividerHeight, _absent)
        ? this.dividerHeight
        : (dividerHeight as num?)?.toDouble(),
    progressColor: identical(progressColor, _absent)
        ? this.progressColor
        : progressColor as Color?,
    progressTrack: identical(progressTrack, _absent)
        ? this.progressTrack
        : progressTrack as Color?,
    progressBufferColor: identical(progressBufferColor, _absent)
        ? this.progressBufferColor
        : progressBufferColor as Color?,
    progressThickness: identical(progressThickness, _absent)
        ? this.progressThickness
        : (progressThickness as num?)?.toDouble(),
    progressSize: identical(progressSize, _absent)
        ? this.progressSize
        : (progressSize as num?)?.toDouble(),
  );

  /// 用可变字体轴保留 CSS 数值字重，静态字体同时提供最近百位回退。
  FontWeight weight(double value) =>
      FontWeight.values[((value / 100).round() - 1).clamp(0, 8)];
}
