part of flutter_base;

extension ThemeExtension on BuildContext {
  /// 根据当前[ThemeMode]获取相应的主题配置
  AppThemeData get currentTheme => FlutterUtil.isDarkMode(this) ? AppController.of.darkTheme : AppController.of.theme;

  Color colorHover(Color color) => color.deepen(AppController.of.config.hoverScale);

  Color colorTap(Color color) => color.deepen(AppController.of.config.tapScale);
}
