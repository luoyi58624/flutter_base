import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show GestureBinding, PointerDownEvent, PointerEvent;
import 'package:flutter/services.dart' show HardwareKeyboard, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

import '../../../utils/internal/benchmark_probe.dart' show BenchmarkProbe, MountTrace, elMountTraceEnabled;
import '../../../utils/internal/focus.dart';
import '../event/event.dart';
import '../render/render_view.dart';
import '../semantics/semantics_frame.dart';
import '../style/cascade/style_spec.dart';
import '../style/state/view_state.dart';
import '../style/style.dart';
import '../style/style_context.dart';
import '../text/text_engine.dart' show TextAccessibility;
import '../view.dart';

part 'focus_indicator.dart';

/// ElView 的 Element：负责渲染树挂载、样式/事件推送与最小焦点集成。
///
/// 焦点只做三件事：把节点挂到最近的 Flutter [Focus]（无则根 scope）、把
/// 三态（focus / focusWithin / focusVisible）同步给渲染层、转发指针聚焦与
/// 键盘回调。Tab/方向键遍历、焦点恢复、区域归属一律交给 Flutter。
class ViewElement extends RenderObjectElement {
  ViewElement(ElView super.widget);

  bool? _isTextAccessibilityRoot;

  /// 同一 MediaQuery 中仅由继承根订阅文本无障碍设置。
  TextAccessibility? resolveTextAccessibility() {
    if (_isTextAccessibilityRoot == null) {
      final mediaQuery = getElementForInheritedWidgetOfExactType<MediaQuery>();
      var isRoot = true;
      visitAncestorElements((ancestor) {
        if (ancestor is ViewElement) {
          isRoot = !identical(mediaQuery, ancestor.getElementForInheritedWidgetOfExactType<MediaQuery>());
          return false;
        }
        return true;
      });
      _isTextAccessibilityRoot = isRoot;
    }
    if (!_isTextAccessibilityRoot!) return null;
    return (
      bold: MediaQuery.boldTextOf(this),
      lineHeight: MediaQuery.maybeLineHeightScaleFactorOverrideOf(this),
      letterSpacing: MediaQuery.maybeLetterSpacingOverrideOf(this),
      wordSpacing: MediaQuery.maybeWordSpacingOverrideOf(this),
    );
  }

  Element? _child;
  List<Element> _children = const <Element>[];
  ValueListenable<Object?>? _childListenable;
  bool _childNeedsUpdate = false;
  bool _updatingContent = false;

  /// 懒建：只有富文本多子路径（`forgetChild` 命中 `_children`）才需要。
  /// 单 child / 纯文本 / 裸行恒为 null —— 虚拟滚动每行都白付一个 Set 是不可接受的。
  Set<Element>? _forgottenChildren;

  FocusNode? _node;
  FocusAttachment? _attachment;
  FocusOnKeyEventCallback? _previousOnKeyEvent;
  bool _keyHandlerWrapped = false;
  late final FocusOnKeyEventCallback _keyEventHandler = _handleKeyEvent;
  bool _ownsNode = false;
  bool _hadPrimaryFocus = false;
  bool _hadFocusWithin = false;
  bool _activeForFocus = false;

  bool _deactivated = false;

  /// 元素是否处于活动树；失活后不能再做祖先查找，延迟回调须先检查。挂载过程中视为活动。
  bool get isActiveInTree => !_deactivated;

  /// 登记到全局收环路由的回调（字段级持有，保证登记/注销是同一实例）。
  late final VoidCallback _focusRingRetractor = _retractFocusRing;

  // 焦点环实际登记的 View 桶，未亮环时为空。
  int? _focusRingBucket;
  bool get _focusIndicatorOn => _focusRingBucket != null;

  /// 外部节点的禁用兜底状态：禁用时压住 canRequestFocus，恢复时写回原值。
  bool _nodeDisabledByView = false;
  bool _nodeCanRequestFocusBeforeDisable = false;

