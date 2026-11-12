// ignore_for_file: prefer_initializing_formals

part of 'context_menu.dart';

/// 上下文菜单句柄，负责逻辑关闭、退场摘除和焦点生命周期。
class ElContextMenuHandle extends ChangeNotifier {
  ElContextMenuHandle._({
    required BuildContext source,
    required OverlayState overlay,
    required _MenuChain chain,
    required int level,
    required Offset position,
    required BuildContext? anchor,
    required bool restoreFocus,
    required Duration exitDuration,
    required Widget Function(BuildContext context, bool exiting) builder,
  }) : _source = source,
       _overlay = overlay,
       _chain = chain,
       _level = level,
       _position = position,
       _anchor = anchor,
       _restoreFocus = restoreFocus,
       _exitDuration = exitDuration,
       _builder = builder,
       _previousFocus = FocusManager.instance.primaryFocus,
       _owner = SelectionChromeSlot.maybeOf(source),
       _route = ModalRoute.of(source),
       _viewId = View.of(source).viewId,
       _themes = InheritedTheme.capture(from: source, to: overlay.context),
       _direction = Directionality.maybeOf(source) ?? TextDirection.ltr;

  final BuildContext _source;
  final OverlayState _overlay;
  final _MenuChain _chain;
  final int _level;
  final Offset _position;
  final BuildContext? _anchor;
  final bool _restoreFocus;
  final Duration _exitDuration;
  final Widget Function(BuildContext context, bool exiting) _builder;
  final FocusNode? _previousFocus;
  final SelectionChromeMountHost? _owner;
  final ModalRoute<dynamic>? _route;
  final int _viewId;
  final CapturedThemes _themes;
  final TextDirection _direction;
  final FocusScopeNode _focusScope = FocusScopeNode(
    debugLabel: 'ElContextMenu',
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey _ignoreKey = GlobalKey();
  final GlobalKey _semanticsKey = GlobalKey();
  final Completer<void> _closed = Completer<void>();
  OverlayEntry? _entry;
  Timer? _exitTimer;
  bool _open = true;
  bool _capturedFocus = false;
  bool _finalized = false;
  bool _pointerRouteInstalled = false;
  bool _layerMounted = false;
  bool _scopeDisposed = false;

  /// 菜单是否仍可交互；关闭时立即变为 false。
  bool get isOpen => _open;

  /// 菜单是否仍处于展示阶段，不含退场保活。
  bool get isShowing => _open;

  /// 当前面板或其子菜单是否持有焦点。
  bool get hasFocus =>
      _open &&
      (_focusScope.hasFocus || _chain._entries.any((entry) => entry._level > _level && entry._focusScope.hasFocus));

  /// 菜单退场并完全摘除后完成。
  Future<void> get closed => _closed.future;

  /// 接续打开菜单的触屏长按，滑到目标项后松手执行；普通点击与鼠标事件不接续。
  void trackTouch(ElEventDetails event) {
    final original = event.originalEvent;
    if (!_open ||
        event.defaultPrevented ||
        event.phase != ElEventPhase.longPress ||
        original is! PointerDownEvent ||
        original.viewId != _viewId) {
      return;
    }
    if (_chain._touch?.begin(original) == true) TouchHaptics.activate(original);
  }

  void _mount() {
    if (!_open) return;
    _entry = OverlayEntry(builder: (_) => _MenuOverlayLayer(handle: this));
    _overlay.insert(_entry!);
    // 打开菜单的 pointer down 仍在分发中，下一微任务再监听外部点击。
    scheduleMicrotask(() {
      if (!_open) return;
      GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointer);
      _pointerRouteInstalled = true;
    });
    FocusManager.instance.addListener(_handleFocusChanged);
    _owner?.stateListenable?.addListener(_handleOwnerChanged);
    _MenuOwnerWatch.add(this);
  }

  void _captureFocus() {
    if (!_open || _focusScope.context == null) return;
    FocusUtil.requestFocus(_focusScope);
    _capturedFocus = _focusScope.hasFocus;
  }

  bool _contains(Offset global) {
    final render = _activeRender(_contentKey.currentContext);
    return render is RenderBox &&
        render.attached &&
        render.hasSize &&
        render.size.contains(render.globalToLocal(global));
  }

