# ElPopover

包裹任意目标，在周围弹出可包含交互内容的卡片。定位、触发与生命周期由 [ElPopup](../../widgets/popup/popup.dart) 承担，品牌只负责卡片外观、箭头与进退场。

## 构造

| 参数 | 类型与默认值 | 用途 |
| --- | --- | --- |
| `child` | `Widget`，必填 | 触发目标 |
| `content` | `Object`，必填 | 卡片正文，文字或 Widget |
| `title` | `Object?` | 标题 |
| `trigger` | `Set<ElPopupTrigger> = {click}` | 可组合 click、hover、focus、contextMenu |
| `placement` | `ElPlacement = .bottom` | 首选方位，空间不足时自动翻转 |
| `width` | `double?` | 卡片宽度，省略时按内容与品牌最小宽度 |
| `showArrow` | `bool = true` | 显示指向目标的箭头 |
| `hoverIntent` | `ElHoverIntent` | 悬停触发的打开、关闭延迟与安全区域 |
| `disabled` | `bool = false` | 禁用全部触发，已打开时关闭 |
| `controller` | `ElPopupController?` | 外部开闭 |
| `onOpenChanged` | `ValueChanged<bool>?` | 开闭状态变化 |
| `style` | `ElStyle?` | 在品牌卡片样式后合并 |
| `event` | `ElEvent?` | 目标事件，`preventDefault()` 阻止打开或关闭 |

两端共用 `ElComponents.popover`。

## 调用

```dart
final controller = useMemoized(ElPopupController.new);
ElPopover(
  controller: controller,
  title: '删除记录',
  content: ElButton(onPressed: controller.close, child: '知道了'),
  child: ElButton(child: '删除'),
);
```

悬停触发时斜向移入卡片途中不关闭；焦点触发时焦点离开目标与卡片后关闭；右键触发时在指针位置打开。卡片内容可用 `ElPopup.maybeOf(context)` 关闭自身。

## 当前实现

[桌面](../../../ui/desktop/components/popover/index.dart)：Element 白底浅边框卡片，150 毫秒淡入淡出。[移动](../../../ui/mobile/components/popover/index.dart)：大圆角浮起卡片，从箭头处缩放淡入，默认不附带悬停。
