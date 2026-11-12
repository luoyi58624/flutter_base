import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show GestureBinding, PointerDownEvent, PointerEvent;
import 'package:flutter/services.dart' show HardwareKeyboard, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

import '../../../utils/internal/benchmark_probe.dart' show BenchmarkProbe, MountTrace, elMountTraceEnabled;
import '../../../utils/internal/focus.dart';
import '../content.dart';
import '../event/event.dart';
import '../render/render_view.dart';
import '../semantics/semantics_frame.dart';
import '../style/cascade/style_spec.dart';
import '../style/state/view_state.dart';
import '../style/style_context.dart';
import '../view.dart';
import 'content_binding.dart';

part 'focus.dart';
part 'focus_indicator.dart';

/// ElView 的 Element：负责渲染树挂载、样式/事件推送与最小焦点集成。
///
/// 焦点只做三件事：把节点挂到最近的 Flutter [Focus]（无则根 scope）、把
/// 三态（focus / focusWithin / focusVisible）同步给渲染层、转发指针聚焦与
/// 键盘回调。Tab/方向键遍历、焦点恢复、区域归属一律交给 Flutter。
class ViewElement extends RenderObjectElement implements ContentElementHost {
  ViewElement(ElView super.widget);

  Element? _child;
  ContentElementBinding? _contentBinding;
  ValueListenable<Object?>? _childListenable;
  bool _childNeedsUpdate = false;
  bool _updatingContent = false;

  /// 焦点集成：只有声明了焦点来源的视图才持有，见 [_FocusSources._syncFocus]。
  _ViewFocus? _focus;

  bool _deactivated = false;

  /// 元素是否处于活动树；失活后不能再做祖先查找，延迟回调须先检查。挂载过程中视为活动。
  bool get isActiveInTree => !_deactivated;

  ElView get _view => widget as ElView;
  ElRenderView get _renderView => renderObject as ElRenderView;

  @override
  BuildContext get context => this;

  @override
  ElRenderView get renderView => _renderView;

  @override
  Element? updateContentChild(Element? child, Widget? widget, Object? slot) => updateChild(child, widget, slot);

  @override
  List<Element> updateContentChildren(List<Element> children, List<Widget> widgets, Set<Element>? forgottenChildren) =>
      updateChildren(children, widgets, forgottenChildren: forgottenChildren);

  // 渲染层按需回读主焦点；读元素当前的焦点对象，换节点后不会留下指向旧节点的闭包。
  bool _focusSemanticsGetter() => _focus?.node.hasPrimaryFocus ?? false;

  // --- Element lifecycle -------------------------------------------------

  @override
  void mount(Element? parent, Object? newSlot) {
    final trace = elMountTraceEnabled ? (Stopwatch()..start()) : null;
    super.mount(parent, newSlot);
    if (trace != null) {
      MountTrace.superMountUs += trace.elapsedMicroseconds;
      trace.reset();
    }
    _renderView.bindElementWidget(_view);
    // 焦点宿主先于子树建立：子节点 reparent 时才能找到本节点作为父。
    _syncFocus();
    if (trace != null) {
      MountTrace.focusUs += trace.elapsedMicroseconds;
      trace.reset();
    }
    _updateContent(_syncChildListenable(_view.child));
    if (trace != null) {
      MountTrace.payloadUs += trace.elapsedMicroseconds;
      MountTrace.mountCount++;
    }
  }

  @override
  void update(covariant ElView newWidget) {
    _childNeedsUpdate = false;
    super.update(newWidget);
    _renderView.bindElementWidget(newWidget);
    _syncFocus();
    _updateContent(_syncChildListenable(newWidget.child));
  }

