# ElScrollView 能力迁移到官方 Scrollable 的计划

日期：2026-11-10
审计基线：c801180，外加工作区中尚未提交的 ElScroll 原型
前置文档：[recycler_retirement_and_scrollable.md](recycler_retirement_and_scrollable.md)

本文只是计划，没有改动实现，也没有运行测试。文件路径相对于项目根目录；执行时先核对当前源码，保留在途修改。

## 1. 结论与范围

方向确定为：**官方 Scrollable 负责手势识别和滚动宿主，官方 Viewport 负责 Sliver 布局，El 的能力全部落在自建的 ScrollPosition 和它周围的 Widget / Sliver 上。**

这推翻了前置文档里的一条约束和一个步骤：

- 「已确定的约束」第一条（内容拖拽识别必须接 El 自定义事件系统）作废。
- 5.2 第 1 步（El 自定义拖拽事件驱动 position）作废，改为官方识别器经 `position.drag()` 驱动。

前置文档的其余部分继续有效，尤其是第 3 节的能力矩阵、第 4 节的 bibi 验收场景和 5.3 的核心不变量，本文直接引用，不重复抄录。

本文覆盖：位置层设计、下拉刷新（Widget 形式与 Sliver 形式）、滚动条、其余 ElScrollView 能力的迁移归属、阶段顺序和验收。

## 2. 当前起点

| 项目 | 状态 |
| --- | --- |
| lib/src/flutter/slivers/scroll/ | scroll.dart（ElScroll，默认构造接收 children，`ElScroll.sliver` 接收 Sliver）、scroll_position.dart（嵌套接力与协作链）、nested_scroll.dart（ElNestedScroll）、refresh.dart（ElRefresh）、sliver_refresh.dart（ElSliverRefresh）、scrollbar.dart（桌面滚动条宿主），合计约 1240 行 |
| test/flutter/views/sliver_scroll_test.dart | 22 个无头用例，已在 Windows 端通过（2026-11-10） |
| test/flutter/views/sliver_refresh_test.dart、sliver_scrollbar_test.dart、sliver_smooth_scroll_test.dart | Widget 入口刷新、桌面滚动条宿主、平滑滚轮的无头用例 |
| test/flutter/views/sliver_sliver_refresh_test.dart | Sliver 入口刷新的 10 个无头用例，**尚未在 Windows 端跑过** |
| ElSliverList、ElSliverRecyclerList / Grid | 已是官方 RenderSliver，可直接放进 ElScroll |
| lib/src/flutter/views/scroll/ | 旧实现约 2.9 万行，其中 virtual/ 1.2 万行；本计划完成前保持可用 |

阶段 0 与阶段 1 的拖动、松手、惯性三部分已通过原型测试。刷新的两个入口、桌面滚动条宿主和平滑滚轮已有实现，各阶段的完成情况见第 7 节。

## 3. 位置层：统一输入账本

所有需要「先于正文消费输入」的能力（刷新、折叠头、bibi 页头、显式嵌套协作）共用一个入口，不各自去改物理或监听通知。sliver_bibi 用 ScrollPhysics 分账之所以别扭，就是因为物理只覆盖拖拽一种来源。

### 3.1 官方入口与钩子

| 输入来源 | 官方入口 | 账本钩子 |
| --- | --- | --- |
| 触摸、触控板 pan | `Drag.update` → `applyUserOffset(delta)` | pre 阶段 → 正文 → post 阶段 |
| 松手 | `Drag.end` → `goBallistic(velocity)` | 释放速度交接，零速也回调 |
| 惯性帧 | BallisticScrollActivity → `setPixels` | 自建惯性活动，逐帧过账本；只对声明了惯性行程的参与者开放 |
| 滚轮 | Scrollable → `pointerScroll(delta)` | 平滑算法 + pre / post |

四个入口都在 `ScrollPositionWithSingleContext` 上可重写，已在本机 SDK 源码核对。

### 3.2 约定

- **只用消费量**：钩子返回已消费的量，与输入同号且绝对值不超过输入。前置文档已指出旧代码里消费量与剩余量混用，这里统一，Mixin 层不再保留剩余量写法。
- **pre 在物理之前**：账本看到的是原始手指位移。物理阻尼后的量不再交给任何参与者，保证输入量 = 参与者消费 + 正文消费 + 剩余。
- **普通嵌套不走账本**：ElScroll 之间的同轴接力继续由 `drag()` 入口的整段归属决定（起手贴边才交给外层，途中撞边界锁定）。账本只服务显式协作的参与者。
- **参与者经作用域登记**：ElScroll 在自身子树提供登记入口，并遮断上层作用域，避免内层 ElScroll 误绑外层的参与者。排序沿用现有 `inputOrder` 的语义：pre 按声明顺序，post 反序，多参与者必须列全。

