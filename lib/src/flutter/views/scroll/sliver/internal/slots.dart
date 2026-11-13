import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'child_source.dart';
import 'render.dart';

/// builder 与 recycler 共用的槽位登记和 RenderObject 子节点协议。
///
/// 子树只在布局阶段按窗口构建：配置或依赖变化仅递增 [generation] 并请求重新布局，
/// 槽位在下一次被布局时按版本刷新。
mixin SlotRegistry<S extends Slot> on RenderObjectElement implements SliverChildSource {
  final Set<S> slots = {};
  final Map<int, S> active = {};
  List<int> window = const [];
  bool _deferred = false;

  @override
  int generation = 0;

  @override
  bool get mountsAll => false;

  @override
  RenderNaturalSliver get renderObject => super.renderObject as RenderNaturalSliver;

  @override
  RenderBox? childAt(int index) => active[index]?.box;

  // 与 LayoutBuilder 一致：帧外的请求推迟到下一帧开始，避免在空闲阶段改动布局脏标记。
  void scheduleRelayout() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.idle && phase != SchedulerPhase.postFrameCallbacks) {
      renderObject.scheduleLayoutCallback();
    } else if (!_deferred) {
      _deferred = true;
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        _deferred = false;
        if (mounted) renderObject.scheduleLayoutCallback();
      });
    }
  }

  @override
  void markNeedsBuild() {
    generation++;
    scheduleRelayout();
  }

  @override
  void update(covariant RenderObjectWidget newWidget) {
    generation++;
    super.update(newWidget);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    for (final slot in slots.toList(growable: false)) {
      if (slot.child case final child?) visitor(child);
    }
  }

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    for (final index in window) {
      if (active[index]?.child case final child?) visitor(child);
    }
  }

  @override
  void insertRenderObjectChild(RenderBox child, covariant S slot) {
    renderObject.insert(child, after: renderObject.lastChild);
    (child.parentData! as NaturalSliverParentData).slot = slot;
    slot.box = child;
  }

  @override
  void moveRenderObjectChild(RenderBox child, covariant S oldSlot, covariant S newSlot) {
    oldSlot.box = null;
    newSlot.box = child;
    (child.parentData! as NaturalSliverParentData).slot = newSlot;
  }

  @override
  void removeRenderObjectChild(RenderBox child, covariant S slot) {
    slot.box = null;
    renderObject.remove(child);
  }

  @override
  void forgetChild(Element child) {
    final slot = child.slot! as S;
    slots.remove(slot);
    if (identical(active[slot.index], slot)) active.remove(slot.index);
    slot.child = null;
    super.forgetChild(child);
  }

  /// 卸载槽位的子树并注销登记。
  void discard(S slot) {
    slots.remove(slot);
    slot.child = updateChild(slot.child, null, slot);
  }
}
