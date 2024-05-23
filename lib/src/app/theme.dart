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

  /// 全局背景色，包括：Modal弹窗、Drawer弹窗等所有路由页面的基础背景颜色
  Color bgColor;

  /// 头部导航栏背景颜色，如果为空则使用[primary]颜色(此逻辑主要适配 Material2)
  late Color headerColor;

  /// 卡片背景色，与背景色做一个稍微的区分
  Color cardColor;

  /// 模态弹窗背景色，如果为空则使用[bgColor]
  late Color modalColor;

  /// 文字颜色
  Color textColor;

  /// icon颜色
  Color iconColor;

  /// 根据字体颜色自动创建一组次级颜色: 0 - 5
  List<Color> get textColors =>
      List.generate(6, (index) => textColor.deepen(4 * (index + 1), darkScale: 8 * (index + 1)));

  /// 根据图标颜色自动创建一组次级颜色: 0 - 5
  List<Color> get iconColors =>
      List.generate(6, (index) => iconColor.deepen(4 * (index + 1), darkScale: 8 * (index + 1)));

  /// 卡片高度海拔，如果追求扁平化，那么在亮色模式下一般会设置较低的海拔或者无海拔，
  /// 但是，在暗色模式下设置一定的海拔可以让卡片、弹窗等模块更具层次感。
  double cardElevation;

  /// 模态弹窗海拔
  double modalElevation;

  /// 默认的亮色主题构造函数
  AppThemeData({
    this.primary = const Color.fromARGB(255, 0, 120, 212),
    this.success = const Color.fromARGB(255, 16, 185, 129),
    this.info = const Color.fromARGB(255, 127, 137, 154),
    this.warning = const Color.fromARGB(255, 245, 158, 11),
    this.error = const Color.fromARGB(255, 239, 68, 68),
    this.bgColor = const Color(0xfffafafa),
    Color? headerColor,
    this.cardColor = const Color(0xffffffff),
    Color? modalColor,
    this.textColor = const Color(0xff1f1f1f),
    this.iconColor = const Color(0xff1b1e23),
    this.cardElevation = 0,
    this.modalElevation = 2,
  }) {
    this.headerColor = headerColor ?? primary;
    this.modalColor = modalColor ?? bgColor;
  }

  /// 默认的暗色主题构造函数
  AppThemeData.dark({
    this.primary = const Color(0xff0ea5e9),
    this.success = const Color(0xff14b8a6),
    this.info = const Color(0xff64748B),
    this.warning = const Color(0xfffbbf24),
    this.error = const Color(0xfffb7185),
    this.bgColor = const Color(0xff2b2b2b),
    Color? headerColor = const Color(0xff3F3F46),
    this.cardColor = const Color(0xff3c3c3c),
    Color? modalColor = const Color(0xff3c3f41),
    this.textColor = const Color(0xfffafafa),
    this.iconColor = const Color(0xfff6f6f6),
    this.cardElevation = 2,
    this.modalElevation = 4,
  }) {
    this.headerColor = headerColor ?? primary;
    this.modalColor = modalColor ?? bgColor;
  }

  AppThemeData copyWith({
    Color? primary,
    Color? success,
    Color? info,
    Color? warning,
    Color? error,
    Color? bgColor,
    Color? headerColor,
    Color? cardColor,
    Color? modalColor,
    Color? textColor,
    Color? iconColor,
    double? cardElevation,
    double? modalElevation,
  }) {
    return AppThemeData(
      primary: primary ?? this.primary,
      success: success ?? this.success,
      info: info ?? this.info,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      bgColor: bgColor ?? this.bgColor,
      headerColor: headerColor ?? this.headerColor,
      cardColor: cardColor ?? this.cardColor,
      modalColor: modalColor ?? this.modalColor,
      textColor: textColor ?? this.textColor,
      iconColor: iconColor ?? this.iconColor,
      cardElevation: cardElevation ?? this.cardElevation,
      modalElevation: modalElevation ?? this.modalElevation,
    );
  }
}
