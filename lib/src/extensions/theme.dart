part of flutter_base;

extension FlutterBaseThemeExtension on BuildContext {
  /// 根据当前[ThemeMode]获取相应的主题配置
  AppThemeData get currentTheme => isDarkMode
      ? AppController.of?.darkTheme ?? AppController._defaultDarkTheme
      : AppController.of?.theme ?? AppController._defaultTheme;
}
