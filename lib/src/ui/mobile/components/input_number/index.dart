import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';

/// 移动数字步进器共用输入与表单值模型，边界值禁用对应按钮。
Widget inputNumberBuilder(BuildContext context, ElInputNumber c) => _Number(c);

class _Number extends ElInputNumModelValue {
  _Number(this.c) : super(value: c.value, modelValue: c.modelValue, onChanged: c.onChanged);
  final ElInputNumber c;
  num normalize(num value) {
    if (c.stepStrictly) value = (value / c.step).round() * c.step;
    if (c.precision != null) value = num.parse(value.toStringAsFixed(c.precision!));
    if (c.min != null && value < c.min!) value = c.min!;
    if (c.max != null && value > c.max!) value = c.max!;
    return value;
  }

  @override
  Widget obsBuilder(BuildContext context) {
    final t = context.elTheme;
    final value = $obs.value;
    void change(int direction) => $obs.value = normalize((value ?? c.min ?? 0) + direction * c.step);
    return ElView(
      style: ElStyle(
        width: c.width ?? 138,
        borderRadius: .circular(12),
        backgroundColor: t.fill,
        border: .all(borderColor: t.borderColor),
        clipBehavior: .antiAlias,
      ).merge(c.style),
      child: Row(
        children: [
          if (c.controls)
            ElButton(
              semanticLabel: '减少',
              disabled: c.disabled || c.readOnly || (value != null && c.min != null && value <= c.min!),
              variant: .text,
              style: const ElStyle(width: 40, padding: .zero),
              child: '−',
              onPressed: () => change(-1),
            ),
          Expanded(
            child: _NumberInput(
              value: value == null
                  ? ''
                  : c.precision == null
                  ? value.toString().replaceFirst(RegExp(r'\.0$'), '')
                  : value.toStringAsFixed(c.precision!),
              semanticLabel: c.semanticLabel,
              disabled: c.disabled,
              readOnly: c.readOnly,
              placeholder: c.placeholder,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              onChanged: (text) {
                if (text.trim().isEmpty) {
                  $obs.value = null;
                  return;
                }
                final parsed = num.tryParse(text);
                if (parsed != null && parsed.isFinite) $obs.value = normalize(parsed);
              },
              textAlign: .center,
              style: const ElStyle(
                height: 42,
                padding: .zero,
                border: .only(),
                boxShadow: [],
                borderRadius: .zero,
                onFocusWithin: ElStyle(boxShadow: [], border: .only()),
              ),
            ),
          ),
          if (c.controls)
            ElButton(
              semanticLabel: '增加',
              disabled: c.disabled || c.readOnly || (value != null && c.max != null && value >= c.max!),
              variant: .text,
              style: const ElStyle(width: 40, padding: .zero),
              child: '+',
              onPressed: () => change(1),
            ),
        ],
      ),
    );
  }
}

class _NumberInput extends ElInput {
  const _NumberInput({
    super.value,
    super.semanticLabel,
    super.disabled,
    super.readOnly,
    super.placeholder,
    super.keyboardType,
    super.onChanged,
    super.textAlign,
    super.style,
  });
  @override
  bool get formBindable => false;
}
