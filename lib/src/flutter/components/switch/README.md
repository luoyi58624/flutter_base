# Switch

`ElSwitch` 声明布尔开关，模型由 ElFormModelValue 持有，外观由 `switcher(context, widget, model)` 提供。通用规范见 [Components](../README.md)。

```dart
final enabled = ValueNotifier(false);
ElSwitch(
  modelValue: enabled,
  onChanged: (value) { debugPrint('通知：$value'); },
  semanticLabel: '消息通知',
);
```

| 参数 | 用途 |
| --- | --- |
| value / modelValue / onChanged | bool 输入、双向绑定和变化通知；value 与 modelValue 互斥 |
| disabled / loading | 禁止切换；loading 同时显示加载状态 |
| style / event | 外观与追加事件；event.preventDefault 阻止默认切换 |
| focusNode / semanticLabel | 外部焦点与辅助名称 |

放在 `ElFormItem(prop: ...)` 内时与表单字段双向同步。外部 notifier 和焦点节点由调用方持有并释放。
