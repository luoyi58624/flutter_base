part of flutter_base;

/// 第一次使用MyApp时创建的context，防止用户嵌套多个MyApp或其他顶级App时重复初始化某些内容，例如[globalNavigatorKey],[initBuilder]
BuildContext? _initContext;

/// 默认的国际化配置
const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
  GlobalWidgetsLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// 默认支持的语言
const _supportedLocales = [
  Locale('zh', 'CH'),
  Locale('en', 'US'),
];

class FlutterApp extends StatelessWidget {
  const FlutterApp({
    super.key,
    this.title = 'Flutter App',
    this.theme,
    this.darkTheme,
    this.themeMode = ThemeMode.system,
    this.onGenerateRoute,
    this.localizationsDelegates,
    this.supportedLocales,
    this.locale = const Locale('zh', 'CN'),
    this.showPerformanceOverlay = false,
    this.builder,
  });

  /// App标题
  final String title;

  /// Material亮色主题
  final ThemeData? theme;

  /// 当设备设置为黑暗模式时App使用的主题
  final ThemeData? darkTheme;

  /// 主题模式
  final ThemeMode themeMode;

  /// 自定义生成首屏页，此选项一般用于拦截用户是否登录
  final RouteFactory? onGenerateRoute;

  /// 国际化配置，你传入的新配置将合并至默认配置，默认配置为：
  /// ```dart
  /// [
  ///  GlobalWidgetsLocalizations.delegate,
  ///  GlobalMaterialLocalizations.delegate,
  ///  GlobalCupertinoLocalizations.delegate,
  /// ]
  /// ```
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;

  /// 支持的语言数组，你传入的新配置将合并至默认配置，默认配置为：
  /// ```dart
  /// [
  ///   Locale('zh', 'CH'),
  ///   Locale('en', 'US'),
  /// ]
  final Iterable<Locale>? supportedLocales;

  /// 默认的语言，默认为：const Locale('zh', 'CN')
  final Locale locale;

  /// 是否开启性能视图
  final bool showPerformanceOverlay;

  final TransitionBuilder? builder;

  @override
  Widget build(BuildContext context) {
    var $localizationsDelegates = (localizationsDelegates ?? []).toList();
    $localizationsDelegates.addAll(_localizationsDelegates);
    var $supportedLocales = (supportedLocales ?? []).toList();
    $supportedLocales.addAll(_supportedLocales);
    ThemeData? $theme;
    ThemeData? $darkTheme;
    switch (themeMode) {
      case ThemeMode.system:
        $theme = _buildThemeData();
        $darkTheme = _buildThemeData(brightness: Brightness.dark);
      case ThemeMode.light:
        $theme = _buildThemeData();
      case ThemeMode.dark:
        $theme = _buildThemeData(brightness: Brightness.dark);
    }
    return MaterialApp.router(
      routerConfig: router.instance,
      theme: $theme,
      darkTheme: $darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: $localizationsDelegates,
      supportedLocales: $supportedLocales,
      locale: locale,
      showPerformanceOverlay: showPerformanceOverlay,
      builder: (context, child) {
        _initContext ??= context;
        if (_initContext != context) {
          return child!;
        } else {
          var textTheme = const CupertinoThemeData().textTheme;
          return Overlay(
            initialEntries: [
              OverlayEntry(builder: (context) {
                toast.init(context);
                return MediaQuery(
                  // 解决modal_bottom_sheet在高版本安卓系统上动画丢失
                  data: MediaQuery.of(context).copyWith(accessibleNavigation: false),
                  // 解决使用cupertino组件时文字渲染异常
                  child: Material(
                    // 注入默认的cupertino主题
                    child: CupertinoTheme(
                      data: CupertinoThemeData(
                        primaryColor: appTheme.primaryColor,
                        textTheme: CupertinoTextThemeData(
                          textStyle: textTheme.textStyle.copyWith(
                            fontWeight: appTheme.defaultFontWeight,
                            fontFamily: appTheme.fontFamily,
                          ),
                          tabLabelTextStyle: textTheme.tabLabelTextStyle.copyWith(
                            fontSize: 12,
                            fontFamily: appTheme.fontFamily,
                          ),
                          navActionTextStyle: textTheme.navActionTextStyle.copyWith(
                            fontWeight: appTheme.defaultFontWeight,
                            color: appTheme.primaryColor,
                            fontFamily: appTheme.fontFamily,
                          ),
                        ),
                      ),
                      child: builder == null ? child! : builder!(context, child),
                    ),
                  ),
                );
              }),
            ],
          );
        }
      },
    );
  }

  /// 构建MaterialApp主题数据
  ThemeData _buildThemeData({
    Brightness brightness = Brightness.light, // 指定亮色主题或黑色主题
  }) {
    Color appbarBackground = brightness == Brightness.light ? Colors.white : const Color(0xff0f0f0f);
    Color bodyBackground = brightness == Brightness.light ? const Color(0xfffafafa) : const Color(0xff2b2b2b);
    // 默认的图标、文字颜色
    Color defaultIconTextColor = brightness == Brightness.light ? Colors.grey.shade900 : Colors.grey.shade100;
    ColorScheme colorScheme = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: appTheme.primaryColor,
    );
    var $theme = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    return ThemeData(
      useMaterial3: true,
      // 解决web上material按钮外边距为0问题，与移动端的效果保持一致
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      // 统一页面过渡动画，为了保证ios的兼容性(手指滑动页面返回)，必须以ios过渡动画为主
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      }),
      // 根据主题色创建material3的主题系统
      colorScheme: colorScheme,
      fontFamily: appTheme.fontFamily,
      textTheme: _textTheme,
      splashFactory: appTheme.enableRipple ? InkRipple.splashFactory : noRipperFactory,
      scaffoldBackgroundColor: bodyBackground,
      cardTheme: const CardTheme(
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        textColor: $theme.primaryColor,
        shape: Border.all(width: 0, style: BorderStyle.none),
        collapsedShape: Border.all(width: 0, style: BorderStyle.none),
      ),
      appBarTheme: $theme.appBarTheme.copyWith(
        centerTitle: appTheme.centerTitle,
        scrolledUnderElevation: 0,
        backgroundColor: appbarBackground,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: defaultIconTextColor,
        ),
        iconTheme: IconThemeData(
          color: defaultIconTextColor,
        ),
      ),
      iconTheme: IconThemeData(
        color: defaultIconTextColor,
      ),
    );
  }

  /// material文字主题
  get _textTheme => TextTheme(
        displaySmall: TextStyle(
          fontWeight: appTheme.defaultFontWeight,
        ),
        displayMedium: TextStyle(
          fontWeight: appTheme.defaultFontWeight,
        ),
        displayLarge: TextStyle(
          fontWeight: appTheme.defaultFontWeight,
        ),
        titleSmall: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
        titleLarge: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
        bodySmall: TextStyle(
          fontWeight: appTheme.defaultFontWeight,
        ),
        bodyMedium: TextStyle(
          fontWeight: appTheme.defaultFontWeight,
        ),
        bodyLarge: TextStyle(
          fontWeight: appTheme.defaultFontWeight,
        ),
        labelSmall: TextStyle(
          fontWeight: appTheme.defaultFontWeight,
        ),
        labelMedium: TextStyle(
          fontWeight: appTheme.defaultFontWeight,
        ),
        labelLarge: TextStyle(
          fontWeight: appTheme.defaultFontWeight,
        ),
      );
}
