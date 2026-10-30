import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'scroll_position_binding.dart';

/// position 换绑无感的滚动 offset 变更中继。
///
/// Scrollable 在 didChangeDependencies / 控制器与物理变更时**重建 ScrollPosition
/// 实例**（官方同款行为，路由转场如预测性返回也会触发）。直接
/// `position.addListener` 的长期监听会在换绑后挂在已 dispose 的旧实例上永久失聪
/// ——选区句柄滚动同步就曾因此在预测性返回后脱位。viewport render 持有本中继并
/// 在 position setter 里换绑转接，外部监听者无感。
class ScrollOffsetRelay extends ChangeNotifier {
  /// viewport render 在滚动 offset 变化时转发。
  void notify() => notifyListeners();
}

/// Shared contract for scrollable render viewports used by selection.
abstract interface class ScrollViewport implements RenderBox {
  ScrollPosition get position;

  /// 滚动 offset 变更的稳定监听通道（跨 [position] 实例换绑存活）。
  ///
  /// 长期监听（如选区端点滚动同步）必须挂这里而不是 `position.addListener`。
  Listenable get scrollOffsetListenable;
  Axis get axis;
  AxisDirection get axisDirection;
  Clip get clipBehavior;

  /// 正文可滚动区域的本地矩形，扣除占位滚动条，保留正文自身 padding。
  Rect get contentViewportRect;

  bool containsGlobalPosition(Offset globalPosition);
  bool get hasActivePointerScrollActivity;
  bool canConsumePointerScrollEvent(PointerScrollEvent event);

  /// 把外部 chrome 命中的滚轮事件直接交给本视口滚动编排。
  bool dispatchPointerScroll(PointerScrollEvent event);
  void cancelPointerScrollActivity();
  bool isAncestorOf(RenderObject node);
  bool dispatchSelectionPointerSignal(PointerSignalEvent event);
  double applySelectionAutoScrollDelta(double delta);

  /// 内容区拖拽滚动认领的 pointer 种类集合。
  ///
  /// 未显式配置 [dragDevices] 时等价于 [kViewportDragDevices]。
  Set<PointerDeviceKind> get effectiveContentDragDevices;
}
