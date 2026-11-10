# 滚动宿主与共用策略

`ElScroll` 基于官方 `Scrollable` 和 `Viewport`；普通内容使用默认构造，Sliver 组合使用 `ElScroll.sliver`。刷新入口为外层 `ElRefresh` 或起点处的 `ElSliverRefresh`，桌面滚动条使用 `ElDesktopScrollbar`。

| 目录 | 职责 |
| --- | --- |
| `common/` | 嵌套协作及输入来源、平台物理、标准位置上的平滑滚轮 |
| `refresh/` | 刷新配置、状态快照、刷新宿主及 Android / iOS 指示器 |
| `scrollbar/` | Windows / macOS 桌面条带及基于标准位置的交互 |

Android 滚动条使用官方 `Scrollbar`，iOS 使用官方 `CupertinoScrollbar`，两者不迁移旧自绘实现。桌面条带仅向标准 `ScrollPosition` 发送命令，不包含旧虚拟行的分数映射和位置引擎分支。

旧 `ElScrollView` 的控制器、完整滚动快照、输入事务、运动引擎、虚拟管线、旧滚动条及其专属适配继续留在 `views/scroll/`。仅共用的刷新配置与外观、平台物理、嵌套协议和平滑算法保留旧路径转导出。新版刷新宿主和平滑滚轮移除了旧输入协作分支，`ElScroll` 通过标准 `ScrollController` 适配器共享真实位置。

## 刷新距离

每种 `ElRefresher` 独立声明触发距离 `triggerExtent`、刷新停靠距离 `refreshingExtent` 和最大拉距 `maxPullExtent`，宿主不根据指示器 Widget 的尺寸推断阈值。第三方指示器通过 `ElCustomRefresher` 或继承 `ElRefresher` 接入，并以 `snapshot.progress` 和 `snapshot.status` 驱动视觉。

iOS 默认触发距离为 60 逻辑像素：顶部间距 16、指示器半径 14，中心位于 30，露出 60 的间隙时正好居中；此时进度达到 1 并进入待释放状态，松手后才刷新，回拉到阈值以内再松手则取消。刷新停靠距离仍为 60，默认最大拉距保持 250；显式指定触发距离时沿用原有的 2.5 倍最大拉距。Android 与自定义指示器保持各自的距离规则。
