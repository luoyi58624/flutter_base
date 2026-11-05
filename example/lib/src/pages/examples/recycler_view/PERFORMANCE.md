# 真实示例行的结构复用验证

后续聊天首入约 200ms 的分段定位与修复，见 [聊天页面首次进入开销](CHAT_ENTRY_PERFORMANCE.md)。

日期：2026-11-06。Flutter 3.47.5 / Dart 3.13.4，Windows `flutter_test` Debug。没有操作手机、启动前台应用或热重载；下述主机耗时不是手机 UI/raster FrameTiming。

本轮直接使用复选和聊天页面的真实 Adapter、ViewHolder、品牌组件与业务数据，补上此前只看 holder 外壳和简化测试行的覆盖缺口。

## 修复内容

旧复选行根 `ElCardView`、复选框与聊天根 `Padding` 的 Key 都随业务 ID 改变。同一 holder 换绑另一条数据时，Flutter 会重新挂载行内部子树，破坏结构复用。新的 holder 保留固定卡片、布局和控件，只将实际变化发送到文本、语义、选中状态等消费叶子。

复选框有一个必要例外：换到不同 ID 且选中值也不同时，仅重置复选动画叶子，防止上一条记录的过渡带到新行。相同选中值的跨 ID 绑定保持原 Checkbox State，同一记录的用户切换继续正常过渡；整张卡与 Row 始终保留。

普通 ListView 的数据行仍可使用数据 ID 作为身份。需要避免的是在 RecyclerView 已确定的同一个 holder 内，再用变化的业务 ID 迫使固定结构替换。

## 同一真实行连续绑定

基线取自 `e775dfd` 的旧复选/聊天源码，保存为本地快照；当前回收内核与品牌组件相同。测试保持真实页面及其业务模型存活，通过公开 Adapter 接口创建一个同类型 holder，将实际 itemView 挂在固定 360 宽区域，再依次绑定 121 个不同 ID，记录后 120 次绑定。聊天两个方向分别检测，数据内容和时间确实改变。

| 场景 | 绑定次数 | 旧版新建 / 移除 Element | 修复后新建 / 移除 | 根 RenderObject 保留次数（旧→新） | 文本 RenderParagraph 保留次数（旧→新） |
| --- | ---: | ---: | ---: | ---: | ---: |
| 复选行 | 120 | 4320 / 4320 | 0 / 0 | 0 → 120 | 0 → 240 |
| 发出消息 | 120 | 1680 / 1680 | 0 / 0 | 0 → 120 | 0 → 360 |
| 收到消息 | 120 | 1680 / 1680 | 0 / 0 | 0 → 120 | 0 → 360 |

原复选树初始 37 个 Element，新树为 42 个；聊天从 15 个变为 17 个。少量叶子监听器增加了固定节点数量，换来换绑时不再销毁和创建整棵子树。测试要求根绘制对象和文本绘制对象全部保留，同时核对最后显示的真实数据 ID 和文案。

单组主机 `pump` 墙钟数据如下，单位 ms：

| 场景 | 旧 P50 / P95 | 新 P50 / P95 |
| --- | ---: | ---: |
| 复选行 | 7.964 / 13.038 | 3.111 / 5.196 |
| 发出消息 | 4.818 / 7.326 | 3.148 / 5.218 |
| 收到消息 | 4.771 / 6.110 | 1.845 / 3.140 |

这组结果确认无谓挂载工作被消除。耗时包含 Debug、测试框架和主机调度，不能换算成手机帧率，也不能作为真机已达到 1ms 的证据；新数据仍需要文字排版，不能把动态内容绑定与重复文档的静态结构平移当成完全相同的负载。

## 真实视口连续滚动

另一组测试直接滚动两个完整页面，共 64 个输入帧，按共同 holder 集合记录实际跨 ID 重绑定。合法新增 holder 单独计数，不把其首次创建误当作复用失败。

| 页面 | 跨 ID 绑定 | 观察到的 holder 数量 | 已复用子树新建 / 移除 Element | 固定框架 Widget 更新 |
| --- | ---: | ---: | ---: | ---: |
| 万条复选 | 64 | 9 | 0 / 0 | 0 |
| 变高聊天 | 38 | 8 | 0 / 0 | 0 |

这些断言覆盖卡片 Element/RenderObject、Row、布局构件与 Checkbox State，另外验证最新 ID 的点击回调、旧记录勾选保留、不同选中值换绑的局部动画重置，以及主题和宽度变化。

## 页面与容器对比

- 两页移除正文顶部的大工具卡，计数与图标下拉操作放入导航头；390×844 测试视口中，复选滚动区域大于 740，聊天大于 650。
- 下拉菜单可切换真实 `ListView.builder` / `RecyclerView`，共用同一批记录和行组件，选择状态、消息和输入保留。
- 两种容器都按需挂载、逐项隔离重绘，官方列表关闭 keepAlive。切换后复选从首项、聊天从最新位置开始比较。
- 复选的首末定位、序号弹窗、清空均通过菜单操作验证；聊天发送、历史插入、底部跟随和阅读旧消息时的新消息保持均覆盖。
- 官方聊天列表还单独检测历史插入与新消息追加后的可见文本锚点，测试误差小于 0.1px。

## 运行与原始数据

