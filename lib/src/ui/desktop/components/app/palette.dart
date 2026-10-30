part of 'index.dart';

/// 类型化主题值，组件只读取实际值，不参与 ElView 样式解析。
@immutable
class ElThemeData {
  /// 创建主题，未指定的字段使用默认浅色外观。
  ElThemeData({
    this.brightness = Brightness.light,
    ElLevelType? size,
    List<double>? buttonHeights,
    Color? black,
    Color? white,
    Color? bgColor,
    Color? cardColor,
    Color? primary,
    Color? success,
    Color? info,
    Color? warning,
    Color? error,
    Color? textColorXs,
    Color? textColorSm,
    Color? textColorMd,
    Color? textColorLg,
    Color? textColorXl,
    List<double>? fontSizes,
    List<double>? iconSizes,
    Color? iconColor,
    Color? appbarColor,
    List<double>? borderWidths,
    Color? borderColor,
    double? radiusXs,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    List<BoxShadow>? shadowXs,
    List<BoxShadow>? shadowSm,
    List<BoxShadow>? shadowMd,
    List<BoxShadow>? shadowLg,
    List<BoxShadow>? shadowXl,
    Color? shadowColor,
    List<double>? appbarHeights,
    int? indexNormal,
    int? indexPopper,
    int? indexTop,
    Color? maskColor,
    Color? maskColorExtraLight,
    Color? overlayColor,
    Color? overlayColorLight,
    Color? overlayColorLighter,
    Color? svgMonochromeGrey,
    List<ElTransition>? transitionAll,
    List<ElTransition>? transitionBorder,
    List<ElTransition>? transitionBoxShadow,
    List<ElTransition>? transitionColor,
    Duration? transitionDuration,
    Duration? transitionDurationFast,
    List<ElTransition>? transitionFade,
    List<ElTransition>? transitionFadeLinear,
    Curve? transitionEaseInOutBezier,
    Curve? transitionFastBezier,
    List<ElTransition>? transitionMdFade,
  }) : size = size ?? (ElPlatform.isDesktop ? ElLevelType.md : ElLevelType.lg),
       buttonHeights = buttonHeights ?? (const [24.0, 32.0, 36.0, 40.0, 44.0]),
       black = black ?? (const Color(0xff000000)),
       white = white ?? (const Color(0xffffffff)),
       bgColor = bgColor ?? (const Color(0xffffffff)),
       cardColor = cardColor ?? (const Color(0xffffffff)),
       primary = primary ?? (const Color(0xff409eff)),
       success = success ?? (const Color(0xff67c23a)),
       info = info ?? (const Color(0xff909399)),
       warning = warning ?? (const Color(0xffe6a23c)),
       error = error ?? (const Color(0xfff56c6c)),
       textColorXs = textColorXs ?? (const Color(0xff303133)),
       textColorSm = textColorSm ?? (const Color(0xff606266)),
       textColorMd = textColorMd ?? (const Color(0xff909399)),
       textColorLg = textColorLg ?? (const Color(0xffc0c4cc)),
       textColorXl = textColorXl ?? (const Color(0xffd4d7de)),
       fontSizes = fontSizes ?? (const [13.0, 14.0, 15.0, 15.0, 16.0]),
       iconSizes = iconSizes ?? (const [16.0, 20.0, 24.0, 28.0, 32.0]),
       iconColor = iconColor ?? (const Color(0xff909399)),
       appbarColor = appbarColor ?? (const Color(0xffffffff)),
       borderWidths = borderWidths ?? (const [0.5, 0.75, 1.0, 1.5, 2.0]),
       borderColor = borderColor ?? (const Color(0xffdcdfe6)),
       radiusXs = radiusXs ?? (2.0),
       radiusSm = radiusSm ?? (4.0),
       radiusMd = radiusMd ?? (6.0),
       radiusLg = radiusLg ?? (8.0),
       radiusXl = radiusXl ?? (12.0),
       shadowXs = shadowXs ?? (_shadowLevelsLight[ElLevelType.xs]!),
       shadowSm = shadowSm ?? (_shadowLevelsLight[ElLevelType.sm]!),
       shadowMd = shadowMd ?? (_shadowLevelsLight[ElLevelType.md]!),
       shadowLg = shadowLg ?? (_shadowLevelsLight[ElLevelType.lg]!),
       shadowXl = shadowXl ?? (_shadowLevelsLight[ElLevelType.xl]!),
       shadowColor = shadowColor ?? (_shadowColorLight),
       appbarHeights = appbarHeights ?? (const [56.0, 56.0, 56.0, 56.0, 56.0]),
       indexNormal = indexNormal ?? (1),
       indexPopper = indexPopper ?? (2000),
       indexTop = indexTop ?? (1000),
       maskColor = maskColor ?? (const Color(0xe6ffffff)),
       maskColorExtraLight = maskColorExtraLight ?? (const Color(0x4dffffff)),
       overlayColor = overlayColor ?? (const Color(0xcc000000)),
       overlayColorLight = overlayColorLight ?? (const Color(0xb3000000)),
       overlayColorLighter = overlayColorLighter ?? (const Color(0x80000000)),
       svgMonochromeGrey = svgMonochromeGrey ?? (const Color(0xffdcdfe6)),
       transitionAll =
           transitionAll ??
           (const <ElTransition>[
             ElTransition.all(
               Duration(milliseconds: 300),
               Cubic(0.645, 0.045, 0.355, 1),
             ),
           ]),
       transitionBorder =
           transitionBorder ??
           (const <ElTransition>[
             ElTransition.field(
               ElTransitionField.border,
               Duration(milliseconds: 200),
               Cubic(0.645, 0.045, 0.355, 1),
             ),
           ]),
       transitionBoxShadow =
           transitionBoxShadow ??
           (const <ElTransition>[
             ElTransition.field(
               ElTransitionField.boxShadow,
               Duration(milliseconds: 200),
               Cubic(0.645, 0.045, 0.355, 1),
             ),
           ]),
       transitionColor =
           transitionColor ??
           (const <ElTransition>[
             ElTransition.field(
               ElTransitionField.color,
               Duration(milliseconds: 200),
               Cubic(0.645, 0.045, 0.355, 1),
             ),
           ]),
       transitionDuration =
           transitionDuration ?? (const Duration(milliseconds: 300)),
       transitionDurationFast =
           transitionDurationFast ?? (const Duration(milliseconds: 200)),
       transitionFade =
           transitionFade ??
           (const <ElTransition>[
             ElTransition.field(
               ElTransitionField.opacity,
               Duration(milliseconds: 300),
               Cubic(0.23, 1, 0.32, 1),
             ),
           ]),
       transitionFadeLinear =
           transitionFadeLinear ??
           (const <ElTransition>[
             ElTransition.field(
               ElTransitionField.opacity,
               Duration(milliseconds: 200),
               Curves.linear,
             ),
           ]),
       transitionEaseInOutBezier =
           transitionEaseInOutBezier ?? (const Cubic(0.645, 0.045, 0.355, 1)),
       transitionFastBezier =
           transitionFastBezier ?? (const Cubic(0.23, 1, 0.32, 1)),
       transitionMdFade =
           transitionMdFade ??
           (const <ElTransition>[
             ElTransition.fields(
               {ElTransitionField.transform, ElTransitionField.opacity},
               Duration(milliseconds: 300),
               Cubic(0.23, 1, 0.32, 1),
             ),
           ]);

