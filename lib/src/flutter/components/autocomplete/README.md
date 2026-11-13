# Autocomplete

`ElAutocomplete<T>` 绑定输入文本，并以 ElLabelModel<T> 提供同步或异步建议；具体查询、交互和外观由 `autocomplete` 实现。导入与实现登记见 [Components](../README.md)。

```dart
final query = ValueNotifier('');
ElAutocomplete<String>(
  modelValue: query,
  fetchSuggestions: (text) => [
    for (final name in ['Flutter', 'Dart', 'Web'])
      if (name.toLowerCase().contains(text.toLowerCase()))
        ElLabelModel<String>(name, name.toLowerCase()),
  ],
  onSelected: (option) { debugPrint('${option.value}'); },
  placeholder: '搜索技术',
);
```

| 参数 | 用途 |
| --- | --- |
| value / modelValue / onChanged | 输入文本的 String 值通道，与候选业务类型 T 独立 |
| fetchSuggestions / onSelected | 按查询文本提供建议，以及选中建议通知 |
| debounce / triggerOnFocus | 查询等待时间与聚焦时是否查询 |
| highlightFirst / loop | 默认高亮与键盘循环导航 |
| itemBuilder / header / footer | 候选内容和面板头尾 |
| loadingBuilder / emptyBuilder / errorBuilder | 加载、空结果和错误内容 |
| disabled / readOnly / clearable / maxLength | 输入交互限制与清空、长度配置 |
| focusNode / onKeyEvent / onFocus / onBlur / onSubmitted | 输入焦点、键盘与通知 |
| prefix / suffix / placeholder | 输入框内容槽与占位 |
| width / menuHeight / scrollController / anchor / zIndex | 输入宽度、候选层尺寸、滚动与定位 |
| style / panelStyle / optionStyle / semanticLabel | 输入、面板、选项样式与辅助名称 |

数据源可返回 Future，具体实现应按接口约定只采纳最新查询的结果。itemBuilder 定制候选内容，选项外层的命中、语义和 active 状态仍由实现组织。键盘类型、动作键、输入格式化和自动填充配置与 [Input](../input/README.md) 一样通过声明转交实现。

弹层接口草案沿用此构造和查询回调。候选层从输入框的挂载 context 取得窗口和局部 Overlay，输入焦点、键盘及输入法会话由原输入框维持。异步结果只更新仍有效的候选会话。