  @override
  void performRebuild() {
    super.performRebuild();
    if (_childNeedsUpdate) {
      _updateContent(_syncChildListenable(_view.child));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _renderView.setStyleParent(StyleDependencyScope.maybeHostOf(this));
    _focus?.dependenciesChanged();
  }

  @override
  void deactivate() {
    _unsubscribeChildListenable();
    _childNeedsUpdate = false;
    _deactivated = true;
    _renderView.refreshTickerMode(active: false);
    super.deactivate();
  }

  @override
  void activate() {
    _deactivated = false;
    super.activate();
    _renderView.refreshTickerMode();
    _renderView.setStyleParent(StyleDependencyScope.maybeHostOf(this));
    _syncChildListenable(_view.child);
    _childNeedsUpdate = _childListenable != null;
    markNeedsBuild();
    _focus?.reparent();
  }

  @override
  void unmount() {
    final trace = elMountTraceEnabled ? (Stopwatch()..start()) : null;
    _unsubscribeChildListenable();
    _childNeedsUpdate = false;
    // 卸载时元素已失活：只摘节点、收环位与全局登记，不再回写渲染层，也不上提后代。
    _focus?.dispose(reparentDescendants: false);
    super.unmount();
    // 外部保留旧 Element 时也应释放内容模块持有的子树引用。
    _child = null;
    _contentBinding?.dispose(unmounting: true);
    _contentBinding = null;
    if (trace != null) MountTrace.unmountUs += trace.elapsedMicroseconds;
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    assert(_renderView.debugValidateChild(child));
    if (slot is IndexedSlot) {
      final after = slot.value?.renderObject;
      _renderView.insert(child as RenderBox, after: after as RenderBox?);
      return;
    }
    assert(slot == null);
    assert(_renderView.childCount == 0);
    _renderView.insert(child as RenderBox);
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {
    assert(newSlot is IndexedSlot<Element?>);
    final after = (newSlot! as IndexedSlot<Element?>).value?.renderObject;
    _renderView.move(child as RenderBox, after: after as RenderBox?);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    _renderView.remove(child as RenderBox);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    final child = _child;
    if (child != null) visitor(child);
    _contentBinding?.visitChildren(visitor);
  }

  @override
  void forgetChild(Element child) {
    if (child == _child) {
      _child = null;
    } else {
      final forgotten = _contentBinding?.forgetChild(child) ?? false;
      assert(forgotten);
    }
    super.forgetChild(child);
  }

  Object? _syncChildListenable(Object? child) {
    final listenable = child is ValueListenable<Object?> ? child : null;
    if (!identical(_childListenable, listenable)) {
      _unsubscribeChildListenable();
      _childListenable = listenable;
      listenable?.addListener(_handleChildChanged);
    }
    return listenable == null ? child : listenable.value;
  }

  void _unsubscribeChildListenable() {
    _childListenable?.removeListener(_handleChildChanged);
    _childListenable = null;
  }

  void _handleChildChanged() {
    final listenable = _childListenable;
    if (listenable == null) return;
    final value = listenable.value;
    // 内容模块自行判断能否原地更新，结构变化统一交回构建阶段。
    if (!_updatingContent &&
        !_childNeedsUpdate &&
        _child == null &&
        (_renderView.content?.tryUpdatePayload(value) ?? false)) {
      return;
    }
    _childNeedsUpdate = true;
    markNeedsBuild();
  }

  void _updateContent(Object? child) {
    _childNeedsUpdate = false;
    _updatingContent = true;
    try {
      _rebuildChildrenAndPayload(child);
    } finally {
      _updatingContent = false;
    }
  }

  void _rebuildChildrenAndPayload(Object? child) {
    // 独立语义边界从可见盒起算，不能把 margin 重复计入后代坐标。
    if (_view.semantics?.container == true && child != null) {
      final boundaryChild = child is Widget ? child : contentSemanticsChild(child, _view.style);
      if (boundaryChild != null) child = ViewSemanticsFrame(host: _renderView, child: boundaryChild);
    }
    if (child == null || child is Widget) {
      if (child != null) assert(_debugAssertNoFlutterParentDataWidget(child));
      _contentBinding?.dispose();
      _contentBinding = null;
      _renderView.updateContent(null);
      _child = updateChild(
        _child,
        child == null ? null : StyleDependencyScope(host: _renderView, child: child as Widget),
        null,
      );
      return;
    }
    if (_child != null) _child = updateChild(_child, null, null);
    _renderView.updateContent(child);
    _contentBinding ??= _renderView.content!.createElementBinding(this);
    _contentBinding!.update();
  }
}

bool _debugAssertNoFlutterParentDataWidget(Object child) {
  if (child is! ParentDataWidget) return true;
  throw FlutterError(
    'ElView.child 不接受 Flutter ParentDataWidget (${child.runtimeType})。\n'
    'Positioned、Expanded、Flexible、Spacer 等只能直接放在对应的 Flutter Stack 或 Flex 中；\n'
    'ElView 只保留单 child 盒布局；多子布局请直接使用 Flutter 官方布局组件。',
  );
}
