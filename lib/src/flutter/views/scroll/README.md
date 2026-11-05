# Scroll

`ElScrollView` 同时承载普通内容、虚拟 List/Grid，配套索引定位、刷新、滚动条及滚动效果。

本文示例导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。控制器和 FocusNode 在 State / Hook 生命周期内创建，卸载时 dispose；不要在每次 build 中重建。

## 普通滚动与虚拟列表

```dart
SizedBox(
  height: 320,
  child: ElScrollView(
    padding: EdgeInsets.all(16),
    gap: 12,
    children: [
      Text('消息'),
      ElListView.builder(
        itemCount: 1000,
        gap: 8,
        itemBuilder: (_, i) => SizedBox(height: 40, child: Text('第 $i 行')),
      ),
      Text('列表结束'),
    ],
  ),
);
```

- 普通 Widget、普通 List/Grid 全量挂载；`builder` List/Grid 按视口挂卸，必须直接放在 `children` 中，不能再套 Padding / Column。
- 宿主 `padding` 处理整段内边距，`gap` 处理直接成员和布局段之间的间距；段内间距设在 List/Grid 上。
- 默认由父级提供有限视口；在 Column 内通常用 Expanded 包住。
- `shrinkWrap: true` 按完整内容定尺，全部挂载并布局，虚拟挂窗失效。
- List/Grid 的分隔、稳定 Key、重排与保活示例见 [Layout](../layout/README.md)。

## 像素与索引定位

```dart
final controller = ElScrollController();
SizedBox(
  height: 320,
  child: ElScrollView(controller: controller, children: [
    ElListView.builder(
      itemCount: 1000,
      itemBuilder: (_, i) => SizedBox(height: 48, child: Text('$i')),
    ),
  ]),
);
ElButtonView(
  onPressed: () async {
    final reached = await controller.scrollToIndexWithResult(
      500, alignment: 0.5, duration: Duration(milliseconds: 250),
    );
    debugPrint('定位完成：$reached');
  },
  child: '定位第 501 项',
);
```

| API | 用途 |
| --- | --- |
| `ScrollController.jumpTo / animateTo` | 只需像素滚动时可直接用官方控制器；操作前检查 `hasClients` |
| `ElScrollController.scrollToIndex` | 索引定位；不关心完成结果时使用 |
| `scrollToIndexWithResult` | 收敛完成返回 true，取消或未收敛返回 false |
| `cancelScrollToIndex` | 取消索引定位，不影响普通像素动画 |
| `dispatchPointerScroll` | 将外部区域收到的 PointerScrollEvent 转交所属视口 |

索引使用**扁平成员空间**：普通 child 算 1 项，List/Grid 展开计数，List 分隔项也占索引。`alignment: 0 / 0.5 / 1` 分别对齐首端、中心、尾端；不传 duration 或传零时直接定位并校正估算误差。索引 API 需挂到带虚拟段的宿主；一个 ElScrollController 只能挂载一个位置。

## 横向、双轴与键盘

```dart
final vertical = ScrollController();
final horizontal = ScrollController();
SizedBox(
  width: 320, height: 240,
  child: ElScrollView(
    axis: null,
    controller: vertical,
    horizontalController: horizontal,
    children: [SizedBox(width: 1000, height: 800, child: Text('双轴内容'))],
  ),
);
```

| 参数 | 行为 |
| --- | --- |
| `axis` | 默认 vertical；horizontal 为横向；显式 null 为双轴 |
| `reverse` | 反转单轴；双轴不支持 |
| `horizontalController` | 仅双轴使用；此时 controller 负责垂直轴 |
| `mouseWheelHorizontalModifiers` | 横向宿主默认 Ctrl + 纵向滚轮；null 为无修饰键转换；空集合禁用转换 |
| `focusNode`、`keyboardScroll` | 显式声明焦点后，自身持主焦点时响应方向键、PageUp/Down、Home/End；子控件持焦不接管 |
| `keyboardDismissBehavior` | 设为 onDrag 可在拖动时收起软键盘 |
| `crossAxisAlignment` | 普通成员的交叉轴对齐；双轴不适用，baseline 不支持 |

## 刷新与加载历史消息

```dart
SizedBox(
  height: 320,
  child: ElScrollView(
    refresher: ElAndroidRefresher(color: Colors.blue),
    onRefresh: () async {
      // 等待请求并更新业务数据；Future 完成后刷新器收起。
    },
    children: [SizedBox(height: 800, child: Text('向下拉刷新'))],
  ),
);
```

| 配置 | 用途 |
| --- | --- |
| `ElAndroidRefresher` | 悬浮圆盘；distanceToTrigger、color、bgColor |
| `ElIosRefresher` | 内容让位的 iOS 指示器；triggerExtent、color 可配置 |
| `ElCustomRefresher` | 自定义阈值、停靠距离和指示器 builder |
| `ElNoRefresher` | 显式关闭刷新器 |
| `refreshEdge` | leading 为 min 边，trailing 为 max 边；reverse 后视觉方向相反 |
| `pinToEnd` | 当前贴住 max 边时，内容增长后继续贴尾；不强拉回正在阅读历史的位置 |
| `preserveAnchor` | 增删、重排、尺寸变化时尽量保住原可见成员；加载历史消息可开启 |