  /// 指针聚焦时的落点，供 focus 事件回调读取 localPosition。
  Offset? _pendingPointerFocusGlobalPosition;
  Offset? _pendingPointerFocusLocalPosition;

  /// 指针 down 的焦点认领状态：命中派发深→浅，最深目标先认领，浅层外壳
  /// 让位。用 pointer + timeStamp 标识一次 down，下一次 down 自动失效。
  static int? _pointerDownPointer;
  static Duration? _pointerDownTime;
  static bool _pointerDownClaimed = false;

  ElView get _view => widget as ElView;
  ElRenderView get _renderView => renderObject as ElRenderView;

  ElStyle? get _effectiveStyle => _view.style;

  /// 样式里出现 onFocus / onFocusVisible：这是要被聚焦的节点，而不是只给后代
  /// 高亮的壳。
  static final int _focusableVariantMask = (1 << ViewState.focus.index) | (1 << ViewState.focusVisible.index);

  /// onFocusWithin：只要记录“自身或后代持焦”，不参与指针认领。
  static final int _focusWithinVariantMask = 1 << ViewState.focusWithin.index;
  static final int _focusVariantMask = _focusableVariantMask | _focusWithinVariantMask;

  /// 需要焦点节点的来源：显式节点、样式焦点变体（含嵌套在 onDark 等变体内的
  /// 声明，用 mask 判定）、可点且可键盘激活的控件。都没有时不建节点。
  bool get _needsFocusNode => _view.focusNode != null || _hasFocusVariant || _isKeyboardControl;

  bool get _hasFocusVariant => (variantStatesMaskOf(_effectiveStyle) & _focusVariantMask) != 0;

  /// 该节点是否要被用户聚焦（可点击认领、暴露语义）。
  ///
  /// 只看显式节点、onFocus / onFocusVisible 变体和键盘控件：只有 onFocusWithin
  /// 变体的壳节点只做“后代持焦”的高亮，不制造聚焦落点。
  bool get _interactiveFocus =>
      _view.focusNode != null ||
      (variantStatesMaskOf(_effectiveStyle) & _focusableVariantMask) != 0 ||
      _isKeyboardControl;

  /// 可点且声明了键盘回调的控件（按钮、开关、链接等）。
  bool get _isKeyboardControl => (_view.event?.onTap != null) && _hasKeyboardCallback;

  bool get _hasKeyboardCallback => _view.event?.hasKeyboardCallback ?? false;

  bool _focusSemanticsGetter() => _node?.hasPrimaryFocus ?? false;

  // --- Element lifecycle -------------------------------------------------

  @override
  void mount(Element? parent, Object? newSlot) {
    final trace = elMountTraceEnabled ? (Stopwatch()..start()) : null;
    super.mount(parent, newSlot);
    _activeForFocus = true;
    if (trace != null) {
      MountTrace.superMountUs += trace.elapsedMicroseconds;
      trace.reset();
    }
    _renderView.bindElementWidget(_view);
    _renderView.selectionRegistrar = SelectionContainer.maybeOf(this);
    // 焦点宿主先于子树建立：子节点 reparent 时才能找到本节点作为父。
    _syncFocusNode(forceStateSync: true);
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
    _renderView.selectionRegistrar = SelectionContainer.maybeOf(this);
    _syncFocusNode(forceStateSync: true);
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
    _renderView.selectionRegistrar = SelectionContainer.maybeOf(this);
    if (_focusIndicatorOn) _syncFocusRingBucket();
    _reparentFocusNode(createDependency: true);
  }

  @override
  void deactivate() {
    _unsubscribeChildListenable();
    _childNeedsUpdate = false;
    _activeForFocus = false;
    _deactivated = true;
    _renderView.refreshTickerMode(active: false);
    super.deactivate();
  }

