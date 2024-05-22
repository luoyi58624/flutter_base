part of '../../flutter_base.dart';

extension AppContextExtension on BuildContext {
  /// 全局配置数据
  AppConfigData get appConfig => AppWidget.of(this);

  /// 当前主题数据
  AppThemeData get appTheme => BrightnessWidget.isDark(this) ? appConfig.darkTheme : appConfig.theme;

  /// 标题1 - 28px
  TextStyle get h1 => TextStyle(
        fontFamily: appConfig.fontFamily,
        fontWeight: FlutterFont.bold,
        fontSize: 28,
        color: appTheme.textColor,
      );

  /// 标题2 - 24px
  TextStyle get h2 => TextStyle(
        fontFamily: appConfig.fontFamily,
        fontWeight: FlutterFont.bold,
        fontSize: 24,
        color: appTheme.textColor,
      );

  /// 标题3 - 20px
  TextStyle get h3 => TextStyle(
        fontFamily: appConfig.fontFamily,
        fontWeight: FlutterFont.bold,
        fontSize: 20,
        color: appTheme.textColor,
      );

  /// 标题4 - 18px
  TextStyle get h4 => TextStyle(
        fontFamily: appConfig.fontFamily,
        fontWeight: FlutterFont.bold,
        fontSize: 18,
        color: appTheme.textColor,
      );

  /// 标题5 - 16px
  TextStyle get h5 => TextStyle(
        fontFamily: appConfig.fontFamily,
        fontWeight: FlutterFont.bold,
        fontSize: 16,
        color: appTheme.textColor,
      );

  /// 标题6 - 14px
  TextStyle get h6 => TextStyle(
        fontFamily: appConfig.fontFamily,
        fontWeight: FlutterFont.bold,
        fontSize: 14,
        color: appTheme.textColor,
      );
}
