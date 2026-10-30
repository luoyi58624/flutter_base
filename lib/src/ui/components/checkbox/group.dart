import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import '../../../flutter/views/view/semantics/semantics.dart';
import '../../../flutter/views/view/style/style.dart';
import '../../../flutter/views/view/view.dart';
import '../../../flutter/widgets/form/index.dart';

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

  /// 读取最近的多选分组上下文并订阅变化，组外返回 null。
  static ElCheckboxGroupScope? maybeOf(BuildContext context) => _CheckboxGroupItem.maybeOf(context);

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
            onSetSelected: _setSelected,
            child: children[i],
          ),
      ],
    ),
  );
}

/// 多选分组向后代提供的只读状态与受数量限制的选择操作。
abstract interface class ElCheckboxGroupScope {
  /// 当前选中值的只读快照。
  List<Object?> get value;

  /// 整组是否禁用。
  bool get disabled;

  /// 最少可选数量，null 表示不限制。
  int? get min;

  /// 最多可选数量，null 表示不限制。
  int? get max;

  /// 当前后代是否位于分组最后一个直接布局项内。
  bool get isLast;

  /// 当前选中状态下，数量限制是否阻止切换。
  bool limitReached(bool checked);

  /// 更新指定值的选中状态，遵循整组禁用与 min/max 限制。
  void setSelected(Object? value, bool checked);
}

class _CheckboxGroupItem extends InheritedWidget implements ElCheckboxGroupScope {
  const _CheckboxGroupItem({
    super.key,
    required this.selection,
    required this.disabled,
    required this.min,
    required this.max,
    required this.isLast,
    required this.onSetSelected,
    required super.child,
  });

  final List<Object?> selection;
  @override
  List<Object?> get value => List<Object?>.unmodifiable(selection);
  @override
  final bool disabled;
  @override
  final int? min;
  @override
  final int? max;
  @override
  final bool isLast;
  final void Function(Object? value, bool checked) onSetSelected;

  @override
  bool limitReached(bool checked) =>
      checked ? min != null && selection.length <= min! : max != null && selection.length >= max!;

  @override
  void setSelected(Object? value, bool checked) => onSetSelected(value, checked);

  static _CheckboxGroupItem? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CheckboxGroupItem>();

  @override
  bool updateShouldNotify(_CheckboxGroupItem oldWidget) =>
      disabled != oldWidget.disabled ||
      min != oldWidget.min ||
      max != oldWidget.max ||
      isLast != oldWidget.isLast ||
      !listEquals(selection, oldWidget.selection) ||
      onSetSelected != oldWidget.onSetSelected;
}