  @override
  void activate() {
    _isTextAccessibilityRoot = null;
    _deactivated = false;
    super.activate();
    _renderView.refreshTickerMode();
    _renderView.setStyleParent(StyleDependencyScope.maybeHostOf(this));
    _syncChildListenable(_view.child);
    _childNeedsUpdate = _childListenable != null;
    markNeedsBuild();
    _activeForFocus = true;
    _reparentFocusNode();
  }

  @override
  void unmount() {
    final trace = elMountTraceEnabled ? (Stopwatch()..start()) : null;
    _unsubscribeChildListenable();
    _childNeedsUpdate = false;
    _activeForFocus = false;
    // 卸载路径可能早已不满足视觉同步条件，环位与全局登记必须无条件释放。
    _setFocusIndicator(false);
    _disposeFocusNode(reparentDescendants: false);
    super.unmount();
    // 外部保留旧 Element 时也应释放其内容、富文本载荷和求值样式。
    _child = null;
    _children = const <Element>[];
    _forgottenChildren = null;
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
    if (_children.isNotEmpty) {
      final forgotten = _forgottenChildren;
      for (final child in _children) {
        if (forgotten == null || !forgotten.contains(child)) visitor(child);
      }
      return;
    }
    final child = _child;
    if (child != null) visitor(child);
  }