  void _handlePointer(PointerEvent event) {
    if (!_open || event.viewId != _viewId) return;
    if (_level == 0) _chain._touch?.handlePointer(event);
    if (!_open || event is! PointerDownEvent || _chain._touch?.isTracking == true) return;
    if (_chain._entries.any((entry) => entry._contains(event.position))) return;
    // 只关闭菜单，不认领指针，外部控件继续接收同一次点击。
    // 外点关闭不归还焦点：焦点该跟着被点的控件走，菜单不能再抢回来盖掉它。
    _closeChainWithoutFocus();
  }

  void _handleFocusChanged() {
    if (!_open || !_capturedFocus || _chain._entries.any((entry) => entry.hasFocus)) return;
    // 新模态层或外部控件已接管焦点，不能在收菜单时再抢回来。
    _closeChainWithoutFocus();
  }

  void _closeChainWithoutFocus() {
    for (final entry in _chain._entries.reversed.toList()) {
      entry._close(restoreFocus: false);
    }
  }

  void _handleOwnerChanged() {
    if (!(_owner?.canMount ?? true)) _closeChainWithoutFocus();
  }

  RenderObject? _activeRender(BuildContext? context) {
    if (context == null || !context.mounted) return null;
    var active = true;
    assert(() {
      if (context is Element) active = context.debugIsActive;
      return true;
    }());
    if (!active) return null;
    try {
      return context.findRenderObject();
    } on FlutterError {
      return null;
    }
  }

  bool get _sourceIsVisible {
    if (!_overlay.mounted ||
        !_source.mounted ||
        !(_owner?.canMount ?? true) ||
        (_route != null && (!_route.isActive || !_route.isCurrent))) {
      return false;
    }
    final root = _chain._entries.firstOrNull;
    if (_level > 0 && root != null && !identical(root, this)) {
      // 子菜单沿用根菜单的内容归属，不能把父面板尚在淡入误判为源已隐藏。
      return root._sourceIsVisible && (_activeRender(_source)?.attached ?? false);
    }
    try {
      RenderObject? render = _activeRender(_source);
      if (render == null || !render.attached) return false;
      while (render != null) {
        final parent = render.parent;
        if (parent != null && !parent.paintsChild(render)) return false;
        render = parent;
      }
      return true;
    } on FlutterError {
      return false;
    }
  }

  /// 关闭菜单并按打开选项归还焦点；重复调用无副作用。
  void close() => _close(restoreFocus: true);

  void _close({required bool restoreFocus}) {
    if (!_open) return;
    final ownedFocus = _focusScope.hasFocus || _chain._entries.any((entry) => entry.hasFocus);
    _open = false;
    if (_pointerRouteInstalled) GestureBinding.instance.pointerRouter.removeGlobalRoute(_handlePointer);
    FocusManager.instance.removeListener(_handleFocusChanged);
    _owner?.stateListenable?.removeListener(_handleOwnerChanged);
    _MenuOwnerWatch.remove(this);
    // 命中必须与逻辑关闭同步，不能等下一帧重建后才让旧面板失效。
    final ignoring = _activeRender(_ignoreKey.currentContext);
    if (ignoring is RenderIgnorePointer) ignoring.ignoring = true;
    final semantics = _activeRender(_semanticsKey.currentContext);
    if (semantics is RenderExcludeSemantics) semantics.excluding = true;
    if (!_finalized) {
      final entry = _entry;
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (identical(_entry, entry)) entry?.markNeedsBuild();
        });
      } else {
        entry?.markNeedsBuild();
      }
    }
    notifyListeners();
    if (restoreFocus && _restoreFocus && ownedFocus && _sourceIsVisible) _restorePreviousFocus();
    if (_finalized) return;
    if (_exitDuration == Duration.zero || !_sourceIsVisible) {
      _finalize();
    } else {
      _exitTimer = Timer(_exitDuration, _finalize);
    }
  }

  void _restorePreviousFocus() {
    final target = _previousFocus;
    if (target == null || !FocusUtil.isVisible(target)) return;
    void restore() {
      if (!FocusUtil.isVisible(target)) return;
      FocusUtil.markReason(target, ElFocusReason.lifecycle);
      FocusUtil.requestFocus(target);
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => restore());
    } else {
      restore();
    }
  }

  void _finalize() {
    if (_finalized) return;
    _finalized = true;
    _exitTimer?.cancel();
    if (_open) _close(restoreFocus: false);
    final entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
    if (!_layerMounted) _disposeFocusScope();
    if (!_closed.isCompleted) _closed.complete();
  }

  void _disposeFocusScope() {
    if (_scopeDisposed) return;
    _scopeDisposed = true;
    _focusScope.dispose();
  }
}

