import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 时间线节点的语义尺寸。
enum ElTimelineNodeSize {
  /// 普通节点。
  normal,

  /// 强调的大节点。
  large,
}

/// 时间戳相对正文的位置。
enum ElTimelinePlacement {
  /// 时间戳位于正文上方。
  top,

  /// 时间戳位于正文下方。
  bottom,
}

/// 时间线公共声明。
class ElTimeline extends StatelessWidget {
  /// 创建时间线公共声明。
  const ElTimeline({
    super.key,
    required this.children,
    this.style,
    this.semanticLabel,
  });

  /// 时间线成员列表。
  final List<Widget> children;

  /// 组件根样式。
  final ElStyle? style;

  /// 辅助技术读取的组件名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).timelineBuilder!(context, this);
}

/// 时间线成员公共声明。
class ElTimelineItem extends StatelessWidget {
  /// 创建时间线成员公共声明。
  const ElTimelineItem({
    super.key,
    this.child,
    this.timestamp,
    this.placement = ElTimelinePlacement.bottom,
    this.hideTimestamp = false,
    this.type,
    this.color,
    this.size = ElTimelineNodeSize.normal,
    this.hollow = false,
    this.icon,
    this.style,
    this.nodeStyle,
    this.timestampStyle,
    this.contentStyle,
  });

  /// 事件正文内容。
  final Object? child;

  /// 事件时间戳内容。
  final Object? timestamp;

  /// 时间戳相对正文的位置。
  final ElTimelinePlacement placement;

  /// 隐藏时间戳。
  final bool hideTimestamp;

  /// 节点的语义颜色类型。
  final ElThemeType? type;

  /// 显式节点颜色，优先于 type。
  final Color? color;

  /// 节点的语义尺寸。
  final ElTimelineNodeSize size;

  /// 使用空心节点。
  final bool hollow;

  /// 节点图标内容。
  final Object? icon;

  /// 组件根样式。
  final ElStyle? style;

  /// 时间线节点样式。
  final ElStyle? nodeStyle;

  /// 时间戳样式。
  final ElStyle? timestampStyle;

  /// 正文区域样式。
  final ElStyle? contentStyle;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).timelineItemBuilder!(context, this);
}
