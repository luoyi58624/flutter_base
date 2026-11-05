# 性能验收

日期：2026-11-06。初稿审计依据 `921ae77`，本轮实施基线为 `ac9ff5b`；本文已修正为实际验收口径。优化项见[结构复用优化方案](REUSE_OPTIMIZATION.md)。本轮新增测试的最终通过数量和性能数值由结果报告填写，本文件只定义测量方法，不预填结果。

结构与工作量断言适合作为确定性门禁，但必须正确限定预取、动画与消费节点；主机毫秒数只能作诊断，不能换算成手机帧耗时。系统设置中的帧耗时记录器已实现、待统一测试；真机“低 UI 耗时仍抖动”的结论还需要实际呈现节奏，不能仅凭 UI/raster 小于帧预算推断流畅。

## 1. 现有测试与记录的可信度

### 1.1 逐项评估

| 来源 | 测量对象 | 可信，可直接下结论 | 有偏或不可信 | 适合的用途 |
| --- | --- | --- | --- | --- |
| [performance_test.dart](../../../../../test/flutter/views/recycler_view/performance_test.dart) | 测试专用行，一万条、四种类型；关闭预取与位置缓存；`scrollBy` 每帧 88px | 稳定区间的构建、布局、绘制次数，包装变化次数，holder 数量，通知的类型查询数 | pump 墙钟；预取被关闭，没有验证预取；`初始 holder < 20`、`滚动后 holder < 40` 两个门槛过宽 | 门禁加诊断 |
| `optimization_test.dart`、`recycler_view_test.dart`、`tail_entry_test.dart`、`pool_test.dart`、`pointer_scroll_test.dart` | 生命周期、锚点、布局次数、回收、滚轮 | 全部是行为与次数断言 | — | 门禁 |
| [recycler_row_performance_test.dart](../../../../../example/test/recycler_row_performance_test.dart) | 单个真实 holder 连续换绑 120 次 | Element 增删数，根 RenderObject、RenderParagraph 保留数 | 墙钟；行脱离视口单独挂载，不含视口布局和预取 | 门禁加诊断 |
| [recycler_row_reuse_test.dart](../../../../../example/test/recycler_row_reuse_test.dart) | 真实页面 `scrollBy` 64 帧 | 跨 ID 绑定零增删，固定框架零更新 | 墙钟；`scrollBy` 绕过拖动、惯性和重采样 | 门禁 |
| [recycler_cards_test.dart](../../../../../example/test/recycler_cards_test.dart) | 固定节点构建次数、两种图片类型换绑 | 构建次数断言 | 图片在 `runAsync` 中预先解码，解码不在计时内；CPU 绘制记录不等于真机 GPU 光栅化成本 | 门禁 |
| [recycler_chat_entry_test.dart](../../../../../example/test/recycler_chat_entry_test.dart) | 状态构造、首个 pump、首屏绑定 | 首屏绑定次数和可见范围；State 构造的 Stopwatch 计时对纯 Dart 工作的前后比较大体可信 | 首个 pump 墙钟包含 JIT 冷启动 | 门禁加诊断 |
| [PERFORMANCE.md](PERFORMANCE.md)（首轮真机） | Profile `FrameTiming` | 指标类型正确 | 单轮、固定顺序；重复模板场景偏向结构复用；属于历史实现；帧间隔不是实际呈现时间 | 历史参考 |
| 性能浮层目测（如「4ms」「15ms」） | 浮层柱状图 | — | 不是分位数，峰值靠目测，无法复现；浮层本身也有开销 | 只用于发现问题 |
| [frame_timing_recorder_test.dart](../../../../../example/test/frame_timing_recorder_test.dart)、[frame_recording_page_test.dart](../../../../../example/test/frame_recording_page_test.dart) | 统计口径、窗口边界、延迟尾批、订阅与页面操作 | 逻辑和生命周期断言 | 测试喂入帧不是真机产帧，不能据此推断设备性能 | 本轮新增，待统一验证 |

### 1.2 无头计时的系统性偏差

