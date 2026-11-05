import 'package:flutter/widgets.dart';

import '../../utils/model_value/index.dart' show ElModelValue;
import '../../views/tab/tab_controller.dart' show ElTabController;
import '../../views/view/style/style.dart' show ElStyle;
import '../index.dart' show ElComponentProvider;

/// 单个页签的业务身份、标签和正文。
class ElTabPane<T> {
  /// 创建具有明确业务值的页签。
  const ElTabPane({required this.value, this.label, this.child, this.disabled = false});

  /// 所属页签集合内唯一的业务值。
  final T value;

  /// 标签内容，接受文字或 Widget。
  final Object? label;

  /// 页签正文，品牌保留调用方的原实例。
  final Widget? child;

  /// 禁止选择该页。
  final bool disabled;
}

/// 页签值绑定与内容组合声明，底层继续复用 ElTabController / ElTabView。
class ElTabs<T> extends ElModelValue<T> {
  /// 创建与 Web 相同的页签选择与可选横向手势。
  ElTabs({
    super.key,
    super.value,
    super.modelValue,
    super.onChanged,
    required this.panes,
    this.disabled = false,
    this.swipeable = true,
    this.style,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       assert(value != null || modelValue != null || null is T, '非空 T 必须提供 value 或 modelValue');

  /// 挂载后由公共模型持有的当前页签值。
  T get currentValue => $obs.value;

  /// 写入同一模型并沿用公共通知规则。
  set currentValue(T value) => $obs.value = value;

  /// 以业务值标识的页签内容。
  final List<ElTabPane<T>> panes;

  /// 禁止用户选择或滑动切换页签。
  final bool disabled;

  /// 允许单指横向手势切换正文。
  final bool swipeable;

  /// 在品牌默认外观之后合并的根样式。
  final ElStyle? style;

  /// 辅助技术读取的页签分组名称。
  final String? semanticLabel;

  @override
  Widget obsBuilder(BuildContext context) =>
      ElComponentProvider.builderOf(context, this, (b) => b.tabs)<T>(context, this);
}

/// 独立标签栏中的单项内容与交互配置。
class ElTabItem {
  /// 创建一个具有文字、图标或自定义内容的标签项。
  const ElTabItem({this.label, this.icon, this.badge, this.child, this.disabled = false, this.key})
    : assert(label != null || icon != null || child != null);

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
typedef ElTabIndicatorBuilder = Widget Function(BuildContext context, int index, double selectedFraction);

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
      ElComponentProvider.builderOf(context, this, (b) => b.tabBar)(context, this);
}
