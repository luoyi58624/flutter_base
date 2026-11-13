# ElTooltip

> 接口评审草案。构造沿用现有声明，以下交互约定由两端共用。

## 构造

| 参数 | 类型与默认值 | 用途 |
| --- | --- | --- |
| `key` | `Key?` | Widget 标识 |
| `content` | `Object`，必填 | 提示内容，可放文字或包含操作的 Widget |
| `child` | `Widget`，必填 | 触发目标 |
| `placement` | `ElPlacement = .top` | 首选锚定方向 |
| `waitDuration` | `Duration = Duration(milliseconds: 400)` | 悬停触发的等待时长 |
| `showDuration` | `Duration = Duration(seconds: 3)` | 点击或长按后的显示时长 |
| `disabled` | `bool = false` | 禁止显示提示 |
| `arrow` | `bool = true` | 显示指向实际锚点的箭头 |
| `style` | `ElStyle?` | 提示面板样式 |
| `event` | `ElEvent?` | 追加到触发目标的事件 |

两端共用 `ElComponents.tooltip`，签名为 `Widget Function(BuildContext context, ElTooltip component)`。

## 调用

```dart
ElTooltip(
  content: '收藏后可以稍后查看',
  placement: .top,
  child: ElButton(variant: .text, child: '收藏'),
);
```

显示由悬停、点击或长按触发，使用触发目标挂载处的 context 和最近的 Overlay。移动到提示内容上时保留提示。目标卸载、滚出可见区或点击面板外部时关闭。空间不足时按实际翻转方向定位箭头。触发事件的 `preventDefault()` 可以阻止默认显示。

打开提示时保留当前焦点，物理返回放行。

## 当前实现

移动端通过 ElPortal 锚定提示。Material 实现使用 Flutter Tooltip。 [当前组件声明](index.dart) · [Material 实现](../../../ui/material/index.dart)
