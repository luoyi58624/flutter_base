part of '../../flutter_base.dart';

class AppConfigData {
  static AppConfigData config = AppConfigData(
    theme: AppThemeData(headerColor: Colors.white),
    darkTheme: AppThemeData.darkTheme,
    useMaterial3: true,
    appbarHeight: 50,
    cardElevation: 1,
    cardRadius: 8,
  );

  /// Material2 默认配置，和原生样式基本一致
  static AppConfigData m2Config = AppConfigData(
    theme: AppThemeData(primary: Colors.blue),
    darkTheme: AppThemeData.dark(primary: Colors.blue),
    useMaterial3: false,
    appbarHeight: 56,
    appbarElevation: 4,
    appbarScrollElevation: 4,
    centerTitle: false,
    cardElevation: 2,
    cardRadius: 6,
    translucenceStatusBar: true,
  );

  /// Material2 扁平化配置
  static AppConfigData m2FlatConfig = AppConfigData(
    theme: AppThemeData(headerColor: Colors.white),
    darkTheme: AppThemeData.dark(primary: Colors.blue),
    useMaterial3: false,
    appbarHeight: 56,
    appbarScrollElevation: 1,
    cardElevation: 1,
    cardRadius: 8,
    buttonRadius: 6,
  );

  /// Material3 默认配置，和原生样式基本一致
  static AppConfigData m3Config = AppConfigData(
    theme: AppThemeData(headerColor: Colors.white),
    darkTheme: AppThemeData.darkTheme,
    useMaterial3: true,
    appbarHeight: 50,
    appbarElevation: 0,
    appbarScrollElevation: 4,
    centerTitle: false,
    cardElevation: 1,
    cardRadius: 12,
  );

  /// Material3 扁平化配置
  static AppConfigData m3FlatConfig = AppConfigData(
    theme: AppThemeData(headerColor: Colors.white),
    darkTheme: AppThemeData.darkTheme,
    useMaterial3: true,
    appbarHeight: 50,
    cardElevation: 0,
    cardRadius: 8,
  );

  /// app亮色主题
  AppThemeData theme;

  /// app暗色主题
  AppThemeData darkTheme;

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

  /// 卡片海拔高度
  double cardElevation;

  /// 卡片圆角值，包括所有用到类似于卡片的组件，例如：各种弹窗
  double cardRadius;

  /// 按钮圆角值，不指定则使用默认值
  double? buttonRadius;

  /// 是否开启全局波纹，默认true
  bool enableRipple;

  /// 是否开启半透明状态栏，注意：仅M2有效
  bool translucenceStatusBar;

  /// 鼠标悬停背景颜色变化级别：1-100
  int hoverScale;

  /// 手指点击、鼠标点击背景颜色变化级别：1-100
  int tapScale;

  AppConfigData({
    required this.theme,
    required this.darkTheme,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    this.useMaterial3 = true,
    this.appbarHeight = 50,
    this.appbarElevation = 0,
    this.appbarScrollElevation = 0,
    bool? centerTitle,
    this.cardElevation = 0,
    this.cardRadius = 6,
    this.buttonRadius,
    this.enableRipple = true,
    this.translucenceStatusBar = false,
    this.hoverScale = 8,
    this.tapScale = 14,
  }) {
    this.fontFamily = fontFamily ?? FlutterFont.fontFamily;
    this.centerTitle = centerTitle ?? GetPlatform.isMobile ? true : false;
    this.fontFamilyFallback = fontFamilyFallback ?? FlutterFont.fontFamilyFallback;
  }

  AppConfigData copyWith({
    AppThemeData? theme,
    AppThemeData? darkTheme,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    bool? useMaterial3,
    double? appbarHeight,
    double? appbarElevation,
    double? appbarScrollElevation,
    bool? centerTitle,
    double? cardElevation,
    double? cardRadius,
    double? buttonRadius,
    bool? enableRipple,
    bool? translucenceStatusBar,
    int? hoverScale,
    int? tapScale,
  }) {
    return AppConfigData(
      theme: theme ?? this.theme,
      darkTheme: darkTheme ?? this.darkTheme,
      fontFamily: fontFamily ?? this.fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
      useMaterial3: useMaterial3 ?? this.useMaterial3,
      appbarHeight: appbarHeight ?? this.appbarHeight,
      appbarElevation: appbarElevation ?? this.appbarElevation,
      appbarScrollElevation: appbarScrollElevation ?? this.appbarScrollElevation,
      centerTitle: centerTitle ?? this.centerTitle,
      cardElevation: cardElevation ?? this.cardElevation,
      cardRadius: cardRadius ?? this.cardRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      enableRipple: enableRipple ?? this.enableRipple,
      translucenceStatusBar: translucenceStatusBar ?? this.translucenceStatusBar,
      hoverScale: hoverScale ?? this.hoverScale,
      tapScale: tapScale ?? this.tapScale,
    );
  }
}
