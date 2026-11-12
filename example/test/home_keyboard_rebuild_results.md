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
