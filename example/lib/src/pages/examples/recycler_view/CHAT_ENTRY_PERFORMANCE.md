# 聊天页面首次进入开销

日期：2026-11-06。用户截图显示 UI 峰值 201.8ms。本次使用 Windows / Flutter 3.47.5 的无头 Debug 测试分段定位，没有操作手机或运行前台应用；主机测试耗时不等于截图中的 Android Profile 帧耗时。

## 发现与修复

聊天页面的 State 构造会同步执行 `List.generate(10000, _ChatMessage.generated)`。旧消息构造立即拼接正文、创建本地 DateTime、增加分钟偏移，再读取 hour/minute 格式化时间。一万条消息都提前完成这些工作，虽然首屏只显示末尾六条。

现在保留一万条轻量记录，构造时仅保存 ID、方向和可选的输入文案。正文、日期、时间标签改为 `late final`，首次显示时计算并缓存。索引查询和二分查找只读取 ID、方向，不触发正文和本地时间计算；手动输入、历史负 ID 与原有时间显示语义保留。

内核还有较小的额外工作：初始 `stackFromEnd` 先按估高猜窗口，测量后再对齐末尾。旧真实首屏先后绑定了 ID 9992～9999 共八条，最终只显示 9994～9999 六条。现在直接实测最后一项，向前填至覆盖视口，再对齐实际末尾；正常滚动、显式定位与已有数据锚点仍走原路径。

初始类型索引仍为 O(n)，每种类型首次测量也仍会更新估高；本次没有将这些必要索引工作宣称为 O(1)。

## 同一真实页面的前后记录

`recycler_chat_entry_test.dart` 继承真实页面并计时 `super.createState()`，先预备共用 MaterialApp 外壳，再分别记录首个 pump 和后续 settle。真实行通过框架构建回调与现有数据监听器记录，没有替换成简化行。

| 指标 | 修改前 | 修改后 |
| --- | ---: | ---: |
| 聊天 State 同步构造 | 214.878 ms | 2.699 ms |
| 首个 pump 主机墙钟，包含 State 构造 | 426.008 ms | 179.180 ms |
| 首屏创建的真实行 Element | 7 | 6 |
| 观察到的数据绑定次数 / 不同消息 ID | 8 / 8 | 6 / 6 |
| 观察到的消息范围 | 9992～9999 | 9994～9999 |
| 最终可见范围 | 9994～9999 | 9994～9999 |
| 末尾距离 extentAfter | 0 | 0 |

另外在只修改消息模型、尚未修改内核时，独立运行得到 State 构造 2.883ms，行绑定仍为八条。这将主要的初始化收益与尾部布局收益分开；该次聊天测试在新进程中先运行，冷启动/JIT 成本不同，因此不拿它的首个 pump 总墙钟与表中数据比较。

这些数字记录有限次数 Debug 主机运行，包含 JIT、框架测试和主机调度。尤其不能把 179.180ms 当作 Android 优化后的 UI 帧耗时，也不能将总墙钟差额都归因于内核分支。可以直接确认的是同步 State 构造的昂贵工作被移除，以及真实首屏多余绑定被消除。Android 呈现峰值仍需之后真机确认。

## 回归范围

- 新增三页真实首入诊断：复选、聊天、复杂卡片，记录初始化、首帧、稳定状态及真实行工作量。
- 聊天额外断言首次绑定仅覆盖最终可见消息，每条只绑定一次，首帧已经贴底。
- 新增五项尾部布局测试：万条变高记录、超高末项、纵横方向和反向、RTL、不对称内边距、短内容、显式定位优先；统计真实 build 和 RenderBox 布局次数。
- 现有回归覆盖发送/接收、历史插入、阅读锚点、容器切换、真实子树复用及两种容器的滑块拖拽。

本次共 88 项通过：RecyclerView 内核子集 55 项、相关示例子集 33 项，静态分析无诊断。测试使用结构和行为断言，不设依赖机器速度的毫秒通过门槛。

```powershell
# 仓库根目录
flutter test test/flutter/views/recycler_view --no-pub --concurrency=1 --timeout 90s
# example 目录
flutter test test/recycler_chat_entry_test.dart test/recycler_long_examples_test.dart test/recycler_row_reuse_test.dart test/recycler_row_performance_test.dart test/recycler_scrollbar_test.dart --no-pub --concurrency=1 --timeout 90s
```

本机忽略目录 `.codex-run/recycler-chat-entry-20261106/` 保存 `before.log`、`data-only.log`、`after.log` 和 `core.log`。修改前生产源码对应提交 `bae938a`。
