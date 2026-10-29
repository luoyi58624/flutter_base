/// **迁移桩（stub）**：el_ui 的真实 `RenderScrollViewportBase` 位于
/// `cores/scroll/common/render/scroll_viewport_base.dart`（≈86KB，`part` 了
/// virtual scroll 渲染与语义，并拖进 smooth scroll / virtual 引擎）。
///
/// 本次迁移只把 selection 子系统所需的最小闭包搬进 flutter_base，
/// **不搬**该文件。全仓唯一的消费点是
/// `cores/selection/box/box_selection_view.dart` 里双轴滚动的横轴补偿：
///
/// ```dart
/// final cross = viewport is RenderScrollViewportBase && viewport.horizontalPosition != null
///     ? pixels(viewport.horizontalPosition!, viewport.horizontalAxisDirection)
///     : 0.0;
/// ```
///
/// 因此这里只声明该判断用到的两个成员，并把本桩挂在 [ScrollViewport] 之下
/// （真实实现同样 `implements ScrollViewport`），从而让上面的 `is` 判定能发生
/// 类型提升。本包内没有任何实现者，判断恒为 false → 横轴补偿恒走 0.0 分支，
/// 语义等价于「无横向滚动视口」，不会产生错误行为。
///
/// 后续接回真实滚动引擎时：删除本桩，改为 `import` 真实现，并把
/// `scroll/virtual` 闭包一并迁回（见 `.claude/plan/elview-selection-migration.md`）。
library;

import 'package:flutter/rendering.dart' show AxisDirection;
import 'package:flutter/widgets.dart' show ScrollPosition;

import '../viewport/scroll_viewport.dart' show ScrollViewport;

/// 滚动视口的物理、事件、指标和继承基座（此处仅为类型标记桩）。
abstract interface class RenderScrollViewportBase implements ScrollViewport {
  /// 双轴滚动时的横向 position；单轴滚动为 null。
  ScrollPosition? get horizontalPosition;

  /// 双轴滚动时的横向方向。
  AxisDirection get horizontalAxisDirection;
}
