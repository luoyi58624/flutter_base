part of '../style/style.dart';

/// 仅作用于当前文本的高级配置，不继承且不参与状态、断点、入场与关键帧变体。
@ElModelGenerator.copy(generateProps: true)
@immutable
class ElTextOptions with Equatable {
  /// 创建稀疏配置，未声明的环境参数由当前文本宿主提供。
  const ElTextOptions({
    this.locale,
    this.textScaler,
    this.strutStyle,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.leadingDistribution,
    this.textBaseline,
  });

  /// 当前段落的字形语言提示，不向后代继承。
  final Locale? locale;

  /// 当前段落的文字缩放规则，不向后代继承。
  final TextScaler? textScaler;

  /// 当前段落的最小行高与基线度量，不向后代继承。
  final StrutStyle? strutStyle;

  /// 当前段落的宽度基准，未声明时使用 parent，不向后代继承。
  final TextWidthBasis? textWidthBasis;

  /// 当前段落首尾行的行高度量规则，不向后代继承。
  final TextHeightBehavior? textHeightBehavior;

  /// 当前文本的行高余量分布，未声明时由文本引擎采用 even。
  final TextLeadingDistribution? leadingDistribution;

  /// 当前文本的字形基线种类。
  final TextBaseline? textBaseline;

  /// 按非空字段合并声明，等值结果保留当前实例。
  ElTextOptions merge([ElTextOptions? other]) {
    if (other == null) return this;
    final result = ElTextOptionsExt(this).merge(other);
    return result == this ? this : result;
  }

  @override
  List<Object?> get props => _props;
}
