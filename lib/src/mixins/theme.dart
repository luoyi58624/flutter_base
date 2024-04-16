part of flutter_base;

/// 主题混入
mixin FlutterThemeMixin<T extends StatefulWidget, D> on State<T> {
  /// 暗色主题文字颜色
  Color get $textWhiteColor => FlutterController.of.darkTheme.textColor;

  /// 亮色主题文字颜色
  Color get $textBlackColor => FlutterController.of.theme.textColor;

  Color get $textColor =>
      FlutterUtil.isDarkMode(context) ? FlutterController.of.darkTheme.textColor : FlutterController.of.theme.textColor;

  Color get $bgColor =>
      FlutterUtil.isDarkMode(context) ? FlutterController.of.darkTheme.bgColor : FlutterController.of.theme.bgColor;

  Color get $headerColor => FlutterUtil.isDarkMode(context)
      ? FlutterController.of.darkTheme.headerColor
      : FlutterController.of.theme.headerColor;

  Color get $primaryColor =>
      FlutterUtil.isDarkMode(context) ? FlutterController.of.darkTheme.primary : FlutterController.of.theme.primary;

  Color get $successColor =>
      FlutterUtil.isDarkMode(context) ? FlutterController.of.darkTheme.success : FlutterController.of.theme.success;

  Color get $infoColor =>
      FlutterUtil.isDarkMode(context) ? FlutterController.of.darkTheme.info : FlutterController.of.theme.info;

  Color get $warningColor =>
      FlutterUtil.isDarkMode(context) ? FlutterController.of.darkTheme.warning : FlutterController.of.theme.warning;

  Color get $errorColor =>
      FlutterUtil.isDarkMode(context) ? FlutterController.of.darkTheme.error : FlutterController.of.theme.error;

  Color get $defaultBorderColor => FlutterUtil.isDarkMode(context)
      ? FlutterController.of.darkTheme.defaultBorderColor
      : FlutterController.of.theme.defaultBorderColor;

  double get $radius => FlutterController.of.config.radius;

  FontWeight get $defaultFontWeight => FlutterController.of.config.defaultFontWeight;
}
