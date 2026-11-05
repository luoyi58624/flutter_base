import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 进度展示的几何形态。
enum ElProgressShape {
  /// 直线进度条。
  line,

  /// 完整圆环。
  circle,
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

/// 品牌实现传给读数插槽的归一化进度。
class ElProgressValue {
  /// 创建当前完成量、总量和百分比的快照。
  const ElProgressValue({required this.value, required this.max, required this.percentage});

  /// 限制在总量范围内的完成量，null 表示不确定进度。
  final double? value;

  /// 归一化后的正数总量。
  final double max;

  /// 完成比例的百分数，不确定时为 0。
  final double percentage;
}

/// 根据归一化进度构建自定义读数。
typedef ElProgressTextBuilder = Widget Function(BuildContext context, ElProgressValue value);

/// 条形和圆环进度的公共声明，沿用 Web 的完成量与缓冲量语义。
class ElProgress extends StatelessWidget {
  /// 创建条形进度，省略完成量时展示不确定状态。
  const ElProgress({
    super.key,
    this.value,
    this.buffer,
    this.max = 100,
    this.status = .normal,
    this.showText = true,
    this.textBuilder,
    this.semanticLabel = '进度',
    this.style,
  }) : shape = .line;

  /// 创建使用相同数值和状态接口的完整圆环。
  const ElProgress.circle({
    super.key,
    this.value,
    this.buffer,
    this.max = 100,
    this.status = .normal,
    this.showText = true,
    this.textBuilder,
    this.semanticLabel = '进度',
    this.style,
  }) : shape = .circle;

  /// 由构造方法确定的进度形态。
  final ElProgressShape shape;

  /// 当前完成量，省略或非有限数值表示不确定进度。
  final double? value;

  /// 已缓冲量，与完成量使用相同单位。
  final double? buffer;

  /// 总量，非正数或非有限数值由品牌实现回退为 100。
  final double max;

  /// 进度的语义状态。
  final ElProgressStatus status;

  /// 显示默认读数、状态图标或自定义读数。
  final bool showText;

  /// 自定义读数，接收与默认读数相同的归一化进度。
  final ElProgressTextBuilder? textBuilder;

  /// 辅助技术读取的进度名称。
  final String? semanticLabel;

  /// 在品牌默认外观之后合并的根样式。
  final ElStyle? style;

  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.progressBuilder)(context, this);
}
