part of flutter_base;

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
    required this.router,
    this.localizationsDelegates,
    this.supportedLocales,
    this.locale = const Locale('zh', 'CN'),
    this.builder,
  });

  /// App标题
  final String title;

  /// 声明式路由配置
  ///
  /// 示例：
  /// ``` dart
  /// final router = GoRouter(
  ///   navigatorKey: RouterUtil.rootNavigatorKey,
  ///   routes: [
  ///     GoRoute(path: '/', builder: (context, state) => HomePage()),
  ///   ],
  /// );
  /// ```
  final GoRouter router;

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

  final TransitionBuilder? builder;

  @override
  Widget build(BuildContext context) {
    FlutterController c = Get.find();
    var $localizationsDelegates = (localizationsDelegates ?? []).toList();
    $localizationsDelegates.addAll(_localizationsDelegates);
    var $supportedLocales = (supportedLocales ?? []).toList();
    $supportedLocales.addAll(_supportedLocales);
    return Obx(() => MaterialApp.router(
          routerConfig: router,
          theme: AppThemeUtil.buildMaterialhemeData(c.theme, c.config),
          darkTheme: AppThemeUtil.buildMaterialhemeData(c.darkTheme, c.config),
          themeMode: c.themeMode,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: $localizationsDelegates,
          supportedLocales: $supportedLocales,
          locale: locale,
          showPerformanceOverlay: c.config.showPerformanceOverlay,
          builder: (context, child) {
            return MediaQuery(
              // 解决modal_bottom_sheet在高版本安卓系统上动画丢失
              data: MediaQuery.of(context).copyWith(accessibleNavigation: false),
              // 解决使用cupertino组件时文字渲染异常
              child: Material(
                // 注入默认的cupertino主题
                child: CupertinoTheme(
                  data: AppThemeUtil.buildCupertinoThemeData(c.getTheme(context), c.config),
                  child: Overlay(
                    initialEntries: [
                      OverlayEntry(builder: (context) {
                        toast.init(context);
                        return builder == null ? child! : builder!(context, child);
                      })
                    ],
                  ),
                ),
              ),
            );
          },
        ));
  }
}

class AppThemeUtil {
  AppThemeUtil._();

  /// 构建MaterialApp主题数据
  static ThemeData buildMaterialhemeData(FlutterThemeData theme, FlutterConfigData config) {
    Color appbarBackground = theme.brightness == Brightness.light ? Colors.white : const Color(0xff0f0f0f);
    Color bodyBackground = theme.brightness == Brightness.light ? const Color(0xfffafafa) : const Color(0xff2b2b2b);
    // 默认的图标、文字颜色
    Color defaultIconTextColor = theme.brightness == Brightness.light ? Colors.grey.shade900 : Colors.grey.shade100;
    ColorScheme colorScheme = ColorScheme.fromSeed(
      brightness: theme.brightness,
      seedColor: theme.primary,
    );
    var $theme = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    return ThemeData(
      useMaterial3: FlutterController.of.config.useMaterial3,
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
      fontFamily: config.fontFamily ?? (GetPlatform.isWindows ? "微软雅黑" : null),
      textTheme: _buildTextTheme(config),
      splashFactory: config.enableRipple ? InkRipple.splashFactory : noRipperFactory,
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
        centerTitle: config.centerTitle,
        toolbarHeight: config.headerHeight,
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

  static CupertinoThemeData buildCupertinoThemeData(FlutterThemeData theme, FlutterConfigData config) {
    var textTheme = CupertinoThemeData(brightness: theme.brightness).textTheme;
    return CupertinoThemeData(
      // brightness: theme.brightness,
      primaryColor: theme.primary,
      textTheme: CupertinoTextThemeData(
        textStyle: textTheme.textStyle.copyWith(
          fontWeight: config.defaultFontWeight,
          fontFamily: config.fontFamily,
        ),
        tabLabelTextStyle: textTheme.tabLabelTextStyle.copyWith(
          fontSize: 12,
          fontFamily: config.fontFamily,
        ),
        navActionTextStyle: textTheme.navActionTextStyle.copyWith(
          fontWeight: config.defaultFontWeight,
          color: theme.primary,
          fontFamily: config.fontFamily,
        ),
      ),
    );
  }

  /// material文字主题
  static TextTheme _buildTextTheme(FlutterConfigData config) {
    return TextTheme(
      displaySmall: TextStyle(
        fontWeight: config.defaultFontWeight,
      ),
      displayMedium: TextStyle(
        fontWeight: config.defaultFontWeight,
      ),
      displayLarge: TextStyle(
        fontWeight: config.defaultFontWeight,
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
        fontWeight: config.defaultFontWeight,
      ),
      bodyMedium: TextStyle(
        fontWeight: config.defaultFontWeight,
      ),
      bodyLarge: TextStyle(
        fontWeight: config.defaultFontWeight,
      ),
      labelSmall: TextStyle(
        fontWeight: config.defaultFontWeight,
      ),
      labelMedium: TextStyle(
        fontWeight: config.defaultFontWeight,
      ),
      labelLarge: TextStyle(
        fontWeight: config.defaultFontWeight,
      ),
    );
  }
}
