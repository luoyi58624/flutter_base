part of 'view_element.dart';

/// 焦点来源判定与焦点对象的创建、更换、释放。
extension _FocusSources on ViewElement {
  /// 样式里出现 onFocus / onFocusVisible：这是要被聚焦的节点，而不是只给后代
  /// 高亮的壳。
  static final int _focusableVariantMask = (1 << ViewState.focus.index) | (1 << ViewState.focusVisible.index);

  /// onFocusWithin：只要记录“自身或后代持焦”，不参与指针认领。
  static final int _focusVariantMask = _focusableVariantMask | (1 << ViewState.focusWithin.index);

  /// 需要焦点对象的来源：显式节点、样式焦点变体（含嵌套在 onDark 等变体内的
  /// 声明，用 mask 判定）、可点且可键盘激活的控件。都没有时不创建。
  bool get _needsFocus =>
      _view.focusNode != null || (variantStatesMaskOf(_view.style) & _focusVariantMask) != 0 || _isKeyboardControl;

  /// 该节点是否要被用户聚焦（可点击认领、暴露语义）。
  ///
  /// 只看显式节点、onFocus / onFocusVisible 变体和键盘控件：只有 onFocusWithin
  /// 变体的壳节点只做“后代持焦”的高亮，不制造聚焦落点。
  bool get _interactiveFocus =>
      _view.focusNode != null || (variantStatesMaskOf(_view.style) & _focusableVariantMask) != 0 || _isKeyboardControl;

  /// 可点且声明了键盘回调的控件（按钮、开关、链接等）。
  bool get _isKeyboardControl => _view.event?.onTap != null && (_view.event?.hasKeyboardCallback ?? false);

  /// 按当前声明同步焦点：没有来源时不创建，来源全部撤掉时释放并退回零焦点状态。
  void _syncFocus() {
    var focus = _focus;
    if (!_needsFocus) {
      if (focus == null) return;
      focus.dispose();
      _renderView.setFocusSemantics(includeSemantics: false, focusable: false);
      return;
    }
    final desired = _view.focusNode;
    // 三种替换场景：首次创建、调用方换节点、调用方摘掉节点回落到内部节点。
    if (focus == null || (desired != null && !identical(desired, focus.node)) || (desired == null && !focus.ownsNode)) {
      focus?.dispose();
      focus = _focus = _ViewFocus(this, desired);
      focus.sync(nodeChanged: true);
    } else {
      focus.sync(nodeChanged: false);
    }
  }

  /// 最近祖先焦点节点：ElView 节点优先，其次 Flutter Focus，最后根 scope。
  ///
  /// ElView 节点优先级最高，嵌套视图的 focusWithin / 后代持焦判断才成立；Flutter
  /// Focus 只在没有 ElView 祖先（或祖先没有焦点对象）时兜底。
  FocusNode _nearestFocusParent({required bool createDependency}) {
    FocusNode? ancestorNode;
    visitAncestorElements((ancestor) {
      final focus = ancestor is ViewElement ? ancestor._focus : null;
      if (focus == null) return true;
      ancestorNode = focus.node;
      return false;
    });
    return ancestorNode ??
        Focus.maybeOf(this, scopeOk: true, createDependency: createDependency) ??
        FocusManager.instance.rootScope;
  }

  /// 本节点的焦点挂点更换或消失后，把仍挂在本节点上的后代重新挂到最近的祖先。
  ///
  /// 拥有焦点对象的后代是子树挂点：reparent 一次即剪枝返回，更深的节点挂在
  /// 它身上，不受本节点变化影响。
  void _reparentDescendantFocus() {
    void walk(Element element) {
      if (element is ViewElement && element.mounted) {
        final focus = element._focus;
        if (focus != null) {
          focus
            ..reparent()
            ..syncRender(force: true);
          return;
        }
        // 没有焦点对象的后代没有挂点，继续下钻找声明者。
      }
      element.visitChildren(walk);
    }

    visitChildren(walk);
  }
}

