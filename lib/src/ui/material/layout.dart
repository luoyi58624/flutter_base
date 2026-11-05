part of 'index.dart';

Widget _collapse<D>(ElCollapse<D> c) => _frame(
  c.style,
  c.semanticLabel,
  Column(
    mainAxisSize: .min,
    children: [
      for (final item in c.children)
        Builder(
          builder: (context) {
            final expanded = c.mode == .single
                ? c.currentValue == item.value
                : (c.currentValue as List).contains(item.value);
            return _frame(
              item.style,
              null,
              ExpansionTile(
                key: ValueKey((item.value, expanded)),
                title: _content(item.title),
                initiallyExpanded: expanded,
                enabled: !c.disabled && !item.disabled,
                onExpansionChanged: (open) {
                  if (c.mode == .single) {
                    c.currentValue = (open ? item.value : null) as D;
                  } else {
                    final dynamic next = (c.currentValue as List).toList();
                    open ? next.add(item.value) : next.remove(item.value);
                    c.currentValue = next as D;
                  }
                },
                children: [Padding(padding: const EdgeInsets.all(16), child: _content(item.child))],
              ),
            );
          },
        ),
    ],
  ),
);

Widget _steps(ElSteps c) {
  if (c.children.isEmpty) return const SizedBox.shrink();
  final current = c.currentValue.clamp(0, c.children.length - 1);
  return _frame(
    c.style,
    c.semanticLabel,
    SizedBox(
      height: c.vertical ? null : 240,
      child: Stepper(
        type: c.vertical ? .vertical : .horizontal,
        currentStep: current,
        physics: const NeverScrollableScrollPhysics(),
        controlsBuilder: (context, details) => const SizedBox.shrink(),
        onStepTapped: c.disabled || !c.interactive
            ? null
            : (index) {
                if (!c.children[index].disabled) c.currentValue = index;
              },
        stepIconBuilder: (index, state) => c.children[index].icon == null ? null : _content(c.children[index].icon),
        steps: [
          for (var i = 0; i < c.children.length; i++)
            Step(
              title: _content(c.children[i].title),
              content: c.children[i].description == null
                  ? const SizedBox.shrink()
                  : _content(c.children[i].description),
              isActive: i <= current,
              state: c.children[i].disabled
                  ? .disabled
                  : i == current && c.status == .error
                  ? .error
                  : i < current
                  ? .complete
                  : .indexed,
            ),
        ],
      ),
    ),
  );
}

class _MaterialTabs<T> extends HookWidget {
  const _MaterialTabs(this.c);
  final ElTabs<T> c;
  @override
  Widget build(BuildContext context) {
    if (c.panes.isEmpty) return const SizedBox.shrink();
    final index = math.max(0, c.panes.indexWhere((pane) => pane.value == c.currentValue));
    final controller = useTabController(initialLength: c.panes.length, initialIndex: index, keys: [c.panes.length]);
    useEffect(() {
      if (controller.index != index) controller.index = index;
      return null;
    }, [controller, index]);
    useEffect(() {
      void changed() {
        final selected = controller.index;
        if (c.panes[selected].value == c.currentValue) return;
        if (c.disabled || c.panes[selected].disabled) {
          final previous = c.panes.indexWhere((pane) => pane.value == c.currentValue);
          if (previous >= 0 && controller.index != previous) controller.index = previous;
        } else {
          c.currentValue = c.panes[selected].value;
        }
      }

      controller.addListener(changed);
      return () => controller.removeListener(changed);
    }, [controller, c]);
    return _frame(
      c.style,
      c.semanticLabel,
      LayoutBuilder(
        builder: (context, constraints) => Column(
          mainAxisSize: .min,
          children: [
            IgnorePointer(
              ignoring: c.disabled,
              child: TabBar(
                controller: controller,
                isScrollable: true,
                tabAlignment: .start,
                tabs: [
                  for (final pane in c.panes)
                    Tab(
                      child: Opacity(opacity: pane.disabled ? .4 : 1, child: _content(pane.label ?? pane.value)),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: constraints.hasBoundedHeight ? math.max(0, constraints.maxHeight - 48) : 160,
              child: TabBarView(
                controller: controller,
                physics: c.disabled || !c.swipeable ? const NeverScrollableScrollPhysics() : null,
                children: [for (final pane in c.panes) pane.child ?? const SizedBox.shrink()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialTabBar extends HookWidget {
  const _MaterialTabBar(this.c);
  final ElTabBar c;
  @override
  Widget build(BuildContext context) {
    if (c.tabs.isEmpty) return const SizedBox.shrink();
    useListenable(c.controller);
    final index = c.controller.index.clamp(0, c.tabs.length - 1);
    final native = useTabController(initialLength: c.tabs.length, initialIndex: index, keys: [c.tabs.length]);
    useEffect(() {
      if (native.index != index) native.index = index;
      if (!native.indexIsChanging) native.offset = (c.controller.position - index).clamp(-1, 1);
      return null;
    }, [native, index, c.controller.position]);
    return SizedBox(
      height: c.height,
      child: TabBar(
        controller: native,
        isScrollable: c.scrollable,
        tabAlignment: c.scrollable ? .start : .fill,
        labelColor: c.selectedColor,
        unselectedLabelColor: c.color,
        indicatorColor: c.indicatorColor,
        indicatorWeight: c.indicatorHeight,
        tabs: [
          for (final tab in c.tabs)
            Tab(
              key: tab.key,
              child: Opacity(
                opacity: tab.disabled ? .4 : 1,
                child:
                    tab.child ??
                    Row(
                      mainAxisSize: .min,
                      spacing: 6,
                      children: [
                        if (tab.icon != null) tab.icon!,
                        if (tab.label != null) Text(tab.label!),
                        if (tab.badge != null) tab.badge!,
                      ],
                    ),
              ),
            ),
        ],
        onTap: (selected) {
          if (c.tabs[selected].disabled) {
            native.index = index;
            return;
          }
          c.controller.animateTo(selected);
          c.onTap?.call(selected);
        },
      ),
    );
  }
}

Widget _alert(ElAlert c) => Builder(
  builder: (context) {
    if (!c.currentValue) return const SizedBox.shrink();
    final accent = switch (c.type) {
      .success => Colors.green,
      .warning => Colors.orange,
      .error => Theme.of(context).colorScheme.error,
      .info => Colors.blue,
      .primary => Theme.of(context).colorScheme.primary,
    };
    final icon = c.icon == null
        ? null
        : c.icon is ElEmptyWidget
        ? Icon(switch (c.type) {
            .error => Icons.error_outline,
            .warning => Icons.warning_amber,
            .success => Icons.check_circle_outline,
            _ => Icons.info_outline,
          }, color: accent)
        : _content(c.icon);
    return _frame(
      c.style,
      c.semanticLabel,
      MaterialBanner(
        backgroundColor: accent.withValues(alpha: .08),
        leading: icon,
        forceActionsBelow: true,
        content: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          spacing: 4,
          children: [if (c.title != null) _content(c.title), if (c.description != null) _content(c.description)],
        ),
        actions: [
          if (c.closable)
            TextButton(
              onPressed: () {
                c.currentValue = false;
                c.onClose?.call();
              },
              child: const Text('关闭'),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  },
);
