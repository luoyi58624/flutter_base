import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 进度展示的几何形态。
enum ElProgressShape {
  /// 直线进度条。
  line,

  /// 完整圆环。
  circle,

  /// 底部留缺口的仪表盘圆环。
  dashboard,
}

/// 进度的语义状态。
enum ElProgressStatus {
  /// 普通进行状态。
  normal,

  /// 成功完成状态。
  success,

  /// 警告状态。
  warning,

  /// 错误状态。
  error,
}

/// 按百分比上界匹配的进度颜色配置。
class ElProgressColorStop {
  /// 创建百分比上界与颜色的映射。
  const ElProgressColorStop({required this.percentage, required this.color});

  /// 使用该颜色的百分比上界。
  final double percentage;

  /// 该区间采用的实际颜色。
  final Color color;
}

/// 品牌实现传给读数插槽的进度快照。
class ElProgressValue {
  /// 创建进度快照，数值归一化由品牌实现完成。
  const ElProgressValue({
    required this.value,
    required this.max,
    required this.percentage,
  });

  /// 完成量，null 表示不确定进度。
  final double? value;

  /// 读数采用的总量。
  final double max;

  /// 完成比例的百分数。
  final double percentage;
}

/// 根据进度快照构建自定义读数。
typedef ElProgressTextBuilder = Widget Function(
  BuildContext context,
  ElProgressValue value,
);

/// 条形、圆环与仪表盘进度的公共声明。
class ElProgress extends StatelessWidget {
  /// 创建条形进度，percentage 与 value 两种数值输入互斥。
  const ElProgress({
    super.key,
    this.percentage,
    this.value,
    this.buffer,
    this.max = 100,
    this.status = ElProgressStatus.normal,
    this.showText = false,
    this.textBuilder,
    this.semanticLabel,
    this.strokeLinecap = StrokeCap.round,
    this.colorStops,
    this.style,
    this.strokeWidth = 6,
    this.color,
    this.trackColor,
    this.width = 126,
    this.transitionDuration = const Duration(milliseconds: 600),
    this.indeterminateDuration = const Duration(seconds: 3),
  }) : shape = ElProgressShape.line,
       assert(percentage == null || value == null, 'percentage 与 value 互斥'),
       assert(
         percentage == null || (percentage >= 0 && percentage <= 100),
         'percentage 必须在 0 至 100 之间',
       );

  /// 创建完整圆环进度。
  const ElProgress.circle({
    super.key,
    this.percentage,
    this.value,
    this.buffer,
    this.max = 100,
    this.status = ElProgressStatus.normal,
    this.showText = false,
    this.textBuilder,
    this.semanticLabel,
    this.strokeLinecap = StrokeCap.round,
    this.colorStops,
    this.style,
    this.strokeWidth = 6,
    this.color,
    this.trackColor,
    this.width = 126,
    this.transitionDuration = const Duration(milliseconds: 600),
    this.indeterminateDuration = const Duration(seconds: 3),
  }) : shape = ElProgressShape.circle,
       assert(percentage == null || value == null, 'percentage 与 value 互斥'),
       assert(
         percentage == null || (percentage >= 0 && percentage <= 100),
         'percentage 必须在 0 至 100 之间',
       );

  /// 创建底部留缺口的仪表盘进度。
  const ElProgress.dashboard({
    super.key,
    this.percentage,
    this.value,
    this.buffer,
    this.max = 100,
    this.status = ElProgressStatus.normal,
    this.showText = false,
    this.textBuilder,
    this.semanticLabel,
    this.strokeLinecap = StrokeCap.round,
    this.colorStops,
    this.style,
    this.strokeWidth = 6,
    this.color,
    this.trackColor,
    this.width = 126,
    this.transitionDuration = const Duration(milliseconds: 600),
    this.indeterminateDuration = const Duration(seconds: 3),
  }) : shape = ElProgressShape.dashboard,
       assert(percentage == null || value == null, 'percentage 与 value 互斥'),
       assert(
         percentage == null || (percentage >= 0 && percentage <= 100),
         'percentage 必须在 0 至 100 之间',
       );

  /// 由命名构造确定的进度形态。
  final ElProgressShape shape;

  /// 直接指定 0 至 100 的完成百分比，和 value 互斥。
  final double? percentage;

  /// 以 max 为总量的当前完成量，和 percentage 互斥。
  final double? value;

  /// 缓冲完成量，与 value 使用相同单位。
  final double? buffer;

  /// value 和 buffer 的总量基准。
  final double max;

  /// 进度的语义状态。
  final ElProgressStatus status;

  /// 显示品牌默认读数或自定义读数插槽。
  final bool showText;

  /// 根据品牌实现提供的进度快照构建读数。
  final ElProgressTextBuilder? textBuilder;

  /// 辅助技术读取的进度名称。
  final String? semanticLabel;

  /// 进度笔画两端的形状。
  final StrokeCap strokeLinecap;

  /// 按百分比上界排列的分段颜色。
  final List<ElProgressColorStop>? colorStops;

  /// 组件根样式。
  final ElStyle? style;

  /// 直线条或圆环的笔画宽度。
  final double strokeWidth;

  /// 进度颜色，分段色标可由品牌实现优先处理。
  final Color? color;

  /// 进度轨道颜色。
  final Color? trackColor;

  /// 圆环与仪表盘的逻辑直径。
  final double width;

  /// 完成量变化的过渡时长。
  final Duration transitionDuration;

  /// 不确定进度动画的周期。
  final Duration indeterminateDuration;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).progressBuilder!(context, this);
}