  @override
  void forgetChild(Element child) {
    if (_children.contains(child)) {
      var forgotten = _forgottenChildren;
      if (forgotten == null) {
        assert(() {
          BenchmarkProbe.forgottenChildrenAllocCount++;
          return true;
        }());
        forgotten = _forgottenChildren = <Element>{};
      }
      forgotten.add(child);
      _children = List<Element>.of(_children)..remove(child);
      super.forgetChild(child);
      return;
    }
    assert(child == _child);
    _child = null;
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
    // 普通文本没有 Element 子树变化，直接复用现有引擎；结构变化交回构建阶段。
    // 独立图标与文字的缩放规则不同，类别切换时也需要重新推送环境参数。
    if (!_updatingContent &&
        !_childNeedsUpdate &&
        _child == null &&
        _children.isEmpty &&
        value is! Widget &&
        value is! Iterable &&
        value is! InlineSpan &&
        (_renderView.rawChild is IconData) == (value is IconData)) {
      _renderView.setTextPayload(value);
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
    if (_view.semantics?.container == true && (child is Widget || child is Iterable || child is InlineSpan)) {
      child = ViewSemanticsFrame(
        host: _renderView,
        child: child is Widget ? child : ElView(locale: _view.locale, child: child),
      );
    }
    if (child == null || child is Widget) {
      if (child != null) assert(_debugAssertNoFlutterParentDataWidget(child));
      _renderView.setTextPayload(null);
      if (_children.isNotEmpty) {
        _children = updateChildren(_children, const [], forgottenChildren: _forgottenChildren);
        _forgottenChildren?.clear();
      }
      _child = updateChild(
        _child,
        child == null ? null : StyleDependencyScope(host: _renderView, child: child as Widget),
        null,
      );
      return;
    }
    if (child is Iterable) {
      final items = <Object?>[];
      for (final item in child) {
        if (item == null) continue;
        assert(_debugAssertNoFlutterParentDataWidget(item));
        items.add(item);
      }
      child = items;
    }
    final engine = _renderView.setTextPayload(child);
    if (_child != null) _child = updateChild(_child, null, null);
    final spans = engine?.structure.spans;
    final widgets = spans == null || spans.isEmpty ? const <Widget>[] : spans.map((span) => span.child).toList();
    if (_children.isNotEmpty || widgets.isNotEmpty) {
      _children = updateChildren(_children, [
        for (final widget in widgets)
          StyleDependencyScope(key: widget.key == null ? null : ValueKey(widget.key), host: _renderView, child: widget),
      ], forgottenChildren: _forgottenChildren);
    }
    _forgottenChildren?.clear();
  }

  // --- 焦点节点同步 -----------------------------------------------------

  void _syncFocusNode({bool forceStateSync = false}) {
    if (!_needsFocusNode) {
      _releaseFocusSources();
      return;
    }

    final desiredNode = _view.focusNode;
    final previousIdentity = _node;
    // 三种替换场景：首次创建、调用方换节点、调用方摘掉节点回落到内部节点。
    if (_node == null ||
        (desiredNode != null && !identical(desiredNode, _node)) ||
        (desiredNode == null && !_ownsNode)) {
      _disposeFocusNode();
      _node = desiredNode ?? FocusNode(debugLabel: 'ElView');
      _ownsNode = desiredNode == null;
      _node!.addListener(_handleFocusChange);
      _attachment = _node!.attach(this);
    }

    final node = _node!;
    final disabled = _renderView.disabled;
    _applyFocusNodeState(node, disabled: disabled);
    if (disabled && node.hasFocus) {
      FocusUtil.markReason(node, ElFocusReason.lifecycle);
      node.unfocus();
    }
    _renderView.requestFocusForEvent = _interactiveFocus && !disabled ? _requestFocusFromPointer : null;
    _renderView.setFocusSemantics(
      includeSemantics: _interactiveFocus,
      focusable: _interactiveFocus && node.canRequestFocus && !disabled,
      focused: node.hasPrimaryFocus,
      focusedGetter: _focusSemanticsGetter,
    );
    _syncKeyEventHandler(node);
    // reparent 是 O(祖先深度) 的走查：仅在节点身份变化时主动挂一次；祖先
    // ViewElement 节点/Focus 变化由 didChangeDependencies 兜底。
    if (!identical(previousIdentity, node)) {
      _reparentFocusNode();
      // 新节点替换旧节点：后代此前挂到了更上层，需要重新挂回本节点。
      _reparentDescendantFocusNodes();
    }
    _syncRenderFocus(force: forceStateSync);
  }

  /// 同步节点上的可聚焦开关。
  ///
  /// 内部节点完全由样式决定；外部节点归调用方所有，这里只在禁用期间临时压住
  /// [FocusNode.canRequestFocus]，恢复启用时写回原值，避免偷改调用方的意图。
  void _applyFocusNodeState(FocusNode node, {required bool disabled}) {
    if (_ownsNode) {
      node
        ..skipTraversal = !_interactiveFocus
        ..canRequestFocus = _interactiveFocus && !disabled
        ..descendantsAreFocusable = !disabled
        ..descendantsAreTraversable = !disabled;
      return;
    }
    if (disabled && !_nodeDisabledByView) {
      _nodeDisabledByView = true;
      _nodeCanRequestFocusBeforeDisable = node.canRequestFocus;
      node.canRequestFocus = false;
    } else if (!disabled && _nodeDisabledByView) {
      _nodeDisabledByView = false;
      if (_nodeCanRequestFocusBeforeDisable) node.canRequestFocus = true;
      _nodeCanRequestFocusBeforeDisable = false;
    }
  }

  // 无本地回调的主焦点仍须转发按键，让逻辑祖先收到未消费的事件。
  bool get _needsKeyEventHandler => _needsFocusNode;

  void _syncKeyEventHandler(FocusNode node) {
    if (!_needsKeyEventHandler) {
      _restoreKeyEventHandler(node);
      return;
    }
    if (!_keyHandlerWrapped) {
      // 只记一次“安装前”的 handler：之后调用方/组件可能在它之上再包一层，
      // 反复回记会互把对方记成 previous，形成无限递归（select 触发过
      // StackOverflowError）。
      _previousOnKeyEvent = node.onKeyEvent;
      _keyHandlerWrapped = true;
      node.onKeyEvent = _keyEventHandler;
      return;
    }
    if (identical(node.onKeyEvent, _keyEventHandler)) return;
    if (identical(node.onKeyEvent, _previousOnKeyEvent)) {
      // 被还原成安装前的状态（换节点、组件重置）：重新包一层。
      node.onKeyEvent = _keyEventHandler;
    }
    // 其余情况是别的层在更外层包了自己的 handler 且链着我们的：保持不动。
  }

  void _restoreKeyEventHandler(FocusNode node) {
    if (identical(node.onKeyEvent, _keyEventHandler)) {
      node.onKeyEvent = _previousOnKeyEvent;
    }
    // 组件在更外层包过我们时链里仍留着我们的 handler，它有 mounted/identity
    // 守卫，卸载后恒返回 ignored，不再强行摘链。
    _previousOnKeyEvent = null;
    _keyHandlerWrapped = false;
  }

  /// 只转发 ElEvent 键盘回调；Tab / 方向键遍历交给 Flutter 默认策略。
  ///
  /// 判定口径：回调显式 `preventDefault()` 才算消费（返回 handled），否则一律
  /// ignored——Flutter 的遍历只在 ignored 时接管，不 preventDefault 就不能吞键。
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!mounted || !identical(_node, node)) return KeyEventResult.ignored;

