part of '../../flutter_base.dart';

class AppResponsiveData {
  /// 默认的响应式配置
  static AppResponsiveData responsive = AppResponsiveData();

  /// 手机最大尺寸
  final double sm;

  /// 平板最大尺寸
  final double md;

  /// 桌面最大尺寸
  final double lg;

  /// 大屏桌面最大尺寸
  final double xl;

  AppResponsiveData({
    this.sm = 640,
    this.md = 1024,
    this.lg = 1920,
    this.xl = 2560,
  });

  AppResponsiveData copyWith({
    double? sm,
    double? md,
    double? lg,
    double? xl,
  }) {
    return AppResponsiveData(
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
    );
  }
}
