import 'package:flutter/foundation.dart' show VoidCallback, internal;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show Element;

Element? _buildOrigin;

/// 在 Flutter 更新视图渲染对象期间，记录已知处于构建分支中的 Element。
@internal
void withBuildDependencyOrigin(Element origin, VoidCallback update) {
  final previous = _buildOrigin;
  _buildOrigin = origin;
  try {
    update();
  } finally {
    _buildOrigin = previous;
  }
}

/// 当前帧能否安全地将样式读者加入构建队列。
@internal
bool canMarkBuildDependent(Element reader) {
  if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) return true;
  final origin = _buildOrigin;
  // 物理后代可交给各自构建域在本帧调度，LayoutBuilder 会在布局阶段重建；跨 Overlay 读者仍需延期。
  if (origin == null || reader.depth <= origin.depth) return false;
  var isDescendant = false;
  reader.visitAncestorElements((ancestor) {
    isDescendant = identical(ancestor, origin);
    return ancestor.depth > origin.depth;
  });
  return isDescendant;
}

/// 在当前帧结束后派发，并保证读者能在下一帧重建。
@internal
void scheduleBuildDependencyFlush(FrameCallback flush) {
  final binding = SchedulerBinding.instance;
  binding.addPostFrameCallback(flush);
  binding.scheduleFrame();
}
