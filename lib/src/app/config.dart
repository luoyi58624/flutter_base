part of '../../flutter_base.dart';

class AppConfigData {
  /// 全局字体
  String? fontFamily;

  /// 全局字体名字
  String get fontFamilyName => fontFamily == null || fontFamily == '' ? '系统字体' : fontFamily!;

  /// 如果[fontFamily]为空，那么会依次根据设置的字体列表去匹配相应的字体
  List<String>? fontFamilyFallback;

  /// 是否启用material3，默认true
  bool useMaterial3;

  /// appbar高度
  double appbarHeight;

  /// appbar海拔高度
  double appbarElevation;

  /// app滚动时海拔高度
  double appbarScrollElevation;

  /// appbar标题是否居中，默认情况下，在移动端标题居中，pc端跟随默认
  late bool centerTitle;

  /// 全局圆角值，例如：Card、Modal、PopupMenu
  double radius;

  /// 按钮圆角值，不指定则使用默认值
  double? buttonRadius;

  /// 是否开启全局波纹，默认true
  bool enableRipple;

  /// 是否开启半透明状态栏，注意：仅M2有效
  bool translucenceStatusBar;

  AppConfigData({
    String? fontFamily,
    List<String>? fontFamilyFallback,
    this.useMaterial3 = true,
    this.appbarHeight = 50,
    this.appbarElevation = 0,
    this.appbarScrollElevation = 0,
    bool? centerTitle,
    this.radius = 6,
    this.buttonRadius,
    this.enableRipple = true,
    this.translucenceStatusBar = false,
  }) {
    this.fontFamily = fontFamily ?? ElFont.fontFamily;
    this.centerTitle = centerTitle ?? ElPlatform.isMobile ? true : false;
    this.fontFamilyFallback = fontFamilyFallback ?? ElFont.fontFamilyFallback;
  }

  AppConfigData copyWith({
    String? fontFamily,
    List<String>? fontFamilyFallback,
    bool? useMaterial3,
    double? appbarHeight,
    double? appbarElevation,
    double? appbarScrollElevation,
    bool? centerTitle,
    double? radius,
    double? buttonRadius,
    bool? enableRipple,
    bool? translucenceStatusBar,
  }) {
    return AppConfigData(
      fontFamily: fontFamily ?? this.fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
      useMaterial3: useMaterial3 ?? this.useMaterial3,
      appbarHeight: appbarHeight ?? this.appbarHeight,
      appbarElevation: appbarElevation ?? this.appbarElevation,
      appbarScrollElevation: appbarScrollElevation ?? this.appbarScrollElevation,
      centerTitle: centerTitle ?? this.centerTitle,
      radius: radius ?? this.radius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      enableRipple: enableRipple ?? this.enableRipple,
      translucenceStatusBar: translucenceStatusBar ?? this.translucenceStatusBar,
    );
  }
}
