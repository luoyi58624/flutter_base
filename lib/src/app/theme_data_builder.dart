part of '../../flutter_base.dart';

ThemeData _buildThemeData(AppConfigData appData, Brightness brightness) {
  bool isDarkMode = brightness == Brightness.dark;
  final lightTheme = appData.theme;
  final darkTheme = appData.darkTheme;
  final appTheme = isDarkMode ? darkTheme : lightTheme;
  final fontFamily = appData.fontFamily;
  final isM3 = appData.useMaterial3;
  Color appbarColor = appTheme.headerColor ?? appTheme.primary;

  if (appData.translucenceStatusBar) {
    DartUtil.delay(() {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Color.fromRGBO(0, 0, 0, 200)));
    }, 200);
  } else {
    DartUtil.delay(() {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Color.fromRGBO(0, 0, 0, 0)));
    }, 200);
  }

  final buttonBorder = appData.buttonRadius != null
      ? RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appData.buttonRadius!),
        )
      : null;
  final buttonStyle = appData.buttonRadius != null
      ? ButtonStyle(
          shape: WidgetStatePropertyAll(buttonBorder),
        )
      : null;

  final cardBorder = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(appData.cardRadius),
  );

  final themeData = ThemeData(
    useMaterial3: isM3,
    colorScheme: isM3
        ? ColorScheme.fromSeed(brightness: brightness, seedColor: appTheme.primary)
        : ColorScheme.fromSwatch(brightness: brightness, primarySwatch: appTheme.primary.toMaterialColor()),
    // 设置全局默认文字主题
    textTheme: _textTheme(appTheme, appData),
    // 是否禁用波纹
    splashFactory: appData.enableRipple ? InkRipple.splashFactory : noRipperFactory,
    // 解决web上material按钮外边距为0问题，与移动端的效果保持一致
    materialTapTargetSize: MaterialTapTargetSize.padded,
    // 标准显示密度
    visualDensity: VisualDensity.standard,
    // 统一页面过渡动画
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    }),
    // 背景颜色
    scaffoldBackgroundColor: appTheme.bgColor,
    // 图标颜色
    iconTheme: IconThemeData(color: appTheme.iconColor),
  );

  return themeData.copyWith(
    buttonTheme: ButtonThemeData(shape: buttonBorder),
    elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
    textButtonTheme: TextButtonThemeData(style: buttonStyle),
    filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
    appBarTheme: AppBarTheme(
      centerTitle: appData.centerTitle,
      toolbarHeight: appData.appbarHeight,
      elevation: appData.appbarElevation,
      scrolledUnderElevation: appData.appbarScrollElevation,
      backgroundColor: appbarColor,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FlutterFont.bold,
        color: appbarColor.isDark ? darkTheme.textColor : lightTheme.textColor,
      ),
      iconTheme: IconThemeData(
        color: appbarColor.isDark ? darkTheme.iconColor : lightTheme.iconColor,
      ),
    ),
    tabBarTheme: TabBarTheme(
      unselectedLabelStyle: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FlutterFont.bold,
        fontSize: 15,
      ),
      labelStyle: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FlutterFont.bold,
        fontSize: 15,
        color: appTheme.primary,
      ),
      unselectedLabelColor: appbarColor.isDark ? darkTheme.textColors[1] : lightTheme.textColor,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      elevation: 2,
      type: BottomNavigationBarType.fixed,
      backgroundColor: appTheme.headerColor,
      unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FlutterFont.medium),
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FlutterFont.bold, color: appTheme.primary),
      unselectedIconTheme: const IconThemeData(size: 26),
      selectedIconTheme: IconThemeData(color: appTheme.primary, size: 26),
    ),
    cardTheme: CardTheme(
      color: appTheme.cardColor,
      // m3会将此颜色和color进行混合从而产生一个新的material颜色 (生成一个淡淡的Primary Color)，
      // 这里将其重置为透明，表示卡片用默认color展示
      surfaceTintColor: Colors.transparent,
      elevation: isDarkMode ? 4 : appData.cardElevation,
      margin: const EdgeInsets.all(8),
      shape: cardBorder,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: appTheme.cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FlutterFont.medium,
        color: appTheme.textColor,
        fontSize: 15,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FlutterFont.normal,
        color: appTheme.textColors[1],
        fontSize: 13,
      ),
      iconColor: appTheme.iconColor,
    ),
    inputDecorationTheme: InputDecorationTheme(
      // border: const OutlineInputBorder(
      //   borderSide: BorderSide(color: Colors.grey),
      // ),
      labelStyle: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FlutterFont.medium),
      hintStyle: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FlutterFont.medium),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      textColor: appTheme.primary,
      shape: Border.all(width: 0, style: BorderStyle.none),
      collapsedShape: Border.all(width: 0, style: BorderStyle.none),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: appTheme.cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: isDarkMode ? 8 : 2,
      enableFeedback: true,
      textStyle: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FlutterFont.normal,
        color: appTheme.textColor,
        fontSize: 14,
      ),
      shape: cardBorder,
    ),
    dialogTheme: DialogTheme(
      titleTextStyle: TextStyle(
        color: appTheme.textColor,
        fontSize: 18,
        fontWeight: FlutterFont.bold,
      ),
      contentTextStyle: TextStyle(
        color: appTheme.textColors[2],
        fontSize: 15,
        fontWeight: FlutterFont.normal,
      ),
      elevation: appData.cardElevation,
      backgroundColor: appTheme.cardColor,
      surfaceTintColor: Colors.transparent,
      shape: cardBorder,
      actionsPadding: const EdgeInsets.all(8),
      insetPadding: EdgeInsets.zero,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      refreshBackgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.white,
      color: isDarkMode ? Colors.white : appTheme.primary,
    ),
    segmentedButtonTheme: const SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          StadiumBorder(side: BorderSide()),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: Colors.grey)),
      ),
    ),
  );
}

