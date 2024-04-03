part of flutter_base;

/// 主题混入
mixin FlutterThemeMixin<T extends StatefulWidget, D> on State<T> {
  /// 暗色主题文字颜色
  Color get $textWhiteColor => FlutterAppData.of(context).darkTheme.textColor;

  /// 亮色主题文字颜色
  Color get $textBlackColor => FlutterAppData.of(context).theme.textColor;

  Color get $textColor => FlutterAppData.of(context).currentTheme.textColor;

  Color get $bgColor => FlutterAppData.of(context).currentTheme.bgColor;

  Color get $headerColor => FlutterAppData.of(context).currentTheme.headerColor;

  Color get $primaryColor => FlutterAppData.of(context).currentTheme.primary;

  Color get $successColor => FlutterAppData.of(context).currentTheme.success;

  Color get $infoColor => FlutterAppData.of(context).currentTheme.info;

  Color get $warningColor => FlutterAppData.of(context).currentTheme.warning;

  Color get $errorColor => FlutterAppData.of(context).currentTheme.error;

  Color get $defaultBorderColor => FlutterAppData.of(context).currentTheme.defaultBorderColor;

  double get $radius => FlutterAppData.of(context).config.radius;

  FontWeight get $defaultFontWeight => FlutterAppData.of(context).config.defaultFontWeight;

  Color get $menuActiveColor => FlutterAppData.of(context).currentTheme.menuActiveColor;
}
