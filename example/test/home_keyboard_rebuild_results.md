# 首页输入与键盘重建回归（2026-11-12）

用户在 Profile 模式点击首页「资料编辑与校验」的输入框后，录到 UI 峰值 69.9 ms。无头测试将点击聚焦和键盘高度变化分开后，发现主要重建扩散来自键盘阶段。

移动组件和编辑器读取 `disableAnimations` 时使用了完整的 MediaQuery 订阅，键盘的 viewInsets 变化也会唤醒它们；外层导航 Scaffold 收缩后，首页 LayoutBuilder 又重新创建了全部章节。

修复改为只订阅 `disableAnimations`，并复用首页章节和首屏 Widget 实例。宽度、主题、字号及组件自身状态继续通过原有依赖更新，键盘避让保持开启。

## 同场景构建数量

`home_keyboard_rebuild_test.dart` 使用真实 App / 移动导航壳，以 390 × 900 视口点击显示名称输入框，再依次设置键盘高度 120、240、320 和 0；通过 Flutter 的 `debugOnRebuildDirtyWidget` 统计每个采样帧的构建调用。

| 阶段 | 修改前 | 修改后 |
| --- | ---: | ---: |
| 点击聚焦 | 225 | 225 |
| 键盘高度 120 | 6384 | 533 |
| 键盘高度 240 | 6380 | 533 |
| 键盘高度 320 | 6380 | 533 |
| 收起键盘 | 6380 | 533 |

键盘每个采样帧中的 ShowcasePanel 从 74 次降为 0，EditableView 从 20 次降为 0。这是构建工作量对比，不是设备帧耗时；新的真机 Profile 峰值尚未复测。

## 验证

- `example/test/home_keyboard_rebuild_test.dart`：真实点击、键盘避让、焦点和表单值保持，以及不重建屏外面板和编辑器。
- `test/ui/mobile/keyboard_dependencies_test.dart`：键盘高度不唤醒卡片和编辑器，减少动画设置切换仍生效。
- `test/ui/cores/editable/editable_keyboard_reopen_test.dart`：Android / iOS、开启 / 关闭选区交互时，收起键盘后仍可再次唤起并输入。
- 原有首页布局、滚动绘制、跨断点状态和交互测试保持通过。

需要保存完整构建明细时，在 `example/` 设置 `HOME_KEYBOARD_REPORT=build/home-keyboard.json` 后运行 `flutter test --no-pub --concurrency=1 test/home_keyboard_rebuild_test.dart`。

## 真机继续卡顿后的布局定位（同日）

用户确认剩余卡顿出现在键盘升起或收起。经用户授权，只读连接 PLJ110 上现有的 Profile 实例；使用 VM Service 读取已经开启的时间线，没有重启应用、修改采样开关或操作设备。当前工程 SDK 为 Flutter 3.50.0 / Dart 3.14。

请求覆盖约 11 秒，环形缓冲区实际保留最后约 5.95 秒。`getCpuSamples` 超时，没有取得有效 CPU 调用栈；以下数据来自成功返回的框架 / 引擎时间线，各阶段统计独立，不能把嵌套事件相加当作总帧耗时。

| 时间线事件 | 完整事件数 | P95（ms） | 最大值（ms） |
| --- | ---: | ---: | ---: |
| Animator::BeginFrame | 233 | 25.781 | 32.473 |
| LAYOUT | 234 | 22.762 | 30.005 |
| SEMANTICS | 233 | 5.343 | 17.756 |
| PAINT | 234 | 1.266 | 7.739 |
| Rasterizer::DrawToSurfaces | 232 | 4.110 | 6.220 |

慢帧的主要耗时在布局。进一步给原首页回归增加 `ElRenderView.debugLayoutCount` 差值统计后，键盘高度每变化一次就有 1601 次 ElView 布局，其中 1512～1529 次位于屏外。

原因是 `LayoutReferenceBox` 在祖先内容区参照变化时，无条件把全部后代 RenderObject 标记为需要布局。键盘收缩视口会逐帧触发这条路径，即使 Widget 没有重建，长页面的固定尺寸及屏外内容仍会参与布局。

修复按变化的宽 / 高轴传播，只标记无界约束下实际使用百分比或 calc 长度的节点；近层参照隔离更远祖先的变化，其自身尺寸变化时再继续通知后代。普通 Flutter 约束变化仍走原有布局机制，键盘避让保持开启。

| 场景 | ElView 布局前 → 后 | 屏外布局前 → 后 |
| --- | ---: | ---: |
| 点击聚焦 | 4 → 4 | 0 → 0 |
| 键盘高度 120 | 1601 → 0 | 1516 → 0 |
| 键盘高度 240 | 1601 → 0 | 1522 → 0 |
| 键盘高度 320 | 1601 → 0 | 1529 → 0 |
| 收起键盘 | 1601 → 0 | 1512 → 0 |

布局数统计采样前已经挂载、可由 ElView Widget 定位的渲染节点，不代表 Scaffold / 滚动视口等所有 Flutter 节点都没有布局。屏外范围使用展示滚动区的视口矩形。以上为无头回归的工作量，不是真机修复后的帧耗时。

新增 `test/flutter/views/view/layout_reference_test.dart` 的 9 个回归覆盖双轴、固定尺寸隔离、嵌套百分比、百分比 min/max、calc 和不相关轴；连同原有 `layout_test.dart`、`animation_test.dart` 共 418 项通过。首页键盘回归新增布局数量上限，验证避让、焦点和输入内容保持；相关文件静态分析通过。

本次 Profile 实例仍运行原二进制，需要重新构建运行 Profile 后确认设备帧耗时，不能热重载应用本次修改。只读采样的阶段汇总、筛选后的时间线和无头对比明细保存在忽略目录 `example/build/home-keyboard-device-20261112/`。
