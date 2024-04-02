part of flutter_base;

const Color _primaryColor = Color.fromARGB(255, 0, 120, 212);
const Color _successColor = Color.fromARGB(255, 16, 185, 129);
const Color _warningColor = Color.fromARGB(255, 245, 158, 11);
const Color _errorColor = Color.fromARGB(255, 239, 68, 68);
const Color _infoColor = Color.fromARGB(255, 127, 137, 154);

late AppTheme appTheme;

/// 初始化主题配置，它会在你执行[initMyFlutter]函数时立即注入到[MyTheme]对象，随后你可以在任意地方使用[appTheme]实例调用全局主题
class AppThemeModel {
  /// 全局主题色，将统一应用于[MaterialApp]和[CupertinoApp]
  Color? primaryColor;

  /// 成功颜色
  Color? successColor;

  /// 警告颜色
  Color? warningColor;

  /// 错误、危险颜色
  Color? errorColor;

  /// 普通信息颜色
  Color? infoColor;

  /// 自定义全局字体
  String? fontFamily;

  /// 设置全局普通文字字重，默认w500，flutter原始默认为w400
  FontWeight? defaultFontWeight;

  /// appbar高度
  double? appbarHeight;

  /// 导航栏标题是否居中，默认情况下，移动端标题将居中、桌面端则左对齐
  bool? centerTitle;

  /// 是否全局启动波纹，默认true
  bool? enableRipple;

  /// 启用半透明状态栏，默认false
  bool? translucenceStatusBar;

  AppThemeModel({
    this.primaryColor,
    this.successColor,
    this.warningColor,
    this.errorColor,
    this.infoColor,
    this.fontFamily,
    this.defaultFontWeight,
    this.appbarHeight,
    this.centerTitle,
    this.enableRipple,
    this.translucenceStatusBar,
  });
}

class AppTheme {
  /// 全局主题色，将统一应用于[MaterialApp]和[CupertinoApp]
  late Color primaryColor;

  /// 成功颜色
  late Color successColor;

  /// 警告颜色
  late Color warningColor;

  /// 错误、危险颜色
  late Color errorColor;

  /// 普通信息颜色
  late Color infoColor;

  /// 自定义全局字体，当你遇到flutter字体渲染问题时将会使用它
  String? fontFamily;

  /// 设置全局普通文字字重，默认w500，flutter原始默认为w400
  late FontWeight defaultFontWeight;

  /// appbar高度
  late double appbarHeight;

  /// 导航栏标题是否居中，默认情况下，移动端标题将居中、桌面端则左对齐
  late bool centerTitle;

  /// 是否全局启动波纹，默认true
  late bool enableRipple;

  /// 启用半透明状态栏，默认false
  late bool translucenceStatusBar;

  AppTheme([AppThemeModel? _]) {
    primaryColor = _?.primaryColor ?? _primaryColor;
    successColor = _?.successColor ?? _successColor;
    warningColor = _?.warningColor ?? _warningColor;
    errorColor = _?.errorColor ?? _errorColor;
    infoColor = _?.infoColor ?? _infoColor;

    fontFamily = _?.fontFamily;
    defaultFontWeight = _?.defaultFontWeight ?? FontWeight.w500;
    appbarHeight = _?.appbarHeight ?? 56;
    centerTitle = _?.centerTitle ?? (GetPlatform.isMobile ? true : false);
    enableRipple = _?.enableRipple ?? true;
    translucenceStatusBar = _?.translucenceStatusBar ?? false;
  }
}
