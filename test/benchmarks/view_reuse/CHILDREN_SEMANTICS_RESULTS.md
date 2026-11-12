# children 常驻列表的语义队列诊断

2026-11-12。示例已统一为 CustomScrollView，默认官方 SliverList / SliverGrid，只切换内容 Sliver。children 仍按约定全量挂载、布局并保留子树，仅绘制可见部分。

## 复现结果

使用实际 TakeawaySliverPage 的 1000 张卡片，390 × 844、DPR 1、250px 缓存窗口、本地图片。页面外层始终包着 ExcludeSemantics。以下是 Windows flutter_tester 的 debug 墙钟时间，不是手机或桌面应用的帧时间，也不包含设备呈现和真实输入排队。

| 测量 | 测试环境启用语义管线 + ExcludeSemantics | 测试环境未启用语义管线 + ExcludeSemantics |
| --- | ---: | ---: |
| children 连续三次滚动的完整 pump | 104.037 / 101.598 / 99.232ms | 2.333 / 1.225 / 1.138ms |
| children 布局阶段增量 | 0.311ms | 0.256ms |
| children 绘制阶段增量 | 2.881ms | 2.950ms |
| children 语义阶段增量 | 99.015ms | 0.777ms |
| 切入 children，全量挂载并稳定 | 12.336s | 11.556s |

阶段增量通过递进 EnginePhase 分开的 pump 测量，不应相加当成某一真实帧，也不用于严格比较零点几毫秒的差异。完整滚动的另一轮 12 次样本为 103–164ms，慢项同样持续存在。children 和官方在抽样帧实际绘制的 RenderObject 类型、数量基本一致，仅内容 Sliver 的类型不同；关闭测试语义管线没有改变绘制工作量。全量挂载成本与滚动时的语义开销是两个问题。

## 定位

项目 FVM SDK 为 Flutter 3.50 beta，提交 `ab2912035e1`，SDK 工作树未改动。

用户现场为安卓，页面稳定后持续滚动仍卡。本报告复现出同类停顿，但没有连接安卓应用确认 `SemanticsBinding.instance.semanticsEnabled` 或采集设备 trace，因此不能据此断言安卓现场只有这一个瓶颈。

`packages/flutter/lib/src/rendering/object.dart` 的 `PipelineOwner.flushSemantics`：

1. `_deferredNodesNeedingSemanticsGeometryUpdate` 保存当前不在语义树中的待更新节点。
2. 每次 flush 将整个集合加入待处理集合，并清空原集合。
3. 节点的 `parentDataDirty` 仍为 true 时，又将它加入延迟集合。

因此，全量挂载但被 ExcludeSemantics 或 Sliver 可见性过滤排除的节点，会在后续每帧被反复取出、检查、加入。ExcludeSemantics 只控制语义树内容，并没有关闭 PipelineOwner 的语义管线。这条重试路径不在 assert 内；debug 数值仍不能直接推算 profile / release 的影响。

此机制来自上游 [Flutter PR #192146](https://github.com/flutter/flutter/pull/192146)，目的是恢复弹窗遮挡期间移动过的节点的无障碍位置。修复必须保留这项正确性，不能直接删掉待更新记录。

本次查询的 [master object.dart](https://raw.githubusercontent.com/flutter/flutter/master/packages/flutter/lib/src/rendering/object.dart) 仍有相同的延迟集合重试代码，不能承诺直接升级 master 就会解决。

## 为什么 UI 柱状图可能很低

该 SDK 的 `RendererBinding.drawFrame` 先调用 `RenderView.compositeFrame()`，然后才调用 `flushSemantics()`。单视图的场景提交进入引擎 `RuntimeController::Render` → `CheckIfAllViewsRendered` → `Animator::OnAllViewsRendered` → `EndFrame`，其中已记录 `RecordBuildEnd`。

所以，提交场景之后的语义处理仍占用 Dart UI 线程、阻塞下一次输入和下一帧，但不会完整反映在该帧的 buildDuration 中。查看 buildDuration 小，并不能排除本次复现中的约 100ms 停顿。上述调用位置见 SDK 的 `rendering/binding.dart`、`engine/src/flutter/runtime/runtime_controller.cc`、`engine/src/flutter/shell/common/animator.cc`。

## 复现命令

诊断入口：`example/test/sliver_children_scroll_test.dart`，默认跳过。外卖诊断每次仅切入一次 1000 children，采样三次滚动及分阶段 pump，90 秒超时；不要批量反复运行。

在 example 目录执行：

```powershell
& ..\.fvm\flutter_sdk\bin\flutter.bat test --no-pub --concurrency=1 --dart-define=SLIVER_CHILDREN_DIAGNOSE=true test/sliver_children_scroll_test.dart --reporter expanded

& ..\.fvm\flutter_sdk\bin\flutter.bat test --no-pub --concurrency=1 --dart-define=SLIVER_CHILDREN_DIAGNOSE=true --dart-define=SLIVER_DIAGNOSE_SEMANTICS=false test/sliver_children_scroll_test.dart --plain-name '外卖 children 持续滚动只绘制可见子树' --reporter expanded
```

另有 32 个简单常驻子项的诊断：不构建、不布局、不绘制，只连续调用 `flushSemantics`，统计被 ExcludeSemantics 排除的 RenderObject 的 owner 访问次数，用来观察 SDK 对离屏队列的重复扫描。

当前 SDK 的输出为 `excluded_semantics_owner_reads=[32, 32, 32], retained_children=32`：没有任何新变化，三次语义刷新仍逐一访问全部 32 个被排除子项。

## 本轮范围

修改并验证示例的默认值、命名、四种模式和统一宿主；保留复现脚本与证据。未修改共享 Flutter SDK，也未以关闭应用无障碍作为修复。SDK 根因修复需要另行明确范围，并验证被屏蔽节点恢复后的语义几何。没有进行真机 profile / release 验证。

涉及的 89 项示例回归通过，覆盖菜单、路由、外卖、网格、瀑布流、选择、聊天、长文、媒体及滚动条；新增诊断已显式执行。静态分析仅有现存 material.dart 弃用提示。尝试热重载时 DTD 没有已连接应用，未启动或重启用户应用。
