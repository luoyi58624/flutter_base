# Flutter 复杂卡片的底层成本诊断

2026-11-12。只新增诊断测试、离线分析工具与记录，没有修改生产组件或外卖页面。

## 已经测到的结论

1. **保留 TextPainter 对象没有消除新文字的排版成本。** 48 段中文全部换字，新建对象约 4.03ms，保留对象后换字约 4.17ms；同字、同约束且保留排版缓存才降到约 0.16ms。这是无头 debug 微基准，不是设备帧时间。
2. **现有 Profile 应用的慢帧不是只有 build。** 95 个超过 8.33ms 的帧，平均 18.49ms；扣除嵌套 build 后的布局为 7.20ms，语义为 3.85ms，build 本身为 4.58ms。
3. **不能把剩余布局时间全归给 SkParagraph。** 实际采到了 paragraph 排版和释放、字体/HarfBuzz/ICU、VM 句柄和分配、语义集合维护等路径。很多原生样本没有调用者，仍不能按毫秒完整归因。
4. **创建/重建计数不能替代这些阶段。** 旧报告中换字布局次数为 288 → 288，配置优化没有减少实际排版。也不能反向说所有上层成本都只有几微秒：这次 Profile 现场的 build 合计确实是毫秒级。

## 真实 Profile 现场

用户授权后，通过现有 DDS 进程提供的 VM Service 地址，只读调用 getVM、getFlagList、getVMTimelineFlags、getVMTimeline、getCpuSamples。没有启动、重启、热重载、注入代码或控制窗口，没有修改采样配置。连接地址和认证码没有写入报告。

- 现有应用进程 94196，路径为 `example/build/windows/x64/runner/Profile/example.exe`；启动命令也包含 `--profile`。
- VM profiler 本来已开启，采样间隔为 1000µs；Timeline 已记录 Dart、Embedder、GC 和 Microtask。
- 读取的是**已有环形缓冲区**，不是刚刚按统一速度重放的一轮滚动。完整 Frame 事件从 175939103092 到 175946600712，跨度约 7.50 秒。
- Timeline 共 32368 个事件，配对得到 217 个完整 UI Frame。4 个边缘未配对的同步结束事件被丢弃，未将半帧算入数据。
- CPU 共 1480 个样本，1463 个集中在起点附近前三秒。1242 个落入完整帧，1124 个落入 95 个慢帧。不能把快照的约 25 分钟时间范围描述成连续负载采样。
- 调用栈有 `_ShowcaseStoreHost.build`、`_StorePhoto.build`、`_TakeawayShowcaseState._storeAt`，确认来自首页外卖路径。
- 采样后工作树有其他会话修改首页。这里评价已加载的 Profile 二进制，不能把之后的磁盘修改算作这轮测量的实现。

### 帧阶段

217 帧中，UI Frame 中位数 3.45ms、P90 23.52ms，95 帧超过 8.33ms。这是 UI 工作超预算次数，**不是显示系统实际丢帧率**。

下表只统计这 95 个慢帧，使用平均数以便相加：

| 不重叠阶段 | 平均耗时 | 占慢帧总时长 |
| --- | ---: | ---: |
| BUILD，包含布局中触发的 build | 4.578ms | 24.8% |
| LAYOUT，扣除其中的 BUILD | 7.204ms | 39.0% |
| SEMANTICS | 3.851ms | 20.8% |
| PAINT，CPU 绘制录制 | 1.870ms | 10.1% |
| 合成、树清理、帧后回调及其他 | 0.987ms | 5.3% |
| 合计 | 18.490ms | 100% |

原始 LAYOUT 平均 11.781ms，其中包含上述 build。`analyze_profile.py` 对区间求并集及交集，避免把二者直接相加。

SEMANTICS 内部已记录的子阶段分别为：updateChildren 0.995ms、ensureGeometry 0.493ms、ensureSemanticsNode 0.408ms。剩余约 1.954ms 还包含其他语义处理和提交，不能直接叫整树重建或全算成平台提交。

95 个慢帧中 16 个与 UI 线程 GC 区间重叠，GC 重叠平均为 0.731ms，最大 5.769ms。它已经包含在相应阶段内，**不能再加到总时间上，也不能用 GC 解释所有慢帧**。

### 已确认的实际调用链

```text
recycler.runRebind
  → LayoutBuilder / RichText.updateRenderObject
  → RenderParagraph.text=
  → TextPainter.markNeedsLayout
  → native Paragraph.dispose

recycler.runRebind
  → RenderFlex / RenderParagraph.performLayout
  → TextPainter.layout
  → native Paragraph._layout

PipelineOwner.flushSemantics
  → updateChildren / collectChildMergeUpAndSiblingGroup
  → Set 添加、rehash、toSet / 配置比较 / 节点提交
```

