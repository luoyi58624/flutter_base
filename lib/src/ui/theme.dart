import 'package:flutter/widgets.dart';

import '../flutter/commons/models.dart';
import '../flutter/extensions/index.dart' show ElColorExt;
import '../flutter/views/view/view.dart';

/// 两端共用的主题变量键，默认值由主题宿主通过 ElView 注入。
abstract final class ElTheme {
  /// 品牌主色。
  static const $primary = '--el-color-primary';

  /// 成功色。
  static const $success = '--el-color-success';

  /// 信息色。
  static const $info = '--el-color-info';

  /// 警告色。
  static const $warning = '--el-color-warning';

  /// 错误色。
  static const $error = '--el-color-error';

  /// 黑色基准。
  static const $black = '--el-color-black';

  /// 白色基准。
  static const $white = '--el-color-white';

  /// 页面背景。
  static const $bgColor = '--el-bg-color';

  /// 卡片背景。
  static const $cardColor = '--el-card-color';

  /// 控件填充。
  static const $fill = '--el-fill';

  /// 主要文字。
  static const $textColor = '--el-text-color';

  /// 常规文字。
  static const $textRegular = '--el-text-regular';

  /// 次要文字。
  static const $textSecondary = '--el-text-secondary';

  /// 占位文字。
  static const $textPlaceholder = '--el-text-placeholder';

  /// 弱化文字。
  static const $textDisabled = '--el-text-disabled';

  /// 基础边框。
  static const $borderColor = '--el-border-color';

  /// 未选中控件的灰色。
  static const $gray = '--el-gray';

  /// 悬停底色。
  static const $hover = '--el-hover';

  /// 按压底色。
  static const $press = '--el-press';

  /// 选中底色。
  static const $selectedBackground = '--el-selected-background';

  /// 主色背景上的文字。
  static const $primaryText = '--el-primary-text';

  /// 浅色背景上的对比文字。
  static const $textOnLight = '--el-text-on-light';

  /// 深色背景上的对比文字。
  static const $textOnDark = '--el-text-on-dark';

  /// 最小层级阴影。
  static const $shadowXs = '--el-shadow-xs';

  /// 小阴影。
  static const $shadowSm = '--el-shadow-sm';

  /// 标准阴影。
  static const $shadowMd = '--el-shadow-md';

  /// 弹层阴影。
  static const $shadowLg = '--el-shadow-lg';

  /// 模态阴影。
  static const $shadowXl = '--el-shadow-xl';

  /// 选中状态阴影。
  static const $selectedShadow = '--el-selected-shadow';

  /// 模态遮罩。
  static const $overlayColor = '--el-overlay-color';

  /// 较浅遮罩。
  static const $overlayColorLight = '--el-overlay-color-light';

  /// 最浅遮罩。
  static const $overlayColorLighter = '--el-overlay-color-lighter';

  /// 遮罩模糊半径。
  static const $overlayBackdropBlur = '--el-overlay-backdrop-blur';

  /// 全局控件尺寸档。
  static const $size = '--el-component-size';

  /// 五档控件高度。
  static const $controlHeights = '--el-control-heights';

  /// 五档字号。
  static const $fontSizes = '--el-font-sizes';

  /// 五档图标尺寸。
  static const $iconSizes = '--el-icon-sizes';

  /// 五档边框宽度。
  static const $borderWidths = '--el-border-widths';

  /// 最小圆角。
  static const $radiusXs = '--el-radius-xs';

  /// 小圆角。
  static const $radiusSm = '--el-radius-sm';

  /// 标准圆角。
  static const $radiusMd = '--el-radius-md';

  /// 大圆角。
  static const $radiusLg = '--el-radius-lg';

  /// 最大圆角。
  static const $radiusXl = '--el-radius-xl';

  /// 默认字体。
  static const $fontFamily = '--el-font-family';

  /// 字体回退顺序。
  static const $fontFamilyFallback = '--el-font-family-fallback';

  /// 正文字重。
  static const $fontWeight = '--el-font-weight';

  /// 操作字重。
  static const $fontWeightAction = '--el-font-weight-action';

  /// 小标题字重。
  static const $fontWeightSubtitle = '--el-font-weight-subtitle';

