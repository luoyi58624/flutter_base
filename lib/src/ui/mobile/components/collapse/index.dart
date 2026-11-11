import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../commons/icons.dart';
import '../../internal/common.dart';

/// 折叠组用公共单值或列表模型决定展开项，收起时保留子树。
Widget collapseBuilder<D>(BuildContext context, ElCollapse<D> c) => ElView(
  style: c.style,
  semantics: ElSemantics(container: true, label: c.semanticLabel),
  child: Column(
    mainAxisSize: .min,
    crossAxisAlignment: .stretch,
    children: [
      for (final item in c.children)
        _Panel(
          item: item,
          open: c.mode == .single ? c.currentValue == item.value : (c.currentValue as List).contains(item.value),
          disabled: c.disabled || item.disabled,
          onToggle: () {
            if (c.mode == .single) {
              c.currentValue = (c.currentValue == item.value ? null : item.value) as D;
            } else {
              final next = (c.currentValue as List).toList();
              next.contains(item.value) ? next.remove(item.value) : next.add(item.value);
              // toList 保留调用方 List<T> 的运行时元素类型。
              c.currentValue = next as D;
            }
          },
        ),
    ],
  ),
);

/// 独立面板保留本地展开状态。
Widget collapseItemBuilder<T>(BuildContext context, ElCollapseItem<T> c) => _Standalone(c);

class _Standalone extends StatefulWidget {
  const _Standalone(this.item);
  final ElCollapseItem item;
  @override
  State<_Standalone> createState() => _StandaloneState();
}

class _StandaloneState extends State<_Standalone> {
  bool open = false;
  @override
  Widget build(BuildContext context) => _Panel(
    item: widget.item,
    open: open,
    disabled: widget.item.disabled,
    onToggle: () => setState(() => open = !open),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.item, required this.open, required this.disabled, required this.onToggle});
  final ElCollapseItem item;
  final bool open, disabled;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    final t = context.elTheme;
    return ElView(
      style: ElStyle(
        border: ElBorder.only(borderBottom: ElBorderSide(borderColor: t.borderColor)),
      ).merge(item.style),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          ActionView(
            disabled: disabled,
            selected: open,
            onActivate: (_) => onToggle(),
            style: ElStyle(
              minHeight: 56,
              padding: const .symmetric(vertical: 16),
              fontSize: 14,
              fontWeight: .w500,
              color: disabled ? t.textDisabled : t.textColor,
            ),
            child: Row(
              children: [
                Expanded(child: buildContent(item.title)),
                ElView(
                  style: ElStyle(
                    iconSize: 16,
                    iconColor: t.textSecondary,
                    transform: ElTransform.rotate(open ? -1.5707963268 : 1.5707963268),
                    transition: const [ElTransition.all(Duration(milliseconds: 180))],
                  ),
                  child: ElMobileIcons.chevronRight,
                ),
              ],
            ),
          ),
          Offstage(
            offstage: !open,
            child: TickerMode(
              enabled: open,
              child: ElView(
                style: ElStyle(padding: const .only(bottom: 18), fontSize: 13, lineHeight: 1.8, color: t.textSecondary),
                child: item.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
