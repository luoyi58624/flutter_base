part of '../../flutter_base.dart';

// extension AppThemeColorExtension on Color {
//   Color get appTextColor => isDark?AppWidget.of(context).
// }

extension AppDataContextExtension on BuildContext {
  AppData get appData => AppWidget.of(this);

  /// 全局配置数据
  AppConfigData get appConfig => appData.config;

  /// 当前主题数据
  AppThemeData get appTheme => BrightnessWidget.isDark(this) ? appData.darkTheme : appData.theme;
}

extension AppResponsiveContextExtension on BuildContext {
  /// 移动端设备
  bool get sm => MediaQuery.sizeOf(this).width < appData.responsive.sm;

  /// 平板设备
  bool get md => MediaQuery.sizeOf(this).width < appData.responsive.md;

  /// 桌面设备
  bool get lg => MediaQuery.sizeOf(this).width < appData.responsive.lg;

  /// 大屏桌面设备
  bool get xl => MediaQuery.sizeOf(this).width < appData.responsive.xl;
}

/// 字体排版扩展
extension TypographyContextExtension on BuildContext {
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

  /// 标题6 - 14px
  TextStyle get p => TextStyle(
        fontFamily: appConfig.fontFamily,
        fontWeight: FlutterFont.normal,
        fontSize: 16,
        color: appTheme.textColor,
      );
}
