import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 步骤的展示状态。
enum ElStepStatus {
  /// 尚未开始。
  wait,

  /// 当前处理中。
  process,

  /// 已完成。
  finish,

  /// 发生错误。
  error,

  /// 成功完成。
  success,
}

/// 步骤集合与当前下标的公共声明。
class ElSteps extends StatelessWidget {
  /// 创建步骤条配置，不派生条目状态。
  const ElSteps({
    super.key,
    required this.children,
    this.active = 0,
    this.direction = Axis.horizontal,
    this.finishStatus = ElStepStatus.finish,
    this.processStatus = ElStepStatus.process,
    this.style,
    this.semanticLabel,
  });

  /// 步骤内容，通常为 ElStep。
  final List<Widget> children;

  /// 当前步骤的下标。
  final int active;

  /// 步骤排列方向。
  final Axis direction;

  /// 当前下标之前的步骤状态配置。
  final ElStepStatus finishStatus;

  /// 当前步骤的状态配置。
  final ElStepStatus processStatus;

  /// 步骤条样式。
  final ElStyle? style;

  /// 步骤条的辅助名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).stepsBuilder!(context, this);
}

/// 单个步骤的内容与状态覆盖声明。
class ElStep extends StatelessWidget {
  /// 创建步骤配置。
  const ElStep({
    super.key,
    this.title,
    this.description,
    this.icon,
    this.status,
    this.style,
    this.titleStyle,
    this.descriptionStyle,
  });

  /// 步骤标题。
  final Object? title;

  /// 步骤说明。
  final Object? description;

  /// 自定义图标或内容。
  final Object? icon;

  /// 显式状态，供实现覆盖组内推导值。
  final ElStepStatus? status;

  /// 根节点样式。
  final ElStyle? style;

  /// 标题样式。
  final ElStyle? titleStyle;

  /// 说明样式。
  final ElStyle? descriptionStyle;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).stepBuilder!(context, this);
}
