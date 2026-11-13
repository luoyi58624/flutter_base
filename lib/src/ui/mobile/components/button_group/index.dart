import 'package:flutter/material.dart';

import '../../../../flutter/commons/models.dart' show ElThemeType;
import '../../../../flutter/components/tokens.dart' show ElThemeContextExt;
import '../../../../flutter/components/button_group/index.dart';
import '../../../../flutter/views/view/semantics/semantics.dart' show ElSemantics;
import '../../../../flutter/views/view/view.dart' show ElView;
import '../../../../flutter/widgets/form/index.dart' show ElFormModelValue;
import '../../internal/common.dart' show buildContent;

/// 用 Material 分段按钮承接移动端按钮组，沿用公共模型和值通知。
Widget buttonGroupBuilder<D>(BuildContext context, ElButtonGroup<D> component) =>
    component.mode == null ? _ButtonGroup<Object?>(component) : _ButtonGroup<D>(component);

class _ButtonGroup<D> extends ElFormModelValue<D> {
  _ButtonGroup(this.component)
    : super(value: component.value, modelValue: component.modelValue, onChanged: component.onChanged);

  final ElButtonGroup<D> component;

  @override
  bool get valueChannelRequired => component.mode != null;

  Object? _valueOf(int index) => component.children[index].value ?? index;

  bool _selected(int index) => switch (component.mode) {
    null => false,
    .single => $obs.value == _valueOf(index),
    .multi => ($obs.value as Iterable?)?.contains(_valueOf(index)) ?? false,
  };

  void _activate(int index) {
    final item = component.children[index];
    if (component.disabled || item.disabled) return;
    final value = _valueOf(index);
    switch (component.mode) {
      case null:
        break;
      case .single:
        final clear = _selected(index) && !component.mandatory && null is D;
        $obs.value = clear ? null as D : value as D;
      case .multi:
        final current = $obs.value;
        assert(current is List || current is Set, 'ElButtonGroup.multi 的选中值必须为 List / Set 集合');
        final has = (current as Iterable).contains(value);
        if (!(has && current.length == 1 && component.mandatory)) {
          // 在原集合上复制以保留元素类型，不能把 Material 的下标集合直接回写给业务模型。
          final dynamic next = current is Set ? current.toSet() : (current as List).toList();
          has ? next.remove(value) : next.add(value);
          $obs.value = next as D;
        }
    }
    item.onPressed?.call();
  }

  Widget _label(ElButtonGroupItem item) {
    final child = item.child;
    final content = switch (child) {
      Widget() => child,
      IconData() => Icon(child),
      InlineSpan() => Text.rich(child),
      Iterable() => buildContent(child),
      _ => Text(child?.toString() ?? ''),
    };
    return item.semanticLabel == null
        ? content
        : Semantics(label: item.semanticLabel, excludeSemantics: true, child: content);
  }

  @override
  Widget obsBuilder(BuildContext context) {
    final theme = context.elTheme;
    final accent =
        component.bgColor ??
        switch (component.type) {
          ElThemeType.primary => theme.primary,
          ElThemeType.success => theme.success,
          ElThemeType.warning => theme.warning,
          ElThemeType.error => theme.error,
          ElThemeType.info => theme.info,
          null => null,
        };
    final foreground = accent == null
        ? null
        : ThemeData.estimateBrightnessForColor(accent) == .dark
        ? theme.textOnDark
        : theme.textOnLight;
    final selected = {
      for (var i = 0; i < component.children.length; i++)
        if (_selected(i)) i,
    };

    return ElView(
      style: component.style,
      semantics: ElSemantics(container: true, label: component.semanticLabel),
      // Material 按钮内部持有焦点节点，移动默认不让它们抢焦点或参与键盘遍历。
      child: ExcludeFocus(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bounded = component.axis == .horizontal ? constraints.hasBoundedWidth : constraints.hasBoundedHeight;
            return SegmentedButton<int>(
              segments: [
                for (var i = 0; i < component.children.length; i++)
                  ButtonSegment(
                    value: i,
                    label: _label(component.children[i]),
                    enabled: !component.children[i].disabled,
                  ),
              ],
              selected: selected,
              // 必选由公共模型约束，让重复点击选中项仍能调用条目 onPressed。
              emptySelectionAllowed: true,
              multiSelectionEnabled: component.mode == .multi,
              showSelectedIcon: false,
              direction: component.axis,
              expandedInsets: component.block && bounded ? EdgeInsets.zero : null,
              style: SegmentedButton.styleFrom(
                visualDensity: .standard,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                backgroundColor: component.mode == null ? accent : null,
                foregroundColor: component.mode == null ? foreground : null,
                selectedBackgroundColor: accent,
                selectedForegroundColor: foreground,
              ),
              onSelectionChanged: component.disabled
                  ? null
                  : (next) {
                      final added = next.difference(selected);
                      final index = added.isNotEmpty ? added.first : selected.difference(next).first;
                      _activate(index);
                    },
            );
          },
        ),
      ),
    );
  }
}