### 3.3 已实现的形态（2026-11-10）

- 协作方协议直接复用已导出的 `ElNestedScrollParent`，链的排序与钳制复用 `NestedScrollChain`，没有新增协议。
- 登记入口是 `ElNestedScroll(parent:, child:)`，采用安卓式语义：ElScroll 上方的所有协作方都参与，不做作用域遮断。3.2 中「遮断上层作用域」一条因此不再适用。刷新是例外：ElScroll 会在自身子树遮断 `ElRefreshScope`，内层 ElScroll 不会绑到外层的 ElRefresh。
- 视口内部的协作方经 `ScrollHostPosition.addEdgeParticipant` 登记，目前只有 ElSliverRefresh。它排在链的最外侧：pre 最先、post 最后，所以折叠头先展开完才轮到刷新拉出，反向移动时刷新先收回。
- 有边界协作方时，`ScrollHostPhysics` 让内容不足一屏的 ElScroll 也接受拖动；调用方传入 NeverScrollableScrollPhysics 时仍然不接受。
- 只有真正持有本次拖动的 ElScroll 驱动协作链；内层贴边把手势交给外层后，包在内外层之间的协作方不参与。
- 惯性帧按帧差经过 pre 与 post。协作方消费后真实像素落后于模拟位置；Clamping 的模拟不含边界，不受影响，Bouncing 的模拟仍按起飞位置判断边界，这一偏差尚未处理。
- 正文在该方向无法起惯性时（例如贴边），协作方收不到惯性位移，需要在 `onNestedPreFling` 里自行收尾。
- 滚轮尚未接入协作链：官方 Scrollable 在正文贴边时不会调用 `pointerScroll`，需要阶段 5 自己监听指针信号。

### 3.4 本阶段要回答的问题

1. `applyUserOffset` 拿到的 delta 已经过 ScrollDragController 的起动阈值（iOS 物理为 3.5 px）。旧实现为此自建了不带阈值的拖拽控制器，新实现是否需要同样处理，由阶段 1 的测试决定。
2. 官方 `ScrollDragController.end` 把速度直接交给 `goBallistic`，中间没有钩子；速度交接必须在 `goBallistic` 重写里区分「拖拽释放」与「程序调用」。

## 4. 下拉刷新

### 4.1 能否以 Widget 形式迁移

能，而且改动比预想小。现有 `RefreshHost`（refresh/refresh_host.dart）本来就是一个包在视口外的 StatefulWidget，状态机的数据源是标准 `ScrollNotification`（只认 depth == 0）。它和 ElScrollView 的耦合只有三处：

| 耦合点 | 现状 | 迁移后 |
| --- | --- | --- |
| 输入分账 | `RefreshScrollLink` 挂进 ElScrollView 的拦截链 | 改为账本参与者：`consumeActive` 接 pre，`consumeBoundaryPull` 接 post，`releaseInput` 接释放 |
| 是否手指直接拖动 | `RefreshDockPhysics._directDrag` 读 `ScrollInputTransaction.current` | 改读位置状态（当前活动是否为拖拽） |
| 物理注入 | ElScrollView 在内部把物理包成 `RefreshDockPhysics` | ElScroll 发现已绑定「内容让位」刷新器时自动包装 |

以下内容原样保留，不重写：`ElRefresher`、`ElRefreshSnapshot`、`ElRefreshDetails`、`ElRefreshEdge`、四个刷新器及两个 spinner，以及 `ElRefresher.build` 的层级组合。sliver_bibi 的 refresh.dart 已经证明指示器这一半可以脱离 ElScrollView 使用。

### 4.2 两个入口，一套状态机

先把 `_RefreshHostState` 里的状态机抽成不依赖 Widget 的运动对象（状态、拉出量、阈值判定、停靠与收回动画、触觉）。两个入口共用它：

**Widget 入口 `ElRefresh`**

```dart
ElRefresh(
  onRefresh: load,
  child: ElScroll(slivers: [...]),
)
```

- 包住任意直接后代 ElScroll，刷新器从参数或 ElViewProvider 读取。
- 悬浮式（Android）：指示器叠在视口之上，正文不动，沿用现有组合。
- 内容让位式（iOS）：靠越界露出间隙，停靠靠 `RefreshDockPhysics` 外扩边界，沿用现有做法。

**Sliver 入口 `ElSliverRefresh`**