  /// 标题字重。
  static const $fontWeightTitle = '--el-font-weight-title';

  /// 无主题宿主时使用的通用浅色值，品牌只需覆盖自身差异。
  static const Map<Object, Object> lightVars = {
    $primary: Color(0xff409eff),
    $success: Color(0xff67c23a),
    $info: Color(0xff909399),
    $warning: Color(0xffe6a23c),
    $error: Color(0xfff56c6c),
    $black: Color(0xff000000),
    $white: Color(0xffffffff),
    $bgColor: Color(0xffffffff),
    $cardColor: Color(0xffffffff),
    $fill: Color(0xfff1f2f4),
    $textColor: Color(0xff303133),
    $textRegular: Color(0xff606266),
    $textSecondary: Color(0xff909399),
    $textPlaceholder: Color(0xffc0c4cc),
    $textDisabled: Color(0xffd4d7de),
    $borderColor: Color(0xffdcdfe6),
    $gray: Color(0xffbac2ce),
    $hover: Color(0xffe9ecf0),
    $press: Color(0xffe0e4ea),
    $selectedBackground: Color(0xffffffff),
    $primaryText: Color(0xffffffff),
    $textOnLight: Color(0xff303133),
    $textOnDark: Color(0xffffffff),
    $shadowXs: <BoxShadow>[],
    $shadowSm: <BoxShadow>[],
    $shadowMd: <BoxShadow>[],
    $shadowLg: <BoxShadow>[],
    $shadowXl: <BoxShadow>[],
    $selectedShadow: <BoxShadow>[],
    $overlayColor: Color(0xcc000000),
    $overlayColorLight: Color(0xb3000000),
    $overlayColorLighter: Color(0x80000000),
    $overlayBackdropBlur: 4.0,
    $size: ElLevelType.md,
    $controlHeights: <double>[24, 32, 36, 40, 44],
    $fontSizes: <double>[13, 14, 15, 15, 16],
    $iconSizes: <double>[16, 20, 24, 28, 32],
    $borderWidths: <double>[0.5, 0.75, 1, 1.5, 2],
    $radiusXs: 2.0,
    $radiusSm: 4.0,
    $radiusMd: 6.0,
    $radiusLg: 8.0,
    $radiusXl: 12.0,
    $fontFamily: '',
    $fontFamilyFallback: <String>[],
    $fontWeight: 400.0,
    $fontWeightAction: 500.0,
    $fontWeightSubtitle: 600.0,
    $fontWeightTitle: 700.0,
  };

  /// 通用暗色增量，变体命中时覆盖浅色表。
  static const Map<Object, Object> darkVars = {
    $bgColor: Color.fromRGBO(30, 30, 30, 1),
    $cardColor: Color.fromRGBO(43, 43, 43, 1),
    $textColor: Color(0xffe5eaf3),
    $textRegular: Color(0xffcfd3dc),
    $textSecondary: Color(0xffa3a6ad),
    $textPlaceholder: Color(0xff8d9095),
    $textDisabled: Color(0xff6c6e72),
    $borderColor: Color(0xff4c4d4f),
    $fill: Color(0xff333944),
    $gray: Color(0xff7c899c),
    $hover: Color(0xff3c4350),
    $press: Color(0xff464e5b),
    $selectedBackground: Color(0xff414956),
  };
}

/// 主题快捷读取沿用旧实现的薄扩展，调用入口本身不订阅。
extension ElThemeContextExt on BuildContext {
  /// 当前主题的按键读取入口。
  ElThemeExt get elTheme => ElThemeExt(this);

  /// 读取必需变量，缺失时由调用方的声明错误直接暴露。
  T elVar<T extends Object>(Object key) => ElView.of(this).getVar<T>(key)!;

  /// 读取变量，缺失时使用默认值。
  T elVarOr<T extends Object>(Object key, T fallback) => ElView.maybeOf(this)?.getVar<T>(key) ?? fallback;

  /// 仅在变量缺失时计算默认值。
  T elVarOrElse<T extends Object>(Object key, T Function() orElse) => ElView.maybeOf(this)?.getVar<T>(key) ?? orElse();
}

