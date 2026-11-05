# InputNumber

`ElInputNumber` 声明数值输入、步进和范围配置，通过 `inputNumber(context, component)` 提供具体实现。导入与实现登记见 [Components](../README.md)。

```dart
final quantity = ValueNotifier<num?>(1);
ElInputNumber(
  modelValue: quantity,
  min: 0,
  max: 100,
  step: 1,
  precision: 0,
  semanticLabel: '数量',
);
```

| 参数 | 用途 |
| --- | --- |
| value / modelValue / onChanged | num? 模型，可表达空值；value 与 modelValue 互斥 |
| step / stepStrictly | 步进幅度与是否限制为步长倍数 |
| min / max / precision | 数值上下界与小数精度 |
| controls / controlsPosition | 显示步进控件，位置为 sides 或 right |
| disabled / readOnly | 禁用交互与只读模式 |
| placeholder / width / style | 占位、宽度和样式 |
| semanticLabel / autofillHints | 辅助名称与自动填充提示 |

构造检查 min 不大于 max、precision 非负；文本解析、格式化、步进边界和表单同步由 Builder 实现。外部模型使用 `ValueNotifier<num?>`，不要用不可空或更窄泛型的 notifier 替代。
