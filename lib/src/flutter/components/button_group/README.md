# ButtonGroup

`ElButtonGroup` 声明一组按钮，支持普通、单选和多选三种构造，绑定、布局与交互由 `buttonGroupBuilder` 实现。导入与实现登记见 [Components](../README.md)。

```dart
final layout = ValueNotifier<String?>('grid');
ElButtonGroup<String?>.single(
  modelValue: layout,
  children: [
    ElButtonGroupItem(value: 'grid', child: '网格'),
    ElButtonGroupItem(value: 'list', child: '列表'),
  ],
);

final filters = ValueNotifier<List<String>>([]);
ElButtonGroup<List<String>>.multi(
  modelValue: filters,
  children: [
    ElButtonGroupItem(value: 'read', child: '已读'),
    ElButtonGroupItem(value: 'starred', child: '收藏'),
  ],
);
```

| 参数 | 用途 |
| --- | --- |
| children | 至少两个 ElButtonGroupItem；条目 value 缺省时使用下标 |
| value / modelValue / onChanged | single、multi 的模型输入与变化通知 |
| mandatory | 选择模式中保留至少一个选中项 |
| type / bgColor | 整组语义色与显式颜色 |
| disabled / axis / block | 整组禁用、排列方向和沿排列方向撑满 |
| style / semanticLabel | 容器样式与组名称 |
| 条目 disabled / flex / onPressed | 单项禁用、空间份额和激活通知 |

普通构造不提供值绑定，`mode` 为 null。single 的泛型是整个单值模型类型，允许取消时应使用可空模型；multi 的泛型是整个 List 或 Set 类型。Builder 从 `mode` 读取模式，并在更新选择后调用条目 `onPressed`。自由布局的单选、多选上下文见 [Radio](../radio/README.md) 和 [Checkbox](../checkbox/README.md)。
