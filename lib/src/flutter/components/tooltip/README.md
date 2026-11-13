# ElTooltip

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

桌面端悬停 `waitDuration` 后淡入，指针移到提示上保持打开，离开目标与提示 100 毫秒后淡出；触摸点击切换。移动端点击切换、长按打开，打开后 `showDuration` 自动关闭，目标所在列表滚动时关闭，不响应鼠标悬停。

定位由 [ElPopup](../../widgets/popup/popup.dart) 承担：滚动和窗口变化时同帧跟随目标，首选侧放不下时翻到对侧，交叉轴越界时起止对调，最后钳进视口安全区；箭头按实际方位指向目标中心。目标滚出可见区时暂时隐藏，点击外部关闭。触发事件的 `preventDefault()` 可以阻止默认显示。字符串内容同时写入目标的 tooltip 语义。

## 当前实现

[桌面](../../../ui/desktop/components/tooltip/index.dart) · [移动](../../../ui/mobile/components/tooltip/index.dart) · [Material](../../../ui/material/index.dart)
