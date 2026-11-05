# Button

`ElButton` 声明普通按钮，`ElToggleButton` 声明布尔切换按钮。外观由 `buttonBuilder(context, widget)` 与 `toggleButtonBuilder(context, widget, model)` 提供，通用规范见 [Components](../README.md)。

```dart
ElButton(
  onPressed: () { debugPrint('保存'); },
  type: ElThemeType.primary,
  icon: Icons.save,
  child: '保存',
);

ElButton(variant: .outline, style: ElStyle(width: '100%'), child: '通栏按钮');

ElButton(semanticLabel: '新增', style: ElStyle(borderRadius: .circular(999)), child: Icons.add);

final favorite = ValueNotifier(false);
ElToggleButton(modelValue: favorite, child: '收藏');
```

| 参数 | 用途 |
| --- | --- |
| child / icon | 内容与前置图标；child 为 IconData 时渲染为方形图标按钮 |
| onPressed | 普通按钮的激活动作，为空不等于禁用 |
| value / modelValue / onChanged | 仅 ElToggleButton，选中态的双向绑定 |
| type / variant | 语义色与视觉层级 solid、outline、text、link |
| disabled / loading | 禁用；loading 仅普通按钮，保留焦点但阻止激活 |
| style / event | 外观与追加事件；event.preventDefault 阻止默认激活或切换 |
| focusNode / semanticLabel | 外部焦点与辅助名称 |

圆角、正圆、通栏宽度等形状由 style 表达；显式 width 时按宽度布局，否则按内容宽度排布。
