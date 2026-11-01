import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_base/ui.dart';

import '../flutter/views/view/render/render_view.dart' show ViewStateRenderAccess;
import '../flutter/views/view/style/cascade/resolver.dart' show StyleResolver;
import '../flutter/views/view/style/resolved/resolved_style.dart' show InheritedText, ResolvedStyle;
import '../flutter/views/view/style/state/view_state.dart' show ViewState;
import '../flutter/views/view/style/style_context.dart' show StyleDependencyScope, BuildDependencySource;

part 'material_theme_vars.dart';

/// 将当前 ElView 主题变量转换为官方 Material 组件样式。
extension ElMaterialThemeExt on BuildContext {
  /// 跟随最近 ElView 的明暗状态，未安装视图主题时沿用官方 Theme 的明暗。
  ThemeData get elMaterialThemeData => elMaterialTheme(ElView.maybeOf(this)?.brightness ?? Theme.of(this).brightness);

  /// 按指定明暗轴生成主题，可同时传入 MaterialApp.theme / darkTheme。
  ///
  /// 保留变量及字体样式的级联与 onDark 覆写，未配置字体时沿用 Flutter 默认。
  ThemeData elMaterialTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final isDesktop = ElPlatform.isDesktop;

    final source = _materialStyle(this, brightness);
    final vars = source.vars;
    T read<T extends Object>(Object key) {
      final value = vars[key];
      return value is T ? value : ElTheme.lightVars[key] as T;
    }

    final primary = read<Color>(ElTheme.$primary);
    final error = read<Color>(ElTheme.$error);

    final bgColor = read<Color>(ElTheme.$bgColor);
    final cardColor = read<Color>(ElTheme.$cardColor);
    final fillColorLight = brightness == Brightness.dark ? const Color(0xff262727) : const Color(0xfff5f7fa);

    final textColor = read<Color>(ElTheme.$textColor);
    final regularTextColor = read<Color>(ElTheme.$textRegular);
    final secondaryTextColor = read<Color>(ElTheme.$textSecondary);
    final placeholderColor = read<Color>(ElTheme.$textPlaceholder);
    final disabledTextColor = placeholderColor;

    final borderColor = read<Color>(ElTheme.$borderColor);
    final dividerColor = read<Color>(ElTheme.$dividerColor);
    final borderColorLight = _shade(borderColor, brightness, 3);
    final borderWidth = read<num>(ElTheme.$borderWidth).toDouble();
    final borderRadius = BorderRadius.circular(read<num>(ElTheme.$radiusSm).toDouble());
    // 沿用旧桥的卡片预设：圆角取通用 lg 档，描边取浅边框色。
    final cardRadius = BorderRadius.circular(read<num>(ElTheme.$radiusLg).toDouble());
    final cardHairlineColor = _shade(borderColor, brightness, 5);

    final text = source.text;
    final fontSize = text?.fontSize ?? 15.0;
    double size(double preset) => preset * fontSize / 15;
    FontWeight weight(Object key) => FontWeight.values[((read<num>(key) / 100).round() - 1).clamp(0, 8)];
    final family = text?.fontFamily ?? read<String>(ElTheme.$fontFamily);
    final fallback = text?.fontFamilyFallback ?? read<List<String>>(ElTheme.$fontFamilyFallback);
    // 只转接实际继承的字体属性，不自行生成字体族、回退表或可变轴。
    final typography = TextStyle(
      fontStyle: text?.fontStyle,
      height: text?.lineHeight,
      leadingDistribution: text?.leadingDistribution,
      letterSpacing: text?.letterSpacing,
      wordSpacing: text?.wordSpacing,
      fontFeatures: text?.fontFeatureSettings,
      fontVariations: text?.fontVariationSettings,
      textBaseline: text?.textBaseline,
    );
    final bodyWeight = text?.fontWeight ?? weight(ElTheme.$fontWeight);
    final actionWeight = weight(ElTheme.$fontWeightAction);
    final subtitleWeight = weight(ElTheme.$fontWeightSubtitle);
    final titleWeight = weight(ElTheme.$fontWeightTitle);
    TextTheme adaptTextTheme(TextTheme theme) {
      TextStyle? apply(TextStyle? style, FontWeight fontWeight) => style
          ?.merge(typography)
          .copyWith(fontSize: style.fontSize == null ? null : size(style.fontSize!), fontWeight: fontWeight);
      return TextTheme(
        displayLarge: apply(theme.displayLarge, titleWeight),
        displayMedium: apply(theme.displayMedium, titleWeight),
        displaySmall: apply(theme.displaySmall, titleWeight),
        headlineLarge: apply(theme.headlineLarge, titleWeight),
        headlineMedium: apply(theme.headlineMedium, titleWeight),
        headlineSmall: apply(theme.headlineSmall, titleWeight),
        titleLarge: apply(theme.titleLarge, titleWeight),
        titleMedium: apply(theme.titleMedium, subtitleWeight),
        titleSmall: apply(theme.titleSmall, subtitleWeight),
        bodyLarge: apply(theme.bodyLarge, bodyWeight),
        bodyMedium: apply(theme.bodyMedium, bodyWeight),
        bodySmall: apply(theme.bodySmall, bodyWeight),
        labelLarge: apply(theme.labelLarge, actionWeight),
        labelMedium: apply(theme.labelMedium, actionWeight),
        labelSmall: apply(theme.labelSmall, actionWeight),
      );
    }

