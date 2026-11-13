import 'package:flutter/widgets.dart';

import 'child_source.dart';
import 'layout.dart';
import 'render.dart';
import 'slots.dart';

/// builder 生命周期：只构建缓存窗口，离开窗口即销毁，沿用官方 delegate 的包装、KeepAlive 与 Key 规则。
abstract class BuilderSliver extends RenderObjectWidget {
  const BuilderSliver({super.key, required this.delegate, required this.childCount, this.itemType});

  final SliverChildBuilderDelegate delegate;

  /// 布局条目数，分隔符列表中包含分隔符。
  final int childCount;

  /// 尺寸估值的分组，未指定时所有条目共用一个估值。
  final Object? Function(int index)? itemType;

  SliverLayoutSpec get spec;

  @override
  RenderObjectElement createElement() => BuilderElement(this);

  @override
  RenderNaturalSliver createRenderObject(BuildContext context) => RenderNaturalSliver(context as BuilderElement, spec);

  @override
  void updateRenderObject(BuildContext context, RenderNaturalSliver renderObject) {
    renderObject
      ..spec = spec
      ..scheduleLayoutCallback();
  }
}

// 子树属于外层 BuildScope：条目自身的 setState 走正常 build 阶段，只有创建与配置刷新发生在布局中。
class BuilderElement extends RenderObjectElement with SlotRegistry<Slot> {
  BuilderElement(BuilderSliver super.widget);

  // 离开窗口但请求了 KeepAlive 的槽位。
  final Map<int, Slot> kept = {};
  int _prepared = -1;

  BuilderSliver get _config => widget as BuilderSliver;

  @override
  int get childCount => _config.childCount;

  @override
  bool get hasTypes => _config.itemType != null;

  @override
  Object? typeOf(int index) => _config.itemType!(index);

  bool _keepsAlive(Slot slot) => (slot.box!.parentData! as NaturalSliverParentData).keepAlive;

  void _refresh(Slot slot) {
    slot.generation = generation;
    slot.child = updateChild(slot.child, _config.delegate.build(this, slot.index), slot);
  }

  void _discard(Slot slot) {
    if (identical(kept[slot.index], slot)) kept.remove(slot.index);
    discard(slot);
  }

  @override
  bool beginLayout() {
    if (_prepared == generation) return false;
    _prepared = generation;
    var moved = false;
    owner!.buildScope(this, () {
      final delegate = _config.delegate;
      final count = childCount;
      final placed = <int, Slot>{};
      final stayed = <Slot>[];
      // 按 Key 找到新序号的槽位优先占位；原地不动的槽位与它冲突时销毁，不留下脱离登记的子树。
      for (final slot in slots.toList(growable: false)) {
        final key = slot.child?.widget.key;
        final index = key != null && delegate.findChildIndexCallback != null
            ? delegate.findIndexByKey(key)
            : slot.index;
        if (index == null || index < 0 || index >= count) {
          discard(slot);
        } else if (index == slot.index) {
          stayed.add(slot);
        } else if (placed.containsKey(index)) {
          discard(slot);
        } else {
          moved = true;
          slot.index = index;
          placed[index] = slot;
        }
      }
      for (final slot in stayed) {
        if (placed.containsKey(slot.index)) {
          discard(slot);
        } else {
          placed[slot.index] = slot;
        }
      }
      active.clear();
      kept.clear();
      for (final slot in placed.values) {
        (slot.active ? active : kept)[slot.index] = slot;
        _refresh(slot);
      }
    });
    return moved;
  }

  // 回收即销毁，窗口确定前不回收：边界条目不会在同一轮先销毁再重建而丢失 State。
  @override
  void prepareWindow(List<int> window) {}

  @override
  RenderBox layoutChild(int index, BoxConstraints constraints) {
    var slot = active[index];
    if (slot == null) {
      slot = kept.remove(index) ?? Slot(null, index);
      slots.add(slot);
      active[index] = slot;
    }
    if (slot.child == null || slot.generation != generation) {
      final target = slot;
      owner!.buildScope(this, () => _refresh(target));
    }
    slot.active = true;
    return slot.box!..layout(constraints, parentUsesSize: true);
  }

  @override
  void endLayout(List<int> window) {
    final contains = windowMembership(window);
    final retired = [
      for (final entry in active.entries)
        if (!contains(entry.key)) entry.value,
    ];
    for (final slot in retired) {
      active.remove(slot.index);
      slot.active = false;
      kept[slot.index] = slot;
    }
    final dropped = [
      for (final slot in kept.values)
        if (!_keepsAlive(slot)) slot,
    ];
    if (dropped.isNotEmpty) owner!.buildScope(this, () => dropped.forEach(_discard));
    this.window = window;
    if (window.isNotEmpty) _config.delegate.didFinishLayout(window.first, window.last);
  }

  @override
  Iterable<RenderBox> get parked => kept.values.map((slot) => slot.box!);

  @override
  void forgetChild(Element child) {
    final slot = child.slot! as Slot;
    if (identical(kept[slot.index], slot)) kept.remove(slot.index);
    super.forgetChild(child);
  }
}