/// 两端共用的类型化主题读面，每个 getter 只订阅它读取的变量。
extension type const ElThemeExt(BuildContext _context) {
  T _read<T extends Object>(Object key) => ElView.maybeOf(_context)?.getVar<T>(key) ?? ElTheme.lightVars[key] as T;
  double _number(Object key) => _read<num>(key).toDouble();

  /// 当前明暗状态。
  Brightness get brightness => ElView.maybeOf(_context)?.brightness ?? Brightness.light;

  /// 品牌主色。
  Color get primary => _read(ElTheme.$primary);

  /// 成功色。
  Color get success => _read(ElTheme.$success);

  /// 信息色。
  Color get info => _read(ElTheme.$info);

  /// 警告色。
  Color get warning => _read(ElTheme.$warning);

  /// 错误色。
  Color get error => _read(ElTheme.$error);

  /// 黑色基准。
  Color get black => _read(ElTheme.$black);

  /// 白色基准。
  Color get white => _read(ElTheme.$white);

  /// 页面背景。
  Color get bgColor => _read(ElTheme.$bgColor);

  /// 卡片背景。
  Color get cardColor => _read(ElTheme.$cardColor);

  /// 控件填充。
  Color get fill => _read(ElTheme.$fill);

  /// 主要文字。
  Color get textColor => _read(ElTheme.$textColor);

  /// 常规文字。
  Color get textRegular => _read(ElTheme.$textRegular);

  /// 次要文字。
  Color get textSecondary => _read(ElTheme.$textSecondary);

  /// 占位文字。
  Color get textPlaceholder => _read(ElTheme.$textPlaceholder);

  /// 弱化文字。
  Color get textDisabled => _read(ElTheme.$textDisabled);

  /// 基础边框。
  Color get borderColor => _read(ElTheme.$borderColor);

  /// 未选中控件的灰色。
  Color get gray => _read(ElTheme.$gray);

  /// 悬停底色。
  Color get hover => _read(ElTheme.$hover);

  /// 按压底色。
  Color get press => _read(ElTheme.$press);

  /// 选中底色。
  Color get selectedBackground => _read(ElTheme.$selectedBackground);

  /// 主色背景上的文字。
  Color get primaryText => _read(ElTheme.$primaryText);

  /// 浅色背景上的文字。
  Color get textOnLight => _read(ElTheme.$textOnLight);

  /// 深色背景上的文字。
  Color get textOnDark => _read(ElTheme.$textOnDark);

  /// 最小阴影。
  List<BoxShadow> get shadowXs => _read(ElTheme.$shadowXs);

  /// 小阴影。
  List<BoxShadow> get shadowSm => _read(ElTheme.$shadowSm);

  /// 标准阴影。
  List<BoxShadow> get shadowMd => _read(ElTheme.$shadowMd);

  /// 弹层阴影。
  List<BoxShadow> get shadowLg => _read(ElTheme.$shadowLg);

  /// 模态阴影。
  List<BoxShadow> get shadowXl => _read(ElTheme.$shadowXl);

  /// 选中状态阴影。
  List<BoxShadow> get selectedShadow => _read(ElTheme.$selectedShadow);

  /// 模态遮罩。
  Color get overlayColor => _read(ElTheme.$overlayColor);

  /// 较浅遮罩。
  Color get overlayColorLight => _read(ElTheme.$overlayColorLight);

  /// 最浅遮罩。
  Color get overlayColorLighter => _read(ElTheme.$overlayColorLighter);

  /// 遮罩模糊半径。
  double get overlayBackdropBlur => _number(ElTheme.$overlayBackdropBlur);

  /// 全局控件档位。
  ElLevelType get size => _read(ElTheme.$size);

  /// 五档控件高度。
  List<double> get controlHeights => _read(ElTheme.$controlHeights);

  /// 五档字号。
  List<double> get fontSizes => _read(ElTheme.$fontSizes);

  /// 五档图标尺寸。
  List<double> get iconSizes => _read(ElTheme.$iconSizes);

  /// 五档边框宽度。
  List<double> get borderWidths => _read(ElTheme.$borderWidths);

  /// 最小圆角。
  double get radiusXs => _number(ElTheme.$radiusXs);

