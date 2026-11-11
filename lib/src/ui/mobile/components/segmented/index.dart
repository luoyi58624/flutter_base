import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../internal/common.dart';

/// 移动端分段选择沿用公共模型，选中背景由样式引擎过渡。
Widget segmentedBuilder<T>(BuildContext context, ElSegmented<T> c) {
  final t = context.elTheme;
  return ElView(
    semantics: ElSemantics(container: true, label: c.semanticLabel),
    style: ElStyle(padding: const .all(4), backgroundColor: t.fill, borderRadius: .circular(13)).merge(c.style),
    child: Row(
      children: [
        for (final option in c.options)
          Expanded(
            child: ActionView(
              disabled: c.disabled || option.disabled,
              selected: c.currentValue == option.value,
              onActivate: (_) => c.currentValue = option.value,
              style: ElStyle(
                minHeight: 38,
                padding: const .symmetric(horizontal: 6, vertical: 8),
                alignment: .center,
                fontSize: 13,
                fontWeight: .w500,
                color: option.disabled
                    ? t.textDisabled
                    : c.currentValue == option.value
                    ? t.primary
                    : t.textSecondary,
                backgroundColor: c.currentValue == option.value ? t.selectedBackground : const Color(0x00000000),
                borderRadius: .circular(10),
                boxShadow: c.currentValue == option.value ? t.selectedShadow : const [],
                transition: const [ElTransition.all(Duration(milliseconds: 150))],
              ),
              child: buildContent(option.label ?? option.value),
            ),
          ),
      ],
    ),
  );
}