```dart
ElScroll(slivers: [
  pinnedHeader,
  ElSliverRefresh(onRefresh: load),
  ElSliverRecyclerList(...),
])
```

- 内容让位式：刷新期间用真实的 layoutExtent 占位，不再需要外扩物理边界，结构与官方 CupertinoSliverRefreshControl 一致。
- 悬浮式：零布局占位，把指示器钉在视口边缘绘制。
- 能放在固定头部下方，这是 Widget 入口做不到的，也是 bibi 需要的形态。

### 4.3 不能直接用官方刷新控件的原因

- CupertinoSliverRefreshControl 在拉到阈值时立即触发；本库规则是松手才触发，拉回阈值内再松手不触发。
- Material RefreshIndicator 回拖时列表与指示器同时移动；本库规则是指示器先完全回位，列表才动。

两条规则都写在 refresher.dart 的注释里，属于已定行为，迁移时保持。

### 4.4 必须保持的行为

以 test/flutter/views/scroll/refresh_test.dart 为准，至少覆盖：

- 悬浮与让位两种形态，leading / trailing 两条边，reverse。
- 松手触发、未达阈值收回、反向撤销不触发、惯性冲顶不拉起刷新。
- 回拖先回位指示器；刷新拖动不穿透点击。
- 空内容可下拉；停靠、完成停留、收起动画；`maxPullExtent` 硬上限。
- `requestRefresh()` 程序触发；刷新中卸载不回写。

### 4.5 风险

- Widget 入口的让位式依赖越界：外层是 Clamping 物理时由 `RefreshDockPhysics` 放开刷新边，需要确认这段逻辑脱离旧输入事务后仍成立。
- 是否让 Widget 入口的让位式改为内部插入 Sliver、从而删掉 `RefreshDockPhysics`，等 Sliver 入口在 Windows 端验证通过后再决定。

### 4.6 Sliver 入口的实现结论（2026-11-10，未验证）

实现在 sliver_refresh.dart，没有复用 `RefreshHost`：旧状态机靠滚动通知反推越界量，Sliver 入口直接从协作链拿位移，状态机只剩拉出、取消、刷新、完成四个转移，单独写更短。刷新器、快照、details 三个模型原样复用。

- **让位式**：间隙是本 Sliver 的 scrollExtent 与 layoutExtent，后面的 Sliver 被真实推开，滚动位置停在 0 不越界，因此不需要 `RefreshDockPhysics`，Clamping 与 Bouncing 物理表现一致。拉出阻尼沿用官方 Bouncing 的系数，受 `maxPullExtent` 约束。
- **悬浮式**：零占位，指示器铺满视口并钉在本 Sliver 的可见起点；首个 Sliver 最后绘制，天然盖在正文之上。
- **正文之下的指示器**：本 Sliver 自己把指示器裁到正文让出的间隙，不使用 `RefreshGapClip`。
- **间隙在已滚过的位置变化**（刷新完成时正文已上滚、滚动途中程序触发刷新）：用 scrollOffsetCorrection 同步修正偏移，屏幕上的正文不跳。
- **trailing 边不提供 Sliver 入口**：靠后的 Sliver 先绘制，悬浮式会被正文盖住；让位式要在内容末尾占位，内容不足一屏时间隙不贴视口底边。trailing 边继续使用 ElRefresh。
- **只用刷新器的 buildIndicator 与策略参数**；覆写 `ElRefresher.build` 接管层级的刷新器用 ElRefresh。指示器不参与命中。

已知缺口：

- 完成停留（finishDelay）期间拖动不会提前收起。
- 带刷新的 ElScroll 嵌在同轴的外层 ElScroll 里时，贴边起手的拖动按接力规则交给外层，内层刷新拉不出来。
- 内容不足一屏且 ElSliverRefresh 是后来才插入的，要等内容尺寸下一次变化才开始接受拖动（官方只在尺寸变化时重新决定是否可拖）。

## 5. 滚动条

### 5.1 移动端用官方实现

官方 `ScrollBehavior.buildScrollbar` 在移动平台默认直接返回 child，不显示滚动条。因此由 `ElScrollBehavior.buildScrollbar` 显式安装：

| 平台 | 实现 |
| --- | --- |
| iOS | CupertinoScrollbar |
| Android | Material Scrollbar（已定，2026-11-10）。基础层已有文件导入 Material，不新增依赖 |

`ElIosScrollBar`、`ElAndroidScrollBar` 随之删除，不留兼容层。lib 之外引用它们的有 views/view/provider.dart 的平台默认回落和示例 doc_scroll_view.dart 的 `_DocIosScrollBar`，一并迁到官方控件。示例的 `RecyclerExampleScrollbar` 已经在用官方 CupertinoScrollbar，可作参照。

