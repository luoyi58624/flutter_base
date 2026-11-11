# ElView 与回收列表的重建基准

本目录只提供测试与分析，不修改组件实现。重点区分创建、配置更新、业务 builder、自身 Element 重建和真实布局；不能仅凭 RenderObject 保留或 builder 没执行，就认为整个更新过程没有工作。

当前结果见 [BASELINE.md](BASELINE.md)，完整采样摘要见 [baseline-2026-11-12.jsonl](baseline-2026-11-12.jsonl)。JSONL 包含生产版本、源文件 SHA256、每轮原始微秒样本和累计工作量，缺失的计数字段按零理解。

## 运行

在仓库根目录执行，默认只跑短样本正确性与工作量检查：

```powershell
flutter test test/benchmarks/view_reuse --no-pub --concurrency=1 --timeout 30s --reporter expanded
```

开启计时后，每个场景热身 2 次、采样 12 次、正反顺序各一轮；向前滚动热身 8 次，让缓存窗口先离开列表起点：

```powershell
$taskProcess = [Diagnostics.Process]::GetCurrentProcess()
$taskProcess.PriorityClass = 'BelowNormal'
flutter test test/benchmarks/view_reuse --no-pub --concurrency=1 --timeout 30s --reporter expanded --dart-define=VIEW_REUSE_TIMING=true --dart-define=VIEW_REUSE_SAMPLES=12
```

可以仅指定一个测试文件，或通过 `--plain-name` 选中单个场景。不要用全量仓库测试代替本目录基准，也不要为验证而启动前台应用。`VIEW_REUSE_SAMPLES` 必须大于零；扩大样本前先考虑机器占用。

输出中的 `VIEW_REUSE_RESULT ` 后面是 JSON；`VIEW_REUSE_OBSERVATION ` 单独报告行为观察。日志重定向到 `.codex/` 可以保留每个样本的完整工作量，后续提取前缀行即可进行同场景对照。当前提交的 JSONL 保留原始时间和累计工作量，不重复存储日志中的每样本工作字典。

## 测试矩阵

| 文件 | 负载与对照 | 变化方式 |
| --- | --- | --- |
| `view_benchmark_test.dart` | 24 个节点，ElView 对应原生 SizedBox、ColoredBox、RichText、DecoratedBox、Padding 和 GestureDetector 组合 | 空盒、纯色、文字、带圆角/内边距/点击的文字；卸载再创建、相同参数新 Widget、等值新样式与字符串、文字变化、背景变化、稳定 Widget child、通知直达文字 |
| `listenable_benchmark_test.dart` | 24 个叶子，ValueListenableBuilder、ElListenableBuilder 无 select、标量、record、新 List 身份比较、List 自定义值比较 | 等值通知、选中字段变化、无关字段变化、同帧往返通知；稳定 child 与重建静态内容对照 |
| `sliver_benchmark_test.dart` | 同一个 CustomScrollView，500 条记录，自然高度，360×360 视口、144 像素缓存 | 等值通知、等值新列表、离屏记录变化、可见记录变化、前后滚动；所有记录文字相同与记录不同两种数据 |
| 同上，`sliver_parent` 组 | 列表外的普通监听器与带值比较的 ElListenableBuilder；内部统一用文本直达 | 同一列表通知、等值新列表、可见记录变化，分开测父配置刷新成本 |

列表内部五种接法：

| 名称 | 实际接法 |
| --- | --- |
| `sliverList` | SliverList，条目内 ValueListenableBuilder 重建卡片 |
| `recycler` | ElSliverRecyclerList，条目内同样用 ValueListenableBuilder 重建卡片 |
| `recyclerSelect` | recycler，ElListenableBuilder 按当前文字筛选整卡更新 |
| `recyclerLocalSelect` | recycler，固定卡片，只让标题的 ElListenableBuilder 按当前文字筛选 |
| `recyclerDirect` | recycler，固定卡片，把稳定的 ValueListenable<String> 直接传给 ElView.child |