刷新器仅在 `onRefresh` 非 null 时挂载；达到阈值后**松手**才触发。反向聊天列表顶部拉取旧消息用 `refreshEdge: ElRefreshEdge.trailing`；贴尾追加与保留阅读位置是两个独立开关。

自定义指示器通过 `details.snapshot` 读取状态和进度，返回值覆盖整个视口，需自行定位并保持无交互部分命中透明：

```dart
final refresher = ElCustomRefresher(
  triggerExtent: 80,
  refreshingExtent: 48,
  builder: (_, details) => IgnorePointer(
    child: ValueListenableBuilder<ElRefreshSnapshot>(
      valueListenable: details.snapshot,
      builder: (_, value, _) => Align(
        alignment: value.anchoredAtViewportStart
            ? Alignment.topCenter : Alignment.bottomCenter,
        child: Text(value.status == RefreshIndicatorStatus.refresh
            ? '刷新中' : '下拉进度 ${(value.progress * 100).round()}%'),
      ),
    ),
  ),
);
```

`ElRefreshSnapshot` 含 status、pulledExtent、triggerExtent、edge、axisDirection、progress；交互式指示器可调用 `details.requestRefresh()`，非空闲态时无操作。

## 滚动条、物理与滚轮平滑

```dart
ElViewProvider(
  scrollbarBuilder: (_) => ElWindowScrollBar(extent: 12),
  smoothScrollBuilder: (_) => ElWindowsSmoothScroll(),
  refresherBuilder: (_) => ElIosRefresher(),
  child: ScrollConfiguration(
    behavior: ElScrollBehavior(),
    child: SizedBox(
      height: 240,
      child: ElScrollView(children: [SizedBox(height: 1000, child: Text('正文'))]),
    ),
  ),
);
```

| 入口 | 选择 |
| --- | --- |
| `scrollbar` | ElWindowScrollBar / ElMacScrollBar / ElIosScrollBar / ElAndroidScrollBar；ElNoScrollBar 关闭 |
| `smoothScroll` | 默认 `$absent` 继承环境并按平台自适应；`null` 关闭；ElWindowsSmoothScroll / ElChromiumSmoothScroll 指定算法 |
| `physics` | ElBouncingScrollPhysics / ElClampingScrollPhysics / ElBrowserScrollPhysics，或官方 ScrollPhysics |
| `ElScrollBehavior` | 通过官方 ScrollConfiguration 提供本库平台物理；也可用于 MaterialApp.scrollBehavior |

单个宿主显式配置覆盖环境配置；scrollbar / smoothScroll / refresher 从 ElViewProvider 继承，physics 从 ScrollConfiguration 继承。刷新宿主绑定的物理策略优先于普通物理配置。自定义滚动条继承 ElScrollbar，通过 ElScrollbarDetails 读两轴指标和派发交互，不必另建滚动控制器。

平滑滚动严格区分未配置和关闭：`ElScrollView` 不传 `smoothScroll` 或传 `$absent` 时继承；传 `null` 关闭。`ElViewProvider` 不传 `smoothScrollBuilder` 时自适应，回调返回 `$absent` 时继承；显式把 Builder 设为 `null`，或让回调返回 `null`，都会关闭当前子树。祖先已关闭时，后代自适应仍继承关闭；需要重新开启可显式返回算法实例。运行时由算法切换到 `null` 不会重挂子树。

## 可视范围与滚动观察

```dart
final visible = ValueNotifier<ElVisibleRange?>(null);
SizedBox(
  height: 320,
  child: ElScrollView(
    cacheExtent: 400,
    onVisibleRangeChanged: (range) => visible.value = range,
    children: [ElListView.builder(
      itemCount: 1000,
      itemBuilder: (_, i) => SizedBox(height: 48, child: Text('$i')),
    )],
  ),
);
```

`first / last` 是可见窗口，`mountedFirst / mountedLast` 是含缓存的挂载窗口，均为 **[首项, 尾项)**。回调在帧后合并派发，仅有虚拟段时生效；`cacheExtent` 默认 250 逻辑像素，缓存项只测量，不参与绘制、命中与语义。

子项需要逐帧状态时，用真实滚动后代 State 混入 `ElScrollMixin`：

```dart
class ScrollReadout extends StatefulWidget {
  @override
  State<ScrollReadout> createState() => ScrollReadoutState();
}

class ScrollReadoutState extends State<ScrollReadout>
    with ElScrollMixin<ScrollReadout> {
  @override
  bool get rebuildOnScrollUpdate => true;

  @override
  Widget build(BuildContext context) => Text('${scrollSnapshot.contentOffset.round()} px');
}
```

将 `ScrollReadout()` 放进 ElScrollView.children。Mixin 会自动绑定最近宿主并解绑；双轴通过 `requestedScrollAxis` 选轴。创建 ElScrollView 的外层 State 本身不算滚动后代；`ElScrollView.of / maybeOf` 也只向祖先查找。

