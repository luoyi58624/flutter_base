part of flutter_base;

extension ThemeExtension on BuildContext {
  /// 根据当前[ThemeMode]获取相应的主题配置
  FlutterThemeData get currentTheme =>
      FlutterUtil.isDarkMode(this) ? AppController.of.darkTheme : AppController.of.theme;
}
