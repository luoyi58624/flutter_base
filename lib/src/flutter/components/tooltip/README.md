# ElTooltip

提示通过现有 ElPortal 定位，支持悬停、点击和长按。目标滚动、移出可见区域或点击面板外部时关闭；提示内可以放入复制按钮等交互内容。

```dart
ElTooltip(
  content: '收藏后可以稍后查看',
  placement: ElPlacement.top,
  child: ElButton(variant: .text, child: '收藏'),
)
```

`waitDuration` 控制悬停等待，`showDuration` 控制触摸后的显示时长；移入提示内容时保留面板。`arrow: false` 隐藏移动品牌箭头，空间不足时箭头跟随 Portal 实际翻转方向。`style` 作用于提示面板，`event` 作用于触发目标，事件的 `preventDefault` 可阻止默认显示。`disabled` 禁止提示。Material 兜底沿用框架 Tooltip 的定位和外观。
