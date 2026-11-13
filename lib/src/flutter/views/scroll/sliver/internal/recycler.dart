import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../../utils/internal/reuse_animation.dart';
import 'child_source.dart';
import 'index_controller.dart';
import 'layout.dart';
import 'render.dart';
import 'slots.dart';

/// recycler 生命周期：离开窗口的子树按类型入池，换绑时保留 Element、State 和 RenderObject。
abstract class RecyclerSliver extends RenderObjectWidget {
  const RecyclerSliver({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.itemType,
    this.maxRecycledItems = 32,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
  }) : assert(itemCount >= 0),
       assert(maxRecycledItems >= 0);

  final int itemCount;

  /// 创建槽位内容，序号改变时由内容自己的监听器更新数据。
  ///
  /// 父组件更新配置或构建上下文依赖变化时可以重新调用此构建器。
  /// 监听对象由容器持有；事件执行时读取最新 value。
  final Widget Function(BuildContext context, ValueListenable<int> index) itemBuilder;

  /// 返回可相互复用的结构类型，未指定时所有条目属于同一类型。
  final Object? Function(int index)? itemType;

  /// 所有类型合计最多保留的空闲槽位数，不包含当前缓存窗口。
  /// 设为零仍允许同一轮布局先回收再复用。
  final int maxRecycledItems;

  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;

  SliverLayoutSpec get spec;

  /// 按序号定位的内部通道，仅列表开放。
  SliverIndexChannel? get channel => null;

  @override
  RenderObjectElement createElement() => RecyclerElement(this);

  @override
  RenderNaturalSliver createRenderObject(BuildContext context) =>
      RenderNaturalSliver(context as RecyclerElement, spec)..channel = channel;

  @override
  void updateRenderObject(BuildContext context, RenderNaturalSliver renderObject) {
    renderObject
      ..spec = spec
      ..channel = channel
      ..scheduleLayoutCallback();
  }
}

class IndexBinding extends ChangeNotifier implements ValueListenable<int> {
  IndexBinding(this._value);

  int _value;

  @override
  int get value => _value;

  void bind(int value, {bool refresh = false}) {
    if (_value == value && !refresh) return;
    _value = value;
    notifyListeners();
  }
}

class RecyclerSlot extends Slot {
  RecyclerSlot(super.type, super.index);

  late final IndexBinding binding = IndexBinding(index);
  late final ReuseAnimationState animation = ReuseAnimationState();
  late final FocusNode focusNode = FocusNode(canRequestFocus: false, skipTraversal: true);
  Widget? content;

  void dispose() {
    binding.dispose();
    focusNode.dispose();
  }
}

class RecyclerElement extends RenderObjectElement with SlotRegistry<RecyclerSlot> {
  RecyclerElement(RecyclerSliver super.widget);

  final Map<Object?, List<RecyclerSlot>> pool = {};
  // 独立作用域保证子树只在布局中、绑定到有效序号之后刷新，不会以过期序号重建。
  late final BuildScope _scope = BuildScope(scheduleRebuild: _markScopeDirty);
  bool _scopeDirty = false;

  RecyclerSliver get _config => widget as RecyclerSliver;

  @override
  BuildScope get buildScope => _scope;

  @override
  int get childCount => _config.itemCount;

  @override
  bool get hasTypes => _config.itemType != null;

  @override
  Object? typeOf(int index) => _config.itemType?.call(index);

  void _markScopeDirty() {
    _scopeDirty = true;
    scheduleRelayout();
  }

  // 作用域内没有脏子树、槽位也无需更新时，条目布局不必进入 buildScope。
  void _build(VoidCallback callback) {
    owner!.buildScope(this, callback);
    _scopeDirty = false;
  }

  void _update(RecyclerSlot slot, {required bool active, int? index}) {
    final rebound = index != null && slot.index != index;
    final refresh = active && slot.generation != generation;
    if (slot.child != null && slot.active == active && !rebound && !refresh) return;
    if (!active || rebound) slot.focusNode.unfocus();
    if (index != null) {
      slot.index = index;
      slot.binding.bind(index, refresh: refresh);
    }
    if (refresh) {
      slot.generation = generation;
      // 索引语义独立更新，child 保留业务结构，单纯换绑无需重新配置外层状态包装。
      final content = Builder(builder: (context) => _config.itemBuilder(context, slot.binding));
      slot.content = _config.addSemanticIndexes
          ? ValueListenableBuilder<int>(
              valueListenable: slot.binding,
              child: content,
              builder: (_, value, child) => IndexedSemantics(index: value, child: child!),
            )
          : content;
    }
    if (slot.child != null && slot.active == active && !refresh) return;
    slot.active = active;
    slot.child = updateChild(
      slot.child,
      ItemBoundary(
        slot: slot,
        repaintBoundary: _config.addRepaintBoundaries,
        child: TickerMode(
          enabled: active,
          child: HeroMode(
            enabled: active,
            child: Focus(
              focusNode: slot.focusNode,
              canRequestFocus: false,
              skipTraversal: true,
              descendantsAreFocusable: active,
              descendantsAreTraversable: active,
              child: ReuseAnimationScope(state: slot.animation, child: slot.content!),
            ),
          ),
        ),
      ),
      slot,
    );
    if (!active) (slot.box as ItemRenderBoundary?)?.visible = false;
  }

