part of 'index.dart';

/// 通用多选分组，统一维护集合、数量限制、表单绑定与布局。
class ElCheckboxGroup<T> extends ElFormModelValue<List<T>> {
  /// 创建多选分组；子项的 value（未提供时取 label）决定集合中的身份。
  ElCheckboxGroup({
    super.key,
    super.value,
    super.modelValue,
    super.onChanged,
    required this.children,
    this.min,
    this.max,
    this.disabled = false,
    this.direction = Axis.horizontal,
    this.spacing = 0,
    this.runSpacing = 8,
    this.style,
    this.semanticLabel,
  }) : assert(min == null || min >= 0),
       assert(max == null || max >= 0),
       assert(min == null || max == null || min <= max);

  /// 分组内容，允许包装过的多选框。
  final List<Widget> children;

  /// 最少可选数量。
  final int? min;

  /// 最多可选数量。
  final int? max;

  /// 是否禁用整组。
  final bool disabled;

  /// 排布方向。
  final Axis direction;

  /// 相邻子项间距。
  final double spacing;

  /// 换行间距。
  final double runSpacing;

  /// 通用布局样式，品牌变量可由此下发。
  final ElStyle? style;

  /// 辅助技术读取的组名称。
  final String? semanticLabel;

  void _setSelected(Object? label, bool checked) {
    if (disabled) return;
    final selection = $obs.value;
    final current = selection.contains(label);
    if (current == checked ||
        (current ? min != null && selection.length <= min! : max != null && selection.length >= max!)) {
      return;
    }
    final next = selection.toList();
    checked ? next.add(label as T) : next.remove(label);
    $obs.value = next;
  }

  @override
  Widget obsBuilder(BuildContext context) => ElView(
    style: style,
    semantics: ElSemantics(container: true, label: semanticLabel),
    child: Wrap(
      direction: direction,
      spacing: spacing,
      runSpacing: runSpacing,
      crossAxisAlignment: .center,
      children: [
        for (var i = 0; i < children.length; i++)
          _CheckboxGroupItem(
            key: children[i].key == null ? null : ValueKey(children[i].key),
            selection: $obs.value,
            disabled: disabled,
            min: min,
            max: max,
            isLast: i == children.length - 1,
            setSelected: _setSelected,
            child: children[i],
          ),
      ],
    ),
  );
}

class _CheckboxGroupItem extends InheritedWidget {
  const _CheckboxGroupItem({
    super.key,
    required this.selection,
    required this.disabled,
    required this.min,
    required this.max,
    required this.isLast,
    required this.setSelected,
    required super.child,
  });

  final List<Object?> selection;
  final bool disabled;
  final int? min;
  final int? max;
  final bool isLast;
  final void Function(Object? label, bool checked) setSelected;

  bool limitReached(bool checked) =>
      checked ? min != null && selection.length <= min! : max != null && selection.length >= max!;

  static _CheckboxGroupItem? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CheckboxGroupItem>();

  @override
  bool updateShouldNotify(_CheckboxGroupItem oldWidget) =>
      disabled != oldWidget.disabled ||
      min != oldWidget.min ||
      max != oldWidget.max ||
      isLast != oldWidget.isLast ||
      !listEquals(selection, oldWidget.selection) ||
      setSelected != oldWidget.setSelected;
}
