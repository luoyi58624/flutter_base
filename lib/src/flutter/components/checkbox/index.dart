import 'package:flutter/semantics.dart' show SemanticsProperties;
import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart' hide ElCheckboxGroup, ElCheckboxGroupScope;

import 'group.dart';

export 'group.dart' show ElCheckboxGroup, ElCheckboxGroupScope;

/// 多选框公共声明；值绑定与交互共用，Builder 仅提供外观。
class ElCheckbox extends ElModelValue<Object?> {
  /// 创建组内选项，value 未提供时使用右侧文案 label 作为选项值。
  ElCheckbox({Object? value, this.label, super.key, this.disabled = false, this.indeterminate = false})
    : assert(value != null || label != null, '组内选项必须提供 value 或 label'),
      _toggle = false,
      super(value: value ?? label);

  /// 创建独立布尔开关，不接入分组或表单。
  ElCheckbox.toggle({
    bool? value,
    ValueNotifier<bool>? modelValue,
    ValueChanged<bool>? onChanged,
    super.key,
    this.disabled = false,
    this.indeterminate = false,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       label = null,
       _toggle = true,
       super(value: value ?? false, modelValue: modelValue, onChanged: (value) => onChanged?.call(value as bool));

  /// 控件右侧的字符串文案，toggle 构造不提供此参数。
  final String? label;
  final bool _toggle;

  /// 禁止交互与焦点请求。
  final bool disabled;

  /// 显示半选状态，激活后转为选中。
  final bool indeterminate;

  /// 外观后代订阅焦点和按压状态的宿主组。
  static final _groupKey = UniqueKey();

  ElCheckboxGroupScope? get _item => $get<ElCheckboxGroupScope?>(_groupKey);

  bool get _inGroup => !_toggle && _item != null;

  @override
  Widget build(BuildContext context) {
    final item = $set(_groupKey, _toggle ? null : ElCheckboxGroup.maybeOf(context));
    assert(_toggle || item != null, 'ElCheckbox 必须放在 ElCheckboxGroup 内，独立开关请用 ElCheckbox.toggle');
    return super.build(context);
  }

  @override
  Widget obsBuilder(BuildContext context) {
    final item = _item;
    final checked = _inGroup ? item!.hasElement(value) : $obs.value as bool;
    final state = ElCheckboxState(
      checked: checked,
      disabled: disabled || (_inGroup && (checked ? item!.disabledRemove : item!.disabledAdd)),
    );
    void toggle() {
      if (_toggle) {
        $obs.value = !($obs.value as bool);
      } else {
        indeterminate || !checked ? item!.addElement(value) : item!.removeElement(value);
      }
    }

    return ElView(
      event: ElButtonView.buildEvent(toggle, state.disabled, null, activateOnEnter: false),
      semantics: ElSemantics(
        mergeDescendants: true,
        properties: SemanticsProperties(
          enabled: !state.disabled,
          checked: _toggle ? null : (indeterminate ? false : checked),
          mixed: !_toggle && indeterminate ? true : null,
          toggled: _toggle ? checked : null,
          onTap: ElButtonView.buildSemanticsTap(toggle, null, state.disabled),
        ),
      ),
      style: const ElStyle(widthFactor: 1, userSelect: .none),
      child: ElComponentProvider.builderOf(context, this, (b) => b.checkbox)(context, this, state),
    );
  }
}

/// 供外观 Builder 读取的有效状态，不包含模型写入或分组行为。
class ElCheckboxState {
  /// 创建外观状态快照。
  const ElCheckboxState({required this.checked, required this.disabled, this.isLast});

  /// 是否为分组末项；null 表示宿主尚未提供布局信息。
  final bool? isLast;

  /// 当前是否选中。
  final bool checked;

  /// 合并分组限制后的禁用状态。
  final bool disabled;
}
