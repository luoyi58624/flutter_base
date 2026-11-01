part of 'index.dart';

/// 沿用原圆角容器与索引分隔线，直接组合列表子项。
Widget listTileGroupBuilder<D>(BuildContext context, ElListTileGroup<D> component) {
  void select(ElListTile child) {
    if (child.disabled || child.event?.disabled == true) return;
    if (component.mode == .single) {
      component.currentValue = child.value as D;
    } else {
      // toList 保留调用方元素类型，后续操作不修改原选择列表。
      final dynamic next = (component.currentValue as List).toList();
      next.contains(child.value) ? next.remove(child.value) : next.add(child.value);
      component.currentValue = next as D;
    }
  }

  Widget body = RepaintBoundary(
    child: ElView(
      style: ElStyle(backgroundColor: context.elTheme.cardColor, borderRadius: .circular(16), clipBehavior: .hardEdge),
      child: Column(
        mainAxisSize: .min,
        children: [
          for (var i = 0; i < component.children.length; i++)
            ElChildIndex(
              key: component.children[i].key == null ? null : ValueKey(component.children[i].key),
              index: i,
              end: component.children.length - 1,
              child: component.mode == null
                  ? component.children[i]
                  : _ListTile<dynamic>(
                      component.children[i],
                      key: component.children[i].key,
                      selectionMode: component.mode,
                      selected: component.mode == .single
                          ? component.currentValue == component.children[i].value
                          : (component.currentValue as List).contains(component.children[i].value),
                      selectionLeading: component.leading,
                      onSelect: () => select(component.children[i]),
                    ),
            ),
        ],
      ),
    ),
  );
  if (component.mode == .single) {
    body = RadioGroup<Object?>(
      groupValue: component.currentValue,
      onChanged: (value) {
        for (final child in component.children) {
          if (child.value == value) {
            ElButtonView.buildSemanticsTap(
              () {
                select(child);
                child.onTap?.call();
              },
              child.event,
              child.disabled,
            )?.call();
            break;
          }
        }
      },
      child: body,
    );
  }
  if (component.title == null) return body;
  return Column(
    mainAxisSize: .min,
    crossAxisAlignment: .stretch,
    children: [
      ElView(
        style: ElStyle(fontSize: 13, color: context.elTheme.textSecondary, padding: const .fromLTRB(16, 8, 16, 8)),
        child: component.title,
      ),
      body,
    ],
  );
}
