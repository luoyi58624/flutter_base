import 'package:flutter/widgets.dart';

import '../commons/models.dart';
import '../views/view/view.dart';
import 'tokens.dart';

export 'tokens.dart';

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
  T _read<T extends Object>(Object key) {
    final value = ElView.maybeOf(_context)?.getVar<T>(key);
    if (value == null) throw StateError('主题变量 $key 未注入或类型不符，期望 $T');
    return value;
  }

  double _number(Object key) => _read<num>(key).toDouble();

  /// 当前明暗状态。
  Brightness get brightness => ElView.maybeOf(_context)?.brightness ?? Brightness.light;

  /// 品牌主色。
  Color get primary => _read(ElTokens.$primary);

  /// 成功色。
  Color get success => _read(ElTokens.$success);

  /// 信息色。
  Color get info => _read(ElTokens.$info);

  /// 警告色。
  Color get warning => _read(ElTokens.$warning);

  /// 错误色。
  Color get error => _read(ElTokens.$error);

  /// 黑色基准。
  Color get black => _read(ElTokens.$black);

  /// 白色基准。
  Color get white => _read(ElTokens.$white);

  /// 页面背景。
  Color get bgColor => _read(ElTokens.$bgColor);

  /// 卡片背景。
  Color get cardColor => _read(ElTokens.$cardColor);

  /// 卡片及卡片内列表行的按压背景。
  Color get cardPressColor => _read(ElTokens.$cardPressColor);

  /// 内容分隔线颜色，独立于控件边框。
  Color get dividerColor => _read(ElTokens.$dividerColor);

  /// 控件填充。
  Color get fill => _read(ElTokens.$fill);

  /// 主要文字。
  Color get textColor => _read(ElTokens.$textColor);

  /// 常规文字。
  Color get textRegular => _read(ElTokens.$textRegular);

  /// 次要文字。
  Color get textSecondary => _read(ElTokens.$textSecondary);

  /// 占位文字。
  Color get textPlaceholder => _read(ElTokens.$textPlaceholder);

  /// 弱化文字。
  Color get textDisabled => _read(ElTokens.$textDisabled);

  /// 基础边框。
  Color get borderColor => _read(ElTokens.$borderColor);

  /// 未选中控件的灰色。
  Color get gray => _read(ElTokens.$gray);

  /// 悬停底色。
  Color get hover => _read(ElTokens.$hover);

  /// 按压底色。
  Color get press => _read(ElTokens.$press);

  /// 选中底色。
  Color get selectedBackground => _read(ElTokens.$selectedBackground);

  /// 主色背景上的文字。
  Color get primaryText => _read(ElTokens.$primaryText);

  /// 浅色背景上的文字。
  Color get textOnLight => _read(ElTokens.$textOnLight);

  /// 深色背景上的文字。
  Color get textOnDark => _read(ElTokens.$textOnDark);

  /// 最小阴影。
  List<BoxShadow> get shadowXs => _read(ElTokens.$shadowXs);

  /// 小阴影。
  List<BoxShadow> get shadowSm => _read(ElTokens.$shadowSm);

  /// 标准阴影。
  List<BoxShadow> get shadowMd => _read(ElTokens.$shadowMd);

  /// 弹层阴影。
  List<BoxShadow> get shadowLg => _read(ElTokens.$shadowLg);

  /// 模态阴影。
  List<BoxShadow> get shadowXl => _read(ElTokens.$shadowXl);

  /// 选中状态阴影。
  List<BoxShadow> get selectedShadow => _read(ElTokens.$selectedShadow);

  /// 模态遮罩。
  Color get overlayColor => _read(ElTokens.$overlayColor);

  /// 较浅遮罩。
  Color get overlayColorLight => _read(ElTokens.$overlayColorLight);

  /// 最浅遮罩。
  Color get overlayColorLighter => _read(ElTokens.$overlayColorLighter);

  /// 遮罩模糊半径。
  double get overlayBackdropBlur => _number(ElTokens.$overlayBackdropBlur);

  /// 默认边框宽度，控件密度不改变描边粗细。
  double get borderWidth => _number(ElTokens.$borderWidth);

  /// 最小圆角。
  double get radiusXs => _number(ElTokens.$radiusXs);

  /// 小圆角。
  double get radiusSm => _number(ElTokens.$radiusSm);

  /// 标准圆角。
  double get radiusMd => _number(ElTokens.$radiusMd);

  /// 大圆角。
  double get radiusLg => _number(ElTokens.$radiusLg);

  /// 最大圆角。
  double get radiusXl => _number(ElTokens.$radiusXl);

  /// 默认字体。
  String get fontFamily => _read(ElTokens.$fontFamily);

  /// 字体回退顺序。
  List<String> get fontFamilyFallback => _read(ElTokens.$fontFamilyFallback);

  /// 正文字重。
  double get fontWeight => _number(ElTokens.$fontWeight);

  /// 操作字重。
  double get fontWeightAction => _number(ElTokens.$fontWeightAction);

  /// 小标题字重。
  double get fontWeightSubtitle => _number(ElTokens.$fontWeightSubtitle);

  /// 标题字重。
  double get fontWeightTitle => _number(ElTokens.$fontWeightTitle);

  /// 当前语义色集合。
  Map<ElThemeType, Color> get themeColors => {for (final type in ElThemeType.values) type: type.color(_context)};

  /// 悬停边框色。
  Color get borderColorHover => _read(ElTokens.$borderColorHover);

  /// 较浅边框色。
  Color get borderColorLight => _read(ElTokens.$borderColorLight);

  /// 浅边框色。
  Color get borderColorLighter => _read(ElTokens.$borderColorLighter);

  /// 最浅边框色。
  Color get borderColorExtraLight => _read(ElTokens.$borderColorExtraLight);

  /// 加深边框色。
  Color get borderColorDark => _read(ElTokens.$borderColorDark);

  /// 更深边框色。
  Color get borderColorDarker => _read(ElTokens.$borderColorDarker);

  /// 禁用文字色。
  Color get disabledTextColor => _read(ElTokens.$disabledTextColor);

  /// 禁用背景色。
  Color get disabledBgColor => _read(ElTokens.$disabledBgColor);

  /// 禁用边框色。
  Color get disabledBorderColor => _read(ElTokens.$disabledBorderColor);

  /// 选区高亮色。
  Color get selectionColor => _read(ElTokens.$selectionColor);
}

/// 将通用语义类型映射到主题变量。
extension ElThemeTypeColor on ElThemeType {
  /// 当前语义类型对应的变量键。
  Object get token => switch (this) {
    .primary => ElTokens.$primary,
    .success => ElTokens.$success,
    .info => ElTokens.$info,
    .warning => ElTokens.$warning,
    .error => ElTokens.$error,
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
