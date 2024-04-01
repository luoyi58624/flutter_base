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

  /// 构建App主题数据，如果你要构建以黑暗模式为主的应用、或者为App添加黑暗模式，那么你可以调用此方法快速构建相应的主题。
  ///
  /// 提示：默认情况下App只会创建亮色主题。
  ThemeData buildThemeData({
    Brightness brightness = Brightness.light, // 指定亮色主题或黑色主题
  }) {
    Color appbarBackground = brightness == Brightness.light ? Colors.white : const Color(0xff0f0f0f);
    Color bodyBackground = brightness == Brightness.light ? const Color(0xfffafafa) : const Color(0xff2b2b2b);
    // 默认的图标、文字颜色
    Color defaultIconTextColor = brightness == Brightness.light ? Colors.grey.shade900 : Colors.grey.shade100;
    ColorScheme colorScheme = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: primaryColor,
    );
    var $theme = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    return ThemeData(
      useMaterial3: true,
      // 解决web上material按钮外边距为0问题，与移动端的效果保持一致
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      // 统一页面过渡动画，为了保证ios的兼容性(手指滑动页面返回)，必须以ios过渡动画为主
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      }),
      // 根据主题色创建material3的主题系统
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      textTheme: _textTheme,
      splashFactory: enableRipple ? InkRipple.splashFactory : noRipperFactory,
      scaffoldBackgroundColor: bodyBackground,
      cardTheme: const CardTheme(
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        textColor: $theme.primaryColor,
        shape: Border.all(width: 0, style: BorderStyle.none),
        collapsedShape: Border.all(width: 0, style: BorderStyle.none),
      ),
      appBarTheme: $theme.appBarTheme.copyWith(
        centerTitle: centerTitle,
        scrolledUnderElevation: 0,
        backgroundColor: appbarBackground,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: defaultIconTextColor,
        ),
        iconTheme: IconThemeData(
          color: defaultIconTextColor,
        ),
      ),
      iconTheme: IconThemeData(
        color: defaultIconTextColor,
      ),
    );
  }

  /// material文字主题
  get _textTheme => TextTheme(
        displaySmall: TextStyle(
          fontWeight: defaultFontWeight,
        ),
        displayMedium: TextStyle(
          fontWeight: defaultFontWeight,
        ),
        displayLarge: TextStyle(
          fontWeight: defaultFontWeight,
        ),
        titleSmall: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
        titleLarge: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
        bodySmall: TextStyle(
          fontWeight: defaultFontWeight,
        ),
        bodyMedium: TextStyle(
          fontWeight: defaultFontWeight,
        ),
        bodyLarge: TextStyle(
          fontWeight: defaultFontWeight,
        ),
        labelSmall: TextStyle(
          fontWeight: defaultFontWeight,
        ),
        labelMedium: TextStyle(
          fontWeight: defaultFontWeight,
        ),
        labelLarge: TextStyle(
          fontWeight: defaultFontWeight,
        ),
      );
}
