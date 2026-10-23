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

  /// 轮廓粗细、偏移、颜色与渐变，不影响布局。
  outline,

  /// 最小宽度，数值与百分比插值；null 在中点切换。
  minWidth,

  /// 最大宽度，数值与百分比插值；null 在中点切换。
  maxWidth,

  /// 最小高度，数值与百分比插值；null 在中点切换。
  minHeight,

  /// 最大高度，数值与百分比插值；null 在中点切换。
  maxHeight,

  /// 视觉盒宽高比，null 在中点切换，仅正有限数值有效。
  aspectRatio,

  /// 背景渐变，沿原生 Gradient.lerp 规则插值。
  gradient,

  /// 内外阴影的几何与预乘 alpha 颜色，null 平滑退去。
  boxShadow,

  /// 整组透明度，null 按 1 插值，过冲限制在 0～1。
  opacity,

  /// 整组视觉变换，同类函数按参数插值，其他组合逐矩阵分量插值。
  transform,

  /// 变换原点，null 连续回退到当前变换的内部原点或盒中心。
  transformAlignment,

  /// 自身滤镜，各分量从各自恒等值连续过渡。
  filter,

  /// 背景滤镜，各分量从各自恒等值连续过渡。
  backdropFilter,
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
