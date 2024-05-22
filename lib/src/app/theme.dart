part of '../../flutter_base.dart';

/// 主题数据
class AppThemeData {
  /// 默认亮色主题对象
  static AppThemeData theme = AppThemeData();

  /// 默认暗色主题对象
  static AppThemeData darkTheme = AppThemeData.dark();

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

  /// 全局背景色
  Color bgColor;

  /// 卡片背景色
  Color cardColor;

  /// 头部导航栏背景颜色，如果为空则使用[primary]颜色
  Color? headerColor;

  /// 文字颜色
  Color textColor;

  /// icon颜色
  Color iconColor;

  /// 根据字体颜色自动创建一组次级颜色: 0 - 5
  List<Color> get textColors =>
      List.generate(6, (index) => textColor.deepen(5 * (index + 1), darkScale: 8 * (index + 1)));

  /// 根据图标颜色自动创建一组次级颜色: 0 - 5
  List<Color> get iconColors =>
      List.generate(6, (index) => iconColor.deepen(5 * (index + 1), darkScale: 8 * (index + 1)));

  /// 默认的亮色主题构造函数
  AppThemeData({
    this.primary = const Color.fromARGB(255, 0, 120, 212),
    this.success = const Color.fromARGB(255, 16, 185, 129),
    this.info = const Color.fromARGB(255, 127, 137, 154),
    this.warning = const Color.fromARGB(255, 245, 158, 11),
    this.error = const Color.fromARGB(255, 239, 68, 68),
    this.bgColor = const Color(0xfffafafa),
    this.headerColor,
    this.cardColor = const Color(0xffffffff),
    this.textColor = const Color(0xff1f1f1f),
    this.iconColor = const Color(0xff1b1e23),
  });

  /// 默认的暗色主题构造函数
  AppThemeData.dark({
    this.primary = const Color(0xff0ea5e9),
    this.success = const Color(0xff14b8a6),
    this.info = const Color(0xff64748B),
    this.warning = const Color(0xfffbbf24),
    this.error = const Color(0xfffb7185),
    this.bgColor = const Color(0xff181818),
    this.cardColor = const Color(0xff3c3c3c),
    this.headerColor = const Color(0xff3F3F46),
    this.textColor = const Color(0xfffafafa),
    this.iconColor = const Color(0xfff6f6f6),
  });

  AppThemeData copyWith({
    Color? primary,
    Color? success,
    Color? info,
    Color? warning,
    Color? error,
    Color? bgColor,
    Color? headerColor,
    Color? textColor,
    Color? iconColor,
  }) {
    return AppThemeData(
      primary: primary ?? this.primary,
      success: success ?? this.success,
      info: info ?? this.info,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      bgColor: bgColor ?? this.bgColor,
      headerColor: headerColor ?? this.headerColor,
      textColor: textColor ?? this.textColor,
      iconColor: iconColor ?? this.iconColor,
    );
  }
}
