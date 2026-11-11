# 滚动宿主与共用策略

`ElScroll` 基于官方 `Scrollable` 和 `Viewport`；普通内容使用默认构造，Sliver 组合使用 `ElScroll.sliver`。刷新入口为列表中的 `ElSliverRefresh`，桌面滚动条使用 `ElWindowsScrollbar` / `ElMacScrollbar`。

本目录只放滚动机制；能放进 `ElScroll.sliver` 的 Sliver（文档列表、回收列表、折叠头、大标题）位于 `slivers/`；刷新组件位于 `widgets/refresh/`。

| 路径 | 职责 |
| --- | --- |
| `scroll.dart` | `ElScroll` 宿主与外部控制器适配 |
| `scroll_position.dart` | 拖动接力、协作链位移分配、滚轮接收者锁 |
| `scroll_behavior.dart` | `ElScrollBehavior`：平台物理、滚动条与越界效果 |
| `nested/` | `ElNestedScroll`、协作协议与输入来源 |
| `physics/` | Bouncing / Clamping 物理 |
| `smooth/` | 平滑滚轮算法及其在标准位置上的编排 |
| `../widgets/scrollbar/` | `ElWindowsScrollbar` / `ElMacScrollbar` 包装官方 RawScrollbar，Windows 预留 15 像素，macOS/Linux 悬浮 |

Android 滚动条使用官方 `Scrollbar`，iOS 使用官方 `CupertinoScrollbar`，两者不迁移旧自绘实现。桌面滚动条复用官方 RawScrollbar 的指标、绘制和滑块拖动，轨道按下直接定位；Windows 保留两端箭头步进和长按连续滚动，不另设滚动条控制器。

旧 `ElScrollView` 体系已移除。滚动统一建立在官方 Scrollable / Viewport / Sliver 之上，`ElScroll` 通过标准 `ScrollController` 适配器共享真实位置；虚拟列表与网格使用 `slivers/` 下的 Sliver，双轴内容使用纵向 Sliver 加外层横向 `ElScroll`。

## 刷新距离

每种 `ElRefresher` 独立声明触发距离 `triggerExtent`、刷新停靠距离 `refreshingExtent` 和最大拉距 `maxPullExtent`，宿主不根据指示器 Widget 的尺寸推断阈值。第三方指示器通过 `ElCustomRefresher` 或继承 `ElRefresher` 接入，并以 `snapshot.progress` 和 `snapshot.status` 驱动视觉。

iOS 默认触发距离为 60 逻辑像素：顶部间距 16、指示器半径 14，中心位于 30，露出 60 的间隙时正好居中；此时进度达到 1 并进入待释放状态，松手后才刷新，回拉到阈值以内再松手则取消。刷新停靠距离仍为 60，默认最大拉距保持 250；显式指定触发距离时沿用原有的 2.5 倍最大拉距。Android 与自定义指示器保持各自的距离规则。

桌面滚动条可独立包装官方滚动视图：`ElWindowsScrollbar(controller: controller, child: list)` 或 `ElMacScrollbar(controller: controller, child: list)`，与内容共享控制器，未传时使用 `PrimaryScrollController`。

`extent` 设置命中区域宽度，`thickness` 设置可见滑块宽度，两侧细边界仍可拖动；Windows 的 `extent` 同时决定占位宽度，Mac 始终悬浮。`radius`、`minThumbLength` 和 `thumbColor` / `thumbHoverColor` / `thumbActiveColor` 控制滑块外观；Windows 另外提供 `trackColor`、`arrowColor`、`arrowExtent` 和 `arrowSize`。拖动、轨道直接定位、连续交互及 Windows 箭头长按均封装在组件内部。