`sliver_parent` 中的 `sliverList` 也使用直达文字，避免把条目接法差异算到外层监听器头上。父刷新时保持标题 Key 和可复用通知源稳定；同一来源不会为了计数而重建绑定器。SliverList 中重新产生的固定索引来源按正常生命周期转接。

外层 select 对 500 个字符串做 ListEquality；同一列表可以快速返回，等值新列表要逐项比较。这是有成本的策略，不表示任意大数据集合都适合深比较。不同业务索引可以有相同展示文字，本组按展示值比较，不按索引身份比较。

## 计数口径

| 指标 | 含义 |
| --- | --- |
| `view_widget_create / view_mount / view_unmount` | 测试包装的 ElView 配置创建和 Element 生命周期 |
| `view_element_update / view_render_update / view_perform_rebuild` | 实际执行的 ElView 配置更新与显式重建入口；这些是不同方法，不能相加当作总重建次数 |
| `text_environment_update / text_environment_build` | 文本环境子配置推送、文本环境 Element 真正构建 |
| `element_first_build / element_rebuild` | Flutter rebuild 回调，包含测试壳和列表包装器，不包括绕过 rebuild 的全部 RenderObjectElement.update |
| `selector_element_build / value_element_build` | ElListenableBuilder / ValueListenableBuilder 自身 Element 构建，含首次构建；热身后一般只剩重建 |
| `business_builder / item_builder / card_build` | 各组明确记录的业务回调，不代替整个子树的统计 |
| `view_layout / cascade / style_resolve` | 现有 ElView 内核探针，**不包含原生 RenderObject 的布局/级联**；原生行的零不能解释为原生没有布局 |
| `item_factory / slot_mount / slot_dispose / rebind` | 工厂调用、实际宿主 State 生命周期、索引实际变化 |
| `native_*` | 明确包装的原生 RenderObjectWidget 节点；GestureDetector 内部 RenderObject 不计入此项，但其 Element 工作进入全局回调 |

测试使用真正发通知的 ChangeNotifier，即使值相等也通知，避免 ValueNotifier 赋值时提前去重遮住待测行为。`roundTrip` 在同一 pump 前发送两次通知，检查最终值回原值时的合并效果。

`debugOnRebuildDirtyWidget` 的 builtOnce 参数在当前 SDK 中仅随调试打印更新，因此探针用弱身份表自行区分首次构建和重建，没有打开逐条调试打印。所有观测都位于测试目录，不修改生产探针。

断言检查内容、对象身份、监听与卸载，以及等值筛选应保留的子树；不会把当前多余的 Element 重建次数写死为必须保留的行为。滚动窗口边界可以增加一个槽位，因此纯复用断言只检查没有新增槽位的样本，全部创建工作仍保留在报告中。

## 时间与行为边界

- 时间为带测试探针的 flutter_tester **debug 动作加 pump 墙钟**。通知、构造和测试壳更新都在计时内，断言与 JSON 输出在计时外。`recreate` 包含卸载与重新挂载两个 pump。
- 此处不是 profile/release 真机帧耗时，不包含设备 GPU 呈现，不报告 60/120 Hz 达标率，也不使用耗时阈值让测试通过或失败。
- 正反顺序只能帮助识别顺序差异，不能消除 JIT、GC 与系统调度。每轮只有 12 个样本，p95 接近最大值；先看确定性的工作次数，再看两轮时间是否一致。
- `view` 组的普通重建使用 pumpWidget；通知组使用 pump。二者动作范围不同，直接相除不是 ElView 内核的加速倍数。
- 本轮未测图片解码、网络、富文本混排、GPU、内存峰值或长期 GC；列表业务数据为内存字符串。
- 父配置和 Inherited 变化的语义观察独立报告 `semantic_gap`。它们不把当前旧内容当成正确结果，更不能作为性能收益。本轮只记录问题，等待明确目标后处理实现。
