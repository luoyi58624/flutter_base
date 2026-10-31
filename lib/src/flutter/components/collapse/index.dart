import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 折叠面板组公共声明。
class ElCollapse extends StatelessWidget {
  /// 创建折叠面板组公共声明。
  const ElCollapse({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    required this.children,
    this.accordion = false,
    this.style,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥');

  /// 普通值输入，具体同步由品牌实现处理。
  final List<Object?>? value;

  /// 外部双向模型，生命周期由调用方管理。
  final ValueNotifier<List<Object?>>? modelValue;

  /// 模型变化通知。
  final ValueChanged<List<Object?>>? onChanged;

  /// 折叠面板成员列表。
  final List<Widget> children;

  /// 手风琴模式下同时只展开一个成员。
  final bool accordion;

  /// 组件根样式。
  final ElStyle? style;

  /// 辅助技术读取的组件名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).collapseBuilder!(context, this);
}

/// 折叠面板成员公共声明。
class ElCollapseItem extends StatelessWidget {
  /// 创建折叠面板成员公共声明。
  const ElCollapseItem({
    super.key,
    this.name,
    this.title,
    this.child,
    this.disabled = false,
    this.style,
    this.headerStyle,
    this.contentStyle,
    this.semanticLabel,
  });

  /// 成员身份值，省略时由组使用下标。
  final Object? name;

  /// 面板标题内容。
  final Object? title;

  /// 面板正文内容。
  final Object? child;

  /// 禁止用户切换展开状态。
  final bool disabled;

  /// 组件根样式。
  final ElStyle? style;

  /// 标题区域的样式。
  final ElStyle? headerStyle;

  /// 展开正文区域的样式。
  final ElStyle? contentStyle;

  /// 辅助技术读取的组件名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).collapseItemBuilder!(context, this);
}
