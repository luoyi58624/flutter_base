# 复用优化实施结果（2026-11-12）

本文保留第一批实施时的布局与数据；后续外卖视觉修正和其余场景优化见 [FOLLOWUP_RESULTS.md](FOLLOWUP_RESULTS.md)，当前外观及最新数据以该报告为准。

用户在测试分析后明确要求开始优化，并将外卖页改成参考图中的普通卡片布局。本轮重点是减少换绑时的重建，保留现有交互和环境更新；不再用自定义外卖 RenderObject 减少创建数。

## 已实施

- 外卖删除手动绘制、图片流及专用 RenderObject，改用 ElCard、Row、Column、固定高度商品槽位和 ElImage。店名、商品名及菜单文字单行省略；商品方图 104×104，商品宽 104、间隔 8，高度随字号统一增长。
- 外卖保留一万条数据、筛选、购物车、官方/回收列表与网格切换、网络图片开关。换店保留卡片和横向菜单 State，结束旧惯性并恢复当前店铺的菜单位置；本地图集仅改变普通 OverflowBox 的裁切对齐，保留 ElImage 实例。
- 商品瀑布流保留卡片结构，名称、价格、图片资源与几何分别筛选。图片高度变化不重新配置相同资源；点击和阅读锚点始终指向当前绑定商品。450ms 尺寸揭示行为保留。
- 媒体文案改用 ElListenableBuilder 精确筛选，相同来源文字不再重建监听器。官方瀑布流保留同一几何缓存，滚动不再每帧遍历一万条数据；宽度、字号、方向和数据集合变化正确失效。
- recycler 将索引语义的通知放在固定 child 外，只更新 IndexedSemantics，不再为纯换绑重新配置 TickerMode、HeroMode、Focus 和 ReuseAnimationScope。停放子树建立独立布局边界，重新激活时恢复父尺寸依赖。
- 修复平滑滚轮尚未结束时卸载页面的异常：通知宿主已解除后不再发送滚动结束通知，活动由 ScrollPosition 的正常销毁流程释放。

本轮沿用已完成的 ElView 文本环境、ElListenableBuilder 默认等值去重优化，不增加公开 API，也不把主题、字号或真实数据变化当作可跳过的更新。

## 相同数据能否完全避免重建

合成基准与此前 [分层分析](ANALYSIS.md) 使用同一测试入口，500 条记录、12 次采样、正反执行顺序各一轮。以下列出第 0 轮，第二轮同场景的工作次数一致。

| 场景 | 之前 Element 重建 | 现在 Element 重建 | 现在业务 builder / ElView 配置更新 |
| --- | ---: | ---: | ---: |
| 普通 recycler，12 次等值通知 | 216 | 216 | 108 / 324 |
| recycler + select，12 次等值通知 | 0 | 0 | 0 / 0 |
| 固定卡片 + 局部 select，12 次等值通知 | 0 | 0 | 0 / 0 |
| recycler + select，相同文案向前滚动、14 次换绑 | 84 | 14 | 0 / 0 |
| 固定卡片 + 局部 select，相同文案向前滚动、14 次换绑 | 84 | 14 | 0 / 0 |
| ElView 直达文字，相同文案向前滚动、14 次换绑 | 84 | 14 | 0 / 0 |

**等值通知可以零重建；索引改变时整个槽位并非零重建。** 剩余 14 次是索引语义监听器更新，确保辅助技术读到新索引。IndexedSemantics 的 RenderObject 配置更新也仍然存在，不能只凭业务 builder 为零说整帧没有工作。实际数据不同则必须更新相应文字、图片和布局。

固定父配置下的 Inherited 更新、父级刷新、默认 List 身份筛选与显式列表值比较仍按原测试语义执行。回收容器本身不会替业务消除普通 ValueListenableBuilder 的等值通知重建。

## 真实页面短基准

390×800、DPR=1、Android 样式，无头 flutter_tester。每页每模式热身 6 步，前后各采样 8 步，交换官方/回收执行顺序再跑一轮，即每行 32 次滚动样本。使用真实本地图片，计时前预热；外卖另外断言 RenderImage 已解码，避免测到空图片。

表中的时间是合并 32 个样本后的下中位数 / p95，单位毫秒；原始每轮数据均保留。创建与重建分列，官方列重建为零并不代表没有工作。

