// ignore_for_file: prefer_initializing_formals

// 实验性桌面对象框选，与文本选区独立。

import 'dart:async' show scheduleMicrotask;
import 'dart:collection' show UnmodifiableSetView;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../scroll/viewport.dart' show ScrollViewport;
import '../../view/event/event.dart';
import '../../view/render/render_view.dart';
import '../../view/style/style.dart';
import '../../view/view.dart';
import '../common/selection_auto_scroll.dart';
import '../common/selection_boundary.dart';

part 'box_selection_controller.dart';
part 'box_selectable.dart';
part 'box_selection_painter.dart';

/// 实验性鼠标矩形选择区域，只处理当前根登记的稳定对象值。
///
/// 仅用于试验验证，不适用于生产环境。
class ElBoxSelectionView extends StatefulWidget {
  /// 创建桌面框选区域；不提供文本复制或移动端句柄。
  const ElBoxSelectionView({
    super.key,
    required this.child,
    this.enabled = true,
    this.controller,
    this.onSelectionChanged,
    this.dragThreshold = 4,
    this.autoScroll = true,
    this.selectionColor = const Color(0x334099ff),
  });

  /// 被框选对象的显示子树。
  final Widget child;

  /// 是否允许鼠标框选与键盘选择。
  final bool enabled;

  /// 稳定对象值集合，未传时由宿主创建并销毁。
  final ElBoxSelectionController? controller;

  /// 本次变化的只读差集，避免逐事件复制完整选择集合。
  final ValueChanged<({Set<Object> added, Set<Object> removed, int selectedCount})>? onSelectionChanged;

  /// 鼠标开始框选的移动阈值。
  final double dragThreshold;

  /// 是否在拖动到滚动视口边缘时自动滚动。
  final bool autoScroll;

  /// 选框底色，描边使用同色不透明版本。
  final Color selectionColor;

  @override
  State<ElBoxSelectionView> createState() => _BoxSelectionState();
}

