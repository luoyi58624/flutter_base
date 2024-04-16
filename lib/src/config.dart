part of flutter_base;

class FlutterConfigData {
  /// 自定义全局字体
  String? fontFamily;

  /// 设置全局普通文字字重，默认w500，flutter原始默认为w400
  FontWeight defaultFontWeight;

  /// 头部高度 (appbar、navbar)
  double headerHeight;

  /// 导航栏标题是否居中，默认情况下，移动端标题将居中、桌面端则左对齐
  bool? centerTitle;

  /// 是否开启全局波纹，默认true
  bool enableRipple;

  /// 启用半透明状态栏，默认false
  bool translucenceStatusBar;

  /// 组件默认圆角值
  double radius;

  FlutterConfigData({
    this.fontFamily,
    this.defaultFontWeight = FontWeight.w500,
    this.headerHeight = 50,
    this.radius = 6,
    this.centerTitle,
    this.enableRipple = true,
    this.translucenceStatusBar = false,
  }) {
    centerTitle = centerTitle ?? (GetPlatform.isMobile ? true : false);
  }

  FlutterConfigData copyWith(FlutterConfigData? config) {
    fontFamily = config?.fontFamily ?? fontFamily;
    defaultFontWeight = config?.defaultFontWeight ?? defaultFontWeight;
    headerHeight = config?.headerHeight ?? headerHeight;
    radius = config?.radius ?? radius;
    centerTitle = config?.centerTitle ?? centerTitle;
    enableRipple = config?.enableRipple ?? enableRipple;
    translucenceStatusBar = config?.translucenceStatusBar ?? translucenceStatusBar;
    return this;
  }
}
