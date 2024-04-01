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
    this.home,
    this.routes,
    this.theme,
    this.darkTheme,
    this.themeMode = ThemeMode.system,
    this.onGenerateRoute,
    this.navigatorObservers = const <NavigatorObserver>[],
    this.localizationsDelegates,
    this.supportedLocales,
    this.locale = const Locale('zh', 'CN'),
    this.showPerformanceOverlay = false,
    this.builder,
  });

  /// App标题
  final String title;

  /// 首屏页面，如果设置[routes]，则此参数无效
  final Widget? home;

  /// [go_router]路由集合
  final List<RouteBase>? routes;

  /// Material亮色主题
  final ThemeData? theme;

  /// 当设备设置为黑暗模式时App使用的主题
  final ThemeData? darkTheme;

  /// 主题模式
  final ThemeMode themeMode;

  /// 自定义生成首屏页，此选项一般用于拦截用户是否登录
  final RouteFactory? onGenerateRoute;

  /// 监听路由跳转
  final List<NavigatorObserver> navigatorObservers;

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
    if (routes != null) {
      router = FlutterRouter(routes: routes!);
    } else {
      assert(home != null, '必须设置home或routes其中一个参数');
      router = FlutterRouter(routes: [GoRoute(path: '/', builder: (contex, state) => home!)]);
    }
    var $localizationsDelegates = (localizationsDelegates ?? []).toList();
    $localizationsDelegates.addAll(_localizationsDelegates);

    var $supportedLocales = (supportedLocales ?? []).toList();
    $supportedLocales.addAll(_supportedLocales);
    ThemeData? $theme;
    ThemeData? $darkTheme;
    switch (themeMode) {
      case ThemeMode.system:
        $theme = appTheme.buildThemeData();
        $darkTheme = appTheme.buildThemeData(brightness: Brightness.dark);
      case ThemeMode.light:
        $theme = appTheme.buildThemeData();
      case ThemeMode.dark:
        $theme = appTheme.buildThemeData(brightness: Brightness.dark);
    }
    return MaterialApp.router(
      routerConfig: router._router,
      theme: $theme,
      darkTheme: $darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: $localizationsDelegates,
      supportedLocales: $supportedLocales,
      locale: locale,
      showPerformanceOverlay: showPerformanceOverlay,
      builder: builder,
    );
  }
}