  /// 此配色对应的亮暗模式。
  final Brightness brightness;

  /// 组件尺寸档位。
  final ElLevelType size;

  /// 五档按钮高度。
  final List<double> buttonHeights;

  /// 黑色。
  final Color black;

  /// 白色。
  final Color white;

  /// 页面背景。
  final Color bgColor;

  /// 卡片背景。
  final Color cardColor;

  /// 主色。
  final Color primary;

  /// 成功色。
  final Color success;

  /// 信息色。
  final Color info;

  /// 警告色。
  final Color warning;

  /// 错误色。
  final Color error;

  /// 正文文字色。
  final Color textColorXs;

  /// 常规文字色。
  final Color textColorSm;

  /// 次要文字色。
  final Color textColorMd;

  /// 占位文字色。
  final Color textColorLg;

  /// 弱化文字色。
  final Color textColorXl;

  /// 五档字号。
  final List<double> fontSizes;

  /// 五档图标尺寸。
  final List<double> iconSizes;

  /// 图标色。
  final Color iconColor;

  /// appbarColor 主题值。
  final Color appbarColor;

  /// 五档边框宽度。
  final List<double> borderWidths;

  /// 边框色。
  final Color borderColor;

  /// radiusXs 主题值。
  final double radiusXs;

  /// radiusSm 主题值。
  final double radiusSm;

