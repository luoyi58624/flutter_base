import 'package:flutter/widgets.dart';

import '../../../internal.dart';

Widget _builderSuffixIcon(ValueNotifier<bool> expanded) {
  return AnimatedRotation(
    duration: ElCollapseAnimation.defaultDuration,
    curve: ElCollapseAnimation.defaultCurve,
    turns: expanded.value ? 0.5 : 0,
    child: const ElIcon(ElDesktopIcons.arrowDown, size: 14),
  );
}

/// 支持分组标题、路由激活和多层折叠的桌面导航菜单。
class ElNavMenu<T> extends ElModelValue<String> {
  /// 创建绑定菜单，未指定选中值时使用首个叶子 key，分组标题不参与选择。
  // ignore: use_super_parameters
  ElNavMenu({
    Key? key,
    String? value,
    ValueNotifier<String>? modelValue,
    ValueChanged<String>? onChanged,
    required this.children,
    this.style,
    this.itemHeight = 40.0,
    this.iconGap = 12.0,
    this.nestGap = 20.0,
    this.suffixIconBuilder = _builderSuffixIcon,
  }) : router = null,
       super(
         key: key,
         value: value ?? (modelValue == null ? _firstLeafKey(children) : null),
         modelValue: modelValue,
         onChanged: onChanged,
       );

  /// 创建路由导航菜单，高亮跟随路由，onChanged 通知点击的叶子 key。
  // ignore: use_super_parameters
  ElNavMenu.router({
    Key? key,
    required this.router,
    ValueChanged<String>? onChanged,
    required this.children,
    this.style,
    this.itemHeight = 40.0,
    this.iconGap = 12.0,
    this.nestGap = 20.0,
    this.suffixIconBuilder = _builderSuffixIcon,
  }) : super(key: key, value: _firstLeafKey(children), onChanged: onChanged);

  /// 菜单模型集合，group 节点仅渲染弱化标题与留白。
  final List<ElMenuModel<T>> children;

  /// 监听的声明式路由对象，当前配置需提供 uri；为空时使用绑定的选中值。
  final RouterConfig? router;

  /// 定义菜单外观、文本、图标样式
  final ElStyle? style;

  /// 每个菜单的高度
  final double itemHeight;

  /// 图标与标题的间隔
  final double iconGap;

  /// 嵌套菜单距离上一层级的距离
  final double nestGap;

  /// 自定义后缀展开图标
  final Widget Function(ValueNotifier<bool> expanded) suffixIconBuilder;

  @override
  Widget obsBuilder(BuildContext context) {
    // 基类通过普通 Builder 渲染，路由 Hook 需要独立的 Hook 上下文。
    return HookBuilder(
      builder: (context) {
        // Hook 在路由代理替换、置空和卸载时自动解除旧监听。
        final delegate = useListenable(router?.routerDelegate);
        final activeKey = delegate == null ? $obs.value : delegate.currentConfiguration?.uri.path as String?;
        final activeKeys = activeKey == null || activeKey.isEmpty
            ? <String>{}
            : ElNestModel.findKeyPath(children, activeKey).where((e) => !e.group).map((e) => e.key).toSet();
        final theme = context.elTheme;
        final compact = context.elComponentCompact(style);
        final background = style?.backgroundColor ?? theme.cardColor;
        final textColor = theme.textColor;
        final itemStyle = ElStyle(
          backgroundColor: background,
          color: textColor,
          fontSize: compact ? 13 : 14,
          fontWeight: .w400,
          iconSize: compact ? 18 : 20,
          iconColor: textColor,
          cursor: SystemMouseCursors.click,
          alignment: .centerLeft,
          borderRadius: .circular(8),
          userSelect: .none,
          onTap: ElStyle(backgroundColor: Color.lerp(background, textColor, .07)),
          transition: const [
            .field(ElTransitionField.backgroundColor, Duration(milliseconds: 150), Curves.easeOut),
            .fields(
              {ElTransitionField.color, ElTransitionField.iconColor},
              Duration(milliseconds: 150),
              Curves.easeInOut,
            ),
          ],
        );

        void select(ElMenuModel<T> item) {
          // 路由拥有选中状态，点击直接通知，避免内部旧值吞掉返回上一页的操作。
          if (router != null) {
            onChanged?.call(item.key);
          } else {
            $obs.value = item.key;
          }
        }

        return ElView(
          style: ElStyle(backgroundColor: background),
          child: ElScroll(
            padding: const .symmetric(horizontal: 12),
            children: _items(context, children, 0, activeKeys, itemStyle, select),
          ),
        );
      },
    );
  }

