part of flutter_base;

extension AppThemeExtension on BuildContext {
  /// 根据当前[ThemeMode]获取相应的主题配置
  AppThemeData get currentTheme => FlutterUtil.isDarkMode(this) ? AppController.of.darkTheme : AppController.of.theme;
}
