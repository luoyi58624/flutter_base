part of 'sliver.dart';

// 与 recycler 共用几何，普通 builder 只创建官方 delegate 的子树，不创建换绑包装。
class _BuilderElement extends _RecyclerElement {
  _BuilderElement(super.widget);

  final Map<int, _Slot> _kept = {};
  int _preparedGeneration = -1;
  late BuildScope _outerScope;

  @override
  BuildScope get buildScope => _outerScope;

  @override
  void mount(Element? parent, Object? newSlot) {
    _outerScope = parent!.buildScope;
    super.mount(parent, newSlot);
  }

  @override
  void activate() {
    super.activate();
    visitAncestorElements((element) {
      _outerScope = element.buildScope;
      return false;
    });
  }

  @override
  void _prepareLayout() {
    if (_preparedGeneration == _generation) return;
    _preparedGeneration = _generation;
    owner!.buildScope(this, () {
      final delegate = _widget.delegate!;
      final previous = _slots.toList(growable: false);
      _active.clear();
      _kept.clear();
      var moved = false;
      for (final slot in previous) {
        final oldIndex = slot.indexValue;
        final key = slot.child?.widget.key;
        final index = key != null && delegate.findChildIndexCallback != null ? delegate.findIndexByKey(key) : oldIndex;
        if (index == null || index < 0 || index >= _widget._childCount) {
          _discard(slot);
          continue;
        }
        moved |= index != oldIndex;
        slot.indexValue = index;
        (slot.active ? _active : _kept)[index] = slot;
      }
      if (moved) renderObject._extents = null;
      for (final slot in _slots.toList(growable: false)) {
        _updateSlot(slot, active: slot.active, index: slot.indexValue);
      }
    });
  }

  @override
  void _updateSlot(_Slot slot, {required bool active, int? index}) {
    slot.active = active;
    if (index != null) slot.indexValue = index;
    if (slot.child != null && slot.generation == _generation) return;
    slot.generation = _generation;
    slot.child = updateChild(slot.child, _widget.delegate!.build(this, slot.indexValue), slot);
  }

  @override
  _Slot _obtain(int index) {
    var slot = _active[index];
    if (slot != null) return slot;
    slot = _kept.remove(index) ?? _Slot(_widget.itemType?.call(index), index);
    _slots.add(slot);
    _active[index] = slot;
    return slot;
  }

  @override
  RenderBox _layoutItem(int index, BoxConstraints constraints) {
    final slot = _obtain(index);
    if (slot.child == null || slot.generation != _generation) {
      owner!.buildScope(this, () => _updateSlot(slot, active: true, index: index));
    }
    slot.active = true;
    final box = slot.box!;
    box.layout(constraints, parentUsesSize: true);
    return box;
  }

  @override
  void _retire(_Slot slot) {
    _active.remove(slot.indexValue);
    slot.active = false;
    if ((slot.box!.parentData! as _RecyclerParentData).keepAlive) {
      _kept[slot.indexValue] = slot;
    } else {
      _discard(slot);
    }
  }

  @override
  void _discard(_Slot slot) {
    _kept.remove(slot.indexValue);
    super._discard(slot);
    slot.dispose();
  }

  @override
  void _discardInvalidSpares() {}

  @override
  void _finishLayout(Set<int> wanted) {
    for (final entry in _active.entries.toList(growable: false)) {
      if (!wanted.contains(entry.key)) _retire(entry.value);
    }
    for (final slot in _kept.values.toList(growable: false)) {
      final box = slot.box!;
      if (!(box.parentData! as _RecyclerParentData).keepAlive) {
        _discard(slot);
      } else if (box.hasSize) {
        box.layout(box.constraints, parentUsesSize: false);
      }
    }
    final changed = wanted.length != _visibleIndices.length || _visibleIndices.any((i) => !wanted.contains(i));
    if (changed) _visibleIndices = wanted.toList()..sort();
    if (changed || _laidOutGeneration != _generation) renderObject.markNeedsSemanticsUpdate();
    _laidOutGeneration = _generation;
    if (_visibleIndices.isNotEmpty) _widget.delegate!.didFinishLayout(_visibleIndices.first, _visibleIndices.last);
  }

  @override
  void forgetChild(Element child) {
    final slot = child.slot! as _Slot;
    _kept.remove(slot.indexValue);
    super.forgetChild(child);
  }

  @override
  void unmount() {
    for (final slot in _slots) {
      slot.dispose();
    }
    super.unmount();
  }
}
