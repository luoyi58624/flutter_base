import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 树形导航选择与侧栏元数据的公共声明。
class ElNavigationMenu<T> extends StatelessWidget implements ElSidebar {
  /// 创建导航菜单配置，不建立选中或展开状态。
  const ElNavigationMenu({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    required this.items,
    this.onSelect,
    this.disabledKeys = const {},
    this.style,
    this.itemStyle,
    this.collapseButtonStyle,
    this.semanticLabel,
    this.width,
    this.expandTop = false,
    this.drawer = false,
    this.keepAlive = true,
  });

  /// 当前选中叶子项的 key。
  final String? value;

  /// 外部导航选择模型。
  final ValueNotifier<String?>? modelValue;

  /// 叶子 key 变化通知。
  final ValueChanged<String?>? onChanged;

  /// 菜单树数据，同一树内 key 应唯一。
  final List<ElMenuModel<T>> items;

  /// 用户选中叶子项后的数据通知。
  final ValueChanged<ElMenuModel<T>>? onSelect;

  /// 禁用项的 key 集合。
  final Set<String> disabledKeys;

  /// 根节点样式。
  final ElStyle? style;

  /// 菜单项样式。
  final ElStyle? itemStyle;

  /// 折叠入口样式。
  final ElStyle? collapseButtonStyle;

  /// 导航区域的辅助名称。
  final String? semanticLabel;

  /// 展开侧栏的逻辑宽度。
  @override
  final double? width;

  /// 是否延伸至视口顶部。
  @override
  final bool expandTop;

  /// 是否始终使用抽屉形态。
  @override
  final bool drawer;

  /// 抽屉关闭后是否保留菜单状态。
  @override
  final bool keepAlive;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).navigationMenuBuilder!<T>(context, this);
}
