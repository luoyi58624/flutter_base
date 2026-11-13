# Popup / Portal

## 窗口弹层宿主

`ElPopupHost` 可以安装在 `MaterialApp.builder`，每个 FlutterView 各有自己的 Overlay。独立面板的 State 和关闭结果随宿主存活。应用在窗口的宿主子树内取 context，调用 `ElPopupHost.handleBack(context)` 可处理一次返回。

接物理返回时，应用在创建 `WidgetsApp` 或 `Router` 前登记 `ElPopupBackObserver`，按视图 ID 提供仍挂载的宿主子树 context。需要处理 Android 预测性返回时，在参与回退的页面内安装 `ElPopupBackScope`，并通过观察者合并应用的 `onNavigationNotification` 和弹层状态。窗口卸载时用 `detachView` 清理，应用卸载时注销并释放观察者。

## 进退场动画

`ElOverlayTransition` 让品牌 Builder 自己决定弹层的进退场时长和曲线：挂载后进场，所在弹层关闭时先退场再移除；直接放在页面里时显示终态。用法见 [ElToast](../../components/toast/README.md)。

## 锚定弹层

锚定弹层，祖先需有官方 Overlay（通常由 MaterialApp / Navigator 提供）。导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

## 控制器开闭

```dart
final controller = ElPortalController();
ElPortal(
  controller: controller,
  anchor: ElOverlayAnchor(
    placement: ElPlacement.bottomStart,
    offset: 8,
    matchMinWidth: true,
  ),
  captureFocus: true,
  restoreFocus: true,
  overlayBuilder: (_) => Container(
    width: 180, padding: EdgeInsets.all(12), color: Colors.white,
    child: ElButtonView(onPressed: controller.close, child: '关闭面板'),
  ),
  child: ElButtonView(onPressed: controller.toggle, child: '打开'),
);
```

controller 在 State / Hook 生命周期内持有并 dispose。open / close / toggle 操作开闭，isOpen 读取状态；`await controller.closed` 等待退场并摘除内容，isOpen=false 时内容可能还在退场。

## 声明式面板

```dart
final open = ValueNotifier(false);
ValueListenableBuilder<bool>(
  valueListenable: open,
  builder: (_, value, _) => ElPortal(
    panel: value ? Container(color: Colors.white, padding: EdgeInsets.all(12), child: Text('面板')) : null,
    onDismiss: () => open.value = false,
    child: ElButtonView(onPressed: () => open.value = !open.value, child: '切换'),
  ),
);
```

不传 controller 时，panel 非空表示展开。panel 与 overlayBuilder 二选一；外部 notifier 持有至卸载后 dispose。onDismiss 同步用户关闭产生的外部状态变化。

## 定位配置 ElOverlayAnchor

| 参数 | 默认与说明 |
| --- | --- |
| placement | 默认 bottom；支持 top/bottom/left/right 及其 Start/End 变体 |
| offset / crossOffset | 主轴间距、交叉轴偏移，默认均为 0 |
| flip / shift | 空间不足时翻面、沿边调整，默认均为 true |
| viewportPadding | 与视口边缘的保留距离，默认 8 |
| matchWidth / matchMinWidth | 面板宽度或最小宽度跟随锚点，默认均 false；同时开启时 matchWidth 优先 |

ElPortal.geometryOf(context) 在面板子树读最终 placement、anchorRect、overlayRect、arrowTarget，可用于箭头定位；phaseOf(context) 读 ElPortalPhase，供入退场外观使用。

## 关闭、焦点与悬停

| 参数 | 行为 |
| --- | --- |
| rootOverlay | 默认 false，选择最近 Overlay；true 使用根 Overlay |
| closeOnOutsideTap / consumeOutsideTap | 默认 true / false，外部点击可关闭但默认不吞掉该点击 |
| closeOnEscape / closeOnBack | 默认 true / false。安装宿主后由应用返回桥处理，独立使用时沿用页面局部历史 |
| hideWhenUnlinked / closeWhenUnlinked | 锚点失联时隐藏呈现或关闭状态，默认均 false |
| captureFocus / restoreFocus | 默认均 false；需要面板捕获并恢复焦点时显式开启 |
| exitDuration | 默认零；声明退场保活时长，需与视觉退场时长匹配 |
| hoverIntent | ElHoverIntent(openDelay:, closeDelay:, safePolygon:) 控制悬停开闭和跨越空隙的安全区域 |

嵌套面板的外部点击与 Escape 由最上层弹层协调。面板需要文档选择时，内部另包 ElSelectionView。
