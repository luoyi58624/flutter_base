part of flutter_base;

class FlutterThemeData {
  final Color white = const Color(0xffffffff);
  final Color black = const Color(0xff000000);
  final Color transparent = const Color(0x00000000);

  /// 当前主题模式
  Brightness brightness;

  /// 主要颜色
  Color primary;

  /// 成功颜色
  Color success;

  /// 普通颜色
  Color info;

  /// 警告颜色
  Color warning;

  /// 错误颜色
  Color error;

  /// 全局背景白色
  Color bgColor;

  /// 头部导航栏背景颜色
  Color headerColor;

  /// 主要区域背景颜色
  Color mainColor;

  /// 全局文字颜色
  Color textColor;

  /// 默认的icon亮色颜色
  Color iconColor;

  /// 默认的边框颜色
  Color defaultBorderColor;

  /// 菜单栏背景色
  Color menuBackground;

  /// 菜单栏激活文字颜色
  Color menuActiveColor;

  /// 默认的亮色主题构造函数
  FlutterThemeData({
    this.brightness = Brightness.light,
    this.primary = const Color.fromARGB(255, 0, 120, 212),
    this.success = const Color.fromARGB(255, 16, 185, 129),
    this.info = const Color.fromARGB(255, 127, 137, 154),
    this.warning = const Color.fromARGB(255, 245, 158, 11),
    this.error = const Color.fromARGB(255, 239, 68, 68),
    this.bgColor = const Color(0xffffffff),
    this.headerColor = const Color(0xfff3f4f6),
    this.mainColor = const Color(0xffffffff),
    this.textColor = const Color(0xff1f1f1f),
    this.iconColor = const Color(0xff1f1f1f),
    this.defaultBorderColor = const Color(0xffdcdfe6),
    this.menuBackground = const Color(0xff565c64),
    this.menuActiveColor = const Color(0xffffd04b),
  });

  /// 默认的暗色主题构造函数
  FlutterThemeData.dark({
    this.brightness = Brightness.dark,
    this.primary = const Color(0xff0ea5e9),
    this.success = const Color(0xff14b8a6),
    this.info = const Color(0xff64748B),
    this.warning = const Color(0xfffbbf24),
    this.error = const Color(0xfffb7185),
    this.bgColor = const Color(0xff000000),
    this.headerColor = const Color(0xff404040),
    this.mainColor = const Color(0xff2b2b2b),
    this.textColor = const Color(0xfff6f6f6),
    this.iconColor = const Color(0xfff6f6f6),
    this.defaultBorderColor = const Color(0xffa3a3a3),
    this.menuBackground = const Color(0xff374151),
    this.menuActiveColor = const Color(0xff6ee7b7),
  });

  FlutterThemeData copyWith({
    Brightness? brightness,
    Color? primary,
    Color? success,
    Color? info,
    Color? warning,
    Color? error,
    Color? bgColor,
    Color? headerColor,
    Color? mainColor,
    Color? textColor,
    Color? iconColor,
    Color? defaultBorderColor,
    Color? menuBackground,
    Color? menuActiveColor,
  }) {
    return FlutterThemeData(
      brightness: brightness ?? this.brightness,
      primary: primary ?? this.primary,
      success: success ?? this.success,
      info: info ?? this.info,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      bgColor: bgColor ?? this.bgColor,
      headerColor: headerColor ?? this.headerColor,
      mainColor: mainColor ?? this.mainColor,
      textColor: textColor ?? this.textColor,
      iconColor: iconColor ?? this.iconColor,
      defaultBorderColor: defaultBorderColor ?? this.defaultBorderColor,
      menuBackground: menuBackground ?? this.menuBackground,
      menuActiveColor: menuActiveColor ?? this.menuActiveColor,
    );
  }
}