```powershell
cd example
flutter test test/recycler_long_examples_test.dart test/recycler_row_reuse_test.dart test/recycler_row_performance_test.dart --no-pub --concurrency=1 --timeout 90s
```

三份测试分别提供页面行为、实际视口内部复用、真实 Adapter 行绑定对照；输出包含 `RECYCLER_REAL_ROW_PERF` 与实际滚动工作量 JSON，不使用依赖机器速度的毫秒通过门槛。

本机被 Git 忽略的 `.codex-run/recycler-real-rows-20261106/` 保存旧页面快照、基线测试、`before.log`、`after.log`、`comparison.json` 和文档/路由回归日志。完整页面复用与菜单测试日志另在 `.codex-run/recycler-headless-20261106/real-row-reuse.log`、`real-rows-ui.log`。

本轮没有重新测手机呈现间隔，不能仅凭子树复用修复就认定全部掉帧已经消失。真机目标约 1ms 的进展应由下一轮相同手势的 Profile 耗时及实际呈现节奏共同确认。

## 复杂卡片与安卓滚动条

新增「复杂卡片面板」，包含一万条独立的生态观察记录、两种离线照片、渐变图注、标签、统计、进度、调查员、阴影、按压缩放和激活状态。两种列表共用真实卡片组件和业务数据；每项独立隔离重绘。卡片按照片模板分两种 viewType，标题、地点、描述、编号等仍随不同记录重新绑定，没有将重复内容伪装成动态数据。

菜单中的「更新可见卡片数据」只修改访问次数、进度和更新时间，对应三个可监听字段；图片、固定图标、标签与排版不会收到数据通知。激活状态另外通知外观与选中标记，固定内容作为 `ValueListenableBuilder.child` 保留。主题、字体大小与宽度改变仍允许必要的环境更新。

AndroidX 的 payload 也由 Adapter 显式解释：开发者可以只调用某个 TextView 的 setText，系统不会自动推导哪些子 View 要更新；默认 payload bind 仍回退完整绑定，且离屏 payload 可能丢失。[AndroidX 官方源码](https://android.googlesource.com/platform/frameworks/support/+/androidx-main/recyclerview/recyclerview/src/main/java/androidx/recyclerview/widget/RecyclerView.java)。Flutter 的对应方法是缩小监听范围并保留固定 Widget 实例，无需修改引擎；相同 child 实例会截断后续 Widget 更新遍历。[Flutter 官方性能说明](https://docs.flutter.dev/perf/best-practices#control-build-cost)

`RepaintBoundary` 仅隔离绘制，不能阻止 build 或 layout。文字内容变长、实际约束变化时，必要排版成本仍会发生；结构复用也不等于零构建，测试必须直接观察真实 build 和固定 Widget 身份。

复选、聊天、卡片以及文档四种模式现在均显示 iOS 风格滚动条，在 Android 上按住滑块约 100ms 后拖动。滚动条连接列表的真实 ScrollPosition，关闭平台自动滚动条避免重复；聊天仅消息区域可拖，输入栏独立。

当前 SDK 的内容拖动和 Cupertino 滑块拖动都调用 ScrollPosition.drag/update。差别包括手势入口、滑块轨道到内容位移的映射、鼠标与触摸重采样、松手后的速度处理；Windows 滑块结束使用零速度，而移动端允许继续惯性。因此「Windows 滑块顺滑、Android 触摸抖动」还不能定位到某一项原因。新增 Android 滑块有助于在同设备上比较输入路径，本次没有采集新的手机呈现数据。

新增测试的实际输出如下：

| 检查 | 结果 |
| --- | --- |
| 刷新统计：33 个固定文字、图片、图标、布局节点的实际 build 次数 | 0 |
| 刷新统计：观察次数文本的实际 build 次数 | 1 |
| 切换激活：上述固定节点的实际 build 次数 | 0 |
| 照片类型 0 / 1，各 32 次真实跨 ID 绑定 | 每类 33 个不同 ID，新增 / 移除 Element 均 0，固定节点 build 均 0 |
| 每棵真实卡片树初始 Element 数量 | 195 |
| 主机绑定 pump 墙钟 P50 / P95，照片类型 0 | 5.765 / 9.281 ms |
| 主机绑定 pump 墙钟 P50 / P95，照片类型 1 | 4.749 / 8.790 ms |

墙钟数值只记录一次 Debug 测试运行的现场，不设依赖机器速度的通过门槛，也不代表 Android 帧耗时。测试另外覆盖实际按下/松开缩放、两种列表激活与数据保留、真正跨 holder 回收后的点击对象、反复切换后模型释放、暗色主题和 320 宽下两倍字号，以及三类独立列表和文档四模式的真实滑块触摸拖动。

本次相关子集共 81 项通过：核心 29、卡片 9、滚动条 11、原长列表示例 10、真实行复用 6、文档 15、路由 1。静态分析无诊断。可分别在根目录运行核心测试，在 `example` 中运行相关示例测试：

```powershell
flutter test test/flutter/views/recycler_view/recycler_view_test.dart --no-pub --concurrency=1 --timeout 90s
# 以下在 example 目录执行
flutter test test/recycler_cards_test.dart test/recycler_scrollbar_test.dart test/recycler_long_examples_test.dart test/recycler_row_reuse_test.dart test/recycler_doc_page_test.dart test/deep_link_test.dart --no-pub --concurrency=1 --timeout 90s
```
