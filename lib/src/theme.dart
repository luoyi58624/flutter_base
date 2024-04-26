part of flutter_base;

class AppThemeData {
  static Color white = const Color(0xffffffff);
  static Color black = const Color(0xff000000);
  static Color transparent = const Color(0x00000000);

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

  /// 背景色
  Color bgColor;

  /// 二级背景色，这是一个用于与背景色做一个轻微的区分
  Color bgColor2;

  /// 三级背景色，这是一个用于与背景色做一个稍重的区分
  Color bgColor3;

  /// 头部导航栏背景颜色
  Color headerColor;

  /// 全局文字颜色
  Color textColor;

  /// 默认的icon亮色颜色
  Color iconColor;

  /// 默认的亮色主题构造函数
  AppThemeData({
    this.brightness = Brightness.light,
    this.primary = const Color.fromARGB(255, 0, 120, 212),
    this.success = const Color.fromARGB(255, 16, 185, 129),
    this.info = const Color.fromARGB(255, 127, 137, 154),
    this.warning = const Color.fromARGB(255, 245, 158, 11),
    this.error = const Color.fromARGB(255, 239, 68, 68),
    this.bgColor = const Color(0xffffffff),
    this.bgColor2 = const Color(0xfff6f6f6),
    this.bgColor3 = const Color(0xffdde1e3),
    this.headerColor = const Color(0xfff3f4f6),
    this.textColor = const Color(0xff1f1f1f),
    this.iconColor = const Color(0xff1f1f1f),
  });

  /// 默认的暗色主题构造函数
  AppThemeData.dark({
    this.brightness = Brightness.dark,
    this.primary = const Color(0xff0ea5e9),
    this.success = const Color(0xff14b8a6),
    this.info = const Color(0xff64748B),
    this.warning = const Color(0xfffbbf24),
    this.error = const Color(0xfffb7185),
    this.bgColor = const Color(0xff181818),
    this.bgColor2 = const Color(0xff2d2d2d),
    this.bgColor3 = const Color(0xff4a4a4a),
    this.headerColor = const Color(0xff404040),
    this.textColor = const Color(0xfff6f6f6),
    this.iconColor = const Color(0xfff6f6f6),
  });

  AppThemeData copyWith({
    Brightness? brightness,
    Color? primary,
    Color? success,
    Color? info,
    Color? warning,
    Color? error,
    Color? bgColor,
    Color? bgColor2,
    Color? bgColor3,
    Color? headerColor,
    Color? textColor,
    Color? iconColor,
  }) {
    return AppThemeData(
      brightness: brightness ?? this.brightness,
      primary: primary ?? this.primary,
      success: success ?? this.success,
      info: info ?? this.info,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      bgColor: bgColor ?? this.bgColor,
      bgColor2: bgColor2 ?? this.bgColor2,
      bgColor3: bgColor3 ?? this.bgColor3,
      headerColor: headerColor ?? this.headerColor,
      textColor: textColor ?? this.textColor,
      iconColor: iconColor ?? this.iconColor,
    );
  }
}