### 5.2 桌面端保留定制

RawScrollbar 的 ScrollbarPainter 只能画一个滑块和一条轨道，做不了 `ElWindowScrollBar` 的步进按钮、Widget 构建的滑块、轨道悬停和占位 gutter。所以桌面保留 `ElScrollbar` 这套外观与策略模型（`ElWindowScrollBar`、`ElMacScrollBar`、`ElNoScrollBar`），只换宿主：

- 新增一个包在 Scrollable 外的宿主 Widget，由 `ElScrollBehavior.buildScrollbar` 在桌面平台安装。
- 指标来自 `ScrollableDetails.controller` 的位置和 ScrollMetricsNotification；命令走位置的 `jumpTo` / `animateTo` / `pointerScroll`。
- 滑块拖拽接管当前活动，释放后不恢复旧目标。
- Windows 的 inset 占位由宿主直接缩小 child 的布局宽度，首帧即正确。

`ElScrollbarAxisDetails`、`ElScrollbarDetails` 接口保持，自定义滚动条不用改。

### 5.3 待核对

- scrollbar_base.dart（1768 行）里有多少逻辑依赖滚动条作为视口成员参与层序（默认 zIndex 10）和 `ElPositioned`。宿主移到视口外之后这部分应当可以删除，需逐段确认。
- `ScrollbarThumbDragDelegate`（滑块分数到像素的自定义映射）和 `dragOptimize` 目前由虚拟管线提供。迁移后由回收 Sliver 提供还是直接取消，取决于估算高度下拖拽是否仍跳动，放到阶段 4 用真实滑块拖动测试判断。
- 单实例覆盖：ElScroll 的 `scrollbar` 参数需要先关掉环境滚动条再安装自己的宿主。

## 6. 其余能力的迁移归属

「官方直接承担」表示不写新实现，只需接线和回归。

| 能力 | 归属 | 说明 |
| --- | --- | --- |
| 同轴嵌套接力 | 已在原型中 | 滚轮目前是官方行为，缺 500 ms 交接保护，阶段 5 补 |
| deltaInterceptor、inputOrder、ElNestedScrollMixin | 位置账本 | 统一为消费量约定 |
| 平滑滚轮、横向修饰键 | 位置的 `pointerScroll` | 复用 ElSmoothScroll 算法与 SmoothPointerScrollController，先查它们对旧视口的依赖 |
| 触控板 | 官方直接承担 | 官方把 PanZoom 交给同一组拖拽识别器 |
| 鼠标拖动内容 | 官方直接承担 | `ScrollBehavior.dragDevices` |
| 拖拽起动距离 | 官方直接承担 | MediaQuery 的 gestureSettings |
| 物理 | 复用 | 三个 El 物理本身就是 ScrollPhysics；逐个检查是否读取旧输入事务 |
| 键盘滚动、焦点 | 官方直接承担 | ScrollAction / ScrollIntent 与 Focus；确认「子控件持焦不接管」的规则 |
| 拖动收起键盘 | 接线 | 监听 ScrollUpdateNotification，与官方 ScrollView 相同 |
| showOnScreen、语义滚动、选区自动滚动 | 官方直接承担 | ElSliverList 已为此保留离屏变换 |
| reverse、RTL、shrinkWrap | 官方直接承担 | shrinkWrap 用 ShrinkWrappingViewport |
| padding、gap、crossAxisAlignment | Sliver 层 | padding 用 SliverPadding；gap 与交叉轴对齐由内容 Sliver 自己声明 |
| scrollToIndex、可见范围 | 内容 Sliver 提供几何 | 位置层只做像素滚动，不展开列表也不维护高度索引 |
| pinToEnd、preserveAnchor | 位置层 + Sliver | 贴尾在范围变化时修正像素；锚点保持由 Sliver 的 scrollOffsetCorrection 承担 |
| ElScrollMixin 观察接口 | 重建在位置监听与通知之上 | 条目快照改由 RenderSliver 与视口换算 |
| sticky | 先评估官方 | PinnedHeaderSliver、SliverPersistentHeader |
| 折叠、大标题 | 账本参与者 + Sliver | consumeDelta 模式走账本；尺寸变化类先评估 SliverResizingHeader |
| reveal、parallax、progress、stretch | 观察类效果 | 只依赖位置与条目几何 |
| ElPositioned 视口固定内容 | 视口外叠层 | 旧实现是视口直接成员，新实现改为 ElScroll 外层的层叠 |
| 双轴滚动 | **单独评估** | 一维 Sliver 不提供双轴；编辑器和表格在用，见第 8 节 |