/// 仅在应用本来产生帧时检查归属，不主动驱动帧或常驻计时器。
class _MenuOwnerWatch {
  static final Set<ElContextMenuHandle> _handles = {};
  static bool _scheduled = false;

  static void add(ElContextMenuHandle handle) {
    _handles.add(handle);
    _schedule();
  }

  static void remove(ElContextMenuHandle handle) => _handles.remove(handle);

  static void _schedule() {
    if (_scheduled || _handles.isEmpty) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      for (final handle in _handles.toList()) {
        if (!handle._sourceIsVisible) handle._closeChainWithoutFocus();
      }
      _schedule();
    });
  }
}

class _MenuOverlayLayer extends StatefulWidget {
  const _MenuOverlayLayer({required this.handle});

  final ElContextMenuHandle handle;

  @override
  State<_MenuOverlayLayer> createState() => _MenuOverlayLayerState();
}

class _MenuOverlayLayerState extends State<_MenuOverlayLayer> {
  @override
  void initState() {
    super.initState();
    widget.handle._layerMounted = true;
  }

  @override
  void dispose() {
    widget.handle._finalize();
    widget.handle._disposeFocusScope();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final handle = widget.handle;
    final overlayRender = handle._overlay.context.findRenderObject();
    Offset local(Offset global) => overlayRender is RenderBox ? overlayRender.globalToLocal(global) : global;
    Rect? anchor;
    final anchorContext = handle._anchor;
    if (anchorContext != null && anchorContext.mounted) {
      final render = anchorContext.findRenderObject();
      if (render is RenderBox && render.attached && render.hasSize) {
        anchor = Rect.fromPoints(
          local(render.localToGlobal(Offset.zero)),
          local(render.localToGlobal(render.size.bottomRight(Offset.zero))),
        );
      }
    }
    return Directionality(
      textDirection: handle._direction,
      child: FocusScope(
        node: handle._focusScope,
        onKeyEvent: (_, event) {
          if (!handle.isOpen || event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            // hover 展开的子菜单可能尚未移焦，Escape 仍只关闭最深一层。
            handle._chain.closeFrom(handle._chain._entries.length - 1);
            return KeyEventResult.handled;
          }
          return event.logicalKey == LogicalKeyboardKey.tab ? KeyEventResult.handled : KeyEventResult.ignored;
        },
        child: CustomSingleChildLayout(
          delegate: _MenuPositionDelegate(position: local(handle._position), anchor: anchor),
          child: ExcludeSemantics(
            key: handle._semanticsKey,
            excluding: !handle.isShowing,
            child: IgnorePointer(
              key: handle._ignoreKey,
              ignoring: !handle.isOpen,
              child: KeyedSubtree(
                key: handle._contentKey,
                child: handle._themes.wrap(
                  SelectionContainer.disabled(
                    child: Builder(builder: (context) => handle._builder(context, !handle.isShowing)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuPositionDelegate extends SingleChildLayoutDelegate {
  const _MenuPositionDelegate({required this.position, this.anchor});

  final Offset position;
  final Rect? anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final anchor = this.anchor;
    var left = anchor?.right ?? position.dx;
    if (anchor != null && left + childSize.width > size.width - 4) left = anchor.left - childSize.width;
    final maxLeft = (size.width - childSize.width - 4).clamp(4.0, double.infinity);
    final maxTop = (size.height - childSize.height - 4).clamp(4.0, double.infinity);
    return Offset(left.clamp(4.0, maxLeft).toDouble(), (anchor?.top ?? position.dy).clamp(4.0, maxTop).toDouble());
  }

  @override
  bool shouldRelayout(_MenuPositionDelegate oldDelegate) =>
      position != oldDelegate.position || anchor != oldDelegate.anchor;
}
