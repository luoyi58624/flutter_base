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

/// 支持路由激活和多层折叠的桌面导航菜单。
class ElNavMenu<T> extends ElModelValue<String> {
  /// 创建绑定菜单，未指定选中值时使用首项 key，空列表表示未选中。
  // ignore: use_super_parameters
  ElNavMenu({
    Key? key,
    String? value,
    ValueNotifier<String>? modelValue,
    ValueChanged<String>? onChanged,
    required this.children,
    this.style,
    this.itemHeight = 56.0,
    this.iconGap = 8.0,
    this.nestGap = 20.0,
    this.suffixIconBuilder = _builderSuffixIcon,
  }) : router = null,
       super(
         key: key,
         value: value ?? (children.isNotEmpty ? children.first.key : ''),
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
    this.itemHeight = 56.0,
    this.iconGap = 8.0,
    this.nestGap = 20.0,
    this.suffixIconBuilder = _builderSuffixIcon,
  }) : super(
         key: key,
         value: children.isNotEmpty ? children.first.key : '',
         onChanged: onChanged,
       );

  /// 菜单模型集合
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
        final activeKey = delegate == null
            ? $obs.value
            : delegate.currentConfiguration?.uri.path as String?;
        final activeKeys = activeKey == null || activeKey.isEmpty
            ? <String>{}
            : ElNestModel.findKeyPath(
                children,
                activeKey,
              ).map((e) => e.key).toSet();
        final theme = ElThemeData.of(context);
        final background = style?.backgroundColor ?? theme.bgColor;
        final textColor = background.elTextColor(context);
        final itemStyle = ElStyle(
          backgroundColor: background,
          color: textColor,
          fontSize: theme.fontSizes[theme.size.index],
          fontWeight: .w500,
          iconSize: theme.iconSizes[theme.size.index],
          iconColor: textColor,
          cursor: SystemMouseCursors.click,
          alignment: .centerLeft,
          userSelect: .none,
          onHover: ElStyle(backgroundColor: background.deepen(8)),
          transition: const [
            .field(
              ElTransitionField.backgroundColor,
              Duration(milliseconds: 50),
              Curves.easeOut,
            ),
            .fields(
              {ElTransitionField.color, ElTransitionField.iconColor},
              Duration(milliseconds: 150),
              Curves.easeInOut,
            ),
          ],
        ).merge(style);

        void select(ElMenuModel<T> item) {
          $obs.value = item.key;
        }

        return ElView(
          style: ElStyle(backgroundColor: background),
          child: ElScrollView(
            children: [
              for (final item in children)
                _MenuItem<T>(
                  key: ValueKey(item.key),
                  menu: this,
                  item: item,
                  depth: 0,
                  activeKeys: activeKeys,
                  style: itemStyle,
                  onSelected: select,
                ),
            ],
          ),
        );
      },
    );
  }
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
    final primary = ElThemeData.of(context).primary;
    final itemStyle = style.merge(
      ElStyle(
        width: '100%',
        height: menu.itemHeight,
        padding: .only(left: menu.nestGap * (depth + 1), right: menu.nestGap),
        color: isActive ? primary : null,
        iconColor: isActive ? primary : null,
      ),
    );

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
        selected: isActive,
        expanded: hasChildren ? expanded.value : null,
        mergeDescendants: true,
        onTap: activate,
      ),
      // 原生 Icon 不读取 ElStyle，模型图标与默认后缀需要同步 Flutter 图标主题。
      child: IconTheme(
        data: IconThemeData(
          size: itemStyle.iconSize,
          color: itemStyle.iconColor,
        ),
        child: Row(
          children: [
            if (item.icon != null) ...[
              item.icon!,
              SizedBox(width: menu.iconGap),
            ],
            Expanded(
              child: ElView(
                style: const ElStyle(
                  maxLines: 1,
                  softWrap: false,
                  textOverflow: .ellipsis,
                ),
                child: item.title,
              ),
            ),
            if (hasChildren) menu.suffixIconBuilder(expanded),
          ],
        ),
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
            children: [
              for (final child in item.children)
                _MenuItem<T>(
                  key: ValueKey(child.key),
                  menu: menu,
                  item: child,
                  depth: depth + 1,
                  activeKeys: activeKeys,
                  style: style,
                  onSelected: onSelected,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