/// 一个视图的焦点集成：节点挂接、三态同步、指针聚焦、键盘转发与焦点环登记。
///
/// 生命周期等于一个焦点节点的挂接期：视图声明焦点来源时创建，换节点时整体更换，
/// 来源撤掉或卸载时释放，因此没有焦点来源的视图不持有任何焦点状态。
final class _ViewFocus {
  _ViewFocus(this.element, FocusNode? external)
    : node = external ?? FocusNode(debugLabel: 'ElView'),
      ownsNode = external == null {
    assert(() {
      BenchmarkProbe.focusStateInstantiateCount++;
      return true;
    }());
    node.addListener(_handleFocusChange);
    _attachment = node.attach(element);
  }

  final ViewElement element;
  final FocusNode node;

  /// 节点由视图内部创建；外部节点归调用方所有，释放时不销毁。
  final bool ownsNode;

  late final FocusAttachment _attachment;

  // 字段级持有，保证节点上的安装/还原、全局收环路由的登记/注销是同一实例。
  late final FocusOnKeyEventCallback _keyEventHandler = _handleKeyEvent;
  late final VoidCallback _ringRetractor = _retractRing;

  FocusOnKeyEventCallback? _previousOnKeyEvent;
  bool _keyHandlerWrapped = false;
  bool _hadPrimaryFocus = false;
  bool _hadFocusWithin = false;

  // 焦点环实际登记的 View 桶，未亮环时为空。
  int? _ringBucket;
  bool get _ringOn => _ringBucket != null;

  /// 外部节点的禁用兜底状态：禁用时压住 canRequestFocus，恢复时写回原值。
  bool _disabledByView = false;
  bool _canRequestFocusBeforeDisable = false;

  /// 当前是否接受指针聚焦：可聚焦且未禁用，随声明同步。
  bool acceptsPointer = false;

  /// 指针聚焦时的落点，供 focus 事件回调读取 localPosition。
  Offset? _pendingGlobalPosition;
  Offset? _pendingLocalPosition;

  /// 指针 down 的焦点认领状态：命中派发深→浅，最深目标先认领，浅层外壳
  /// 让位。用 pointer + timeStamp 标识一次 down，下一次 down 自动失效。
  static int? _pointerDownPointer;
  static Duration? _pointerDownTime;
  static bool _pointerDownClaimed = false;

  ElRenderView get _render => element._renderView;

  /// 把视图当前的声明同步到节点与渲染层；[nodeChanged] 表示节点刚换过身份。
  void sync({required bool nodeChanged}) {
    final interactive = element._interactiveFocus;
    final disabled = _render.disabled;
    _applyNodeState(interactive: interactive, disabled: disabled);
    if (disabled && node.hasFocus) {
      FocusUtil.markReason(node, ElFocusReason.lifecycle);
      node.unfocus();
    }
    acceptsPointer = interactive && !disabled;
    _render.setFocusSemantics(
      includeSemantics: interactive,
      focusable: interactive && node.canRequestFocus && !disabled,
      focused: node.hasPrimaryFocus,
    );
    _syncKeyEventHandler();
    // reparent 是 O(祖先深度) 的走查：仅在节点身份变化时主动挂一次；祖先
    // 焦点挂点变化由 didChangeDependencies 兜底。
    if (nodeChanged) {
      reparent();
      // 新节点替换旧节点：后代此前挂到了更上层，需要重新挂回本节点。
      element._reparentDescendantFocus();
    }
    syncRender(force: true);
  }

  /// 同步节点上的可聚焦开关。
  ///
  /// 内部节点完全由样式决定；外部节点归调用方所有，这里只在禁用期间临时压住
  /// [FocusNode.canRequestFocus]，恢复启用时写回原值，避免偷改调用方的意图。
  void _applyNodeState({required bool interactive, required bool disabled}) {
    if (ownsNode) {
      node
        ..skipTraversal = !interactive
        ..canRequestFocus = interactive && !disabled
        ..descendantsAreFocusable = !disabled
        ..descendantsAreTraversable = !disabled;
      return;
    }
    if (disabled && !_disabledByView) {
      _disabledByView = true;
      _canRequestFocusBeforeDisable = node.canRequestFocus;
      node.canRequestFocus = false;
    } else if (!disabled && _disabledByView) {
      _disabledByView = false;
      if (_canRequestFocusBeforeDisable) node.canRequestFocus = true;
      _canRequestFocusBeforeDisable = false;
    }
  }

