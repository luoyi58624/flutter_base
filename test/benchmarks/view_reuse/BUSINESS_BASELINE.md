# 2026-11-12 实际页面补充基线

本轮仍只写测试和分析，未修改组件或示例实现，优化目标等待用户确定。生产源码保持 `c80a00e` 状态（该提交只添加了上一轮测试与报告）。

测试直接挂载 example 中的 11 个真实页面负载，通过原有菜单回调切换官方 SliverList / ElSliverRecyclerList。使用每页完整的一万条数据，不替换业务行。短样本和计时模式各 11 项通过，定向静态分析通过；计时取得 96 组结果、768 个样本，原始数据见 [business-baseline-2026-11-12.jsonl](business-baseline-2026-11-12.jsonl)。

## 方法与比较边界

- Windows 无头 Flutter 3.47.5 / Dart 3.13.4 debug，Android 平台样式，390×800、像素比 1。单进程、BelowNormal 优先级，每项测试超时 30 秒。
- 每个模式重新创建页面；先滚动 6 步热身，再向前 8 步、向后 8 步，每步 192 像素。两轮使用相反模式顺序。cards、orders 另外执行 8 次实际数据更新。每个样本检查滚动方向或更新结果。
- 图片预加载对应的真实本地素材，外卖关闭网络图片。图片预加载、身份快照和断言都在计时外；debug 构建探针仍在计时内，快照分配也可能影响后续 GC。
- 时间是动作加一次 pump 的墙钟，**不是设备帧耗时**。pump 的 16 ms 是模拟时间推进，不能解释为达到 60 FPS。当前 8 个样本的 p95 按取整算法就是最大值，不设耗时通过阈值。
- 身份快照只覆盖主滚动宿主，包含缓存区和回收池；新建/移出表示相邻快照的差异，不是完整生命周期或临时分配计数。配置变化表示保留的 Element 收到了不同 Widget 实例，不等同于准确的 update 调用数。
- 构建回调和 ElView 内核探针统计整页工作；其中 ElView 布局不包含原生 RenderObject 布局。两个统计范围不能相加作为总成本。
- 同一页面的两模式使用相同页面尺寸、方向与缓存策略；不同页面的工具栏高度不同，实际内容视口为 570–744 像素，不能横向比较页面排名。外卖两模式共用 ElScroll，其他页面共用 CustomScrollView。
- cards、selection 等模式的业务包装也有差异，因此是实际页面方案比较，不能把全部差异归因于列表内核。liveChat 本轮仅测滚动，没有启动消息定时流。

## 向前滚动的实际工作

下表为一轮 **8 次滚动的累计**。两轮所有阶段的确定性工作总数均一致。`新节点` 为 Element 快照新增数；`配置变化` 只计保留节点；两列分别表示不同工作，不能只看其中一列。

| 页面 | 官方新节点 | recycler 新节点 | recycler 配置变化 | 官方已有 Element 重建 | recycler 已有 Element 重建 |
| --- | ---: | ---: | ---: | ---: | ---: |
| cards | 600 | 0 | 132 | 0 | 108 |
| orders | 648 | 612 | 108 | 0 | 84 |
| socialFeed | 874 | 249 | 768 | 0 | 453 |
| chat | 242 | 0 | 215 | 0 | 172 |
| liveChat | 264 | 30 | 200 | 0 | 160 |
| selection | 646 | 0 | 251 | 0 | 197 |
| rectangles | 288 | 0 | 480 | 0 | 336 |
| text | 539 | 0 | 860 | 0 | 626 |
| videoCards | 439 | 5 | 462 | 0 | 186 |
| complex | 355 | 0 | 225 | 0 | 111 |
| takeaway | 2050 | 0 | 86 | 0 | 93 |

官方已有 Element 重建为零，并不表示官方不构建：这里进入窗口的条目主要是首次构建，例如 cards 为 228 次、orders 为 264 次、takeaway 为 1020 次。它们分别计在 `global_first_build`，完整字段保留于 JSONL。

可以确认的现象：