class _BoxSelectionState extends State<ElBoxSelectionView>
    with SingleTickerProviderStateMixin
    implements _BoxSelectionDelegate, SelectionAutoScrollHost {
  late ElBoxSelectionController _controller;
  late final _autoScroll = SelectionAutoScrollController(this);
  final _focus = FocusNode(skipTraversal: true, debugLabel: 'ElBoxSelectionView');
  final _items = <Object, _BoxItemRender>{};
  final _groups = <RenderBox, _BoxGeometryGroup>{};
  final _geometry = <Object, (_BoxGeometryGroup, Rect)>{};
  _BoxRegionRender? _region;
  RenderObject? _downHit;
  Object? _downValue;
  int? _pointer;
  Offset? _lastGlobal;
  Offset? _anchor;
  _BoxGeometryGroup? _anchorGroup;
  Set<Object> _base = const {}, _lastHits = const {};
  bool _dragging = false, _toggle = false, _additive = false, _applying = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ElBoxSelectionController();
    _controller._bind(this);
  }

  @override
  void didUpdateWidget(ElBoxSelectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || oldWidget.controller != widget.controller) _finish();
    if (oldWidget.controller != widget.controller) {
      _controller._unbind(this);
      if (oldWidget.controller == null) _controller.dispose();
      _controller = widget.controller ?? ElBoxSelectionController();
      _controller._bind(this);
      for (final item in _items.values) {
        item.syncSelected();
      }
    }
  }

  @override
  void dispose() {
    _finish();
    _autoScroll.dispose();
    _controller._unbind(this);
    if (widget.controller == null) _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Iterable<Object> get selectableValues =>
      _items.values.where((item) => _itemAvailable(item, visibleOnly: true)).map((item) => item.value);

  bool _itemAvailable(_BoxItemRender item, {required bool visibleOnly}) {
    for (RenderObject? node = item.parent; node != null && node != _region; node = node.parent) {
      if (node is SelectionItemVisibility &&
          !(node as SelectionItemVisibility).isSelectionItemAvailable(item, visibleOnly: visibleOnly)) {
        return false;
      }
    }
    return item.attached && item.hasSize;
  }

  bool _flushGeometry() {
    var changed = false;
    if (_dragging) {
      for (final item in _items.values) {
        changed = _recordGeometry(item) || changed;
      }
    }
    return changed;
  }

  @override
  void selectionChanged(_BoxSelectionChange change) {
    if (_dragging && !_applying) _finish();
    for (final value in change.added.followedBy(change.removed)) {
      _items[value]?.syncSelected();
    }
  }

  @override
  void selectionPublished(_BoxSelectionChange change) => widget.onSelectionChanged?.call(change);

  void _apply({Iterable<Object> added = const [], Iterable<Object> removed = const []}) {
    _applying = true;
    try {
      _controller._applyChanges(added: added, removed: removed);
    } finally {
      _applying = false;
    }
  }

  _BoxGeometryGroup _groupFor(RenderObject item) {
    final region = _region!;
    RenderBox space = region;
    for (RenderObject? node = item; node != null && node != region; node = node.parent) {
      if (node is ScrollViewport) {
        space = node;
        break;
      }
    }
    return _groups.putIfAbsent(space, () => _BoxGeometryGroup(space));
  }

  bool _recordGeometry(_BoxItemRender item) {
    if (!_dragging || _geometry.containsKey(item.value) || !_itemAvailable(item, visibleOnly: false)) return false;
    final group = _groupFor(item);
    final rect = MatrixUtils.transformRect(
      item.getTransformTo(group.space),
      Offset.zero & item.size,
    ).shift(-group.scrollOffset);
    _geometry[item.value] = (group, rect);
    group.add(item.value, rect);
    // 虚拟新项先用未选中的首次布局冻结命中盒，再同步样式并完成本帧布局。
    if (_lastGlobal != null) {
      final hit = group.rectInRoot(rect, _region!).overlaps(_dragRect());
      if (hit) _lastHits.add(item.value);
      final selected = _toggle ? _base.contains(item.value) != hit : _base.contains(item.value) || hit;
      final changed = selected != _controller.isSelected(item.value);
      _apply(added: selected ? [item.value] : const [], removed: selected ? const [] : [item.value]);
      return changed;
    }
    return false;
  }

  bool _owns(ElEventDetails event) =>
      event.originalEvent is PointerEvent && (event.originalEvent! as PointerEvent).pointer == _pointer;

  void _down(ElEventDetails event) {
    final pointer = event.originalEvent;
    if (!widget.enabled ||
        pointer is! PointerDownEvent ||
        pointer.kind != PointerDeviceKind.mouse ||
        _pointer != null) {
      return;
    }
    final region = _region!;
    final hits = BoxHitTestResult();
    region.hitTest(hits, position: region.globalToLocal(event.globalPosition));
    final deepest = hits.path.map((entry) => entry.target).whereType<RenderObject>().firstOrNull;
    Object? value;
    for (RenderObject? node = deepest; node != null && node != region; node = node.parent) {
      if (node is _BoxRegionRender) return;
      if (node is _BoxItemRender) value ??= node.value;
    }
    _pointer = pointer.pointer;
    _downHit = deepest ?? region;
    _downValue = value;
    _lastGlobal = event.globalPosition;
    _anchorGroup = _groupFor(_downHit!);
    _anchor = _anchorGroup!.space.globalToLocal(event.globalPosition) - _anchorGroup!.scrollOffset;
    _toggle = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    _additive = HardwareKeyboard.instance.isShiftPressed;
  }

  void _tapUp(ElEventDetails event) {
    if (!_owns(event) || _dragging) return;
    final value = _downValue;
    if (value == null) {
      if (!_toggle && !_additive) _controller.clear();
    } else if (_toggle && _controller.isSelected(value)) {
      _controller.deselect(value);
    } else {
      _apply(added: [value], removed: _toggle || _additive ? const [] : _controller.selectedValues.toList());
    }
    _finish();
  }

  void _dragStart(ElEventDetails event) {
    if (!_owns(event) || _dragging || !widget.enabled) return;
    event.eagerGesture(cancelSelfTap: true);
    _base = _toggle || _additive ? _controller.selectedValues.toSet() : const {};
    _lastHits = <Object>{};
    _dragging = true;
    _focus.requestFocus();
    // 冻结全部已布局对象，之后只收集虚拟化新挂载的真实对象。
    final last = _lastGlobal;
    _lastGlobal = null;
    for (final item in _items.values) {
      _recordGeometry(item);
    }
    _lastGlobal = last;
    if (!_toggle && !_additive) _apply(removed: _controller.selectedValues.toList());
    GestureBinding.instance.pointerRouter.addGlobalRoute(_globalRoute);
    _update(event.globalPosition);
  }

  Rect _dragRect() {
    final group = _anchorGroup!;
    final start = _region!.globalToLocal(group.space.localToGlobal(_anchor! + group.scrollOffset));
    return Rect.fromPoints(start, _region!.globalToLocal(_lastGlobal!));
  }

  void _update(Offset global) {
    if (!_dragging || _region == null) return;
    _lastGlobal = global;
    final rect = _dragRect();
    _region!.marquee = rect;
    final hits = <Object>{};
    for (final group in _groups.values) {
      hits.addAll(group.query(rect, _region!));
    }
    final added = <Object>{}, removed = <Object>{};
    for (final value in hits.difference(_lastHits)) {
      if (_toggle && _base.contains(value)) {
        removed.add(value);
      } else {
        added.add(value);
      }
    }
    for (final value in _lastHits.difference(hits)) {
      if (_toggle && _base.contains(value)) {
        added.add(value);
      } else if (!_base.contains(value)) {
        removed.add(value);
      }
    }
    _lastHits = hits;
    _apply(added: added, removed: removed);
    _autoScroll.updateForDrag(global, activateAutoScroll: widget.autoScroll);
  }

  void _globalRoute(PointerEvent event) {
    if (event is PointerSignalEvent && _dragging) _autoScroll.dispatchPointerSignalToDragViewport(event);
  }

  void _finish() {
    if (_dragging) GestureBinding.instance.pointerRouter.removeGlobalRoute(_globalRoute);
    _autoScroll.stop();
    _autoScroll.clearDragScrollViewports();
    _pointer = null;
    _dragging = false;
    _downHit = null;
    _downValue = null;
    _anchor = _lastGlobal = null;
    _anchorGroup = null;
    _base = _lastHits = const {};
    _geometry.clear();
    _groups.clear();
    _region?.marquee = null;
  }

  void _key(ElEventDetails event) {
    if (!widget.enabled) return;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _finish();
      _controller.clear();
      event
        ..preventDefault()
        ..stopPropagation();
    } else if (event.logicalKey == LogicalKeyboardKey.keyA &&
        (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed)) {
      _finish();
      _controller.selectAll();
      event
        ..preventDefault()
        ..stopPropagation();
    }
  }

  Widget _blockSelection(Widget child) => SelectionContainer.disabled(child: child);

  @override
  Widget build(BuildContext context) {
    // 框选区域只在启用时可请求焦点；节点由本 State 持有，切换时直接同步开关。
    _focus.canRequestFocus = widget.enabled;
    return _buildContent();
  }

  Widget _buildContent() => _blockSelection(
    SelectionTextBoundary(
      child: SelectionTextBlock(
        child: _BoxScope(
          owner: this,
          controller: _controller,
          child: _BoxRegionWidget(
            owner: this,
            child: ElView(
              style: const ElStyle(backgroundColor: Color(0x00000000)),
              focusNode: _focus,
              event: ElEvent(
                dragStartDistance: widget.dragThreshold,
                dragDevices: const {PointerDeviceKind.mouse},
                onTapDown: _down,
                onTapUp: _tapUp,
                onTapCancel: (event) {
                  if (event.cancelReason == ElEventCancelReason.otherGestureAccepted ||
                      event.cancelReason == ElEventCancelReason.external) {
                    if (!_owns(event)) return;
                    _finish();
                  }
                },
                onDragStart: _dragStart,
                onDragUpdate: (event) {
                  if (_owns(event)) _update(event.globalPosition);
                },
                onDragEnd: (event) {
                  if (!_owns(event)) return;
                  if (_dragging) _update(event.globalPosition);
                  _finish();
                },
                onDragCancel: (event) {
                  if (_owns(event)) _finish();
                },
                onPointerCancel: (event) {
                  if (_owns(event)) _finish();
                },
                onBlur: (_) => _finish(),
                onKeyDown: _key,
              ),
              child: _BoxContentBoundary(child: widget.child),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  PointerDeviceKind? get activePointerKind => _pointer == null ? null : PointerDeviceKind.mouse;
  @override
  bool get isPointerDragging => _dragging;
  @override
  bool get isHandleDragInProgress => false;
  @override
  RenderObject? get referenceParticipantForAutoScroll => _anchorGroup?.space ?? _downHit;
  @override
  RenderObject? get anchorParticipantForAutoScroll => _anchorGroup?.space ?? _downHit;
  @override
  RenderObject get autoScrollRoot => _region!;
  @override
  Ticker createAutoScrollTicker(TickerCallback onTick) => createTicker(onTick);
  @override
  void syncSelectionAfterScrollDelta() {
    if (_lastGlobal != null) _update(_lastGlobal!);
  }

  @override
  void invalidateParticipantGeometry() {} // 索引使用内容坐标，纯滚动只改变查询变换。
  @override
  bool get selectionUsesMobileAutoScroll => false;
  @override
  bool isTouchSelectionPointer(PointerDeviceKind kind) => false;
  @override
  SelectionAutoScrollConfig autoScrollConfigFor({required bool touch}) => SelectionAutoScrollConfig.mouse;
}

class _BoxGeometryGroup {
  _BoxGeometryGroup(this.space);
  final RenderBox space;
  final _entries = <Object, Rect>{};
  SelectionRectIndex<Object>? _index;
  Offset get scrollOffset {
    final viewport = space;
    if (viewport is! ScrollViewport) return Offset.zero;
    double pixels(ScrollPosition position, AxisDirection direction) =>
        !position.hasPixels || !position.hasContentDimensions
        ? 0
        : axisDirectionIsReversed(direction)
        ? position.maxScrollExtent - position.pixels
        : position.pixels;
    final main = pixels(viewport.position, viewport.axisDirection);
    // 官方视口只有单一主轴，双轴滚动由内外两层视口各自贡献偏移。
    return viewport.axis == Axis.vertical ? Offset(0, -main) : Offset(-main, 0);
  }

  void add(Object value, Rect rect) {
    _entries[value] = rect;
    _index?.add((rect: rect, value: value));
  }

  Rect rectInRoot(Rect rect, RenderBox root) =>
      MatrixUtils.transformRect(space.getTransformTo(root), rect.shift(scrollOffset));
  Iterable<Object> query(Rect rect, RenderBox root) sync* {
    if (!space.attached) return;
    final local = MatrixUtils.transformRect(root.getTransformTo(space), rect).shift(-scrollOffset);
    final index = _index ??= SelectionRectIndex(_entries.entries.map((entry) => (rect: entry.value, value: entry.key)));
    for (final value in index.query(local)) {
      if (rectInRoot(_entries[value]!, root).overlaps(rect)) yield value;
    }
  }
}
