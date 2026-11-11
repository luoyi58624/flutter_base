import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../../flutter.dart';
import '../../internal/common.dart';

/// 移动标签页复用 ElTabView，非定高场景测量原内容以避免裁切。
Widget tabsBuilder<T>(BuildContext context, ElTabs<T> c) => _Tabs<T>(c);

class _Tabs<T> extends HookWidget {
  const _Tabs(this.c);
  final ElTabs<T> c;
  @override
  Widget build(BuildContext context) {
    final enabled = c.panes.where((pane) => !pane.disabled).toList();
    if (enabled.isEmpty) return const SizedBox.shrink();
    final index = math.max(0, enabled.indexWhere((pane) => pane.value == c.currentValue));
    final controller = useMemoized(() => ElTabController(length: enabled.length, initialIndex: index), [
      enabled.length,
    ]);
    useEffect(() => controller.dispose, [controller]);
    useEffect(() {
      if (controller.index != index) controller.animateTo(index);
      return null;
    }, [index, controller]);
    final heights = useState(<T, double>{});
    return ElView(
      style: c.style,
      semantics: ElSemantics(container: true, label: c.semanticLabel),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final natural = !constraints.hasBoundedHeight;
          final height = natural
              ? heights.value[enabled[index].value] ?? 240
              : math.max(0.0, constraints.maxHeight - 48);
          return Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [
              _Header(
                items: [
                  for (final pane in c.panes)
                    (
                      label: pane.label,
                      selected: pane.value == c.currentValue,
                      disabled: c.disabled || pane.disabled,
                      onTap: () => c.currentValue = pane.value,
                    ),
                ],
              ),
              SizedBox(
                height: height,
                child: IgnorePointer(
                  ignoring: c.disabled,
                  child: ElTabView(
                    controller: controller,
                    physics: c.swipeable ? null : const NeverScrollableScrollPhysics(),
                    onIndexChanged: (i) => c.currentValue = enabled[i].value,
                    children: [
                      for (final pane in enabled)
                        natural
                            ? OverflowBox(
                                alignment: .topCenter,
                                minHeight: 0,
                                maxHeight: double.infinity,
                                child: ElChildSizeBuilder(
                                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                                  child: pane.child ?? const SizedBox.shrink(),
                                  builder: (size, child) {
                                    if (heights.value[pane.value] != size.height) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (context.mounted && heights.value[pane.value] != size.height) {
                                          heights.value = {...heights.value, pane.value: size.height};
                                        }
                                      });
                                    }
                                    return child;
                                  },
                                ),
                              )
                            : pane.child ?? const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.items});
  final List<({Object? label, bool selected, bool disabled, VoidCallback onTap})> items;
  @override
  Widget build(BuildContext context) {
    final t = context.elTheme;
    return ElView(
      style: ElStyle(
        border: ElBorder.only(borderBottom: ElBorderSide(borderColor: t.borderColor)),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: ActionView(
                disabled: item.disabled,
                selected: item.selected,
                onActivate: (_) => item.onTap(),
                style: ElStyle(
                  minHeight: 48,
                  alignment: .center,
                  padding: const .symmetric(horizontal: 6, vertical: 12),
                  fontSize: 14,
                  fontWeight: item.selected ? .w600 : .w400,
                  color: item.disabled
                      ? t.textDisabled
                      : item.selected
                      ? t.primary
                      : t.textSecondary,
                  border: ElBorder.only(
                    borderBottom: ElBorderSide(
                      borderColor: item.selected ? t.primary : const Color(0x00000000),
                      borderWidth: 2,
                    ),
                  ),
                ),
                child: buildContent(item.label),
              ),
            ),
        ],
      ),
    );
  }
}

/// 独立标签栏直接监听已有控制器，不再创建第二套页状态。
Widget tabBarBuilder(BuildContext context, ElTabBar c) => ListenableBuilder(
  listenable: c.controller,
  builder: (context, _) => SizedBox(
    height: c.height,
    child: _Header(
      items: [
        for (var i = 0; i < c.tabs.length; i++)
          (
            label: c.tabs[i].child ?? c.tabs[i].label,
            selected: i == c.controller.index,
            disabled: c.tabs[i].disabled,
            onTap: () {
              c.controller.animateTo(i);
              c.onTap?.call(i);
            },
          ),
      ],
    ),
  ),
);
