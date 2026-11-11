# 测试分析：复用保留了什么，重建还剩什么

本阶段只补测试和分析，等待用户确定下一步优化目标，没有继续修改生产实现。测量对象是采样时的工作树，包含此前已完成的实现修改；历史初始结果保留在 [BASELINE.md](BASELINE.md)，不能把其中旧实现的行为当成当前结论。

**结论：ElView 能利用 recycler 保留节点的优势，但能省下多少重建，取决于业务绑定方式。ElListenableBuilder 可以在特定等值通知场景做到自身和子树都不重建；“套一层就能让整个列表完全不重建”不成立。**

## 本次验证

- 列表对比：32 项计时测试，156 组、1,872 个样本；每组 12 次操作，模式顺序相反的两轮，累计工作量全部一致。
- 正确性：5 项独立离屏更新测试，确保第 499 项更新后进入视口时确实可命中且显示最新内容；验证不影响计时场景的原始预热轨迹。
- 实际页面：9 项业务测试，80 组、640 个样本，详情见 [BUSINESS_SUPPLEMENT.md](BUSINESS_SUPPLEMENT.md)。入口共 18 个场景，本轮只运行这 9 项。
- 现有待提交布局修改：2 项停放子树回归通过，覆盖列表与 masonry 的离屏布局、再次换绑、恢复尺寸依赖与销毁。

本次共 48 项通过。列表原始数据及源码指纹见 [sliver-select-supplemental-2026-11-12.jsonl](sliver-select-supplemental-2026-11-12.jsonl)。采样时 HEAD 为 `0738735`，工作树中此前的两个回收布局文件仍有未提交修改；数据首行明确记录此限制，不能用 HEAD 单独代表整个测试版本。并行会话之后的文件变化不属于这次采样。

SHA256 只能核对文件，不能还原源码；为保留复现依据，另归档了[测量时的布局差异](tested-recycler-layout-2026-11-12.patch)（零上下文补丁，复现时需要 `git apply --unidiff-zero`）。本阶段没有将这些差异提交进生产文件。采样后媒体三个文件又有并行修改，相册结论明确限定于归档版本。

## 同数据通知：条目内的筛选

同一个 CustomScrollView、500 条记录、相同视口和缓存，自然高度，9 个已绑定条目。下面是一轮 12 次真正通知的累计，数据保持等值：

| 条目接法 | 全局 Element 重建 | 卡片 builder | ElView 配置更新 | ElView 布局 |
| --- | ---: | ---: | ---: | ---: |
| recycler + 整卡 ValueListenableBuilder | 216 | 108 | 324 | 0 |
| recycler + 整卡 ElListenableBuilder.select | 0 | 0 | 0 | 0 |
| recycler + 固定卡片、标题局部 select | 0 | 0 | 0 | 0 |
| recycler + 固定 ElView、文字通知直达 | 0 | 0 | 0 | 0 |

默认 select 的等值拦截现在确实能跳过自身 Element 构建；但仍有 108 次绑定通知和 108 次 select 求值。文字直达也仍有 108 次绑定通知。**零重建不等于零 CPU 工作。**

这要求选中的展示值相等、节点没有被其他配置或继承环境变化标脏。若本次通知的文字实际改变，布局仍必须更新；测试检查了最新内容，不能通过保留旧内容获得“零布局”。此前 ElView 文本环境、同帧往返通知和自定义谓词的测量见 [CORE_OPTIMIZATION.md](CORE_OPTIMIZATION.md)。

## 整张列表外包一层：默认与自定义比较不同

内部全部使用同一文字直达方案，只改变外层监听方式。一轮 12 次操作：

| 外层接法 / 数据 | 监听器自身构建 | 容器 builder | 官方全局重建 | recycler 全局重建 |
| --- | ---: | ---: | ---: | ---: |
| 普通监听 / 同 List 通知 | 12 | 12 | 300 | 876 |
| 默认 select / 同 List 通知 | 0 | 0 | 0 | 0 |
| 默认 select / 内容相同的新 List | 12 | 12 | 300 | 876 |
| 自定义 ListEquality / 同 List 通知 | 12 | 0 | 12 | 12 |
| 自定义 ListEquality / 内容相同的新 List | 12 | 0 | 12 | 12 |

默认 List 使用身份相等：新建 List 不会自动逐项比较。当前默认 select 对同一 List 可以在通知入口拦截，但不能以此支持“原地改 List 后仍只按身份判断”的用法。测试的真实数据变更使用新 List。

自定义 `shouldRebuild` 保留 build 阶段的判断语义，因此等值新 List 能避免整个容器和条目子树更新，外层 Element 仍构建 12 次。逐项比较 500 条记录也有成本；不能把 `ListEquality` 当作任意规模数据的免费去重。

两种容器都能受益于外层筛选。这里 recycler 的 876 次反映了**父配置每次刷新的接法**，不代表稳定配置下 recycler 滚动必然比官方更慢；它恰好说明应该把父配置刷新与滚动换绑分开测量。

## 相同展示文字的滚动仍有容器工作

recycler + select 向前滚动一轮 12 步、换绑 14 次时：

- 卡片 builder、select Element 构建、ElView 配置更新、ElView 布局均为 0。
- 仍有 14 次绑定通知/筛选，以及容器包装产生的 84 次全局 Element 重建。

因此可以描述为“换绑时业务内容不重建”，不能描述为“整个列表滚动完全不重建”。不同业务记录也可能显示相同文字；这个合成基准验证文字和节点工作，不代替回调目标、选择状态、预览覆盖层等业务身份正确性测试。

## 实际页面的下一步观测点

商品页一轮 8 次滚动虽然新增节点为 0，仍有 696 次配置变化、392 次已有 Element 重建。相册则在槽位内使用随记录变化的预览 Key，11 次换绑产生 396 个新节点；槽位保留与内部子树保留是两个不同结果。详情和类型证据见业务补充报告。

这些是候选问题及测量依据，还没有设定下一步必须达到的数值，也没有据此继续调整 API 或业务结构。后续目标可以分别约束业务 builder、监听器自身构建、ElView 配置更新、布局和通知量，而不是只要求“少创建”。

## 复现与限制

```powershell
$taskProcess = [Diagnostics.Process]::GetCurrentProcess()
$taskProcess.PriorityClass = 'BelowNormal'
flutter test test/benchmarks/view_reuse/sliver_benchmark_test.dart --no-pub --concurrency=1 --timeout 30s --reporter expanded --dart-define=VIEW_REUSE_TIMING=true --dart-define=VIEW_REUSE_SAMPLES=12
```

默认不传计时开关时是单轮短样本。ElView 创建/普通重建和单独监听器矩阵仍由同目录另外两个测试文件覆盖，本轮没有重复运行已经验证的全部微基准。

本报告优先使用确定性工作量。时间是带探针的 Windows 无头 debug 动作加 pump，不是真机帧时间；两轮短采样不能排除 JIT、GC 和系统调度影响。没有测设备 GPU、长期内存或长时间垃圾回收，也没有设置时间通过阈值。
