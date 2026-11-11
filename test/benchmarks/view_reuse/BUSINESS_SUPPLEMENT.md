# 真实页面补充测量

本阶段只补测试与分析，后续优化目标等待用户确定。测试直接挂载 example 的现有页面，通过原有菜单切换模式，不替换业务行。测试入口现有 18 个场景；本次只运行新增的网格、媒体、商品与局部更新相关 9 项，全部通过，共 80 组、640 个样本，两轮所有累计工作计数一致。

原始数据：[business-supplemental-2026-11-12.jsonl](business-supplemental-2026-11-12.jsonl)。测试时 HEAD 为 `0738735`，工作树还包含此前尚未提交的回收池布局边界修改，不能仅 checkout 该提交就声称复现了相同实现。数据首行记录 26 个相关文件的 SHA256，运行前后指纹一致。相册已包含该提交的图片预览功能，不能把它与早期无预览版本的差异全部归因于复用策略。

采样后并行会话又修改了 media.dart、media_cards.dart、media_preview.dart，本文不评价这些后续修改。SHA256 不能还原源码，测量时的未提交布局差异另存为[补丁快照](tested-recycler-layout-2026-11-12.patch)，供复现核对使用；生产文件本轮保持原状。

## 范围与方法

- 无头 flutter_tester debug，Android 样式，390×800、DPR 1；单进程、BelowNormal 优先级，每项超时 30 秒。
- 每个模式重新创建页面，先滚动 6 步，再向前 8 步、向后 8 步，两轮交换模式顺序。通常每步 192px；5 列相册使用 48px。
- grid、masonry、商品各用完整 1,000 条记录；默认媒体瀑布流、聊天与选择页各 10,000 条；本地媒体用独立临时目录中的 96 个真实 PNG 文件。
- 本地文件来自三张小型生成图片，比例不同；不访问用户目录、不联网、不启动视频播放。图片 provider 在计时外预热，采样前验证已显示真实图像。
- streamContent 只计不插入消息的正文步骤；selectionToggle 直接操作页面真实复选模型，并验证选择数量变化。结构性消息步骤与流重置在计时外。
- 所有滚动样本检查实际移动，所有业务更新检查内容变化。身份快照和断言不计时，构建探针在计时内。

创建页面、目录 IO、图片预热及模式切换不在本次业务滚动计时内。ElView 首次创建与普通重建另见 [BASELINE.md](BASELINE.md) 和 [CORE_OPTIMIZATION.md](CORE_OPTIMIZATION.md)。

## 向前滚动的工作量

以下是一轮 8 次滚动的累计。新节点指 Element 快照新增，配置变化指保留的 Element 接收不同 Widget 实例；两者不能相加当作 rebuild 调用数。

| 页面 | 官方新节点 | recycler 新节点 | recycler 配置变化 | recycler 已有 Element 重建 |
| --- | ---: | ---: | ---: | ---: |
| liveChat | 264 | 30 | 200 | 160 |
| selection | 646 | 0 | 251 | 197 |
| grid | 372 | 0 | 286 | 202 |
| masonry | 372 | 0 | 228 | 160 |
| mediaVideo | 770 | 0 | 318 | 252 |
| mediaAlbum | 462 | 396 | 466 | 459 |
| mediaWaterfall | 590 | 66 | 249 | 223 |
| mediaLocalWaterfall | 560 | 0 | 244 | 210 |
| productWaterfall | 592 | 0 | 696 | 392 |

这些结果再次说明：**保留槽位不等于整个业务树没有重建。** 商品页没有新增 Element，但已有节点仍发生 696 次配置变化、392 次重建。相册还存在业务子树替换，不能因为使用 recycler 就称为零创建。

相册新增的 396 个节点对应 11 次换绑、每次 36 个 Element：`0738735` 在固定相册内容外包装了 `ElImagePreview.provider(key: ValueKey(entry.key))`，业务 Key 改变会连同内部图片内容重新挂载。类型明细中没有新增外层 `_MediaTile` 或回收边界，槽位本身仍被保留。这个 Key 参与预览状态的记录隔离；是否调整要同时验证已打开预览的换绑行为，当前仅记录现象，不直接删除 Key。