    final colorScheme = ColorScheme.fromSeed(brightness: brightness, seedColor: primary).copyWith(
      // fromSeed 会派生 M3 色调板，将主要语义槽还原为实际主题变量。
      primary: primary,
      onPrimary: _onColor(primary),
      error: error,
      onError: _onColor(error),
      surface: bgColor,
      onSurface: textColor,
      surfaceContainerLowest: cardColor,
      surfaceContainerLow: cardColor,
      surfaceContainer: bgColor,
      outline: borderColor,
      outlineVariant: borderColorLight,
    );

    final themeData = ThemeData(
      useMaterial3: true,
      fontFamily: family.isEmpty ? null : family,
      fontFamilyFallback: fallback.isEmpty ? null : fallback,
      colorScheme: colorScheme,
      canvasColor: bgColor,
      scaffoldBackgroundColor: bgColor,
      dividerColor: dividerColor,
      splashFactory: isDesktop ? InkRipple.splashFactory : InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: isDesktop ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
      // 图标只同步颜色，AppBar / ListTile 等官方组件继续决定尺寸。
      iconTheme: IconThemeData(color: secondaryTextColor),
    );

    final textTheme = adaptTextTheme(themeData.textTheme);
    final normalTextStyle = textTheme.bodyMedium!.copyWith(
      fontSize: fontSize,
      color: textColor,
      fontWeight: bodyWeight,
    );
    final mediumTextStyle = normalTextStyle.copyWith(fontWeight: actionWeight);
    final boldTextStyle = normalTextStyle.copyWith(fontWeight: titleWeight);

    final buttonStyle = ButtonStyle(textStyle: WidgetStatePropertyAll(mediumTextStyle));
    final cardShape = RoundedRectangleBorder(borderRadius: cardRadius);

    final inputRadius = BorderRadius.circular(read<num>(ElTheme.$radiusSm).toDouble());
    final inputBorder = OutlineInputBorder(
      borderRadius: inputRadius,
      borderSide: BorderSide(
        color: read<Color>(ElTheme.$borderColor),
        width: borderWidth,
        strokeAlign: BorderSide.strokeAlignOutside,
      ),
    );