1. **Debug JIT 与断言。** `flutter test` 在 JIT 调试模式下运行，断言开启。不同代码被放大的倍数不同，所以连「A 比 B 快多少」的比例也不能外推到 AOT。
2. **没有代表真机的 GPU 呈现。** 测试可记录绘制命令，部分测试也能离屏生成图像，但它们不能代表目标手机的 GPU 光栅化、缓存、图片上传与屏幕呈现节奏。复杂卡片必须另看真机 raster 与呈现证据。
3. **测试字体。** 测试默认使用测试字体，没有真实的中文字形整形和字体回退，文字密集的行会被低估。
4. **虚拟帧时间。** `pump(Duration)` 推进假时钟，与生产预取预算的真实时钟不同源。预算行为测试必须注入同源可控时钟；未注入的保守分支行为和主机耗时不能代表真机预取命中情况（见 S5）。
5. **输入路径。** `scrollBy` 直接改位置，不经过拖动手势、触摸重采样、惯性模拟和回弹。
6. **单次样本。** 前后版本在不同进程中各跑一次，没有交替、预热和多轮，主机负载会直接进入结果。
7. **测试框架开销。** 每次 pump 的框架成本与被测工作同量级时，差值会被稀释。

偏差方向并不一致：第 2、3 项让主机数字偏低，第 1、7 项让它偏高。所以主机毫秒数既不是真机的上限，也不是下限。

## 2. 分层验收

### L0：结构与工作量门禁

无头、确定、与机器速度无关，只断言次数和身份，不设毫秒门槛。所有性能相关的改动都必须通过。

| 编号 | 断言 | 期望值 | 现状 |
| --- | --- | --- | --- |
| L0-1 | 同类型换 ID 绑定 | 新增、移除 Element 为 0；根 RenderObject 和 RenderParagraph 全部保留 | 已有：复选、聊天、卡片两种类型 |
| L0-2 | 换绑与局部刷新 | 固定节点 build 为 0；按实际消费节点统计，一帧内每个受影响监听根最多重建一次，不相关节点为 0 | 一个字段可驱动百分比文本与进度条等多个消费者，不能把字段数当 build 数 |
| L0-3 | 可见集合不变的平移 | 正文 build、layout、paint 为 0；包装变化为 0 | 已有 |
| L0-4 | 有界挂载 | 受控最小项高场景中，初始驻留 holder ≤ ⌈视口 ÷ 最小项高⌉ + 1 + 预取数；稳定驻留量 ≤ 可见数 + 缓存数 + 预取数 + 类型池上限之和 | 统计当前驻留量而非累计创建数；不可回收 holder 与瞬时过渡需另列，不混用公式 |
| L0-5 | 数据通知 | 无待处理结构变更时，内容通知查询受影响类型；一批结构通知在几何读取/布局兑现时只做一次最终全表类型扫描 | 必须覆盖类型依赖位置、总数量、删除/移动无新增项及批处理中途读取；不能假定稳定 ID 保证类型稳定 |
| L0-6 | 池中静止 | 隐藏加载与过渡行尾帧排空后，不持续请求帧；隔离场景中 `hasScheduledFrame == false`、`transientCallbackCount == 0` | 新增懒时钟、初始静音、恢复、重挂、forceFrames；可见合法加载不应停止 |
| L0-7 | 受控值同帧 | 一次 pump 使用新值；自身不因已渲染同值的补发再构建，父级回灌不产生命令 | 正常受控动画允许继续；增加同值、重入新写入、合并、换模型、卸载反例 |
| L0-8 | 跨记录换绑无状态过渡 | 勾选、开关与进度同帧到目标值；无其他动效的隔离场景无多余 transient callback | 同 ID 更新正常动画、其他 holder 动画与可见不定进度不受影响；持续 keyframe 不因换绑取消 |
| L0-9 | 换绑不产生命令 | 换绑后业务选择集合不变，业务回调次数为 0，或回调幂等 | 复选已有行为测试；待补回调计数 |
| L0-10 | 池中不可见 | 池中条目不参与绘制、命中测试、语义 | 已有 |
| L0-11 | 首屏绑定 | 关闭初始预取与缓存后，首屏绑定等于实际布局需要的可见条目，每条一次 | 开启预取时必须另计预取项，不能把合法预取认作冗余绑定 |
| L0-12 | 预取预算 | 注入预算时钟后，预算内发生预取；超出预算跳过，后续有足够预算的帧补齐 | 本轮实施 S5，生产路径不改时钟语义 |

