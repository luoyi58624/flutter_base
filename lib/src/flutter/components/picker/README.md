# 滚轮选择

`ElPicker<T>` 使用 `List<T>` 模型保存每列业务值。`columns` 是独立列，`options` 是通过现有 `ElMenuOption.children` 表达的级联树，两者二选一。禁用项不可选；父级变化时无效子级收敛到第一个可用项。

`ElDatePicker` 使用 `DateTime`，换月自动限制到有效月末。`ElTimePicker` 使用当天零点起的 `Duration`，支持范围、分钟步长和可选秒列。`value`、`modelValue`、`onChanged` 沿用公共模型通道。

```dart
ElDatePicker(modelValue: date, min: DateTime(2025), max: DateTime(2028, 12, 31));
ElTimePicker(modelValue: time, minuteStep: 15);
```

通过 `ElComponents.picker/datePicker/timePicker` 替换品牌实现，Builder 接收声明和公共 Obs，不另建值通道。