    return themeData.copyWith(
      // 官方按语言选择排版几何；在各语言表上缩放，避免提前固定为某种文字体系。
      typography: themeData.typography.copyWith(
        englishLike: themeData.typography.englishLike.apply(fontSizeFactor: fontSize / 15),
        dense: themeData.typography.dense.apply(fontSizeFactor: fontSize / 15),
        tall: themeData.typography.tall.apply(fontSizeFactor: fontSize / 15),
      ),
      primaryTextTheme: adaptTextTheme(themeData.primaryTextTheme),
      textTheme: textTheme.copyWith(
        titleLarge: boldTextStyle.copyWith(fontSize: size(20)),
        bodyMedium: normalTextStyle,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      floatingActionButtonTheme: FloatingActionButtonThemeData(extendedTextStyle: mediumTextStyle),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            StadiumBorder(
              side: BorderSide(color: borderColor, width: borderWidth),
            ),
          ),
          textStyle: WidgetStatePropertyAll(mediumTextStyle),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: read<Color>(ElTheme.$primary),
        inactiveTrackColor: _shade(borderColor, brightness, 3),
        showValueIndicator: ShowValueIndicator.onDrag,
        valueIndicatorTextStyle: normalTextStyle.copyWith(color: _onColor(primary)),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return fillColorLight;
          }
          return states.contains(WidgetState.selected)
              ? read<Color>(ElTheme.$primary)
              : read<Color>(ElTheme.$borderColor);
        }),
        // M3 未选中滑块默认取 colorScheme.outline（被钉成 borderColor 浅灰）→ 与轨道同色隐形，
        // hover/focus 还会跳成 fromSeed 的浅蓝紫 primaryContainer；钉死 Element 风格滑块恒白
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled) ? placeholderColor : Colors.white,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: read<Color>(ElTheme.$cardColor),
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
        // M3 默认阴影透明，显式着色才能显示滚动后的海拔阴影。
        shadowColor: Colors.black,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        toolbarHeight: 56.0,
        titleTextStyle: boldTextStyle.copyWith(fontSize: size(18), color: textColor),
        iconTheme: IconThemeData(color: secondaryTextColor),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: mediumTextStyle.copyWith(color: primary),
        labelColor: primary,
        unselectedLabelStyle: mediumTextStyle,
        unselectedLabelColor: regularTextColor,
        indicatorColor: primary,
        dividerColor: dividerColor,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgColor,
        // 色阶按**目标轴**现算，不能读 context 的明暗态——本方法可能在亮色页面里
        // 构建整份暗色主题
        indicatorColor: _shade(primary, brightness, 9),
        labelTextStyle: WidgetStatePropertyAll(mediumTextStyle.copyWith(fontSize: size(12))),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 4,
        enableFeedback: true,
        type: BottomNavigationBarType.fixed,
        backgroundColor: bgColor,
        unselectedLabelStyle: mediumTextStyle.copyWith(fontSize: size(12)),
        selectedLabelStyle: mediumTextStyle.copyWith(fontSize: size(12), color: primary),
        unselectedItemColor: secondaryTextColor,
        selectedItemColor: primary,
        selectedIconTheme: IconThemeData(color: primary),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        // M3 会把 surfaceTint 混进 color 里染出一层淡淡的 primary，重置为透明
        // 表示卡片就用 color 本身
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: .zero,
        shape: cardShape.copyWith(
          side: BorderSide(color: cardHairlineColor, width: borderWidth),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: read<Color>(ElTheme.$cardColor),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
      ),
      dividerTheme: DividerThemeData(color: dividerColor, thickness: borderWidth, space: borderWidth),
      listTileTheme: ListTileThemeData(
        titleTextStyle: mediumTextStyle,
        subtitleTextStyle: mediumTextStyle.copyWith(color: secondaryTextColor, fontSize: size(13)),
        iconColor: secondaryTextColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: mediumTextStyle,
        hintStyle: normalTextStyle.copyWith(color: placeholderColor),
        contentPadding: const .all(8),
        // 清除默认图标限制（48*48），否则输入框低于 48 像素时图标会被压扁
        prefixIconConstraints: const BoxConstraints(maxWidth: 48, maxHeight: 48),
        suffixIconConstraints: const BoxConstraints(maxWidth: 48, maxHeight: 48),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: read<Color>(ElTheme.$primary),
            width: borderWidth,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: borderColorLight,
            width: borderWidth,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        textColor: primary,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        enableFeedback: true,
        textStyle: normalTextStyle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(read<num>(ElTheme.$radiusSm).toDouble())),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: read<Color>(ElTheme.$textColor),
          borderRadius: BorderRadius.circular(read<num>(ElTheme.$radiusSm).toDouble()),
        ),
        textStyle: normalTextStyle.copyWith(color: isDark ? textColor : bgColor, fontSize: size(13)),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: boldTextStyle.copyWith(fontSize: size(18)),
        contentTextStyle: normalTextStyle.copyWith(color: regularTextColor),
        elevation: 6,
        backgroundColor: read<Color>(ElTheme.$bgColor),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(read<num>(ElTheme.$radiusSm).toDouble())),
        actionsPadding: const .all(8),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        headerHeadlineStyle: normalTextStyle,
        headerHelpStyle: normalTextStyle,
        weekdayStyle: normalTextStyle,
        dayStyle: normalTextStyle,
        yearStyle: normalTextStyle,
        rangePickerHeaderHelpStyle: normalTextStyle,
        rangePickerHeaderHeadlineStyle: normalTextStyle,
        cancelButtonStyle: buttonStyle,
        confirmButtonStyle: buttonStyle,
      ),
      timePickerTheme: themeData.timePickerTheme.copyWith(
        backgroundColor: bgColor,
        dayPeriodTextStyle: normalTextStyle,
        helpTextStyle: normalTextStyle,
        dialTextStyle: normalTextStyle.copyWith(fontSize: size(18)),
        hourMinuteTextStyle: normalTextStyle.copyWith(fontSize: size(48)),
        cancelButtonStyle: buttonStyle,
        confirmButtonStyle: buttonStyle,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: fillColorLight,
        refreshBackgroundColor: bgColor,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: fillColorLight,
        disabledColor: fillColorLight,
        labelStyle: normalTextStyle.copyWith(fontSize: size(14)),
        side: BorderSide(color: borderColorLight, width: borderWidth),
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: read<Color>(ElTheme.$textColor),
        contentTextStyle: normalTextStyle.copyWith(color: isDark ? textColor : bgColor),
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      disabledColor: disabledTextColor,
      hintColor: placeholderColor,
    );
  }
}

/// 按底色亮度选择可读前景色。
Color _onColor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark ? Colors.white : Colors.black;

/// 按目标明暗轴派生色阶，不能受当前 context 的明暗影响。
Color _shade(Color color, Brightness brightness, int level) => brightness == Brightness.dark
    ? color.mix(const Color(0xff222222), level * 9)
    : color.mix(const Color(0xffffffff), level * 10);