    final previousResult = _previousOnKeyEvent?.call(node, event);
    if (previousResult != null && previousResult != KeyEventResult.ignored) return previousResult;

    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    final keyCallback = _renderView.dispatchKeyEvent(event);
    if (keyCallback?.defaultPrevented != true) return KeyEventResult.ignored;
    return KeyEventResult.handled;
  }

  void _requestFocusFromPointer(PointerDownEvent event, Offset localPosition) {
    final node = _node;
    if (node == null || _renderView.disabled) return;
    // 每次命中项拿到的是按自身坐标变换后的新事件对象，不能用身份做 down
    // 标识；pointer + timeStamp 在同一次 down 的所有命中项间稳定。
    if (_pointerDownPointer != event.pointer || _pointerDownTime != event.timeStamp) {
      _pointerDownPointer = event.pointer;
      _pointerDownTime = event.timeStamp;
      _pointerDownClaimed = false;
    }
    // 本次 down 已有更深的可聚焦视图认领（命中派发深→浅，深处先跑）：
    // 外壳让位，避免把刚交给输入框/编辑器的焦点抢回来。
    if (_pointerDownClaimed) return;
    // 后代已持焦（自身或后代 hasFocus，但主焦点在更深节点）时，本次 down
    // 的焦点归更深节点，祖先不抢。
    if (node.hasFocus && !node.hasPrimaryFocus) {
      _pointerDownClaimed = true;
      return;
    }
    if (!node.canRequestFocus) return;
    _pointerDownClaimed = true;
    _commitPointerFocus(event.position, localPosition);
  }

  void _commitPointerFocus(Offset globalPosition, Offset localPosition) {
    final node = _node;
    if (node == null || !node.canRequestFocus) return;
    final alreadyPrimary = node.hasPrimaryFocus;
    _pendingPointerFocusGlobalPosition = globalPosition;
    _pendingPointerFocusLocalPosition = localPosition;
    _renderView.rememberFocusEventPosition(globalPosition, localPosition);
    FocusUtil.markReason(node, ElFocusReason.pointer);
    node.requestFocus();
    if (alreadyPrimary) {
      _syncRenderFocus(force: true);
    }
  }

  /// 沿真实 Element 祖先链选择最近的焦点挂点。
  ///
  /// 顺序：最近的 ElView 节点 → 最近的 Flutter [Focus] → 根 scope。ElView 节点
  /// 优先级最高，嵌套视图的 focusWithin / 后代持焦判断才成立；Flutter Focus
  /// 只在没有 ElView 祖先（或祖先尚未建节点）时兜底。
  void _reparentFocusNode({bool createDependency = false}) {
    final attachment = _attachment;
    if (attachment == null) return;
    // stale attachment 防御：GlobalKey re-parent 中 deactivate/activate 之间
    // 可能有一帧 element 未 mounted 就走到这里（didChangeDependencies /
    // 上层 activate 触发）——此时 reparent 会挂到 stale parent。跳过等
    // activate 里的正规路径重来。
    if (!mounted) return;
    attachment.reparent(parent: _nearestFocusParent(createDependency: createDependency));
  }

  /// 最近祖先焦点节点：ElView 节点优先，其次 Flutter Focus，最后根 scope。
  FocusNode _nearestFocusParent({required bool createDependency}) {
    FocusNode? ancestorNode;
    visitAncestorElements((ancestor) {
      if (ancestor is ViewElement && ancestor._node != null) {
        ancestorNode = ancestor._node;
        return false;
      }
      return true;
    });
    return ancestorNode ??
        Focus.maybeOf(this, scopeOk: true, createDependency: createDependency) ??
        FocusManager.instance.rootScope;
  }

  /// 本节点的父节点更换/消失后，把仍挂在本节点上的后代重新挂到最近的祖先。
  ///
  /// 拥有自己节点的后代是子树挂点：reparent 一次即剪枝返回，更深的节点挂在
  /// 它身上，不受本节点变化影响。
  void _reparentDescendantFocusNodes() {
    void walk(Element element) {
      if (element is ViewElement && !identical(element, this) && element.mounted) {
        if (element._node != null) {
          element._reparentFocusNode();
          element._syncRenderFocus(force: true);
          return;
        }
        // 无节点的后代没有挂点，继续下钻找声明者。
      }
      element.visitChildren(walk);
    }

    visitChildren(walk);
  }

  void _handleFocusChange() => _syncRenderFocus();

  void _syncFocusRingBucket() {
    assert(() {
      BenchmarkProbe.focusViewIdResolveCount++;
      return true;
    }());
    final previous = _focusRingBucket;
    final bucket = View.maybeOf(this)?.viewId ?? _globalFocusRingViewId;
    if (previous == bucket) return;
    _focusRingBucket = bucket;
    // 跨 View 重挂时先登记新桶，避免最后一个环搬迁时重新安装全局监听。
    _registerFocusRingOwner(_focusRingRetractor, viewId: bucket);
    if (previous != null) _unregisterFocusRingOwner(_focusRingRetractor, viewId: previous);
  }

  void _setFocusIndicator(bool on) {
    if (on) {
      if (!_focusIndicatorOn) _syncFocusRingBucket();
      return;
    }
    final bucket = _focusRingBucket;
    if (bucket == null) return;
    _focusRingBucket = null;
    _unregisterFocusRingOwner(_focusRingRetractor, viewId: bucket);
  }

  /// 指针按下（全局）或触摸形态出现时收起焦点环；焦点本身不动。
  void _retractFocusRing() {
    if (!_focusIndicatorOn) return;
    _setFocusIndicator(false);
    if (_node?.hasPrimaryFocus ?? false) _syncRenderFocus(force: true);
  }

  bool get _canSyncRenderFocusState {
    if (!mounted || !_activeForFocus || !_renderView.attached) return false;
    var disposed = false;
    assert(() {
      disposed = _renderView.debugDisposed == true;
      return true;
    }());
    return !disposed;
  }

  void _syncRenderFocus({bool force = false}) {
    if (!_canSyncRenderFocusState) return;
    final node = _node;
    final primary = node?.hasPrimaryFocus ?? false;
    final within = node?.hasFocus ?? false;
    _renderView.setFocusSemantics(
      includeSemantics: _interactiveFocus,
      focusable: _interactiveFocus && (node?.canRequestFocus ?? false) && !_renderView.disabled,
      focused: primary,
      focusedGetter: _focusSemanticsGetter,
    );
    final primaryChanged = primary != _hadPrimaryFocus;
    if (force || primaryChanged) {
      _hadPrimaryFocus = primary;
      final focusGlobalPosition = primary ? _pendingPointerFocusGlobalPosition : null;
      final focusLocalPosition = primary ? _pendingPointerFocusLocalPosition : null;
      _pendingPointerFocusGlobalPosition = null;
      _pendingPointerFocusLocalPosition = null;
      // force 视觉同步可能发生在 requestFocus 已排队、但目标尚未成为 primary
      // 的同一次 pointer down 内；此时不能提前消费目标节点的 reason。
      final markedReason = primary ? FocusUtil.takeReason(node!) : null;
      // 没有显式 reason 时，靠「导航键仍按下」把 Flutter 的遍历/快捷键换焦
      // 归因为 keyboard；其余无来源的焦点变化是程序化恢复。
      final reason =
          markedReason ??
          (primaryChanged
              ? (_keyboardNavigationInFlight ? ElFocusReason.keyboard : ElFocusReason.programmatic)
              : ElFocusReason.lifecycle);
      // focus-visible 只认「本次聚焦来源」，不看全局 highlightMode（桌面恒为
      // traditional）。已有环位在 force 重同步时保留，指针/触摸才收起。
      if (!primary) {
        _setFocusIndicator(false);
      } else if (markedReason != null) {
        _setFocusIndicator(_focusVisibleForReason(markedReason));
      } else if (primaryChanged) {
        _setFocusIndicator(_focusVisibleForReason(reason));
      }
      _renderView.setFocus(
        primary,
        reason: reason,
        focusVisible: primary && _focusIndicatorOn,
        globalPosition: focusGlobalPosition,
        localPosition: focusLocalPosition,
      );
    }
    if (force || within != _hadFocusWithin) {
      _hadFocusWithin = within;
      _renderView.setFocusWithin(within);
    }
  }

  /// 焦点来源消失（节点/变体/键盘回调全部撤掉）时同步退回零焦点状态。
  void _releaseFocusSources() {
    _disposeFocusNode();
    _renderView.requestFocusForEvent = null;
    _renderView.releaseEventDispatcherIfUnused();
    _renderView.setFocusSemantics(includeSemantics: false, focusable: false);
  }

  void _disposeFocusNode({bool reparentDescendants = true}) {
    final node = _node;
    if (node == null) return;
    if (node.hasFocus) {
      FocusUtil.markReason(node, ElFocusReason.lifecycle);
      // 与 Flutter FocusAttachment.detach 同口径：节点销毁时把焦点交回该 scope
      // 里上一个持焦项；默认的 scope disposition 会清空整条焦点历史，弹层内容
      // 卸载后焦点只能停在 scope 上，无法自然回落。
      node.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    }
    _renderView.requestFocusForEvent = null;
    _renderView.releaseEventDispatcherIfUnused();
    // 先撤语义再清视觉状态：includeFocusSemantics 关掉后 setFocus 不会再
    // 额外标脏语义，避免同一帧重复提交语义更新。
    if (_canSyncRenderFocusState) {
      _renderView.setFocusSemantics(includeSemantics: false, focusable: false);
    }
    _syncRenderFocusToFalse();
    _restoreKeyEventHandler(node);
    node.removeListener(_handleFocusChange);
    _attachment?.detach();
    _attachment = null;
    if (_ownsNode) node.dispose();
    _node = null;
    _ownsNode = false;
    _nodeDisabledByView = false;
    _nodeCanRequestFocusBeforeDisable = false;
    // 挂点消失：把仍挂在本节点上的后代上提，避免焦点节点留在孤立父节点下。
    if (reparentDescendants) _reparentDescendantFocusNodes();
  }

  void _syncRenderFocusToFalse() {
    // 环位与全局登记与「当前能否同步渲染状态」无关，必须无条件清掉。
    _setFocusIndicator(false);
    if (!_canSyncRenderFocusState) return;
    if (_hadPrimaryFocus) {
      _hadPrimaryFocus = false;
      _renderView.setFocus(false, reason: ElFocusReason.lifecycle);
    }
    if (_hadFocusWithin) {
      _hadFocusWithin = false;
      _renderView.setFocusWithin(false);
    }
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