  void _retire(RecyclerSlot slot) {
    active.remove(slot.index);
    (pool[slot.type] ??= []).add(slot);
  }

  RecyclerSlot _obtain(int index) {
    final type = typeOf(index);
    var slot = active[index];
    if (slot != null && slot.type != type) {
      _retire(slot);
      slot = null;
    }
    if (slot == null) {
      final candidates = pool[type];
      if (candidates == null || candidates.isEmpty) {
        slot = RecyclerSlot(type, index);
        slots.add(slot);
      } else {
        slot = candidates.removeLast();
        if (candidates.isEmpty) pool.remove(type);
      }
      active[index] = slot;
    }
    return slot;
  }

  // 必须在 buildScope 刷新脏子树前丢弃失效绑定，避免越界或旧结构读取新类型的数据。
  void _discardInvalidSpares() {
    final count = childCount;
    pool.removeWhere((type, candidates) {
      candidates.removeWhere((slot) {
        if (slot.index < count && slot.type == typeOf(slot.index)) return false;
        discard(slot);
        return true;
      });
      return candidates.isEmpty;
    });
  }

  @override
  bool beginLayout() {
    final count = childCount;
    _build(() {
      for (final entry in active.entries.toList(growable: false)) {
        // 先保留到本轮结束，零容量池也可以马上把槽位交给新条目。
        if (entry.key >= count || entry.value.type != typeOf(entry.key)) _retire(entry.value);
      }
      _discardInvalidSpares();
    });
    return false;
  }

  @override
  void prepareWindow(List<int> window) {
    final contains = windowMembership(window);
    for (final entry in active.entries.toList(growable: false)) {
      if (!contains(entry.key)) _retire(entry.value);
    }
  }

  @override
  RenderBox layoutChild(int index, BoxConstraints constraints) {
    final slot = _obtain(index);
    final rebound = slot.index != index;
    if (rebound || !slot.active || slot.child == null || slot.generation != generation || _scopeDirty) {
      void updateAndLayout() {
        _build(() => _update(slot, active: true, index: index));
        slot.box!.layout(constraints, parentUsesSize: true);
      }

      // 换记录时让构建与布局共享局部作用域，同一记录的状态更新继续正常过渡。
      if (rebound) {
        slot.animation.runRebind(updateAndLayout);
      } else {
        updateAndLayout();
      }
    } else {
      slot.box!.layout(constraints, parentUsesSize: true);
    }
    return slot.box!;
  }

  @override
  void endLayout(List<int> window) {
    final contains = windowMembership(window);
    _build(() {
      for (final entry in active.entries.toList(growable: false)) {
        if (!contains(entry.key)) _retire(entry.value);
      }
      _discardInvalidSpares();
      var spares = pool.values.fold(0, (count, candidates) => count + candidates.length);
      while (spares > _config.maxRecycledItems) {
        final type = pool.keys.first;
        final candidates = pool[type]!;
        discard(candidates.removeAt(0));
        spares--;
        if (candidates.isEmpty) pool.remove(type);
      }
      for (final candidates in pool.values) {
        for (final slot in candidates) {
          _update(slot, active: false);
        }
      }
    });
    this.window = window;
  }

  @override
  Iterable<RenderBox> get parked sync* {
    for (final candidates in pool.values) {
      for (final slot in candidates) {
        if (slot.box case final box?) yield box;
      }
    }
  }

  @override
  void forgetChild(Element child) {
    final slot = child.slot! as RecyclerSlot;
    final candidates = pool[slot.type];
    if (candidates != null && candidates.remove(slot) && candidates.isEmpty) pool.remove(slot.type);
    super.forgetChild(child);
  }
}

class ItemBoundary extends SingleChildRenderObjectWidget {
  const ItemBoundary({super.key, required this.slot, required this.repaintBoundary, required super.child});

  final RecyclerSlot slot;
  final bool repaintBoundary;

  @override
  ItemRenderBoundary createRenderObject(BuildContext context) => ItemRenderBoundary(repaintBoundary);

  @override
  void updateRenderObject(BuildContext context, ItemRenderBoundary renderObject) {
    if (renderObject.repaintBoundary == repaintBoundary) return;
    renderObject
      ..repaintBoundary = repaintBoundary
      ..markNeedsCompositingBitsUpdate()
      ..markNeedsPaint();
  }

  @override
  void didUnmountRenderObject(covariant ItemRenderBoundary renderObject) {
    // 在后代 State.dispose 完成后释放绑定，池淘汰时只 deactivate 还不够。
    slot.dispose();
  }
}

class ItemRenderBoundary extends RenderRepaintBoundary implements ViewportVisibility {
  ItemRenderBoundary(this.repaintBoundary);

  bool repaintBoundary;
  bool _visible = false;

  @override
  bool get isRepaintBoundary => repaintBoundary;

  @override
  set visible(bool value) {
    if (_visible == value) return;
    _visible = value;
    // 取消离屏边界的旧图层挂接，避免脏子树在 flushPaint 中独立重画。
    if (!value) layer?.remove();
  }
}