  // 分组直接展开为同级渲染项，不引入折叠状态、额外缩进或导航身份。
  List<Widget> _items(
    BuildContext context,
    List<ElMenuModel<T>> items,
    int depth,
    Set<String> activeKeys,
    ElStyle itemStyle,
    ValueChanged<ElMenuModel<T>> select,
  ) => [
    for (final item in items)
      if (item.group) ...[
        ElView(
          style: ElStyle(
            height: 36,
            alignment: .centerLeft,
            padding: .only(left: 12 + nestGap * depth, right: 12),
            color: context.elTheme.textSecondary,
            fontSize: 12,
            fontWeight: .w500,
            userSelect: .none,
          ),
          child: item.title,
        ),
        ..._items(context, item.children, depth, activeKeys, itemStyle, select),
      ] else
        _MenuItem<T>(
          key: ValueKey(item.key),
          menu: this,
          item: item,
          depth: depth,
          activeKeys: activeKeys,
          style: itemStyle,
          onSelected: select,
        ),
  ];
}

String _firstLeafKey<T>(List<ElMenuModel<T>> items) {
  for (final item in items) {
    if (!item.group && item.children.isEmpty) return item.key;
    final key = _firstLeafKey(item.children);
    if (key.isNotEmpty) return key;
  }
  return '';
}

/// 每项独立保存折叠状态，按模型 key 复用，避免重排时状态串位。
class _MenuItem<T> extends HookWidget {
  const _MenuItem({
    super.key,
    required this.menu,
    required this.item,
    required this.depth,
    required this.activeKeys,
    required this.style,
    required this.onSelected,
  });

  final ElNavMenu<T> menu;
  final ElMenuModel<T> item;
  final int depth;
  final Set<String> activeKeys;
  final ElStyle style;
  final ValueChanged<ElMenuModel<T>> onSelected;

  @override
  Widget build(BuildContext context) {
    final isActive = activeKeys.contains(item.key);
    // 与旧版一致：首次展开激活分支，后续路由变化保留手动折叠状态。
    final expanded = useState(isActive);
    final hasChildren = item.children.isNotEmpty;
    final theme = context.elTheme;
    final primary = theme.primary;
    final selected = isActive && !hasChildren;
    final itemStyle = style
        .merge(
          ElStyle(
            width: '100%',
            height: menu.itemHeight,
            padding: .only(left: 12 + menu.nestGap * depth, right: 12),
            backgroundColor: selected ? Color.lerp(style.backgroundColor, primary, context.isDark ? .16 : .09) : null,
            color: isActive ? primary : null,
            iconColor: isActive ? primary : null,
            fontWeight: selected ? .w500 : null,
          ),
        )
        .merge(menu.style);

    void activate() {
      if (hasChildren) {
        expanded.value = !expanded.value;
      } else {
        onSelected(item);
      }
    }

    final row = ElView(
      style: itemStyle,
      event: ElEvent(onTap: (_) => activate()),
      semantics: ElSemantics(
        button: true,
        selected: selected,
        expanded: hasChildren ? expanded.value : null,
        mergeDescendants: true,
        onTap: activate,
      ),
      child: Row(
        children: [
          if (item.icon != null) ...[elContent(item.icon) as Widget, SizedBox(width: menu.iconGap)],
          Expanded(
            child: ElView(
              style: const ElStyle(maxLines: 1, softWrap: false, textOverflow: .ellipsis),
              child: item.title,
            ),
          ),
          if (hasChildren) elContent(menu.suffixIconBuilder(expanded)) as Widget,
        ],
      ),
    );

    if (!hasChildren) return row;
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        row,
        ElCollapseAnimation(
          expanded.value,
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: menu._items(context, item.children, depth + 1, activeKeys, style, onSelected),
          ),
        ),
      ],
    );
  }
}