## 7. 阶段与验收

每个阶段单独提交，阶段之间旧 ElScrollView 始终可用。测试只跑本阶段涉及的无头用例。

| 阶段 | 内容 | 完成条件 | 状态（2026-11-10） |
| --- | --- | --- | --- |
| 0 | 原型基线 | sliver_scroll_test.dart 全部通过 | 已通过 |
| 1 | 位置账本：拖拽 pre / post、释放交接、参与者作用域与排序 | 输入量守恒；新手势、程序命令接管后旧活动不回写；回答 3.3 的两个问题 | 拖动、松手、惯性已通过；滚轮未接入协作链 |
| 2 | 刷新 Widget 入口：抽出状态机，替换三处耦合 | 4.4 的行为在 ElScroll 上通过；旧 ElScrollView 的刷新测试不回退 | ElRefresh 已实现，复用 `RefreshHost`，状态机未抽出；4.4 尚未逐条对照 |
| 3 | 刷新 Sliver 入口 | 让位式用真实占位；悬浮式 leading 通过；trailing 给出结论 | ElSliverRefresh 已实现，待 Windows 端验证；结论见 4.6 |
| 4 | 滚动条：移动端换官方，桌面换宿主 | 真实滑块拖动、轨道点击、步进、滚轮转发、Windows inset 首帧；删除两个移动端滚动条类 | 桌面宿主已有（scrollbar.dart）；移动端替换与旧类删除未做 |
| 5 | 滚轮与设备：平滑滚轮、500 ms 交接、惯性帧过账本、键盘 | 平滑配置继承与关闭语义不变；各入口互相接管后旧目标不恢复 | 平滑滚轮与惯性帧过账本已有；500 ms 交接、键盘未做 |
| 6 | 观察与效果：ElScrollMixin、sticky、折叠、大标题及其余效果 | effects_test.dart 对应行为迁移通过，只更新相关局部 | 未开始 |
| 7 | 内容几何：scrollToIndex、可见范围、pinToEnd、preserveAnchor、视口固定内容 | 聊天加载历史与贴尾两个场景通过 | 未开始 |
| 8 | bibi 整页迁到 ElScroll | 前置文档第 4 节全部场景；删除 sliver_bibi 里的物理分账和指针计数 | 未开始 |
| 9 | 依赖方迁移与旧实现退役 | 见第 8 节 | 未开始 |

阶段 2 到 4 是用户指定的重点，排在通用能力之前；它们只依赖阶段 1。

## 8. 依赖方与退役

lib 内直接依赖 ElScrollView 的位置：

- views/table/table_view.dart、views/editable/（editable_view.dart、view.dart）、views/image/image_view.dart
- widgets/others/infinite_scroll.dart
- ui/desktop/components 下的 select、autocomplete、mention 面板与 nav_menu
- layout 下的 ElListView / ElGridView（作为 ElScrollView 成员存在）
- ElTabView 没有直接创建 ElScrollView，但声明物理与拖拽设备口径与它一致；退役前核对它引用的旧模块

退役前要先定两件事：

1. **双轴**。编辑器和表格需要两轴同时滚动。可选做法是官方 TwoDimensionalScrollable，或者让这两个组件继续保留一份精简后的旧视口。未评估前不删除旧实现中的双轴部分。
2. **ElListView / ElGridView 的去向**。它们是「ElScrollView 成员」形态的 API；迁移后是映射到对应 Sliver，还是保留为独立组件，需要结合现有调用决定。

这两件事定下来之前，阶段 9 只做依赖方里的单轴场景。

## 9. 需要你决定的事项

已定：

- Android 滚动条用 Material Scrollbar。
- 协作约定统一为消费量（用户交由实现方决定，2026-11-10）。ElScroll 直接使用 `ElNestedScrollParent`，它本来就是消费量约定；旧 `ElNestedScrollMixin` 的剩余量钩子不迁移。

待定，可以等到阶段 9：

1. 双轴走官方二维滚动还是保留精简旧视口。
2. 最终名称沿用 ElScroll，还是在退役时接管 ElScrollView 这个名字。

## 10. 验证约束

- Linux 侧不运行 pub get、build_runner、analyze、test；每个阶段结束列出命令，在 Windows 端执行。
- 只运行无头 flutter test，不运行 flutter run / drive，不做前台窗口或真机测试。
- 滚动条用真实滑块拖动验证，不用 `controller.jumpTo` 代替。
- 无头测试耗时不解释为真机帧耗时。