慢帧 CPU 样本中，runRebind 命中 319 次、flushSemantics 119 次、TextPainter.layout 53 次、ElRenderView._reresolve 20 次。这些是 **inclusive 命中、彼此重叠**，不能相加，也不能把 1 个样本当作精确 1ms。

### 原生符号化

`symbolize_native.py` 只离线使用当前 Python 进程的 DbgHelp，不附加应用、不执行引擎 DLL、不联网下载符号。

- 应用 DLL 与 SDK Profile DLL 的 SHA256 一致：`81f9322fa80ea38ce53a90583d32d72657b53907f98ca3b8ab226fdecb0b0730`。
- 使用本地精确匹配的 PDB，`pdb_unmatched=false`。
- 393 个引擎 RVA 全部解析成功，地址均位于所解析符号的大小范围内。
- 在慢帧的 1124 个样本中，654 个叶节点为 Native，其中 543 个只有一个原生栈地址。解出名字仍不能恢复缺失的调用者。

按原生叶函数名粗分，文字/字体相关命中 168 次，Dart VM 相关 89 次，系统分配/内存或 Windows 运行库相关 230 次，平台语义 12 次，其他原生 155 次；另有 470 个 Dart/其他非原生叶样本。**这是名字分类，不是各阶段 CPU 时间比例**。例如 `RtlAllocateHeap` 缺少调用者，不能判断这些分配由文字、语义还是其他代码触发。

还特意核对了一个会误导结论的热点：全快照 `TryAllocateNewTLAB` 命中 57 次，但 54 次在完整帧区间外，慢帧内只有 3 次。因此不能拿全快照最大原生函数解释慢帧主因。

## 无头底层对照

两份 Dart 测试均默认跳过，只在 `PIPELINE_DIAGNOSTIC=true` 时执行。显式加载真实中文字体，默认 `C:/Windows/Fonts/msyh.ttc`，可通过 `PIPELINE_CJK_FONT` 替换；缺失就跳过，不使用 Ahem 冒充中文排版。

环境为 Windows Flutter 3.47.5 / Dart 3.13.4。`flutter test` 是 debug 无头进程，无法据此声称 Profile/AOT 或手机 120Hz 达标。以下都只测 CPU，不测 GPU raster、图片解码或最终呈现。

### 直接 Paragraph / TextPainter

每卡 48 段，44 段单行、4 段双行，包含真实溢出的省略号；每组 6 次预热、24 个样本，分三轮轮换场景顺序。文本与 TextSpan 在计时外预建。不同组用同长度、不同值的编号隔离缓存，不能将这份合成文案当作完整业务卡片。

| 场景 | 每卡总耗时中位数 |
| --- | ---: |
| 新 Paragraph，新内容 | 2.790ms |
| 新 Paragraph，两个固定内容循环 | 1.385ms |
| 新 Paragraph，新内容但不用省略号 | 2.074ms |
| 新 TextPainter，新内容 | 4.026ms |
| 保留 TextPainter，新内容 | 4.172ms |
| 保留 TextPainter，原 TextSpan 不变 | 0.159ms |
| 保留 TextPainter，等值的新 TextSpan | 0.151ms |

新 Paragraph 的构建、layout、录制、销毁中位数分别约 0.621、1.664、0.260、0.169ms；各阶段中位数不能直接加成总中位数。

两个内容循环为引擎缓存提供了机会，但没有直接统计缓存命中，不能称为已验证的缓存命中率。它也不能证明首次浏览大量不同商家会有相同收益。去掉省略号改变了视觉行为，这里只用于识别代价，不是建议产品删除省略号。

### 直接 RenderObject 树

48 个 RenderParagraph、固定约束、12×4 的 Flex 树，直接 PipelineOwner，不创建 Widget、ElView 或 Sliver。每叶宽100、高50；TextPainter 对照使用相同文案模板、字体13/行高1.3、行数、宽度、省略号和溢出裁剪；编号采用等长但不同的命名空间。

每组3次预热、20个样本，场景轮转。最终同进程对照结果：

| 场景 | 总耗时中位数 |
| --- | ---: |
| 干净树，相同约束再次 layout | 0.037ms |
| 父布局变脏，文字不变，并重录整卡 | 0.690ms |
| 文字不变，只重录整卡 | 0.428ms |
| 48 个 RenderParagraph 全部换字 | 6.953ms |
| 同条件直接 TextPainter 全部换字 | 4.786ms |

RenderParagraph 换字组：setter 0.803ms、flushLayout 5.467ms、paint录制0.525ms。布局内48个 `performLayout` 合计约5.166ms，外层布局执行约0.328ms。说明这组实验里，大量成本已经在文本叶子内，不是 Sliver 调度。

