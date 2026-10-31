import 'package:flutter_base/src/ui/desktop/internal.dart';
import 'package:flutter/material.dart';

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

/// 读取 Element 尺寸、主题和常用边框外观。
extension ElThemeColorExt on BuildContext {
  /// 当前主题的组件尺寸档位。
  ElLevelType elComponentSize([ElStyle? style]) => ElThemeData.of(this).size;

  /// 访问主题对象
  ElThemeExt get elTheme => ElThemeExt(this);

  /// 访问边框对象
  ElBorder elBorder({double? width, Color? color}) => ElBorder.all(
    borderWidth: width ?? elBorderWidth,
    borderColor: color ?? ElThemeData.of(this).borderColor,
  );

  /// 按当前明暗轴生成主题边框色。
  Color elBorderColor(Color color) =>
      isDark ? elDarkBorderColor(color) : elLightBorderColor(color);

  /// 将主题色与全局白色混合 50% 生成亮色边框。
  Color elLightBorderColor(Color color) =>
      color.mix(ElThemeData.of(this, brightness: .light).white, 50);

  /// 将主题色与全局黑色混合 50% 生成暗色边框。
  Color elDarkBorderColor(Color color) =>
      color.mix(ElThemeData.of(this, brightness: .dark).black, 50);

  /// 标准边框宽度，取全局宽度集合的 md 档。
  double get elBorderWidth =>
      ElThemeData.of(this).borderWidths[ElLevelType.md.index];

  /// 普通控件应用的圆角
  BorderRadiusGeometry get elBorderRadius =>
      .circular(ElThemeData.of(this).radiusSm);

  /// 卡片等布局控件应用的圆角（全局 lg 档）
  BorderRadiusGeometry get elCardBorderRadius =>
      .circular(ElThemeData.of(this).radiusLg);
}

/// ElView 响应式状态快捷入口，保持累积 max-width 语义。
///
/// 每个 getter 都直接读取 [ElView.of] 的对应状态位，因此仍是单状态最小粒度
/// 订阅。该扩展可通过 `hide ElResponsiveContextExt` 独立隐藏。
extension ElResponsiveContextExt on BuildContext {
  /// 当前是否命中极小宽度断点。
  bool get xs => ElView.of(this).xs;

  /// 当前是否命中小宽度断点。
  bool get sm => ElView.of(this).sm;

  /// 当前是否命中中等宽度断点。
  bool get md => ElView.of(this).md;

  /// 当前是否命中大宽度断点。
  bool get lg => ElView.of(this).lg;

  /// 当前是否命中超大宽度断点。
  bool get xl => ElView.of(this).xl;
}

/// 当前上下文的 Element 主题及常用派生配色。
extension type const ElThemeExt(BuildContext _context) {
  ElThemeData get _data => ElThemeData.of(_context);

  /// 当前主题中全部语义色的映射。
  Map<ElThemeType, Color> get themeColors => {
    for (final type in ElThemeType.values) type: type.color(_context),
  };

  /// 主要操作的品牌色。
  Color get primary => _data.primary;

  /// 成功状态色。
  Color get success => _data.success;

  /// 警告状态色。
  Color get warning => _data.warning;

  /// 错误状态色。
  Color get error => _data.error;

  /// 普通信息状态色。
  Color get info => _data.info;

  /// 主题定义的黑色基准。
  Color get black => _data.black;

  /// 主题定义的白色基准。
  Color get white => _data.white;

  /// 主要文字色。
  Color get textColor => _data.textColorXs;

  /// 常规文字色。
  Color get textRegular => _data.textColorSm;

  /// 次要文字色。
  Color get textSecondary => _data.textColorMd;

  /// 占位文字色。
  Color get textPlaceholder => _data.textColorLg;

  /// 页面默认背景色。
  Color get bgColor => _data.bgColor;

  /// 默认边框色。
  Color get borderColor => _data.borderColor;

  /// 悬停时使用的强调边框色。
  Color get borderColorHover => borderColor.elLight2(_context, reverse: true);

  /// 第三档浅边框色。
  Color get borderColorLight => borderColor.elLight3(_context);

  /// 第五档浅边框色。
  Color get borderColorLighter => borderColor.elLight5(_context);

  /// 第七档浅边框色。
  Color get borderColorExtraLight => borderColor.elLight7(_context);

  /// 第一档强调边框色。
  Color get borderColorDark => borderColor.elLight1(_context, reverse: true);

  /// 第二档强调边框色。
  Color get borderColorDarker => borderColor.elLight2(_context, reverse: true);

  /// 禁用状态的文字色。
  Color get disabledTextColor => _data.textColorLg;

  /// 跟随明暗轴的禁用背景色。
  Color get disabledBgColor =>
      _context.isDark ? const Color(0xff262727) : const Color(0xfff5f7fa);

  /// 禁用状态的边框色。
  Color get disabledBorderColor => borderColorLight;

  /// 默认遮罩色。
  Color get maskColor => _data.maskColor;

  /// 低遮挡强度的遮罩色。
  Color get maskColorExtraLight => _data.maskColorExtraLight;

  /// 默认浮层覆盖色。
  Color get overlayColor => _data.overlayColor;

  /// 较浅的浮层覆盖色。
  Color get overlayColorLight => _data.overlayColorLight;

  /// 更浅的浮层覆盖色。
  Color get overlayColorLighter => _data.overlayColorLighter;

  /// 当前卡片背景色。
  Color get cardColor => _data.cardColor;

  /// 适合图标和辅助信息的常规颜色。
  Color get iconColor => textSecondary;

  /// 适合文本选择区域的主色色阶。
  Color get selectionColor => primary.elLight7(_context);

  /// 兼容更偏语义化的属性命名。
  Color get placeholderTextColor => textPlaceholder;

  /// 兼容更偏语义化的属性命名。
  Color get secondaryTextColor => textSecondary;

  /// 兼容更偏语义化的属性命名。
  Color get darkerBorderColor => borderColorDarker;
}
