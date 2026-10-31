import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/desktop/internal.dart';

Widget _builderSuffixIcon(ValueNotifier<bool> expanded) {
  return AnimatedRotation(
    duration: ElCollapseAnimation.defaultDuration,
    curve: ElCollapseAnimation.defaultCurve,
    turns: expanded.value ? 0.5 : 0,
    child: Icon(ElIcons.arrowDown, size: 14),
  );
}

class ElNavMenu<T> extends HookWidget {
  const ElNavMenu({
    super.key,
    required this.children,
    this.router,
    this.style,
    this.itemHeight = 56.0,
    this.iconGap = 8.0,
    this.nestGap = 20.0,
    required this.onChanged,
    this.suffixIconBuilder = _builderSuffixIcon,
  });

  /// 菜单模型集合
  final List<ElMenuModel<T>> children;

  /// 监听的声明式路由对象
  final RouterConfig? router;

  /// 定义菜单外观、文本、图标样式
  final ElStyle? style;

  /// 每个菜单的高度
  final double itemHeight;

  /// 图标与标题的间隔
  final double iconGap;

  /// 嵌套菜单距离上一层级的距离
  final double nestGap;

  /// 监听菜单选中变化
  final ValueChanged<ElMenuModel<T>> onChanged;

  /// 自定义后缀展开图标
  final Widget Function(ValueNotifier<bool> expanded) suffixIconBuilder;

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
