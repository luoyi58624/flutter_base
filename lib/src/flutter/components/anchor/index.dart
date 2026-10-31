import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 锚点标记的外观形式。
enum ElAnchorType {
  /// 普通滑块标记。
  normal,

  /// 下划线标记。
  underline,
}

/// 锚点目标与显示内容的数据声明。
class ElAnchorLink {
  /// 创建锚点项。
  const ElAnchorLink({
    required this.targetKey,
    this.title,
    this.name,
    this.depth = 0,
  });

  /// 目标内容的挂载键。
  final GlobalKey targetKey;

  /// 锚点的可见内容。
  final Object? title;

  /// 可选的业务身份值。
  final Object? name;

  /// 竖向锚点的嵌套层级。
  final int depth;

  /// 显式身份优先，缺省使用目标键。
  Object get id => name ?? targetKey;
}

/// 锚点选择、目标列表与滚动配置的公共声明。
class ElAnchor extends StatelessWidget {
  /// 创建锚点配置，不监听或操作滚动位置。
  const ElAnchor({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    required this.controller,
    required this.links,
    this.direction = Axis.vertical,
    this.type = ElAnchorType.normal,
    this.offset = 0,
    this.duration = const Duration(milliseconds: 300),
    this.marker = true,
    this.style,
    this.itemStyle,
    this.semanticLabel,
  });

  /// 当前激活的锚点身份。
  final Object? value;

  /// 外部锚点身份模型。
  final ValueNotifier<Object?>? modelValue;

  /// 激活锚点变化通知。
  final ValueChanged<Object?>? onChanged;

  /// 目标内容所在滚动视图的控制器。
  final ScrollController controller;

  /// 锚点目标列表。
  final List<ElAnchorLink> links;

  /// 锚点排列方向。
  final Axis direction;

  /// 标记外观配置。
  final ElAnchorType type;

  /// 滚动定位的顶部保留偏移。
  final double offset;

  /// 点击定位的动画时长配置。
  final Duration duration;

  /// 是否显示当前项标记。
  final bool marker;

  /// 根节点样式。
  final ElStyle? style;

  /// 锚点项样式。
  final ElStyle? itemStyle;

  /// 锚点区域的辅助名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).anchorBuilder!(context, this);
}