| 页面 | 容器 | 新增 Element | 新增 RenderObject | Element 重建 | 中位 / p95 ms |
| --- | --- | ---: | ---: | ---: | ---: |
| 外卖普通布局 | SliverList | 8540 | 3820 | 0 | 25.817 / 40.571 |
| 外卖普通布局 | ElSliverRecyclerList | 0 | 0 | 452 | 7.910 / 11.918 |
| 商品瀑布流 | SliverGrid | 2700 | 1200 | 0 | 9.509 / 14.908 |
| 商品瀑布流 | ElSliverRecyclerGrid | 0 | 0 | 604 | 6.055 / 10.447 |
| 媒体演示瀑布流 | SliverGrid | 2360 | 1240 | 0 | 9.858 / 16.944 |
| 媒体演示瀑布流 | ElSliverRecyclerGrid | 134 | 64 | 782 | 6.261 / 9.843 |

外卖 recycler 同组还有 432 次 Widget 配置变化，说明保留节点后仍在更新内容。媒体瀑布流会因自然高度和缓存窗口新增槽位，不能宣称所有业务滚动都零创建。

商品的本轮前后对照：

| 32 次滚动的累计工作 | 之前 | 现在 | 变化 |
| --- | ---: | ---: | --- |
| recycler Element 重建 | 1500 | 604 | 减少 59.7% |
| recycler Widget 配置变化 | 2652 | 560 | 减少 78.9% |
| recycler 新增 Element / RenderObject | 0 / 0 | 0 / 0 | 持续复用 |
| 官方新增 Element / RenderObject | 2220 / 1140 | 2700 / 1200 | 细粒度监听增加首次挂载成本 |

收益来自商品调用方和 recycler 包装共同变化，不能全部归给单个组件。官方商品模式保留 cache=0，recycler 使用默认缓存，因此这是实际页面对照，不是缓存条件完全相同的容器微基准。此组没有触发 450ms 尺寸揭示；揭示、远拖和返回锚点由独立行为测试验证。

外卖前后布局、节点组成和实际滚动视口高度均已改变（621→612），旧新时间不能作为纯优化倍数；应看同一新布局下的官方/recycler 对照。媒体本轮没有成功采集紧邻修改前的有效基准，不给出前后计时百分比；几何缓存与等值文案的收益由独立对象身份和重建计数测试验证。

## 验证

- recycler 既有列表、网格、自然高度、换绑过渡及停放布局共 54 项通过；新增状态包装、语义索引和继承更新 2 项通过。
- 平滑滚动及滚轮交接 32 项通过；外卖退出时仍有滚轮动画的真实回归用例通过。
- 外卖行为与布局 10 项、商品 8 项、媒体既有行为 11 项及新复用回归 3 项通过。
- 列表合成基准及离屏语义检查 37 项通过，156 组 / 1872 样本；本轮业务基准 3 项通过，24 组 / 192 样本。
- 16 个改动 Dart 文件格式检查和定向静态分析通过。
- 无头截图检查了真实中文字体和本地 ElImage；320/390 宽度、1.6 倍字号、暗色、单行省略、商品等高和加购语义有布局测试覆盖。

仅运行相关模块测试，没有全仓测试、前台应用、热重载或附加用户应用。本报告的 debug 动作加 pump 墙钟包含探针、JIT、GC 与调度噪声，不是真机 profile/release 帧时间，也不据此承诺帧率。

## 原始记录与复现

- [业务实施前记录](business-implementation-before-2026-11-12.jsonl)：16 组 / 128 样本。原始日志已归档，但这一轮未同步捕获源文件指纹，不能用最终源码哈希替代其来源。
- [业务实施后记录](business-implementation-after-2026-11-12.jsonl)：24 组 / 192 样本，包含最终源码哈希、工作次数、累计类型分布及逐帧时间/身份差异。
- [列表实施后记录](sliver-implementation-after-2026-11-12.jsonl)：156 组 / 1872 样本，包含最终源码哈希、累计工作次数和原始时间。之前版本见 [列表补充记录](sliver-select-supplemental-2026-11-12.jsonl)。

在根目录执行短合成测试：

```powershell
$taskProcess = [Diagnostics.Process]::GetCurrentProcess()
$taskProcess.PriorityClass = 'BelowNormal'
flutter test test/benchmarks/view_reuse/sliver_benchmark_test.dart --no-pub --concurrency=1 --timeout 30s --reporter expanded --dart-define=VIEW_REUSE_TIMING=true --dart-define=VIEW_REUSE_SAMPLES=12
```

在 example 目录执行三个相关业务场景：

```powershell
$taskProcess = [Diagnostics.Process]::GetCurrentProcess()
$taskProcess.PriorityClass = 'BelowNormal'
flutter test test/sliver_business_performance_test.dart --no-pub --concurrency=1 --timeout 30s --reporter expanded --dart-define=BUSINESS_PERF=true --name '业务页面基准 (takeaway|productWaterfall|mediaWaterfall)'
```