1. **复用槽位不保证复用业务行。** orders 的 recycler 仍新增 12 个 `_OrderRow`、12 个 ExamplePanel，产生 612 个新节点，与官方的 648 个接近。源码把 `ValueKey(record.id)` 用于默认回收适配器生成的行，换绑不同记录时业务 Key 变化，会替换子树。这是当前上层写法的具体观测点。
2. **保留业务行也不保证没有配置更新。** videoCards 新节点仅 5 个，但已有节点发生 462 次配置变化，包含 7 次 `_VideoCard`、7 次 ExamplePanel 和 14 次 ElView 配置变化。socialFeed 则同时存在新类型槽位增长与大量已有卡片更新，不能把全部 249 个新节点都称为复用失效。
3. **固定结构已经能减少 ElView 更新。** cards、chat、selection、complex、takeaway 本段 recycler 的 ElView 新建与配置变化都为零，但列表包装、局部文字和其他动态叶子仍有工作。不能描述成整个列表零重建。
4. 主示例的 `text` 使用原生 Text，不能拿该行数据推导 ElView 文本内核性能。ElView 普通配置更新与通知直达的区别由 [微基准](BASELINE.md) 单独测量。

## 同场景的短计时

以下为向前滚动阶段，单位 µs，每次动作的中位数，保留“第 0 轮 / 第 1 轮”。这是当前页面写法的结果，没有优化后的数据。

| 页面 | SliverList | ElSliverRecyclerList |
| --- | ---: | ---: |
| cards | 5118 / 2849 | 5035 / 3829 |
| orders | 9143 / 9161 | 9672 / 11279 |
| socialFeed | 11854 / 7417 | 8861 / 6835 |
| chat | 5745 / 4663 | 4322 / 4516 |
| liveChat | 6599 / 5161 | 4539 / 5100 |
| selection | 8441 / 6752 | 3887 / 4108 |
| rectangles | 2014 / 1770 | 2751 / 1931 |
| text | 4217 / 4342 | 4705 / 5623 |
| videoCards | 3917 / 4335 | 3925 / 5043 |
| complex | 4319 / 5041 | 2649 / 2263 |
| takeaway | 22475 / 20698 | 6391 / 6655 |

当前数据不支持“recycler 对所有页面更快”。固定复杂结构的收益在 complex、takeaway 较明显；轻量 Text/色块和整卡更新场景仍可能被通知、包装和重建成本抵消。两轮 cards 等场景有明显时间波动，应优先依据稳定的工作量解释，不能据此承诺设备加速倍数。

## 可见数据更新

一轮 8 次更新，两种模式的工作计数相同：

| 页面 | 已有 Element 重建 | 配置变化 | 新 Element / RenderObject | ElView 配置变化 |
| --- | ---: | ---: | ---: | ---: |
| cards | 128 | 160 | 0 / 0 | 0 |
| orders | 296 | 560 | 0 / 0 | 0 |

这里更新的是页面现有的访问量/进度等业务字段，数据确实改变。静止更新的成本由业务订阅范围决定，换用 recycler 本身不使这两组刷新更省。

## 后续目标所需的证据已分开

现有基准覆盖了 ElView 创建与重建、监听器相等筛选、合成列表的等值数据与换绑，以及本报告的真实页面滚动。微基准已经确认：ElListenableBuilder 可以挡住等值业务子树更新，但自身 Element 仍构建；文本直达可进一步避免 ElView 配置更新，但真正变字仍需布局。

这些是现状测量，不是已确定的优化方案或阈值。父配置与 Inherited 变化被错误缓存的语义缺口也仍单独保留在微基准报告中，不把旧内容不更新当作性能收益。本轮不改实现。

未覆盖网格/瀑布流、长期消息流、头部插删交互、设备 GPU、内存峰值、长期 GC 和图片冷解码。这份补充不能代表所有 example 页面或所有运行环境。

## 复现

在 `example/` 下执行：

```powershell
$taskProcess = [Diagnostics.Process]::GetCurrentProcess()
$taskProcess.PriorityClass = 'BelowNormal'
flutter test test/sliver_business_performance_test.dart --no-pub --concurrency=1 --timeout 30s --reporter expanded
```

需要短计时时增加 `--dart-define=BUSINESS_PERF=true`；默认两轮，每阶段 8 样本，可用 `BUSINESS_PERF_SAMPLES` 调整。日志中的 `BUSINESS_PERF_CONFIG` 和 `BUSINESS_PERF_RESULT` 为 JSON。提交数据保留类型累计与逐帧工作量、身份差异、原始微秒值，省略重复的逐帧类型字典。
