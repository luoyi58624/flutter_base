# Mention

`ElMention<T>` 声明前缀触发的候选输入，T 表示候选附带数据，输入模型始终是 String；具体编辑和面板交互由 `mention` 实现。导入与实现登记见 [Components](../README.md)。

```dart
final text = ValueNotifier('');
ElMention<int>(
  modelValue: text,
  options: [
    ElMentionOption(value: 'alice', label: 'Alice', data: 1),
    ElMentionOption(value: 'bob', label: 'Bob', data: 2),
  ],
  prefix: ['@'],
  whole: true,
  onSelected: (option, prefix) { debugPrint('$prefix${option.value}'); },
  placeholder: '输入 @ 提及成员',
);
```

| 参数 | 用途 |
| --- | --- |
| value / modelValue / onChanged | String 输入模型，value 与 modelValue 互斥 |
| options | ElMentionOption<T> 候选，包含 value、label、disabled 和 data |
| prefix / split | 前缀列表与分隔符，均限单个非换行 UTF-16 code unit |
| filterOptions / filterOption | 整表或单项过滤；整表过滤优先 |
| onSearch / onSelected / onWholeRemove | 查询、选中与完整提及删除通知 |
| whole / checkIsWhole | 完整提及的删除模式与自定义判定 |
| placement / showArrow / offset / panelWidth / menuHeight | 光标候选层方向、箭头、间距和尺寸 |
| loading / highlightFirst / loop | 加载状态、默认高亮与循环导航 |
| itemBuilder / loadingBuilder / emptyBuilder / header / footer | 面板和候选内容 |
| textarea / minLine / maxLine / maxLength | 输入行数与长度限制 |
| inputPrefix / inputSuffix / style / panelStyle / optionStyle | 输入槽和分层样式 |

焦点、键盘、输入连接、只读与禁用等配置沿用 [Input](../input/README.md) 的声明方式。`resolveElMentionContext` 从编辑文档和折叠选区解析匹配范围；`resolveElMentionWholeContext` 结合候选值或 checkIsWhole 判定完整提及。二者返回上下文数据，不负责写入文档；实现见 [index.dart](index.dart)。