  /// radiusMd 主题值。
  final double radiusMd;

  /// radiusLg 主题值。
  final double radiusLg;

  /// radiusXl 主题值。
  final double radiusXl;

  /// shadowXs 主题值。
  final List<BoxShadow> shadowXs;

  /// shadowSm 主题值。
  final List<BoxShadow> shadowSm;

  /// shadowMd 主题值。
  final List<BoxShadow> shadowMd;

  /// shadowLg 主题值。
  final List<BoxShadow> shadowLg;

  /// shadowXl 主题值。
  final List<BoxShadow> shadowXl;

  /// shadowColor 主题值。
  final Color shadowColor;

  /// appbarHeights 主题值。
  final List<double> appbarHeights;

  /// indexNormal 主题值。
  final int indexNormal;

  /// indexPopper 主题值。
  final int indexPopper;

  /// indexTop 主题值。
  final int indexTop;

  /// maskColor 主题值。
  final Color maskColor;

  /// maskColorExtraLight 主题值。
  final Color maskColorExtraLight;

  /// overlayColor 主题值。
  final Color overlayColor;

  /// overlayColorLight 主题值。
  final Color overlayColorLight;

  /// overlayColorLighter 主题值。
  final Color overlayColorLighter;

  /// svgMonochromeGrey 主题值。
  final Color svgMonochromeGrey;

  /// transitionAll 主题值。
  final List<ElTransition> transitionAll;

  /// transitionBorder 主题值。
  final List<ElTransition> transitionBorder;

  /// transitionBoxShadow 主题值。
  final List<ElTransition> transitionBoxShadow;

  /// transitionColor 主题值。
  final List<ElTransition> transitionColor;

  /// transitionDuration 主题值。
  final Duration transitionDuration;

  /// transitionDurationFast 主题值。
  final Duration transitionDurationFast;

  /// transitionFade 主题值。
  final List<ElTransition> transitionFade;

  /// transitionFadeLinear 主题值。
  final List<ElTransition> transitionFadeLinear;

  /// transitionEaseInOutBezier 主题值。
  final Curve transitionEaseInOutBezier;

  /// transitionFastBezier 主题值。
  final Curve transitionFastBezier;

  /// transitionMdFade 主题值。
  final List<ElTransition> transitionMdFade;

