part of 'index.dart';

/// 可过渡的样式属性。
enum ElTransitionField {
  /// 宽度，支持数值、百分比与自动尺寸过渡。
  width,

  /// 高度，支持数值、百分比与自动尺寸过渡。
  height,

  /// 背景色，采用预乘 alpha 插值。
  backgroundColor,

  /// 内边距，null 按零插值。
  padding,

  /// 外边距，null 按零插值。
  margin,

  /// 背景圆角，null 按零插值，仅触发重绘。
  borderRadius,

  /// 自然盒宽度倍数，null 按 1 插值，负过冲夹到零。
  widthFactor,

  /// 自然盒高度倍数，null 按 1 插值，负过冲夹到零。
  heightFactor,

  /// 边框，逐边过渡粗细、预乘 alpha 颜色与描边位置。
  border,
}

/// 指定属性的时间过渡，时长和延迟均不得为负。
@immutable
@ElModelGenerator(generateProps: true)
class ElTransition with Equatable {
  /// 创建过渡配置，省略 field 表示全部属性。
  const ElTransition({
    this.field,
    this.duration = const Duration(milliseconds: 240),
    this.curve = Curves.easeOutCubic,
    this.delay = Duration.zero,
  });

  /// 过渡全部属性。
  const ElTransition.all([
    this.duration = const Duration(milliseconds: 240),
    this.curve = Curves.easeOutCubic,
    this.delay = Duration.zero,
  ]) : field = null;

  /// 过渡指定属性。
  const ElTransition.field(
    ElTransitionField this.field, [
    this.duration = const Duration(milliseconds: 240),
    this.curve = Curves.easeOutCubic,
    this.delay = Duration.zero,
  ]);

  /// 属性，null 表示全部属性。
  final ElTransitionField? field;

  /// 过渡时长；零时长仍会等待 delay。
  final Duration duration;

  /// 缓动曲线；允许过冲，由具体属性处理有效值边界。
  final Curve curve;

  /// 开始过渡前的等待时间。
  final Duration delay;

  @override
  List<Object?> get props => _props;
}
