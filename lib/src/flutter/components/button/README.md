# Button

`ElButton` 声明按钮内容、外观和激活动作，公共层维护布尔选择模型，具体按钮实现由 `buttonBuilder(context, component)` 提供。导入与实现登记见 [Components](../README.md)。

## 普通按钮与独立开关

```dart
ElButton(
  onPressed: () { debugPrint('保存'); },
  type: ElThemeType.primary,
  child: '保存',
);

final selected = ValueNotifier(false);
ElButton.toggle(
  modelValue: selected,
  onChanged: (value) { debugPrint('选中：$value'); },
  child: '收藏',
);
```

| 参数 | 用途 |
| --- | --- |
| child / leftIcon / rightIcon | 内容与左右槽；child 为图标时左右槽可由实现忽略 |
| onPressed | 普通按钮激活动作；toggle 构造自动提供切换动作 |
| selected | 普通按钮的展示选中态；toggle 时由模型派生 |
| value / modelValue / onChanged | 仅 toggle 构造提供的 bool 值通道，缺省为 false |
| type / bgColor | 语义色与显式颜色覆盖 |
| plain / text / ghost / link / bg | 外观变体；优先级为 link、text、ghost、plain |
| round / circle / block | 胶囊、正圆与撑满宽度 |
| disabled / loading | 阻止默认激活；loading 的配色由实现决定 |
| style / event / focusNode / semanticLabel | 样式、事件、外部焦点与辅助名称 |

## Builder 接入

Builder 从组件读取 `selected`、`isToggle` 和 `onPressed`，并组合 [ButtonView](../../views/button/README.md) 等交互基元。`event` 的默认动作取消规则由实际按钮宿主执行。独立开关沿用 `ElModelValue<bool>`，不自动接入表单。
