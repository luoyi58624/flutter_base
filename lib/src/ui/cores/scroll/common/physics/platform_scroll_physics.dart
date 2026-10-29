import 'package:flutter/widgets.dart';

import 'bouncing_scroll_physics.dart';
import 'clamping_scroll_physics.dart';

/// el 的平台默认滚动物理口径。
///
/// **与 Flutter 官方默认刻意不同**：官方 [ScrollBehavior.getScrollPhysics] 在
/// Windows / Linux 上给 clamping（硬边界、越界只上报通知），el 裁决为 bouncing
/// （橡皮筋越界回弹）——桌面滚动手感向 iOS 对齐，滚轮插值另由
/// `ElWindowsSmoothScroll` 补。这是 el 的口径，不是"官方默认的平台镜像"。
///
/// 口径表：
/// - iOS / Linux / Windows → [ElBouncingScrollPhysics]
/// - macOS → [ElBouncingScrollPhysics]（fast 减速率，对齐 macOS 原生）
/// - Android / Fuchsia → [ElClampingScrollPhysics]（越界通知喂 M3 拉伸）
ScrollPhysics elScrollPhysicsFor(TargetPlatform platform) => switch (platform) {
  TargetPlatform.iOS || TargetPlatform.linux || TargetPlatform.windows => const ElBouncingScrollPhysics(),
  TargetPlatform.macOS => const ElBouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast),
  TargetPlatform.android || TargetPlatform.fuchsia => const ElClampingScrollPhysics(),
};

/// el 系应用的默认滚动物理行为：把 [elScrollPhysicsFor] 接到 Flutter 官方的
/// [ScrollConfiguration] 通道上。
///
/// 挂法（应用根）：
/// ```dart
/// ScrollConfiguration(behavior: const ElScrollBehavior(), child: app)
/// // 或 MaterialApp(scrollBehavior: const ElScrollBehavior())——需要 Material
/// // 那套滚动条 / overscroll 指示器时改用 MaterialScrollBehavior 子类，
/// // 只覆盖 getScrollPhysics 调 elScrollPhysicsFor（见 docs_app）。
/// ```
/// 之后子树里每一个滚动容器（ElScrollView / ElTabView / 官方 Scrollable）都从
/// `ScrollConfiguration.of(context).getScrollPhysics(context)` 取默认物理；想改
/// 就在更靠内的子树再包一层 `ScrollConfiguration`，一条通道管到所有内核。
///
/// 不覆盖 [getPlatform]：官方基类实现恒返回 `defaultTargetPlatform`，够用；
/// Material 侧 `MaterialScrollBehavior.getPlatform` 读的是
/// `Theme.of(context).platform`，那是 Material 的口径，el 不掺和。
class ElScrollBehavior extends ScrollBehavior {
  /// 创建 el 默认滚动物理行为。
  const ElScrollBehavior();

  // 走 getPlatform(context) 而不是硬编码 defaultTargetPlatform：基类实现两者
  // 等价，但硬编码会让官方的 `ScrollBehavior.copyWith(platform: ...)` 失效——
  // 那个副本只覆盖 getPlatform，硬编码就读不到覆盖了。
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => elScrollPhysicsFor(getPlatform(context));
}