所有 intrinsic-size、layout/paint profile 与绘制调试标志都实际读出为 false。叶子 Stopwatch 仍有少量测量开销；普通 debug 断言依然存在。

首次未加入同文案 TextPainter 对照的短运行，换字总中位数为12.782ms；增加对照后是6.953ms。**没有做任何生产优化，不得把这个下降宣称成优化收益**。这个明显波动也是最终必须以现有 Profile 帧记录为主，而不是拿 debug 绝对时间证明设备瓶颈的原因。

## Android / Web 为什么不能按同一条管线理解

- AndroidDemo 使用 RecyclerView 1.3.2，默认启用 deadline prefetch、保留已绑定缓存，横向商品还有共享池。换绑发生时确实大量 setText，但已经绑定的卡片不是每个滚动帧都 setText。预取仍在 UI 线程，只是部分工作可以提前完成。[Android 官方说明](https://developer.android.com/topic/performance/issues/render)
- TextView 在宽度已知、固定高度或新旧文本同高时，可以完成本身文本布局后仅 invalidate，而不请求父布局；简单文本还可能复用 BoringLayout。不能概括所有 setText 免费，也不能说 Flutter 没有布局边界缓存。[TextView 源码](https://android.googlesource.com/platform/frameworks/base/+/main/core/java/android/widget/TextView.java)
- HTML 示例是原生 overflow 滚动，虚拟窗口不变即返回，预先知道三档行高，默认预留至少1000px。浏览器可让已准备内容的合成滚动与主线程内容更新并行；新 DOM 的文字和布局仍要工作。[RenderingNG 架构](https://developer.chrome.com/docs/chromium/renderingng-architecture)
- HTML 面板统计的是 rAF 回调间隔，长帧阈值为50ms；它不能直接等同 Flutter UI CPU 毫秒。这里不否定实际流畅感，也没有用该面板计算平台加速倍数。
- 本轮未取得同设备 Android 的同条件 CPU/呈现 trace，因此没有把用户观察到的“原生<3ms、Flutter>10ms”伪装成已经完成的跨平台量化实验。

## 后续优化应该针对什么

先用毫秒预算约束剩余工作，而不是继续以少建多少 Element 验收：

1. 对文字内容与几何完全相同的场景，保留实际 Paragraph/排版结果；对新内容分别测 paragraph 构建、shape、断行、省略号与字体匹配。缓存旧对象不等于缓存新内容的布局，首次出现的内容也不能凭空跳过排版。
2. 对已知即将出现的卡片，验证提前准备能否降低入场帧峰值，同时记录总 CPU。增大 cache 只是同步提前做工作，不自动降低总成本，也不等同 Android 的 deadline prefetch。
3. 对真实 3.85ms 语义阶段，分别验证结构收集、坐标更新和节点提交，保持无障碍开启。当前 recycler 已排除停放池、已有边界短路，不能在没有证据时指控全树无条件重算，更不能靠关闭语义刷分。
4. 对缺少调用者的原生分配，进一步取得可展开原生栈后才能决定优化对象。当前证据足以反对“全部是文字/全部是GC/全部是build”这三种简单归因。

当前没有证据承诺通用滚动层优化会减少50% UI耗时，也没有证据证明复杂 Flutter 卡片存在不可突破的10ms固定下限。优化是否达到目标，要用同内容、同语义能力的 Profile A/B 结果判断。

## 文件与复现

- `headless-results-2026-11-12.jsonl`：两份无头实验的15条条件和结果记录。
- `profile-results-2026-11-12.json`：完整帧分段、慢帧、符号分类摘要及原始文件哈希。
- 原始 Timeline、CPU、PDB映射保存在仓库忽略目录 `.dart_tool/benchmarks/profile-pipeline-20261112/`，避免把约57MB现场快照提交进代码仓库。

```powershell
flutter test test/benchmarks/pipeline_cost/text_pipeline_diagnostic_test.dart --no-pub --concurrency=1 --timeout 45s --reporter expanded --dart-define=PIPELINE_DIAGNOSTIC=true
flutter test test/benchmarks/pipeline_cost/render_pipeline_diagnostic_test.dart --no-pub --concurrency=1 --timeout 30s --reporter expanded --dart-define=PIPELINE_DIAGNOSTIC=true
python test/benchmarks/pipeline_cost/analyze_profile.py .dart_tool/benchmarks/profile-pipeline-20261112/timeline.json --output .dart_tool/benchmarks/profile-pipeline-20261112/frame-summary.json
```

两份定向测试已通过，定向 Dart 静态分析无问题；没有运行全仓测试。符号化脚本的参数见 `python test/benchmarks/pipeline_cost/symbolize_native.py --help`。