编写 L0-6 时要先确认带动画的行确实已经离屏进入回收池，再断言帧调度；否则可见区域里的正常动画也会让断言失败。

### L1：主机相对基准

无头，只用于比较两种实现或两种容器的相对方向，帮助定位，不作为验收结论。

1. 同一台机器、同一 Flutter 版本、同一个测试文件。容器之间的对比在同一进程内交替执行；版本之间的对比按 ABAB 交替启动进程，每边至少 5 轮。
2. 每轮丢弃前 20% 的样本（JIT 预热），记录本轮的 P50 和 P95。
3. 汇总值取各轮 P50 的中位数，同时报告轮间范围（最小到最大）。
4. 只有各轮方向一致，且差值大于「轮间范围」与「10%」中的较大者，才记为「主机上有差异」。
5. 计时只包住被测操作，例如从 `bindViewHolder` 到下一次 pump 结束；遍历 Element、收集断言数据放在计时区间之外（现有测试已经这样做）。
6. 需要更接近真机的文字成本时，在基准测试中用 `FontLoader` 加载应用实际使用的字体；系统字体回退无法在测试中复现，要在报告中注明。
7. JSON 输出沿用 `RECYCLER_PERF`、`RECYCLER_REAL_ROW_PERF` 标签，增加 `round` 和 `warmup_dropped` 字段。
8. 多轮基准会长时间占用 CPU：执行前先征得同意，放到后台、降低优先级并设置超时。

L1 结果不得表述为帧率、掉帧或真机耗时。

### L2：真机验收

只能由用户在手机上手动执行。按仓库规则，自动化代理不运行 `flutter run`、`flutter drive` 或设备上的 `integration_test`。

#### 准备

- 构建模式：Profile。
- 设备：记录型号、系统版本、刷新率。尽量固定刷新率（120Hz 或 60Hz），电量高于 50%，关闭省电模式，机身不发烫，关闭其他前台应用。
- 应用设置：「全局屏蔽语义」「触摸重采样」两边保持一致并记录；采样时关闭性能浮层，它本身有绘制开销。
- 测「首次滚动」时，每轮都从最近任务中划掉应用再重新打开。

#### 帧耗时记录器（已实现，待统一测试）

入口为系统设置 →「帧耗时记录」。实现位于 [frame_timing_recorder.dart](../../../../../example/lib/src/utils/frame_timing_recorder.dart)、[frame_recording_scope.dart](../../../../../example/lib/src/widgets/frame_recording_scope.dart) 与 [frame_recording.dart](../../../../../example/lib/src/pages/frame_recording.dart)。App 级 Scope 持有记录器，离开设置页仍继续任务，卸载时解除订阅并取消计时器。

使用步骤：先选页面、容器、阶段、准备秒数与采样秒数，选填设备和系统；点击开始后，在准备时间内返回已经配置好的目标页面。记录器不会代替用户切换页面或容器，配置标签应与实际页面一致。常见采样窗口可选 2、10、20、30 秒，准备期可选 5、10、20 秒。

采样口径如下：

