# 滚动宿主与共用策略

`ElScroll` 基于官方 `Scrollable` 和 `Viewport`；普通内容使用默认构造，Sliver 组合使用 `ElScroll.sliver`。刷新入口为列表中的 `ElSliverRefresh`，桌面滚动条使用 `ElDesktopScrollbar`。

本目录只放滚动机制；能放进 `ElScroll.sliver` 的 Sliver（文档列表、回收列表、折叠头、大标题）位于 `slivers/`；刷新组件位于 `widgets/refresh/`。

| 路径 | 职责 |
| --- | --- |
| `scroll.dart` | `ElScroll` 宿主与外部控制器适配 |
| `scroll_position.dart` | 拖动接力、协作链位移分配、滚轮接收者锁 |
| `scroll_behavior.dart` | `ElScrollBehavior`：平台物理、滚动条与越界效果 |
| `nested/` | `ElNestedScroll`、协作协议与输入来源 |
| `physics/` | Bouncing / Clamping 物理 |
| `smooth/` | 平滑滚轮算法及其在标准位置上的编排 |
| `scrollbar/` | `ElDesktopScrollbar` 及 Windows / macOS 桌面条带 |

Android 滚动条使用官方 `Scrollbar`，iOS 使用官方 `CupertinoScrollbar`，两者不迁移旧自绘实现。桌面条带仅向标准 `ScrollPosition` 发送命令，不包含旧虚拟行的分数映射和位置引擎分支。

旧 `ElScrollView` 体系已移除。滚动统一建立在官方 Scrollable / Viewport / Sliver 之上，`ElScroll` 通过标准 `ScrollController` 适配器共享真实位置；虚拟列表与网格使用 `slivers/` 下的 Sliver，双轴内容使用纵向 Sliver 加外层横向 `ElScroll`。

## 刷新距离

每种 `ElRefresher` 独立声明触发距离 `triggerExtent`、刷新停靠距离 `refreshingExtent` 和最大拉距 `maxPullExtent`，宿主不根据指示器 Widget 的尺寸推断阈值。第三方指示器通过 `ElCustomRefresher` 或继承 `ElRefresher` 接入，并以 `snapshot.progress` 和 `snapshot.status` 驱动视觉。

iOS 默认触发距离为 60 逻辑像素：顶部间距 16、指示器半径 14，中心位于 30，露出 60 的间隙时正好居中；此时进度达到 1 并进入待释放状态，松手后才刷新，回拉到阈值以内再松手则取消。刷新停靠距离仍为 60，默认最大拉距保持 250；显式指定触发距离时沿用原有的 2.5 倍最大拉距。Android 与自定义指示器保持各自的距离规则。
