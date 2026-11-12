# Sliver 三种生命周期验证

日期：2026-11-12。使用仓库 `.fvm/flutter_sdk` 的 Flutter 3.50.0 / Dart 3.14；所有命令为无头 `flutter test --no-pub --concurrency=1`，没有运行前台应用或全仓测试。

## 稳定回归门槛

- 1000 项、400×600 视口、250 像素缓存、每帧移动 48 像素，业务内容均为两行真实 Text。
- List：官方与 El builder 在 32 个采样步中均构建 22 项、执行 22 次子项实际布局。
- Grid：官方与 El builder 均构建 44 项、执行 44 次子项实际布局。官方网格使用固定 72 像素行高，El 网格自然测量，同样得到 72 像素。
- recycler 的原有 20 窗口换绑测试保持：静态 Element 重建 0、Widget 替换 0、卡片工厂调用 0，仅动态标题叶子更新。
- children 首次挂载全部内容；普通滚动保持子项实例并使用缓存几何。builder 远跳只创建目标窗口，保活、释放和按 Key 重排均有测试。
- recycler 不提供 AutomaticKeepAlive，未新增保活桶。builder 不创建复用模式的通知器、Focus、TickerMode、HeroMode、复用动画包装。

## builder 同负载耗时

`test/flutter/slivers/sliver_builder_performance_test.dart` 先预热 12 步，再采样 32 步；第二轮反转测试顺序。Sliver 布局耗时通过相同 RenderProxySliver 包装采集，包含子项构建与排版。

| 顺序 | 对照 | 官方 pump 中位 / P95（μs） | El builder pump 中位 / P95（μs） | 官方 / El Sliver 布局中位（μs） |
| --- | --- | --- | --- | --- |
| 正序 | List | 3438 / 4946 | 3377 / 4472 | 1182 / 1174 |
| 正序 | Grid | 3590 / 5803 | 3198 / 5376 | 1561 / 1467 |
| 反序 | List | 1260 / 1853 | 1547 / 1895 | 482 / 614 |
| 反序 | Grid | 2795 / 3667 | 2831 / 4114 | 1309 / 1316 |

前一轮未加布局计时包装的反序测量中，Grid 曾出现 5546 / 15437 μs，而官方为 3923 / 5396 μs；不能只选较快的一轮作为结论。debug JIT、GC、测试顺序和共享机器负载都会影响墙钟结果，次数相同也不等于实际耗时必然相同。

目前证据支持构建和实际排版工作量不增加；不足以保证所有负载都不慢于官方，也不能证明 120 Hz。反序 List 仍有约 0.13 ms 的 Sliver 布局中位差，需要目标设备的 profile/release 对照确认。

## recycler 改动前后

同一命令：`flutter test test/benchmarks/view_reuse/sliver_benchmark_test.dart --no-pub --concurrency=1 --plain-name "sliver recyclerDirect different_rows pass 0" --dart-define=VIEW_REUSE_TIMING=true --dart-define=VIEW_REUSE_SAMPLES=8`。

| 操作 | 改动前中位 / P95（μs） | 改动后中位 / P95（μs） |
| --- | --- | --- |
| 可见文本变化 | 2706 / 3083 | 2661 / 3119 |
| 向前滚动 | 4010 / 7778 | 3881 / 8795 |
| 向后滚动 | 4287 / 5796 | 3254 / 4838 |

每个方向的 8 步仍为换绑 9 次、ElView 实际布局 18 次、Element 重建 25 次。滚动中位没有上升，但向前 P95 有波动，8 个样本不能作为尾延迟无退步的证明。该对照采于通知器延迟分配优化之前；优化后复用工作量测试再次通过。

几何优化：同类型未知高度共享基值，首次实测不再扫描全部未知条目；网格行索引从多次前缀查询改为单次 Fenwick 反查。多类型首次校准仍保留原路径，瀑布流远跳仍需推算前置列几何，未承诺常数时间。
