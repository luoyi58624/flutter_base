part of flutter_base;

class AppConfigData {
  /// 应用标题
  String title;

  /// 自定义全局字体
  String? fontFamily;

  /// 设置全局普通文字字重，默认w500，flutter原始默认为w400
  FontWeight defaultFontWeight;

  /// 头部高度 (appbar、navbar)
  double headerHeight;

  /// 是否启用material3，默认true
  bool useMaterial3;

  /// 组件默认圆角值
  double radius;

  /// 导航栏标题是否居中，默认情况下，移动端标题将居中、桌面端则左对齐
  bool? centerTitle;

  /// 是否开启全局波纹，默认true
  bool enableRipple;

  /// 启用半透明状态栏，默认false
  bool translucenceStatusBar;

  /// 是否开启性能视图
  bool showPerformanceOverlay;

  /// 鼠标悬停背景颜色变化级别：1-100
  int hoverScale;

  /// 手指点击、鼠标点击背景颜色变化级别：1-100
  int tapScale;

  AppConfigData({
    this.title = 'Flutter App',
    this.fontFamily,
    this.defaultFontWeight = FontWeight.w500,
    this.headerHeight = 50,
    this.useMaterial3 = true,
    this.radius = 6,
    this.centerTitle,
    this.enableRipple = true,
    this.translucenceStatusBar = false,
    this.showPerformanceOverlay = false,
    this.hoverScale = 8,
    this.tapScale = 14,
  }) {
    centerTitle = centerTitle ?? (GetPlatform.isMobile ? true : false);
  }

  AppConfigData copyWith({
    String? title,
    String? fontFamily,
    FontWeight? defaultFontWeight,
    double? headerHeight,
    bool? useMaterial3,
    double? radius,
    bool? centerTitle,
    bool? enableRipple,
    bool? translucenceStatusBar,
    bool? showPerformanceOverlay,
    int? hoverScale,
    int? tapScale,
  }) {
    return AppConfigData(
      title: title ?? this.title,
      fontFamily: fontFamily ?? this.fontFamily,
      defaultFontWeight: defaultFontWeight ?? this.defaultFontWeight,
      headerHeight: headerHeight ?? this.headerHeight,
      useMaterial3: useMaterial3 ?? this.useMaterial3,
      radius: radius ?? this.radius,
      centerTitle: centerTitle ?? this.centerTitle,
      enableRipple: enableRipple ?? this.enableRipple,
      translucenceStatusBar: translucenceStatusBar ?? this.translucenceStatusBar,
      showPerformanceOverlay: showPerformanceOverlay ?? this.showPerformanceOverlay,
      hoverScale: hoverScale ?? this.hoverScale,
      tapScale: tapScale ?? this.tapScale,
    );
  }
}
