# 滚动宿主与共用策略

`ElScrollView` 基于官方 `Scrollable` 和 `Viewport`；普通内容使用默认构造，Sliver 组合使用 `ElScrollView.sliver`。刷新入口为列表中的 `ElSliverRefresh`，桌面滚动条使用 `ElWindowsScrollbar` / `ElMacScrollbar`。

本目录包含滚动宿主和相关机制。列表、网格、瀑布流、折叠头和大标题等 Sliver 位于 [`sliver/`](sliver/README.md)，下拉刷新位于 [`refresh/`](refresh/)。

| 路径 | 职责 |
| --- | --- |
| `scroll.dart` | `ElScrollView` 宿主与外部控制器适配 |
| `scroll_position.dart` | 拖动接力、协作链位移分配、滚轮接收者锁 |
| `scroll_behavior.dart` | `ElScrollBehavior`：平台物理、滚动条与越界效果 |
| `nested/` | `ElNestedScroll`、协作协议与输入来源 |
| `physics/` | Bouncing / Clamping 物理 |
| `smooth/` | 平滑滚轮算法及其在标准位置上的编排 |
| `sliver/` | `ElSliverList` / `ElSliverGrid` / `ElSliverMasonry` 与导航头，见 [sliver/README.md](sliver/README.md) |
| `scrollbar/` | `ElWindowsScrollbar` / `ElMacScrollbar` 包装官方 RawScrollbar，Windows 预留 15 像素，macOS/Linux 悬浮 |

Android 滚动条使用官方 `Scrollbar`，iOS 使用官方 `CupertinoScrollbar`，两者不迁移旧自绘实现。桌面滚动条复用官方 RawScrollbar 的指标、绘制和滑块拖动，轨道按下直接定位；Windows 保留两端箭头步进和长按连续滚动，不另设滚动条控制器。

`ElScrollView` 通过标准 `ScrollController` 适配器共享真实滚动位置。虚拟列表与网格使用 `sliver/` 下的 Sliver，双轴内容使用纵向 Sliver 加外层横向 `ElScrollView`。

默认构造的 `spacing` 交给内部 `ElSliverList`，不再使用 `gap`；默认子项全量常驻，`addRepaintBoundaries`、`addSemanticIndexes` 默认开启。`.sliver` 不提供间距或子项包装参数，由各 Sliver 自己声明。

`scrollCacheExtent` 与官方一致使用 `ScrollCacheExtent`，默认 `ScrollCacheExtent.pixels(250)`，也支持视口倍数；普通和 shrinkWrap 视口均生效。该参数决定 builder/recycler 的预布局窗口，不改变 children 全量常驻的生命周期。

`scrollDirection`、`reverse`、`primary`、`scrollBehavior`、`dragStartBehavior`、`keyboardDismissBehavior`、`restorationId`、`semanticChildCount`、`hitTestBehavior`、`anchor`、`paintOrder` 与官方滚动参数对齐；`.sliver` 额外提供 `center`。内部沿用 `CustomScrollView` 的键盘、恢复和语义处理，同时保留现有滚轮平滑与嵌套滚动接力。

## 刷新距离

每种 `ElRefresher` 独立声明触发距离 `triggerExtent`、刷新停靠距离 `refreshingExtent` 和最大拉距 `maxPullExtent`，宿主不根据指示器 Widget 的尺寸推断阈值。第三方指示器通过 `ElCustomRefresher` 或继承 `ElRefresher` 接入，并以 `snapshot.progress` 和 `snapshot.status` 驱动视觉。

iOS 默认触发距离为 60 逻辑像素：顶部间距 16、指示器半径 14，中心位于 30，露出 60 的间隙时正好居中；此时进度达到 1 并进入待释放状态，松手后才刷新，回拉到阈值以内再松手则取消。刷新停靠距离仍为 60，默认最大拉距保持 250；显式指定触发距离时沿用原有的 2.5 倍最大拉距。Android 与自定义指示器保持各自的距离规则。

桌面滚动条可独立包装官方滚动视图：`ElWindowsScrollbar(controller: controller, child: list)` 或 `ElMacScrollbar(controller: controller, child: list)`，与内容共享控制器，未传时使用 `PrimaryScrollController`。

`extent` 设置命中区域宽度，`thickness` 设置可见滑块宽度，两侧细边界仍可拖动；Windows 的 `extent` 同时决定占位宽度，Mac 始终悬浮。`radius`、`minThumbLength` 和 `thumbColor` / `thumbHoverColor` / `thumbActiveColor` 控制滑块外观；Windows 另外提供 `trackColor`、`arrowColor`、`arrowExtent` 和 `arrowSize`。拖动、轨道直接定位、连续交互及 Windows 箭头长按均封装在组件内部。
