import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 标签页组合的外观类型。
enum ElTabsType {
  /// 以活动条指示选中项。
  line,

  /// 独立卡片式标签。
  card,

  /// 卡片标签与内容共用外框。
  borderCard,
}

/// 标签栏相对内容区域的位置。
enum ElTabsPosition {
  /// 标签栏位于上方。
  top,

  /// 标签栏位于下方。
  bottom,

  /// 标签栏位于左侧。
  left,

  /// 标签栏位于右侧。
  right,
}

/// 标签页组合中的单页配置。
class ElTabPane {
  /// 创建标签内容、身份与关闭配置。
  const ElTabPane({
    this.label,
    this.child,
    this.name,
    this.disabled = false,
    this.closable = false,
  });

  /// 标签显示内容，接受文字或 Widget。
  final Object? label;

  /// 该页的正文内容。
  final Widget? child;

  /// 页身份值，省略时由品牌实现采用下标。
  final Object? name;

  /// 禁止用户选择该页。
  final bool disabled;

  /// 显示关闭操作，实际移除由调用方决定。
  final bool closable;
}

/// 标签页组合的公共声明，底层视口仍使用 ElTabView。
class ElTabs extends StatelessWidget {
  /// 创建按页身份值绑定的标签页声明。
  const ElTabs({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    required this.panes,
    this.type = ElTabsType.line,
    this.tabPosition = ElTabsPosition.top,
    this.stretch = false,
    this.addable = false,
    this.onAdd,
    this.onRemove,
    this.style,
    this.headerStyle,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       assert(panes.length > 0, 'panes 不能为空');

  /// 当前页身份值。
  final Object? value;

  /// 外部页身份模型，生命周期由调用方管理。
  final ValueNotifier<Object?>? modelValue;

  /// 当前页身份变化通知。
  final ValueChanged<Object?>? onChanged;

  /// 标签页配置列表。
  final List<ElTabPane> panes;

  /// 标签页外观类型。
  final ElTabsType type;

  /// 标签栏相对内容的位置。
  final ElTabsPosition tabPosition;

  /// 将标签等分整条标签栏。
  final bool stretch;

  /// 显示新增操作入口。
  final bool addable;

  /// 新增操作通知。
  final VoidCallback? onAdd;

  /// 请求移除指定身份的页，真正移除由调用方处理。
  final void Function(Object? name)? onRemove;

  /// 标签页根样式。
  final ElStyle? style;

  /// 标签栏样式。
  final ElStyle? headerStyle;

  /// 辅助技术读取的标签页名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).tabsBuilder!(context, this);
}

/// 独立标签栏中的单项内容与交互配置。
class ElTabItem {
  /// 创建一个具有文字、图标或自定义内容的标签项。
  const ElTabItem({
    this.label,
    this.icon,
    this.badge,
    this.child,
    this.disabled = false,
    this.key,
  }) : assert(label != null || icon != null || child != null);

  /// 标签文字。
  final String? label;

  /// 标签前置图标。
  final Widget? icon;

  /// 标签徽标内容。
  final Widget? badge;

  /// 完整接管标签内容的自定义组件。
  final Widget? child;

  /// 禁止选择该标签。
  final bool disabled;

  /// 标签内容的稳定身份。
  final Key? key;
}

/// 按索引与连续选中度构建自定义标签指示器。
typedef ElTabIndicatorBuilder = Widget Function(
  BuildContext context,
  int index,
  double selectedFraction,
);

/// 与现有 ElTabController 联动的标签栏公共声明。
class ElTabBar extends StatelessWidget {
  /// 创建独立标签栏，控制器由调用方持有。
  const ElTabBar({
    super.key,
    required this.tabs,
    required this.controller,
    this.scrollable = false,
    this.height = 44,
    this.onTap,
    this.indicator,
    this.selectedTextStyle,
    this.textStyle,
    this.selectedColor,
    this.color,
    this.disabledColor,
    this.indicatorColor,
    this.indicatorWidth = 28,
    this.indicatorHeight = 2,
  }) : assert(height > 0),
       assert(indicatorWidth > 0),
       assert(indicatorHeight > 0);

  /// 标签项列表。
  final List<ElTabItem> tabs;

  /// 与正文视口共享的现有通用控制器。
  final ElTabController controller;

  /// 允许标签栏横向滚动。
  final bool scrollable;

  /// 标签栏的显式逻辑高度。
  final double height;

  /// 用户选择标签时的附加通知。
  final ValueChanged<int>? onTap;

  /// 自定义活动指示器。
  final ElTabIndicatorBuilder? indicator;

  /// 选中标签的文字样式。
  final ElStyle? selectedTextStyle;

  /// 未选中标签的文字样式。
  final ElStyle? textStyle;

  /// 选中标签颜色，null 时由品牌决定。
  final Color? selectedColor;

  /// 未选中标签颜色，null 时由品牌决定。
  final Color? color;

  /// 禁用标签颜色，null 时由品牌决定。
  final Color? disabledColor;

  /// 默认指示器颜色，null 时由品牌决定。
  final Color? indicatorColor;

  /// 默认指示器的显式宽度。
  final double indicatorWidth;

  /// 默认指示器的显式高度。
  final double indicatorHeight;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).tabBarBuilder!(context, this);
}