  /// 小圆角。
  double get radiusSm => _number(ElTheme.$radiusSm);

  /// 标准圆角。
  double get radiusMd => _number(ElTheme.$radiusMd);

  /// 大圆角。
  double get radiusLg => _number(ElTheme.$radiusLg);

  /// 最大圆角。
  double get radiusXl => _number(ElTheme.$radiusXl);

  /// 默认字体。
  String get fontFamily => _read(ElTheme.$fontFamily);

  /// 字体回退顺序。
  List<String> get fontFamilyFallback => _read(ElTheme.$fontFamilyFallback);

  /// 正文字重。
  double get fontWeight => _number(ElTheme.$fontWeight);

  /// 操作字重。
  double get fontWeightAction => _number(ElTheme.$fontWeightAction);

  /// 小标题字重。
  double get fontWeightSubtitle => _number(ElTheme.$fontWeightSubtitle);

  /// 标题字重。
  double get fontWeightTitle => _number(ElTheme.$fontWeightTitle);

  /// 当前语义色集合。
  Map<ElThemeType, Color> get themeColors => {for (final type in ElThemeType.values) type: type.color(_context)};
  Color _borderShade(int level, {bool reverse = false}) {
    final dark = brightness == Brightness.dark;
    return dark != reverse ? borderColor.mix(const Color(0xff222222), level * 9) : borderColor.mix(white, level * 10);
  }

  /// 悬停边框色。
  Color get borderColorHover => _borderShade(2, reverse: true);

  /// 较浅边框色。
  Color get borderColorLight => _borderShade(3);

  /// 浅边框色。
  Color get borderColorLighter => _borderShade(5);

  /// 最浅边框色。
  Color get borderColorExtraLight => _borderShade(7);

  /// 加深边框色。
  Color get borderColorDark => _borderShade(1, reverse: true);

  /// 更深边框色。
  Color get borderColorDarker => _borderShade(2, reverse: true);

  /// 禁用文字色。
  Color get disabledTextColor => textPlaceholder;

  /// 禁用背景色。
  Color get disabledBgColor => brightness == Brightness.dark ? const Color(0xff262727) : const Color(0xfff5f7fa);

  /// 禁用边框色。
  Color get disabledBorderColor => borderColorLight;

  /// 选区高亮色。
  Color get selectionColor =>
      brightness == Brightness.dark ? primary.mix(const Color(0xff222222), 63) : primary.mix(white, 70);
}

/// 将通用语义类型映射到主题变量。
extension ElThemeTypeColor on ElThemeType {
  /// 当前语义类型对应的变量键。
  Object get token => switch (this) {
    .primary => ElTheme.$primary,
    .success => ElTheme.$success,
    .info => ElTheme.$info,
    .warning => ElTheme.$warning,
    .error => ElTheme.$error,
  };

  /// 当前主题中的实际语义色。
  Color color(BuildContext context) => switch (this) {
    .primary => context.elTheme.primary,
    .success => context.elTheme.success,
    .info => context.elTheme.info,
    .warning => context.elTheme.warning,
    .error => context.elTheme.error,
  };
}

/// 通用五档圆角、文字和阴影读取。
extension ElLevelTypeExt on ElLevelType {
  /// 当前档位的圆角。
  double radius(BuildContext context) {
    final t = context.elTheme;
    return switch (this) {
      .xs => t.radiusXs,
      .sm => t.radiusSm,
      .md => t.radiusMd,
      .lg => t.radiusLg,
      .xl => t.radiusXl,
    };
  }

  /// 当前档位的文字色。
  Color textColor(BuildContext context) {
    final t = context.elTheme;
    return switch (this) {
      .xs => t.textColor,
      .sm => t.textRegular,
      .md => t.textSecondary,
      .lg => t.textPlaceholder,
      .xl => t.textDisabled,
    };
  }

  /// 当前档位的阴影。
  List<BoxShadow> shadow(BuildContext context) {
    final t = context.elTheme;
    return switch (this) {
      .xs => t.shadowXs,
      .sm => t.shadowSm,
      .md => t.shadowMd,
      .lg => t.shadowLg,
      .xl => t.shadowXl,
    };
  }
}
