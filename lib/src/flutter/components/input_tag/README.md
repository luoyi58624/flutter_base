# InputTag

`ElInputTag` 将草稿文本确认为 String 标签列表，通过 `inputTagBuilder(context, component)` 提供编辑、确认、删除和布局。导入与实现登记见 [Components](../README.md)。

```dart
final tags = ValueNotifier<List<String>>([]);
ElInputTag(
  modelValue: tags,
  trigger: ElInputTagTrigger.enter,
  max: 5,
  clearable: true,
  placeholder: '输入后按 Enter',
  onAdd: (value) { debugPrint('添加：$value'); },
);
```

| 参数 | 用途 |
| --- | --- |
| value / modelValue / onChanged | 已确认的 List<String>，不包含草稿文本 |
| trigger / delimiter | Enter 或 Space 确认，以及分隔符拆分 |
| saveOnBlur / addOnBlur | 失焦确认开关；addOnBlur 非 null 时覆盖 saveOnBlur |
| minLength / max / maxLength | 单项最小长度、标签上限与草稿最大长度 |
| duplicatePolicy / validate / onInvalid | 重复项策略、自定义校验与失败通知 |
| onInput / onAdd / onRemove / onClear / onDragTag | 草稿、增删、清空和拖拽通知 |
| disabled / readOnly / clearable / draggable | 交互限制、清空和拖拽重排 |
| collapseTags / maxCollapseTags / collapseTagsTooltip | 标签折叠数量和隐藏项提示 |
| tagBuilder / tagType / tagEffect / tagSize / tagStyle | 标签内容与外观 |
| controller / focusNode / autofocus / onKeyEvent | 控制门面、焦点和键盘拦截 |
| prefix / suffix / clearIcon / style / semanticLabel | 输入槽、清空图标、外观和辅助名称 |

`ElInputTagController` 提供 attached、focus、blur；未挂载时操作返回 false，同一控制器不能同时绑定多个组件。具体实现负责 attach / detach。已确认值与草稿应分别管理，onChanged 只通知标签列表变化；详细字段见 [index.dart](index.dart)。
