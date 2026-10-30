import 'package:flutter/semantics.dart' show SemanticsProperties;
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:flutter_base/ui.dart' hide ElRadioGroup, ElRadioGroupScope;

import 'group.dart';

export 'group.dart' show ElRadioGroup, ElRadioGroupScope;

/// 单选框公共声明；值绑定与交互共用，Builder 仅提供外观。
class ElRadio<T> extends ElModelValue<Object?> {
  /// 创建组内选项，value 未提供时使用右侧文案 label 作为选项值。
  ElRadio({T? value, this.label, super.key, this.disabled = false})
    : assert(value != null || label != null, '组内选项必须提供 value 或 label'),
      _toggle = false,
      super(value: value ?? label);

  /// 创建独立布尔开关，不接入分组或表单。
  ElRadio.toggle({
    bool? value,
    ValueNotifier<bool>? modelValue,
    ValueChanged<bool>? onChanged,
    super.key,
    this.disabled = false,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       label = null,
       _toggle = true,
       super(value: value ?? false, modelValue: modelValue, onChanged: (value) => onChanged?.call(value as bool));

  /// 控件右侧的字符串文案，toggle 构造不提供此参数。
  final String? label;
  final bool _toggle;

  /// 禁止交互与焦点请求。
  final bool disabled;

  /// 外观后代订阅焦点和按压状态的宿主组。
  static final _groupKey = UniqueKey();
  static final _focusKey = UniqueKey();

  ElRadioGroupScope? get _group => _toggle ? null : $get<ElRadioGroupScope?>(_groupKey);

  @override
  Widget build(BuildContext context) {
    $set(_groupKey, _toggle ? null : ElRadioGroup.maybeOf(context));
    final group = _group;
    assert(_toggle || group != null, 'ElRadio 必须放在 ElRadioGroup 内，独立开关请用 ElRadio.toggle');
    $set(_focusKey, useFocusNode());

    return super.build(context);
  }

  @override
  Widget obsBuilder(BuildContext context) {
    final group = _group;
    final checked = _toggle ? $obs.value as bool : group!.modelValue == value;
    final state = ElRadioState(checked: checked, disabled: disabled);
    if (!_toggle) {
      return RawRadio<Object?>(
        value: value,
        mouseCursor: WidgetStatePropertyAll(disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click),
        toggleable: !group!.widget.required,
        focusNode: $get<FocusNode>(_focusKey),
        autofocus: false,
        groupRegistry: RadioGroup.maybeOf<Object?>(context),
        enabled: !disabled,
        builder: (context, _) => ElView(
          style: ElStyle(widthFactor: 1, userSelect: .none),
          event: ElEvent(disabled: disabled, onPointerDown: (_) => $get<FocusNode>(_focusKey).requestFocus()),
          child: ElComponentProvider.of(context).radioBuilder!<T>(context, this, state),
        ),
      );
    }
    void toggle() {
      $obs.value = !($obs.value as bool);
    }

    return ElView(
      event: ElButtonView.buildEvent(toggle, state.disabled, null, activateOnEnter: false),
      semantics: ElSemantics(
        mergeDescendants: true,
        properties: SemanticsProperties(
          enabled: !state.disabled,
          toggled: checked,
          onTap: ElButtonView.buildSemanticsTap(toggle, null, state.disabled),
        ),
      ),
      style: const ElStyle(widthFactor: 1, userSelect: .none),
      child: ElComponentProvider.of(context).radioBuilder!<T>(context, this, state),
    );
  }
}

/// 供外观 Builder 读取的有效状态，不包含模型写入或分组行为。
class ElRadioState {
  /// 创建外观状态快照。
  const ElRadioState({required this.checked, required this.disabled});

  /// 当前是否选中。
  final bool checked;

  /// 合并分组限制后的禁用状态。
  final bool disabled;
}
