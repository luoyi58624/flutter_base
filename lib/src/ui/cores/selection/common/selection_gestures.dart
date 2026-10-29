part of 'selection_core.dart';

/// 移动端长按进入选中模式的延时。对齐 Android `ViewConfiguration.DEFAULT_LONG_PRESS_TIMEOUT`
/// = **400ms**（原 500ms 偏慢，与 Editor.java 现行常量不一致）。
const Duration touchLongPressDelay = Duration(milliseconds: 400);

// ---- 手势状态机 --------------------------------------------------------------

/// 选区手势状态机。
enum SelectionPointerState {
  /// 无活动指针。
  idle,

  /// 鼠标按下，未越过 dragThreshold；抬起时按连击数走 clear / 词选 / 段选。
  pendingTap,

  /// 触摸按下，等待长按定时器；移动超过 kTouchSlop 视为滚动手势，直接放弃。
  waitingLongPress,

  /// 已进入选区拖拽（鼠标越过 dragThreshold 或触摸长按触发）。
  dragging,
}

// ---- 纯静态判定 -------------------------------------------------------------

/// 是否为"触摸类"pointer：touch / stylus / invertedStylus / unknown。
///
/// 用于 handle 拖动等与滚动认领无关的 touch-like 判定。
bool isTouchSelectionPointerKind(PointerDeviceKind kind) {
  return kind == PointerDeviceKind.touch ||
      kind == PointerDeviceKind.stylus ||
      kind == PointerDeviceKind.invertedStylus ||
      kind == PointerDeviceKind.unknown;
}

/// 最近滚动祖先是否认领 [kind] 的内容区拖拽滚动。
///
/// 从 [start] 沿父链向上找 [ScrollViewport]；未找到时回退 [kViewportDragDevices]。
/// [selectionRoot] 为选区根 render，遍历在其之前停止。
bool scrollClaimsContentDrag(RenderObject? start, RenderObject selectionRoot, PointerDeviceKind kind) {
  RenderObject? node = start;
  while (node != null && !identical(node, selectionRoot)) {
    if (node is ScrollViewport) {
      return node.effectiveContentDragDevices.contains(kind);
    }
    node = node.parent;
  }
  return kViewportDragDevices.contains(kind);
}

/// 是否为"主键 down"事件：触摸类恒 true；鼠标看 `kPrimaryButton` 是否置位。
bool isPrimaryPointerDown(PointerDownEvent event) {
  if (isTouchSelectionPointerKind(event.kind)) return true;
  return (event.buttons & kPrimaryButton) != 0;
}