  /// 创建暗色主题。
  factory ElThemeData.dark() => ElThemeData(
    brightness: Brightness.dark,
    bgColor: const Color.fromRGBO(30, 30, 30, 1.0),
    cardColor: const Color.fromRGBO(43, 43, 43, 1.0),
    primary: const Color(0xff409eff),
    success: const Color(0xff67c23a),
    info: const Color(0xff909399),
    warning: const Color(0xffe6a23c),
    error: const Color(0xfff56c6c),
    textColorXs: const Color(0xffe5eaf3),
    textColorSm: const Color(0xffcfd3dc),
    textColorMd: const Color(0xffa3a6ad),
    textColorLg: const Color(0xff8d9095),
    textColorXl: const Color(0xff6c6e72),
    iconColor: const Color(0xffa3a6ad),
    appbarColor: const Color.fromRGBO(43, 45, 48, 1.0),
    borderColor: const Color(0xff4c4d4f),
    shadowXs: _shadowLevelsDark[ElLevelType.xs]!,
    shadowSm: _shadowLevelsDark[ElLevelType.sm]!,
    shadowMd: _shadowLevelsDark[ElLevelType.md]!,
    shadowLg: _shadowLevelsDark[ElLevelType.lg]!,
    shadowXl: _shadowLevelsDark[ElLevelType.xl]!,
    shadowColor: _shadowColorDark,
    maskColor: const Color(0xcc000000),
    maskColorExtraLight: const Color(0x4d000000),
  );

  /// 覆盖指定的主题字段，其他字段继续使用当前值。
  ElThemeData copyWith({
    Brightness? brightness,
    ElLevelType? size,
    List<double>? buttonHeights,
    Color? black,
    Color? white,
    Color? bgColor,
    Color? cardColor,
    Color? primary,
    Color? success,
    Color? info,
    Color? warning,
    Color? error,
    Color? textColorXs,
    Color? textColorSm,
    Color? textColorMd,
    Color? textColorLg,
    Color? textColorXl,
    List<double>? fontSizes,
    List<double>? iconSizes,
    Color? iconColor,
    Color? appbarColor,
    List<double>? borderWidths,
    Color? borderColor,
    double? radiusXs,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    List<BoxShadow>? shadowXs,
    List<BoxShadow>? shadowSm,
    List<BoxShadow>? shadowMd,
    List<BoxShadow>? shadowLg,
    List<BoxShadow>? shadowXl,
    Color? shadowColor,
    List<double>? appbarHeights,
    int? indexNormal,
    int? indexPopper,
    int? indexTop,
    Color? maskColor,
    Color? maskColorExtraLight,
    Color? overlayColor,
    Color? overlayColorLight,
    Color? overlayColorLighter,
    Color? svgMonochromeGrey,
    List<ElTransition>? transitionAll,
    List<ElTransition>? transitionBorder,
    List<ElTransition>? transitionBoxShadow,
    List<ElTransition>? transitionColor,
    Duration? transitionDuration,
    Duration? transitionDurationFast,
    List<ElTransition>? transitionFade,
    List<ElTransition>? transitionFadeLinear,
    Curve? transitionEaseInOutBezier,
    Curve? transitionFastBezier,
    List<ElTransition>? transitionMdFade,
  }) => ElThemeData(
    brightness: brightness ?? this.brightness,
    size: size ?? this.size,
    buttonHeights: buttonHeights ?? this.buttonHeights,
    black: black ?? this.black,
    white: white ?? this.white,
    bgColor: bgColor ?? this.bgColor,
    cardColor: cardColor ?? this.cardColor,
    primary: primary ?? this.primary,
    success: success ?? this.success,
    info: info ?? this.info,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    textColorXs: textColorXs ?? this.textColorXs,
    textColorSm: textColorSm ?? this.textColorSm,
    textColorMd: textColorMd ?? this.textColorMd,
    textColorLg: textColorLg ?? this.textColorLg,
    textColorXl: textColorXl ?? this.textColorXl,
    fontSizes: fontSizes ?? this.fontSizes,
    iconSizes: iconSizes ?? this.iconSizes,
    iconColor: iconColor ?? this.iconColor,
    appbarColor: appbarColor ?? this.appbarColor,
    borderWidths: borderWidths ?? this.borderWidths,
    borderColor: borderColor ?? this.borderColor,
    radiusXs: radiusXs ?? this.radiusXs,
    radiusSm: radiusSm ?? this.radiusSm,
    radiusMd: radiusMd ?? this.radiusMd,
    radiusLg: radiusLg ?? this.radiusLg,
    radiusXl: radiusXl ?? this.radiusXl,
    shadowXs: shadowXs ?? this.shadowXs,
    shadowSm: shadowSm ?? this.shadowSm,
    shadowMd: shadowMd ?? this.shadowMd,
    shadowLg: shadowLg ?? this.shadowLg,
    shadowXl: shadowXl ?? this.shadowXl,
    shadowColor: shadowColor ?? this.shadowColor,
    appbarHeights: appbarHeights ?? this.appbarHeights,
    indexNormal: indexNormal ?? this.indexNormal,
    indexPopper: indexPopper ?? this.indexPopper,
    indexTop: indexTop ?? this.indexTop,
    maskColor: maskColor ?? this.maskColor,
    maskColorExtraLight: maskColorExtraLight ?? this.maskColorExtraLight,
    overlayColor: overlayColor ?? this.overlayColor,
    overlayColorLight: overlayColorLight ?? this.overlayColorLight,
    overlayColorLighter: overlayColorLighter ?? this.overlayColorLighter,
    svgMonochromeGrey: svgMonochromeGrey ?? this.svgMonochromeGrey,
    transitionAll: transitionAll ?? this.transitionAll,
    transitionBorder: transitionBorder ?? this.transitionBorder,
    transitionBoxShadow: transitionBoxShadow ?? this.transitionBoxShadow,
    transitionColor: transitionColor ?? this.transitionColor,
    transitionDuration: transitionDuration ?? this.transitionDuration,
    transitionDurationFast:
        transitionDurationFast ?? this.transitionDurationFast,
    transitionFade: transitionFade ?? this.transitionFade,
    transitionFadeLinear: transitionFadeLinear ?? this.transitionFadeLinear,
    transitionEaseInOutBezier:
        transitionEaseInOutBezier ?? this.transitionEaseInOutBezier,
    transitionFastBezier: transitionFastBezier ?? this.transitionFastBezier,
    transitionMdFade: transitionMdFade ?? this.transitionMdFade,
  );

