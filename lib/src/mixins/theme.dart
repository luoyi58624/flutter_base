part of flutter_base;

/// 主题混入
mixin FlutterThemeMixin<T extends StatefulWidget, D> on State<T> {
  /// 暗色主题文字颜色
  Color get $textWhiteColor => AppController.of.darkTheme.textColor;

  /// 亮色主题文字颜色
  Color get $textBlackColor => AppController.of.theme.textColor;

  Color get $textColor =>
      FlutterUtil.isDarkMode(context) ? AppController.of.darkTheme.textColor : AppController.of.theme.textColor;

  Color get $bgColor =>
      FlutterUtil.isDarkMode(context) ? AppController.of.darkTheme.bgColor : AppController.of.theme.bgColor;

  Color get $headerColor => FlutterUtil.isDarkMode(context)
      ? AppController.of.darkTheme.headerColor
      : AppController.of.theme.headerColor;

  Color get $primaryColor =>
      FlutterUtil.isDarkMode(context) ? AppController.of.darkTheme.primary : AppController.of.theme.primary;

  Color get $successColor =>
      FlutterUtil.isDarkMode(context) ? AppController.of.darkTheme.success : AppController.of.theme.success;

  Color get $infoColor =>
      FlutterUtil.isDarkMode(context) ? AppController.of.darkTheme.info : AppController.of.theme.info;

  Color get $warningColor =>
      FlutterUtil.isDarkMode(context) ? AppController.of.darkTheme.warning : AppController.of.theme.warning;

  Color get $errorColor =>
      FlutterUtil.isDarkMode(context) ? AppController.of.darkTheme.error : AppController.of.theme.error;

  Color get $defaultBorderColor => FlutterUtil.isDarkMode(context)
      ? AppController.of.darkTheme.defaultBorderColor
      : AppController.of.theme.defaultBorderColor;

  double get $radius => AppController.of.config.radius;

  FontWeight get $defaultFontWeight => AppController.of.config.defaultFontWeight;
}
