/// 移动端底部导航栏：API 与 Material NavigationBar 完全一致，
/// 从官方组件切换过来只改类名，destinations 里的 NavigationDestination 原样复用。
///
/// 只对齐 API，样式是 my-ui 自己的（56 高、顶部 1px 分隔线、无胶囊指示器）。
/// 移动端兼容参照 NavigationBar 的处理：背景铺满屏幕底、内容走 SafeArea。
library;

import 'package:flutter/material.dart'
    show InkResponse, InkRipple, Material, MaterialType, NavigationDestination, NavigationDestinationLabelBehavior;
import 'package:flutter/widgets.dart';

import '../../../../../flutter/commons/theme/index.dart' show ElThemeContextExt;
import '../../../../../flutter/views/view/style/style.dart' show ElBorder, ElBorderSide, ElStyle, ElStyleExt;
import '../../../../../flutter/views/view/view.dart' show ElView;
import '../../../internal/common.dart';

/// 移动端底部导航栏，替换 Material NavigationBar。
///
/// 外层 ElView 负责背景与顶部分隔线，内层 SafeArea 只避让底部安全区，
/// 这样有手势条时背景不会被截断。
class ElBottomTabbar extends StatelessWidget {
  /// onDestinationSelected 为空时整体只读。
  const ElBottomTabbar({
    super.key,
    required this.destinations,
    this.selectedIndex = 0,
    this.onDestinationSelected,
    this.labelBehavior = NavigationDestinationLabelBehavior.alwaysShow,
    this.height = 56,
    this.style,
  });

  /// 导航项，直接复用官方 NavigationDestination（icon/label/enabled 生效）。
  final List<NavigationDestination> destinations;

  /// 当前选中下标，越界时不显示选中态。
  final int selectedIndex;

  /// 点击导航项回调。
  final ValueChanged<int>? onDestinationSelected;

  /// 标题显示策略，复用官方 NavigationDestinationLabelBehavior。
  final NavigationDestinationLabelBehavior labelBehavior;

  /// 内容区高度，不含底部安全区。style.height 给定时以 style 为准。
  final double height;

  /// 底栏外观覆盖，默认顶部 1px 分隔线使用 dividerColor，同名字段优先于默认样式。
  final ElStyle? style;

  @override
  Widget build(BuildContext context) {
    final t = context.elTheme;
    // 高度只在内层定一次，外层去掉 height 避免被 SafeArea 再挤压。
    final barHeight = style?.height ?? height;
    return ElView(
      style: ElStyle(
        width: '100%',
        backgroundColor: t.cardColor,
        border: ElBorder.only(borderTop: ElBorderSide(borderColor: t.dividerColor, borderWidth: 0.5)),
      ).merge(style?.copyWith(height: null)),
      child: SafeArea(
        top: false,
        child: ElView(
          style: ElStyle(height: barHeight),
          // 所有导航项共用墨水层，只在整条底栏边缘裁剪，保留越过单项边界的圆形扩散。
          child: Material(
            type: MaterialType.transparency,
            clipBehavior: Clip.hardEdge,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _TabBarButton(
                      destination: destinations[i],
                      selected: i == selectedIndex,
                      showLabel: switch (labelBehavior) {
                        NavigationDestinationLabelBehavior.alwaysShow => true,
                        NavigationDestinationLabelBehavior.onlyShowSelected => i == selectedIndex,
                        NavigationDestinationLabelBehavior.alwaysHide => false,
                      },
                      onPressed: destinations[i].enabled && onDestinationSelected != null
                          ? () => onDestinationSelected!(i)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBarButton extends StatelessWidget {
  const _TabBarButton({required this.destination, required this.selected, required this.showLabel, this.onPressed});

  final NavigationDestination destination;
  final bool selected;
  final bool showLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.elTheme;
    final color = selected ? t.primary : t.textSecondary;
    // 官方语义：选中且给了 selectedIcon 时优先用它。
    final icon = selected && destination.selectedIcon != null ? destination.selectedIcon! : destination.icon;
    return Semantics(
      label: destination.label,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onPressed,
        excludeFromSemantics: true,
        containedInkWell: false,
        splashFactory: InkRipple.splashFactory,
        splashColor: color.withValues(alpha: 0.10),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElView(
                style: ElStyle(iconSize: 20, iconColor: color),
                child: buildContent(icon),
              ),
              if (showLabel)
                ElView(
                  style: textStyle(
                    context,
                    12,
                    t.fontWeight,
                    color: color,
                    height: 1.2,
                  ).merge(const ElStyle(padding: EdgeInsets.only(top: 2), letterSpacing: .4, softWrap: false)),
                  child: destination.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