  /// 读取最近主题，支持局部 ElView 的明暗模式。
  static ElThemeData of(
    BuildContext context, {
    Brightness? brightness,
    bool reverse = false,
  }) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ElThemeScope>();
    var axis =
        brightness ??
        ElView.maybeOf(context)?.brightness ??
        scope?.brightness ??
        Brightness.light;
    if (reverse) {
      axis = axis == Brightness.dark ? Brightness.light : Brightness.dark;
    }
    return axis == Brightness.dark
        ? (scope?.dark ?? ElThemeData.dark())
        : (scope?.light ?? ElThemeData());
  }
}

/// 局部覆盖组件主题值或尺寸，不创建应用与弹层根。
class ElTheme extends StatelessWidget {
  /// 未指定的主题沿用最近的明暗主题。
  const ElTheme({
    super.key,
    this.data,
    this.darkData,
    this.size,
    required this.child,
  });

  /// 浅色组件主题。
  final ElThemeData? data;

  /// 暗色组件主题。
  final ElThemeData? darkData;

  /// 覆盖此区域的组件尺寸档位。
  final ElLevelType? size;

  /// 应用主题的内容。
  final Widget child;

  @override
  Widget build(BuildContext context) => _ElThemeScope(
    light: (data ?? ElThemeData.of(context, brightness: Brightness.light))
        .copyWith(size: size),
    dark: (darkData ?? ElThemeData.of(context, brightness: Brightness.dark))
        .copyWith(size: size),
    brightness: ElThemeData.of(context).brightness,
    child: child,
  );
}

class _ElThemeScope extends InheritedWidget {
  const _ElThemeScope({
    required this.light,
    required this.dark,
    required this.brightness,
    required super.child,
  });
  final ElThemeData light, dark;
  final Brightness brightness;
  @override
  bool updateShouldNotify(_ElThemeScope oldWidget) =>
      light != oldWidget.light ||
      dark != oldWidget.dark ||
      brightness != oldWidget.brightness;
}
