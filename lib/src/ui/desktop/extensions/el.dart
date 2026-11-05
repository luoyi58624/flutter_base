import 'package:flutter/material.dart';

import '../internal.dart';

/// 读取最近视图的明暗状态。
extension ElDarkExt on BuildContext {
  /// 当前视图是否处于暗色模式。
  bool get isDark => ElView.of(this).isDark;
}

/// 最近 ElView 的交互状态快捷读取入口。
extension ElViewContextExt on BuildContext {
  /// 当前是否悬停，读取时订阅状态变化。
  bool get hasHover => ElView.of(this).hasHover;

  /// 当前是否按下，读取时订阅状态变化。
  bool get hasTap => ElView.of(this).hasTap;
}

/// 桌面控件的密度与边框便利读法，主题值由共享变量入口提供。
extension ElThemeColorExt on BuildContext {
  /// 当前组件样式中的密度优先，其次继承祖先变量，未声明时使用普通密度。
  bool elComponentCompact([ElStyle? style]) {
    final declared = style?.vars?[ElDesktopExt.$compact];
    return declared is bool ? declared : (ElView.maybeOf(this)?.getVar<bool>(ElDesktopExt.$compact) ?? false);
  }

  /// 当前主题的默认边框。
  ElBorder elBorder({double? width, Color? color}) =>
      ElBorder.all(borderWidth: width ?? elBorderWidth, borderColor: color ?? elTheme.borderColor);

  /// 按当前明暗环境派生边框色。
  Color elBorderColor(Color color) => isDark ? elDarkBorderColor(color) : elLightBorderColor(color);

  /// 与主题白色混合生成浅边框。
  Color elLightBorderColor(Color color) => color.mix(elTheme.white, 50);

  /// 与主题黑色混合生成深边框。
  Color elDarkBorderColor(Color color) => color.mix(elTheme.black, 50);

  /// 标准边框宽度。
  double get elBorderWidth => elTheme.borderWidth;

  /// 普通控件圆角。
  BorderRadiusGeometry get elBorderRadius => BorderRadius.circular(elTheme.radiusSm);

  /// 卡片圆角。
  BorderRadiusGeometry get elCardBorderRadius => BorderRadius.circular(elTheme.radiusLg);
}

/// 读取最近视图的响应式状态，保持累积上界判断。
extension ElResponsiveContextExt on BuildContext {
  /// 当前是否命中极小断点。
  bool get xs => ElView.of(this).xs;

  /// 当前是否命中小断点。
  bool get sm => ElView.of(this).sm;

  /// 当前是否命中中断点。
  bool get md => ElView.of(this).md;

  /// 当前是否命中大断点。
  bool get lg => ElView.of(this).lg;

  /// 当前是否命中最大断点。
  bool get xl => ElView.of(this).xl;
}
