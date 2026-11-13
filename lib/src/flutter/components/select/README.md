# Select

`ElSelect<T>` 声明业务值及候选选项，通过 `select(context, component)` 提供输入触发器、过滤与选择面板。导入与实现登记见 [Components](../README.md)。

```dart
final selected = ValueNotifier<String>('grid');
ElSelect<String>(
  modelValue: selected,
  children: [
    ElSelectOption<String>('网格', 'grid'),
    ElSelectOption<String>('列表', 'list'),
  ],
  hintText: '选择布局',
  enableFilter: true,
  semanticLabel: '布局',
);
```

| 参数 | 用途 |
| --- | --- |
| value / modelValue / onChanged | T 模型，value 与 modelValue 互斥 |
| children | ElLabelModel<T> 列表，解析出的值必须唯一 |
| ElSelectOption.content / disabled / semanticLabel | 自定义文本或 Widget 选项、禁用与辅助名称 |
| enabled / disabled | 交互开关，由具体实现综合处理 |
| enableFilter / optionFilter / filterCallback | 过滤开关与自定义过滤 |
| hintText / leadingIcon / trailingIcon / selectedTrailingIcon | 占位与触发器图标 |
| width / menuHeight / scrollController / anchor / zIndex | 触发器和面板尺寸、滚动与锚点 |
| focusNode / keyboardType / textInputAction / inputFormatters | 输入焦点与平台输入配置 |
| style / panelStyle / optionStyle / semanticLabel | 根、面板、选项样式与辅助名称 |

普通 ElLabelModel 的 label 要求非空白且 value 可解析；ElSelectOption 可使用 Widget 内容，并通过 semanticLabel 提供文字名称。组件提供 `toTextEditing` 和 `toModelValue` 做选项文字与值的转换。

弹层接口草案沿用此构造与值绑定。候选层从实际触发器或输入框的挂载 context 取当前窗口和局部 Overlay，沿用已有锚点和输入焦点规则。 [共用动作菜单接口](../dropdown_menu/README.md)

保留的 controller、textStyle、menuStyle、inputDecorationTheme 等兼容字段已经标记弃用，新增用法应遵循 [index.dart](index.dart) 中的替代说明。Select 的标签、帮助和错误信息可组合 [Form](../../widgets/form/README.md)，不通过旧字段增加新的依赖。