CupertinoThemeData _buildCupertinoThemeData(AppConfigData appData, Brightness brightness) {
  AppThemeData theme = brightness == Brightness.light ? appData.theme : appData.darkTheme;
  CupertinoThemeData themeData = CupertinoThemeData(brightness: brightness);
  String? fontFamily = appData.fontFamily ?? themeData.textTheme.textStyle.fontFamily;

  return themeData.copyWith(
    primaryColor: theme.primary,
    textTheme: CupertinoTextThemeData(
      textStyle: themeData.textTheme.textStyle.copyWith(
        fontWeight: FlutterFont.normal,
        fontFamily: fontFamily,
      ),
      tabLabelTextStyle: themeData.textTheme.tabLabelTextStyle.copyWith(
        fontSize: 12,
        fontFamily: fontFamily,
        fontWeight: FlutterFont.normal,
      ),
      navActionTextStyle: themeData.textTheme.navActionTextStyle.copyWith(
        color: theme.primary,
        fontFamily: fontFamily,
        fontWeight: FlutterFont.medium,
        fontSize: 16,
      ),
      navTitleTextStyle: themeData.textTheme.navTitleTextStyle.copyWith(
        fontFamily: fontFamily,
        fontWeight: FlutterFont.medium,
      ),
      navLargeTitleTextStyle: themeData.textTheme.navLargeTitleTextStyle.copyWith(
        fontFamily: fontFamily,
        fontWeight: FlutterFont.normal,
      ),
    ),
  );
}

TextTheme _textTheme(AppThemeData theme, AppConfigData config) {
  return TextTheme(
    displayLarge: TextStyle(
      fontWeight: FlutterFont.bold,
      color: theme.textColor,
      fontFamily: config.fontFamily,
      fontFamilyFallback: config.fontFamilyFallback,
    ),
    displayMedium: TextStyle(
      fontWeight: FlutterFont.medium,
      color: theme.textColor,
      fontFamily: config.fontFamily,
      fontFamilyFallback: config.fontFamilyFallback,
    ),
    displaySmall: TextStyle(
      fontWeight: FlutterFont.medium,
      color: theme.textColor,
      fontFamily: config.fontFamily,
      fontFamilyFallback: config.fontFamilyFallback,
    ),
    headlineLarge: TextStyle(
      fontWeight: FlutterFont.normal,
      color: theme.textColor,
      fontFamily: config.fontFamily,
      fontFamilyFallback: config.fontFamilyFallback,
    ),
    headlineMedium: TextStyle(
      fontWeight: FlutterFont.normal,
      color: theme.textColor,
      fontFamily: config.fontFamily,
      fontFamilyFallback: config.fontFamilyFallback,
    ),
    headlineSmall: TextStyle(
      fontWeight: FlutterFont.normal,
      color: theme.textColor,
      fontFamily: config.fontFamily,
      fontFamilyFallback: config.fontFamilyFallback,
    ),
    titleLarge: TextStyle(
      fontWeight: FlutterFont.bold,
      color: theme.textColor,
      fontFamily: config.fontFamily,
      fontFamilyFallback: config.fontFamilyFallback,
    ),
    titleMedium: TextStyle(
      fontWeight: FlutterFont.bold,
      color: theme.textColor,
      fontFamily: config.fontFamily,
      fontFamilyFallback: config.fontFamilyFallback,
    ),
    titleSmall: TextStyle(
      fontWeight: FlutterFont.bold,
      color: theme.textColor,
      fontFamily: config.fontFamily,
      fontFamilyFallback: config.fontFamilyFallback,
    ),
    bodyLarge: TextStyle(
      fontWeight: FlutterFont.normal,
      color: theme.textColor,
      fontFamily: config.fontFamily,
      fontFamilyFallback: config.fontFamilyFallback,
    ),
    bodyMedium: TextStyle(
      fontWeight: FlutterFont.normal,
      color: theme.textColor,
      fontFamily: config.fontFamily,
      fontFamilyFallback: config.fontFamilyFallback,
    ),
    bodySmall: TextStyle(
      fontWeight: FlutterFont.normal,
      color: theme.textColor,
      fontFamily: config.fontFamily,
      fontFamilyFallback: config.fontFamilyFallback,
    ),
    labelLarge: TextStyle(
      fontWeight: FlutterFont.medium,
      color: theme.textColor,
      fontFamily: config.fontFamily,
      fontFamilyFallback: config.fontFamilyFallback,
    ),
    labelMedium: TextStyle(
      fontWeight: FlutterFont.medium,
      color: theme.textColor,
      fontFamily: config.fontFamily,
      fontFamilyFallback: config.fontFamilyFallback,
    ),
    labelSmall: TextStyle(
      fontWeight: FlutterFont.medium,
      color: theme.textColor,
      fontFamily: config.fontFamily,
      fontFamilyFallback: config.fontFamilyFallback,
    ),
  );
}