官方行进入窗口时的首次构建单独记录在 `global_first_build`，不是零工作。网格官方分支还存在已有节点更新；各模式的类型明细均保留在 JSONL，不能只用“已有 Element 重建”比较双方全部成本。

## 局部业务更新

每行是一轮 8 次更新，不是滚动样本：

| 操作 | 模式 | 新 Element | 配置变化 | 全局已有 Element 重建 |
| --- | --- | ---: | ---: | ---: |
| 纯流式正文 | SliverList | 0 | 16 | 720 |
| 纯流式正文 | recycler | 0 | 34 | 732 |
| 选择切换 | SliverList | 0 | 128 | 88 |
| 选择切换 | recycler | 0 | 128 | 88 |

数据改变时仍需要正文渲染、交互反馈和相关叶子工作；零创建不能当成零重建。选择更新两种容器的工作量一致，说明这部分主要取决于业务订阅范围。这里的全局构建范围比滚动宿主身份快照更大，两个数不能混作同一统计口径。

## 短计时

向前滚动每次动作的中位数，单位 µs，保留第 0 / 第 1 轮：

| 页面 | 官方 | recycler |
| --- | ---: | ---: |
| liveChat | 8749 / 4734 | 5994 / 3287 |
| selection | 10178 / 9050 | 5550 / 5587 |
| grid | 10188 / 9794 | 4250 / 3927 |
| masonry | 8033 / 7553 | 5603 / 3584 |
| mediaVideo | 12955 / 10769 | 4478 / 6680 |
| mediaAlbum | 7062 / 9292 | 10143 / 8797 |
| mediaWaterfall | 8036 / 9396 | 3876 / 3117 |
| mediaLocalWaterfall | 10910 / 10912 | 4169 / 3489 |
| productWaterfall | 7585 / 5990 | 9334 / 6407 |

不能得出“所有 recycler 页面更快”：相册两轮相对顺序不同，商品在这次运行中两轮都没有更低的中位数。时间是带探针的 debug 动作加 pump 墙钟，不是真机帧时间；此处中位数取 8 个样本排序后的第 4 项，p95 等于最大值，不设置时间通过阈值。

## 必须保留的比较边界

- grid/masonry 官方是固定高度 SliverGrid，recycler 使用自然行高/瀑布流；不能称作等几何的纯内核比较。
- 本地瀑布流的官方封面采用未知尺寸的默认比例 1，并预留固定 footer；recycler 使用解码比例和自然文案高度，两者可见内容与几何不同。
- 官方媒体瀑布流使用业务自定义 delegate，布局包含完整几何计算，时间不代表官方 SliverGrid 的固有开销。
- 商品官方 cache 为 0，recycler 使用默认缓存；本次从未触发 450ms 图片尺寸揭示，逐帧要求“已揭晓 0 张”。
- 身份快照包括滚动宿主的缓存和池化后代，不是所有临时对象分配或完整生命周期计数。ElView 布局探针不统计原生 RenderObject 的全部布局。
- 未测图片冷解码、大图缓存压力、设备 GPU、长期 GC、内存峰值或真实视频解码。本轮也没有新增 rich_document、spike 和 nest_scroll 的性能结果。

## 复现

在 `example/` 下运行这次的定向短计时：

```powershell
$taskProcess = [Diagnostics.Process]::GetCurrentProcess()
$taskProcess.PriorityClass = 'BelowNormal'
flutter test test/sliver_business_performance_test.dart --no-pub --concurrency=1 --timeout 30s --reporter expanded --dart-define=BUSINESS_PERF=true --name '业务页面基准 (grid|masonry|media|productWaterfall|liveChat|selection)'
```

可通过 `--plain-name` 限定单场景，或 `--dart-define=BUSINESS_PERF_MODE=official` / `recycler` 限定模式。省略 `BUSINESS_PERF` 则使用一轮、每阶段 3 个短样本；扩大样本前应重新评估机器占用。
