# Tag

`ElTag` 提供展示标签、关闭操作和独立布尔开关。公共宿主维护绑定与交互，`tagBuilder(context, component)` 读取配置绘制品牌外观。导入与实现登记见 [Components](../README.md)。

```dart
ElTag(
  child: '进行中',
  type: ElThemeType.success,
  effect: ElTagEffect.light,
  closable: true,
  onClose: () { debugPrint('关闭标签'); },
);

final selected = ValueNotifier(false);
ElTag.toggle(modelValue: selected, child: '只看未读');
```

| 参数 | 用途 |
| --- | --- |
| child | 文本、图标或 Widget 内容 |
| type / effect | 语义色与 light、dark、plain 填充方式 |
| round / hit | 胶囊圆角与强调描边 |
| closable / onClose | 展示关闭入口并通知调用方；是否移除由调用方决定 |
| value / modelValue / onChanged | toggle 的 bool 值通道，缺省为 false |
| disabled | toggle 构造中禁止切换和关闭 |
| style / closeStyle | 标签与关闭入口的样式 |
| event / focusNode | 事件扩展与 toggle 的外部焦点节点 |
| semanticLabel / closeSemanticLabel | 标签与关闭入口的辅助名称 |

Builder 使用 `isToggle` 区分模式，通过 `selected` 读取当前状态；普通标签始终返回 false。关闭入口的布局由 Builder 提供，普通标签的关闭入口和开关标签的主入口应各自保持可操作。toggle 使用普通模型绑定，不接入表单。