  // --- 键盘转发 ---------------------------------------------------------

  // 无本地回调的主焦点仍须转发按键，让逻辑祖先收到未消费的事件，因此只要持有节点就安装。
  void _syncKeyEventHandler() {
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
      // 被还原成安装前的状态（组件重置）：重新包一层。
      node.onKeyEvent = _keyEventHandler;
    }
    // 其余情况是别的层在更外层包了自己的 handler 且链着我们的：保持不动。
  }

  void _restoreKeyEventHandler() {
    if (identical(node.onKeyEvent, _keyEventHandler)) {
      node.onKeyEvent = _previousOnKeyEvent;
    }
    // 组件在更外层包过我们时链里仍留着我们的 handler，它有 mounted/identity
    // 守卫，释放后恒返回 ignored，不再强行摘链。
    _previousOnKeyEvent = null;
    _keyHandlerWrapped = false;
  }

  /// 只转发 ElEvent 键盘回调；Tab / 方向键遍历交给 Flutter 默认策略。
  ///
  /// 判定口径：回调显式 `preventDefault()` 才算消费（返回 handled），否则一律
  /// ignored——Flutter 的遍历只在 ignored 时接管，不 preventDefault 就不能吞键。
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!element.mounted || !identical(element._focus, this)) return KeyEventResult.ignored;

    final previousResult = _previousOnKeyEvent?.call(node, event);
    if (previousResult != null && previousResult != KeyEventResult.ignored) return previousResult;

    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    final keyCallback = _render.dispatchKeyEvent(event);
    if (keyCallback?.defaultPrevented != true) return KeyEventResult.ignored;
    return KeyEventResult.handled;
  }

  // --- 指针聚焦 ---------------------------------------------------------

  /// 指针按下时认领焦点：同一次按下里最深的可聚焦视图先认领，外壳让位。
  void requestFromPointer(PointerDownEvent event, Offset localPosition) {
    if (!acceptsPointer || _render.disabled) return;
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
    final alreadyPrimary = node.hasPrimaryFocus;
    _pendingGlobalPosition = event.position;
    _pendingLocalPosition = localPosition;
    _render.rememberFocusEventPosition(event.position, localPosition);
    FocusUtil.markReason(node, ElFocusReason.pointer);
    node.requestFocus();
    if (alreadyPrimary) syncRender(force: true);
  }

  // --- 挂接 -------------------------------------------------------------

  /// 沿真实 Element 祖先链把节点挂到最近的焦点挂点。
  void reparent({bool createDependency = false}) {
    // stale attachment 防御：GlobalKey re-parent 中 deactivate/activate 之间
    // 可能有一帧 element 未 mounted 就走到这里（didChangeDependencies /
    // 上层 activate 触发）——此时 reparent 会挂到 stale parent。跳过等
    // activate 里的正规路径重来。
    if (!element.mounted) return;
    _attachment.reparent(parent: element._nearestFocusParent(createDependency: createDependency));
  }

  /// 祖先依赖变化：所属 View 可能更换，祖先焦点挂点也可能变化。
  void dependenciesChanged() {
    if (_ringOn) _syncRingBucket();
    reparent(createDependency: true);
  }

  // --- 焦点环 -----------------------------------------------------------

  void _syncRingBucket() {
    assert(() {
      BenchmarkProbe.focusViewIdResolveCount++;
      return true;
    }());
    final previous = _ringBucket;
    final bucket = View.maybeOf(element)?.viewId ?? _globalFocusRingViewId;
    if (previous == bucket) return;
    _ringBucket = bucket;
    // 跨 View 重挂时先登记新桶，避免最后一个环搬迁时重新安装全局监听。
    _registerFocusRingOwner(_ringRetractor, viewId: bucket);
    if (previous != null) _unregisterFocusRingOwner(_ringRetractor, viewId: previous);
  }

  void _setRing(bool on) {
    if (on) {
      if (!_ringOn) _syncRingBucket();
      return;
    }
    final bucket = _ringBucket;
    if (bucket == null) return;
    _ringBucket = null;
    _unregisterFocusRingOwner(_ringRetractor, viewId: bucket);
  }

  /// 指针按下（全局）或触摸形态出现时收起焦点环；焦点本身不动。
  void _retractRing() {
    if (!_ringOn) return;
    _setRing(false);
    if (node.hasPrimaryFocus) syncRender(force: true);
  }

  // --- 渲染层三态同步 ---------------------------------------------------

  void _handleFocusChange() => syncRender();

  bool get _canSyncRender {
    if (!element.mounted || !element.isActiveInTree || !_render.attached) return false;
    var disposed = false;
    assert(() {
      disposed = _render.debugDisposed == true;
      return true;
    }());
    return !disposed;
  }

  /// 把节点的 focus / focusWithin / focusVisible 同步给渲染层；[force] 时即使未变化也重发。
  void syncRender({bool force = false}) {
    if (!_canSyncRender) return;
    final interactive = element._interactiveFocus;
    final primary = node.hasPrimaryFocus;
    final within = node.hasFocus;
    _render.setFocusSemantics(
      includeSemantics: interactive,
      focusable: interactive && node.canRequestFocus && !_render.disabled,
      focused: primary,
    );
    final primaryChanged = primary != _hadPrimaryFocus;
    if (force || primaryChanged) {
      _hadPrimaryFocus = primary;
      final globalPosition = primary ? _pendingGlobalPosition : null;
      final localPosition = primary ? _pendingLocalPosition : null;
      _pendingGlobalPosition = null;
      _pendingLocalPosition = null;
      // force 视觉同步可能发生在 requestFocus 已排队、但目标尚未成为 primary
      // 的同一次 pointer down 内；此时不能提前消费目标节点的 reason。
      final markedReason = primary ? FocusUtil.takeReason(node) : null;
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
        _setRing(false);
      } else if (markedReason != null) {
        _setRing(_focusVisibleForReason(markedReason));
      } else if (primaryChanged) {
        _setRing(_focusVisibleForReason(reason));
      }
      _render.setFocus(
        primary,
        reason: reason,
        focusVisible: primary && _ringOn,
        globalPosition: globalPosition,
        localPosition: localPosition,
      );
    }
    if (force || within != _hadFocusWithin) {
      _hadFocusWithin = within;
      _render.setFocusWithin(within);
    }
  }

  // --- 释放 -------------------------------------------------------------

  /// 摘下节点并把渲染层退回零焦点状态；[reparentDescendants] 为 false 时不再上提后代（卸载）。
  void dispose({bool reparentDescendants = true}) {
    if (node.hasFocus) {
      FocusUtil.markReason(node, ElFocusReason.lifecycle);
      // 与 Flutter FocusAttachment.detach 同口径：节点销毁时把焦点交回该 scope
      // 里上一个持焦项；默认的 scope disposition 会清空整条焦点历史，弹层内容
      // 卸载后焦点只能停在 scope 上，无法自然回落。
      node.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    }
    acceptsPointer = false;
    _render.releaseEventDispatcherIfUnused();
    // 环位与全局登记与「当前能否同步渲染状态」无关，必须无条件清掉。
    _setRing(false);
    if (_canSyncRender) {
      // 先撤语义再清视觉状态：includeFocusSemantics 关掉后 setFocus 不会再
      // 额外标脏语义，避免同一帧重复提交语义更新。
      _render.setFocusSemantics(includeSemantics: false, focusable: false);
      if (_hadPrimaryFocus) _render.setFocus(false, reason: ElFocusReason.lifecycle);
      if (_hadFocusWithin) _render.setFocusWithin(false);
    }
    _restoreKeyEventHandler();
    node.removeListener(_handleFocusChange);
    _attachment.detach();
    if (ownsNode) node.dispose();
    if (identical(element._focus, this)) element._focus = null;
    // 挂点消失：把仍挂在本节点上的后代上提，避免焦点节点留在孤立父节点下。
    if (reparentDescendants) element._reparentDescendantFocus();
  }
}
