import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 底部导航入口的内容配置。
class ElBottomNavigationBarItem {
  /// 创建导航入口数据。
  const ElBottomNavigationBarItem({
    required this.label,
    this.icon,
    this.selectedIcon,
    this.disabled = false,
  });

  /// 可见文字及辅助名称。
  final String label;

  /// 普通图标或自定义内容。
  final Object? icon;

  /// 选中时的图标或内容。
  final Object? selectedIcon;

  /// 是否禁用该入口。
  final bool disabled;
}

/// 底部导航入口与下标模型的公共声明。
class ElBottomNavigationBar extends StatelessWidget {
  /// 创建底部导航配置，不建立选择绑定。
  const ElBottomNavigationBar({
    super.key,
    this.value = 0,
    this.modelValue,
    this.onChanged,
    required this.items,
    this.disabled = false,
    this.style,
    this.itemStyle,
    this.semanticLabel = '底部导航',
  });

  /// 当前选中入口的下标。
  final int? value;

  /// 外部选择模型。
  final ValueNotifier<int>? modelValue;

  /// 选择下标变化通知。
  final ValueChanged<int>? onChanged;

  /// 导航入口数据。
  final List<ElBottomNavigationBarItem> items;

  /// 是否禁用全部入口。
  final bool disabled;

  /// 导航区域样式。
  final ElStyle? style;

  /// 所有入口的样式覆盖。
  final ElStyle? itemStyle;

  /// 导航区域的辅助名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context)
          .bottomNavigationBarBuilder!(context, this);
}
