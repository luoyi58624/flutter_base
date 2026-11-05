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
  // LayoutBuilder 可以在布局阶段开启独立的构建范围；捕获样式的 Overlay 也可能在另一条物理分支。
  if (origin == null || reader.depth <= origin.depth || !identical(reader.buildScope, origin.buildScope)) return false;
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