- 通过 `SchedulerBinding.addTimingsCallback` 收集 UI（`buildDuration`）、raster、`vsyncOverhead`、`totalSpan` 与原始 vsyncStart。
- 使用显式 `[startUs, endUs)` 窗口按帧时间戳筛选，乱序帧排序、重复时间戳去重。准备期与结束后的帧不进入窗口。
- 不根据间隔长短猜测空闲。窗口内所有超过 100ms 的间隔均保留，并独立输出次数，避免把最严重的活动停顿删除；空闲/活动由阶段标签和显式窗口表达。
- 窗口结束后继续接收 1.1 秒尾批，只保留时间戳仍在原窗口内的帧，然后解除订阅；排空等待记录在 JSON 中，等待不是无限保证，异常迟到的引擎批次仍需结合原始 trace 排查。
- UI、raster、vsyncOverhead、totalSpan、相邻 vsyncStart 间隔输出 P50、P90、P99、最大值与超过 B、1.5B、2B 的数量及比例。分位数使用最近秩，空样本为 0，单帧没有伪造间隔。
- B 按 `View.of(context).display.refreshRate` 计算；刷新率不可用时回退 60Hz 并明确标注来源。采样过程中刷新率改变会使固定预算失真，因此尽量固定设备刷新率。
- 阶段 E 明确输出 `stationary_frame_count`。采样开始不额外通知 UI，期间不逐帧显示统计；开始按钮的界面帧在准备期，结束状态在窗口封口后更新，减少记录器自身制造帧的影响。
- 一键复制 JSON，包含原始每帧数据、窗口边界、页面/容器/阶段、设备手填信息、构建模式及设置快照。提交号读取 `GIT_COMMIT` 的 dart-define；未提供时明确为 `unknown`，报告发布前需补上实际版本。

JSON 中 `is_screen_presentation_timing` 固定为 false。FrameTiming 记录的是 Flutter 管线，不能证明屏幕实际呈现均匀。针对“UI/raster 均低于预算但仍明显抖动”的原问题，Android FrameTimeline 的实际呈现时间、deadline/掉帧与输入到呈现关联是必要的后续证据，不能作为可有可无的补充；自动化代理本轮不操作真机。

#### 场景矩阵

- **页面**：纯文本、万条复选、聊天、复杂卡片；另加文档页的 1 倍和 20 倍。20 倍内容重复，只用来观察结构复用的上限。
- **容器**：长列表示例为 ListView、ElScrollView、RecyclerView；文档另有官方普通滚动。文档 20 倍重复模板只代表结构复用上限，不代替内容各异的万条数据。
- **阶段**：
  - A 首次滚动：冷启动进入页面后开始记录，甩动 6 次（先下 3 次，再上 3 次）。
  - B 稳定滚动：紧接着再做 3 组同样的甩动。
  - C 数据更新中滚动：滚动过程中触发卡片页的「更新可见卡片数据」、聊天页的「模拟收到」。
  - D 远跳后反向：有指定位置入口的万条列表定位到第 5000 项后向上甩动 3 次；仅有首尾入口的页面按现有入口测远跳，记录实际索引。文档条目不足 5000 时不套用这个索引，改用实际中部小节。
  - E 静止：滚动停止 1 秒后记录 2 秒。关闭性能浮层、收起键盘并移除输入焦点，确认没有可见无限加载；需要保留的正常动画单独列场景，不强求零帧。
- **顺序**：每轮按拉丁方轮换容器顺序（ABC、BCA、CAB），共 3 轮。

#### 手势

手动甩动的速度无法精确复现。用户自行对照时可选择 ADB 注入，坐标按设备分辨率调整，每次间隔约 600ms；本轮自动化代理不执行设备操作：

```bash
adb shell input swipe 540 1900 540 500 120
```

ADB 注入不经过真实的触摸延迟，测不了输入到呈现的延迟。

#### 门槛（初值，首轮基线后校准）

B 为帧预算，120Hz 时约 8.33ms，60Hz 时约 16.67ms。

| 阶段 | 指标 | 门槛 |
| --- | --- | --- |
| B 稳定滚动 | UI P99 | ≤ B |
| B 稳定滚动 | UI 超过 B 的帧占比 | ≤ 1% |
| B 稳定滚动 | raster P99 | ≤ B |
| B 稳定滚动 | 帧间隔超过 1.5B 的占比 | ≤ 1% |
| A 首次滚动 | UI 最大值 | ≤ 2B；复杂卡片只记录，暂不设门槛 |
| C 数据更新中滚动 | UI P99 | ≤ B |
| E 静止 | 排除焦点光标、可见加载与记录 UI 自身后，2 秒窗口内的新帧数 | 0 |
| 相对比较 | 同页面、同阶段下 RecyclerView 与 ListView 的 UI P90、P99 | 不劣于 ListView（差值 ≤ 5% 或 ≤ 0.2ms）；复选和卡片的目标是更低 |

