import 'package:flutter/widgets.dart';

import '../../../internal.dart';

/// 根据双向绑定的小节下标高亮条目的桌面页内目录。
class ElAnchor extends ElModelValue<int?> {
  /// 创建目录，点击条目时将其从零开始的下标写入模型。
  ElAnchor({
    super.key,
    required this.links,
    required ValueNotifier<int?> super.modelValue,
    this.style,
    this.itemStyle,
    this.event,
  });

  /// 按正文顺序排列的标题，允许多个条目使用同一标题。
  final List<String> links;

  /// 目录容器的样式。
  final ElStyle? style;

  /// 每个目录条目的样式，在默认样式之后合并。
  final ElStyle? itemStyle;

  /// 每个条目的事件，可阻止默认的模型写入。
  final ElEvent? event;

  @override
  Widget obsBuilder(BuildContext context) {
    final model = $obs;
    final active = model.value;
    final theme = context.elTheme;
    final item = ElStyle(
      padding: const .symmetric(horizontal: 12, vertical: 6),
      alignment: .centerLeft,
      cursor: SystemMouseCursors.click,
      fontSize: 14,
      lineHeight: 1.4,
      color: theme.textSecondary,
      borderRadius: .circular(4),
      onHover: ElStyle(color: theme.primary),
      onFocusVisible: ElStyle(outline: ElOutline(outlineColor: theme.primary, outlineWidth: 2)),
    );
    final selected = ElStyle(color: theme.primary, fontWeight: .w500);

    return ElView(
      style: style,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          for (final (index, title) in links.indexed)
            ElButtonView(
              key: ValueKey(index),
              child: title,
              semanticLabel: title,
              selected: index == active,
              style: (index == active ? item.merge(selected) : item).merge(itemStyle),
              event: event,
              onPressed: () => model.value = index,
            ),
        ],
      ),
    );
  }
}