| Mixin API | 用途 |
| --- | --- |
| `scrollSnapshot` | contentOffset、velocity、direction、activity、atStart / atEnd 等 |
| `onScrollStart / Update / End` | 实际滚动生命周期；重写时调用 super |
| `onScrollMetricsChanged / onScrollActivityChanged` | 视口指标、活动状态变化 |
| `onInputStart / End / Cancel` | 输入会话；松手不等于惯性结束 |
| `onScrollSettle / onMotionSettled / onMotionCancelled` | 收尾任务、运动完成与取消 |
| `listenScrollItem`、`scrollItemSnapshot` | 当前条目的尺寸、相对视口位置、可见比例和 pinned 状态 |
| `trackScrollItemVisibility / trackScrollItemVisibleFraction` | 开启可见性或连续比例跟踪，通过 onScrollItemVisibilityChanged 接收 |

## Sticky、折叠与其他效果

```dart
class StickyTitle extends StatefulWidget {
  @override
  State<StickyTitle> createState() => StickyTitleState();
}

class StickyTitleState extends State<StickyTitle>
    with ElScrollMixin<StickyTitle>, ElStickyMixin<StickyTitle> {
  @override
  double? get stickyOffset => 0;

  @override
  Widget build(BuildContext context) => buildSticky(
    context,
    child: Container(height: 48, color: Colors.white, child: Text('吸顶标题')),
  );
}
```

将 StickyTitle 放在宿主的直接内容槽或 builder 条目中，布局、保活由宿主处理。需要 pinned 变化重建时开启 `stickyListenProgress`，读取 `isStickyPinned`。

| 效果 Mixin（均叠加 ElScrollMixin） | 构建入口与关键配置 |
| --- | --- |
| `ElScrollCollapseMixin` | buildScrollCollapse(context, expanded: ..., collapsed: ...)；direction 显隐、followDelta 跟随位移、consumeDelta 消费输入折叠真实尺寸 |
| `ElLargeTitleNavbarMixin` | buildLargeTitleNavbar；largeTitle / compactTitle 必传，leading / actions / bottom 可选；scale、fade、stretch、snap 控制效果 |
| `ElScrollRevealMixin` | buildScrollReveal；scrollRevealOffset / Distance / Once / Fade |
| `ElParallaxMixin` | buildParallax；parallaxFactor / parallaxMaxOffset |
| `ElScrollProgressMixin` | buildScrollProgress；scrollProgressValue、scrollProgressStyle / Axis |

折叠头的 expanded / collapsed 由真实内容尺寸决定，不必手动推算高度差：

```dart
class CollapsingTitle extends StatefulWidget {
  @override
  State<CollapsingTitle> createState() => CollapsingTitleState();
}

class CollapsingTitleState extends State<CollapsingTitle>
    with ElScrollMixin<CollapsingTitle>, ElScrollCollapseMixin<CollapsingTitle> {
  @override
  Widget build(BuildContext context) => buildScrollCollapse(
    context,
    expanded: SizedBox(height: 96, child: Text('展开标题')),
    collapsed: SizedBox(height: 48, child: Text('紧凑标题')),
  );
}
```

将 CollapsingTitle 放在滚动宿主子树。默认 direction 按滚动方向显隐；可覆写 scrollCollapseMode、scrollCollapseOffset / VelocityThreshold、scrollCollapseSnap / Fade。consumeDelta 需要为参与者声明稳定 scrollInputSlot，并在宿主 inputOrder 中排序；该模式与位置/速度阈值互斥。

## 嵌套滚动与输入协商

内层滚动子树由外层真实后代 State 混入 `ElNestedScrollMixin`，使用 `buildNestedScrollRegion(child: innerScroll)` 包住。参与者声明稳定 `scrollInputSlot`，宿主通过 `inputOrder: {Axis.vertical: [slotA, slotB]}` 排序，多参与者需列全，不能依赖挂载顺序。

- `onNestedPreScroll(input, remaining)`：内层消费前处理。
- `onNestedPostScroll(input, remaining)`：内层到边界后处理余量。
- `onNestedPreFling(details, remainingVelocity)`：处理松手速度；零速度也回调。
- Mixin 钩子返回**剩余量**，未消费时返回原值；pre 按声明顺序、post 按反序。
- 底层 `ElNestedScrollParent` 的 pre/post 以及 `ElScrollDeltaInterceptor.interceptScrollDelta` 返回**消费量**，不要混用。独立 deltaInterceptor 用于输入吸收；启用时使用宿主默认控制器或 ElScrollController。

## 视口固定内容与语义

直接成员可用 `ElPositioned(top: 0, right: 0, zIndex: 20, child: ...)` 固定到视口，任一定位字段存在即脱离正文流；只设 zIndex 仍保留占位。百分比以视口盒为基准，滚动条默认 zIndex 为 10。

`excludeSemantics` 可排除成员语义，`semanticsRole` 设置滚动结构角色；视觉层序不改变文档选择源序，无障碍阅读顺序需要时显式设置语义 sortKey。