上述门槛只能评价管线成本。`vsyncOverhead`、`totalSpan` 与长间隔必须一并报告；即使 UI/raster 全部达标，也不能跳过实际呈现检查后声称原始抖动已经解决。FrameTimeline 的呈现节奏与 deadline 证据另列，避免将 vsyncStart 间隔直接命名为屏幕掉帧率。

#### 归因

超出门槛时，在 Profile 下用 DevTools 时间线查看：

- 内核区间 `RecyclerView.layout`、`RecyclerView.bind`、`RecyclerView.mount`、`RecyclerView.prefetch`；
- 帧内 Build、Layout、Paint 以及帧尾卸载（finalizeTree）的占比；
- raster 超标时看 raster 线程中的阴影、裁剪和 saveLayer。
- UI/raster 很低仍抖动时，检查 vsyncOverhead、totalSpan，再关联 FrameTimeline 的实际 present/deadline 与输入时间，区分调度、输入和呈现链路问题。

#### 报告模板

```markdown

## <页面> · <阶段>
- 提交：<hash>；构建：Profile；设备：<型号> / Android <版本> / <刷新率>Hz
- 设置：屏蔽语义 <开/关>，触摸重采样 <开/关>，性能浮层 关
- 手势：<ADB 命令或手动>，<次数>；轮次：3（顺序 ABC / BCA / CAB）

| 容器 | 帧数 | UI P50 / P99 / max | UI > B | raster P99 / max | 间隔 > 1.5B |
| --- | ---: | ---: | ---: | ---: | ---: |
| ListView | | | | | |
| ElScrollView | | | | | |
| RecyclerView | | | | | |

原始 JSON：<路径>
结论：<只写该设备、该场景成立的结论>
```

## 3. 结论措辞

| 证据层级 | 可以说 | 不能说 |
| --- | --- | --- |
| L0 | 构建、布局、挂载次数减少；结构保留；行为正确 | 更快、更流畅 |
| L1 | 主机上某个操作相对变快或变慢多少（附轮间范围） | 帧率、掉帧、真机耗时 |
| L2 FrameTiming | 该设备、该场景的管线耗时分位数、vsync 间隔与超预算比例 | 用这些数字单独断言实际屏幕无掉帧或推广到其他设备 |
| L2 实际呈现 trace | 该设备、该场景的实际呈现节奏与 deadline 情况 | 不经输入关联就推断触摸延迟，或推广到其他设备 |

## 4. 运行本轮门禁

在 Windows 端串行、降优先级、设超时执行本次涉及的测试文件。本轮增加模型回灌、动画可见性、换绑隔离、类型扫描与预算测试；具体文件以实际改动清单为准，不用全仓测试代替定向回归。以下是相关模块入口，最终通过数量以运行日志和结果报告为准：

```powershell
flutter test test/flutter/views/recycler_view --no-pub --concurrency=1 --timeout 90s
cd example
flutter test test/recycler_row_performance_test.dart test/recycler_row_reuse_test.dart test/recycler_cards_test.dart test/recycler_chat_entry_test.dart test/recycler_long_examples_test.dart --no-pub --concurrency=1 --timeout 90s
flutter test test/frame_timing_recorder_test.dart test/frame_recording_page_test.dart test/scroll_settings_test.dart --no-pub --concurrency=1 --timeout 90s
```

结构改进优先用 L0 的前后工作量报告。若只做了少量主机计时或单轮诊断，应如实列样本与局限，不包装成符合完整 L1 方法的显著性能提升。条件项的决策、未做真机测量的边界也写入最终结果报告。

本轮执行结果见 [REUSE_RESULTS.md](REUSE_RESULTS.md) 与 [五轮摘要](REUSE_RESULTS.json)，确定工作量和主机计时分别报告。
