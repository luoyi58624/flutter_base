# Popup

弹出层分两类，各自只用一套机制：

| 类型 | 入口 | 机制 |
| --- | --- | --- |
| 与元素无关的命令式弹层 | `el.dialog`（对话框、确认、提示、输入、底部面板）、`el.drawer`、`el.message`、`el.toast` | 对话框与抽屉推入根导航器的 `PopupRoute`（[modal.dart](modal.dart)），返回键、Esc、遮罩与 Future 结果沿用官方路由；消息与轻提示挂在根 Overlay |
| 锚定在目标周围的组件 | `ElTooltip`、`ElPopover`、`ElPopupMenu`，以及 select / autocomplete / mention 等输入的下拉面板 | [ElPopup](popup.dart) 包裹目标，用官方 `OverlayPortal` 在布局阶段按目标实时位置解算 |

两类弹层的进退场都由品牌用 [ElOverlayTransition](transition.dart) 声明：关闭时先等登记的动画退场，再移除内容；路由弹层的退场时长与路由同帧结束。

## ElPopup

```dart
final controller = ElPopupController();

ElPopup(
  controller: controller,
  trigger: {.click, .hover},
  anchor: ElOverlayAnchor(placement: .bottomStart, offset: 4),
  builder: (context) => ElOverlayTransition(
    duration: Duration(milliseconds: 150),
    builder: (context, animation) => FadeTransition(opacity: animation, child: panel),
  ),
  child: ElButton(child: '更多'),
);
```

| 参数 | 行为 |
| --- | --- |
| `trigger` | `click` 切换；`hover` 按 `hoverIntent` 延迟开闭，触摸设备点击切换；`focus` 焦点进入目标打开、离开目标与面板后关闭；`contextMenu` 在右键或长按位置打开。为空时只由控制器开闭 |
| `anchor` | 方位、间距、翻转、钳制、宽度跟随与 `cover` 覆盖目标，见下文 |
| `hoverIntent` | `openDelay` / `closeDelay` / `safePolygon`：快速掠过不打开，斜向移向面板途中不关闭 |
| `closeOnOutsideTap` / `consumeOutsideTap` | 默认外部按下即关闭且不吞掉该点击；目标与整条嵌套链都不算外部 |
| `closeOnScroll` | 默认滚动时跟随目标重新定位；为真时目标所在滚动区域开始滚动即关闭 |
| `closeOnEscape` | 焦点在目标或面板内时 Esc 关闭；关闭的弹层不登记 Esc 动作，不会截住外层弹层或路由 |
| `rootOverlay` | 挂到根 Overlay，避免被局部 Overlay 裁剪 |
| `event` | 目标事件先于触发动作执行，`preventDefault()` 阻止打开或关闭 |

- 面板每帧按目标位置布局：滚动、窗口尺寸与键盘变化时同帧跟随并重新选择方位；目标滚出所在滚动区域时暂时隐藏，滚回后恢复。
- 目标位于跟随层（`CompositedTransformFollower`，例如文本选择工具条）内时，官方布局阶段拿不到其位置，改为每帧合成后读取目标实际位置，跟随层移动时面板晚一帧跟上。
- 嵌套在面板内的 `ElPopup` 组成一条链：打开子层关闭同级子层，关闭父层关闭子层，悬停在子层上父层保持打开，Esc 从最内层逐级关闭。
- 面板不主动抢焦点，由菜单等上层组件决定；关闭时焦点若在面板内，交还打开前的位置。
- `ElPopup.maybeOf(context)` 在面板内取控制器关闭自身；`ElPopup.geometryOf(context)` 读实际方位、目标矩形、面板矩形与箭头落点，布局后下一帧更新。
- 返回键不由 `ElPopup` 拦截；需要返回键先关闭弹层时，在目标外层用 `PopScope(canPop: !controller.isOpen)`。

## ElOverlayAnchor

| 参数 | 行为 |
| --- | --- |
| `placement` | 默认 `bottom`；四边 × 起止对齐共十二种 |
| `offset` / `crossOffset` | 主轴间距、交叉轴偏移 |
| `flip` | 首选侧放不下且对侧更宽裕时翻到对侧；交叉轴起止对齐越界而对调后放得下时一并对调 |
| `shift` | 翻转后仍越界时钳进视口安全区，必要时与目标重叠 |
| `viewportPadding` | 安全区内边距，默认 8；视口另外扣除系统边距与键盘 |
| `matchWidth` / `matchMinWidth` | 面板宽度或最小宽度跟随目标 |
| `cover` | 面板从目标所在位置展开并覆盖目标，例如安卓溢出菜单 |

主轴约束取可翻转两侧中较宽裕的一侧，超出部分由面板内部滚动。

## 菜单基座

[context_menu.dart](context_menu.dart) 是文本选择、编辑器、菜单栏与全局右键菜单共用的上下文菜单基座，`ElContextMenuItem` 同时是 `ElPopupMenu` 的条目模型。
