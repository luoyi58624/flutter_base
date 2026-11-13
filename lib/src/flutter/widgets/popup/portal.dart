import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../views/view/event/dispatcher.dart' show EventDispatcher;
import 'anchor.dart';
import 'hover_intent.dart';
import 'host.dart';
import 'popup_stack.dart';
import 'scope.dart';
import 'session.dart';

/// 锚定弹层的进退场阶段，供面板构建时选择对应样式。
enum ElPortalPhase {
  /// 入场首帧，下一帧切换为可见阶段。
  entering,

  /// 面板正常显示。
  visible,

  /// 面板停止交互，等待退场完成后移除。
  exiting,
}

/// 锚定弹层的开闭控制器，关闭后可再次打开。
class ElPortalController extends ChangeNotifier {
  _PortalState? _state;
  void _changed() => notifyListeners();

  /// 是否正在显示并接受交互。
  bool get isOpen => _state?._open ?? false;

  /// 本次内容完成退场并摘除后结清。
  Future<void> get closed => _state?._closed?.future ?? Future.value();

  /// 显示面板；退场期间的打开请求在摘树后执行。
  void open() => _state?._show();

  /// 关闭面板，退场内容立即停止交互。
  void close() => _state?._hide();

  /// 切换开闭状态。
  void toggle() => isOpen || (_state?._queued ?? false) ? close() : open();
}

/// 包裹目标并在其周围展示面板；省略 controller 时由 panel 是否为空控制显示。
class ElPortal extends StatefulWidget {
  /// 创建锚定弹层，panel 与 overlayBuilder 二选一。
  const ElPortal({
    super.key,
    this.controller,
    required this.child,
    this.panel,
    this.overlayBuilder,
    this.anchor = const ElOverlayAnchor(),
    this.anchorPosition,
    this.rootOverlay = false,
    this.exitDuration = Duration.zero,
    this.consumeOutsideTap = false,
    this.closeOnOutsideTap = true,
    this.closeOnOutsidePointerDown = false,
    this.closeOnScroll = false,
    this.closeOnEscape = true,
    this.closeOnBack = false,
    this.onBack,
    this.hideWhenUnlinked = false,
    this.closeWhenUnlinked = false,
    this.onDismiss,
    this.captureFocus = false,
    this.restoreFocus = false,
    this.hoverIntent,
  }) : assert(panel == null || overlayBuilder == null);

  /// 可选开闭控制器。
  final ElPortalController? controller;

  /// 锚定目标。
  final Widget child;

  /// 直接展示的面板。
  final Widget? panel;

  /// 打开时构建的面板。
  final WidgetBuilder? overlayBuilder;

  /// 定位和避让配置。
  final ElOverlayAnchor anchor;

  /// 可选的全局点锚，省略时继续跟随触发元素定位。
  final Offset? anchorPosition;

  /// 是否使用根 Overlay，显示期间保持挂载点不变。
  final bool rootOverlay;

  /// 关闭后保留退场内容的时长，期间固定关闭时的定位和尺寸。
  final Duration exitDuration;

  /// 外点是否阻止背景响应。
  final bool consumeOutsideTap;

  /// 是否通过外点关闭。
  final bool closeOnOutsideTap;

  /// 允许外点关闭时改为按下即请求，省略时保留有效抬起后关闭的行为。
  final bool closeOnOutsidePointerDown;

  /// 触发者祖先滚动或面板外滚轮滚动时请求关闭，面板内部滚动不受影响。
  final bool closeOnScroll;

  /// 是否通过 Escape 关闭。
  final bool closeOnEscape;

  /// 是否消费页面返回以关闭面板。
  final bool closeOnBack;

  /// 系统返回的自定义动作，省略时请求关闭，可用于先返回子菜单层。
  final VoidCallback? onBack;

  /// 目标离开视口时隐藏，返回后恢复。
  final bool hideWhenUnlinked;

  /// 目标离开视口时请求关闭。
  final bool closeWhenUnlinked;

  /// 自定义关闭请求，省略时直接关闭。
  final VoidCallback? onDismiss;

  /// 打开时是否聚焦面板。
  ///
  /// false 时跳过作用域自身的键盘遍历，后代显式配置的焦点仍可使用。
  final bool captureFocus;

  /// 关闭时是否归还焦点。
  final bool restoreFocus;

  /// 悬停开闭与安全区域配置。
  final ElHoverIntent? hoverIntent;

  /// 最近面板的定位结果。
  static ElOverlayAnchorGeometry? geometryOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PortalScope>()?.geometry;

  /// 最近面板的进退场阶段。
  static ElPortalPhase phaseOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PortalScope>()?.phase ?? ElPortalPhase.visible;
  @override
  State<ElPortal> createState() => _PortalState();
}

class _PortalState extends State<ElPortal> {
  final _portal = OverlayPortalController();
  final _targetKey = GlobalKey(), _panelKey = GlobalKey();
  final _focus = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  final _ignoreKey = GlobalKey(), _tapKey = GlobalKey();
  final _scrollPositions = <ScrollPosition>{};
  bool _listeningToPointerScroll = false;
  (int, Offset)? _outsideDown;
  FocusNode? _restore;
  Widget? _content;
  Completer<void>? _closed;
  Timer? _exit;
  LocalHistoryEntry? _back;
  PopupStack? _stack;
  PopupStack? _inputStack;
  OverlayState? _overlay;
  int? _viewId;
  PopupHostState? _host;
  PopupSession<Object?>? _owner;
  HoverIntentMachine? _hover;
  ElOverlayAnchorGeometry? _geometry;
  ElOverlayAnchorGeometry? _layoutGeometry, _exitGeometry;
  ElPortalPhase _phase = ElPortalPhase.entering;
  bool _open = false, _queued = false, _root = false, _lost = false;
  bool get _canInteract => _host?.frontPanel == _owner;
  bool get _top => _open && _canInteract && (_inputStack?.isTopmost(_closed!) ?? false);

  @override
  void initState() {
    super.initState();
    _syncHover();
    FocusManager.instance.addEarlyKeyEventHandler(_key);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewId = popupViewId(context);
    final overlay = _closed == null ? null : Overlay.maybeOf(context, rootOverlay: _root);
    if (_closed != null && (_viewId != viewId || !identical(overlay, _overlay))) {
      if (_open) _hide();
      _exit?.cancel();
      if (_content != null) _finishExit();
    }
    if (widget.controller == null && widget.panel != null) _show();
  }

  void _bindController() {
    final controller = widget.controller;
    if (controller?._state != null && controller!._state != this) throw StateError('控制器只能绑定一个 ElPortal。');
    controller?._state = this;
  }

  @override
  void didUpdateWidget(ElPortal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (identical(oldWidget.controller?._state, this)) oldWidget.controller?._state = null;
      _bindController();
    }

    if (oldWidget.hoverIntent != widget.hoverIntent) _syncHover();
    if (widget.controller == null) {
      if (widget.panel == null) {
        _hide();
      } else if (!_open) {
        _show();
      } else {
        _content = widget.panel;
      }
    } else if (_open && widget.panel != null) {
      _content = widget.panel;
    }
    if (_open && oldWidget.captureFocus != widget.captureFocus) {
      _focus.skipTraversal = !widget.captureFocus;
      if (widget.captureFocus) {
        _rememberFocus();
        _requestFocus();
      } else {
        _releaseFocus();
      }
    }
    _syncStack();
    _syncScrollObservers();
    if (_open && widget.closeOnBack) {
      _attachBack();
    } else {
      _detachBack();
    }
  }

  void _syncHover() {
    _hover?.dispose();
    _hover = widget.hoverIntent == null
        ? null
        : HoverIntentMachine(
            config: widget.hoverIntent!,
            requestOpen: _show,
            requestClose: _hide,
            rectsOf: () => [
              for (final key in [_targetKey, _panelKey])
                if (key.currentContext?.findRenderObject() case RenderBox box when box.attached && box.hasSize)
                  MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size),
            ],
          );
  }

  void _syncStack() {
    final session = _closed;
    if (session == null) return;
    if (_open &&
        (widget.consumeOutsideTap || widget.controller != null || widget.onDismiss != null || widget.closeOnBack)) {
      _inputStack?.register(session, onChanged: _syncGates);
      if (!identical(_stack, _inputStack)) _stack?.register(session);
    } else {
      _unregisterStack(session);
    }
    _syncBackRegistration();
    _syncGates();
  }

  void _unregisterStack(Object session) {
    _inputStack?.unregister(session);
    if (!identical(_stack, _inputStack)) _stack?.unregister(session);
  }

  void _syncBackRegistration() {
    final overlay = _overlay;
    final session = _closed;
    if (overlay == null || session == null) return;
    _host?.registerBack(overlay, session, _open && _canInteract && widget.closeOnBack ? _onHostBack : null);
  }

  bool _onHostBack(BuildContext source) {
    if (!_open || !_canInteract || popupViewId(source) != _viewId || !identical(popupHostOf(source), _host)) {
      return false;
    }
    (widget.onBack ?? widget.onDismiss ?? _hide)();
    return true;
  }

  void _syncGates() {
    final ignore = (_ignoreKey.currentContext as RenderObjectElement?)?.renderObject;
    if (ignore is RenderIgnorePointer) ignore.ignoring = !_open;
    final region = (_tapKey.currentContext as RenderObjectElement?)?.renderObject;
    if (region is RenderTapRegion) {
      region.consumeOutsideTaps = _top && widget.consumeOutsideTap;
      region.behavior = _top ? HitTestBehavior.opaque : HitTestBehavior.deferToChild;
    }
  }

  void _syncScrollObservers() {
    final listening = _open && widget.closeOnScroll;
    if (!listening && _scrollPositions.isEmpty && !_listeningToPointerScroll) return;
    final positions = <ScrollPosition>{};
    if (listening) {
      context.visitAncestorElements((element) {
        if (element is StatefulElement && element.state is ScrollableState) {
          positions.add((element.state as ScrollableState).position);
        }
        return true;
      });
    }
    for (final position in _scrollPositions.difference(positions)) {
      position.removeListener(_scrollChanged);
    }
    for (final position in positions.difference(_scrollPositions)) {
      position.addListener(_scrollChanged);
    }
    _scrollPositions
      ..clear()
      ..addAll(positions);
    if (listening == _listeningToPointerScroll) return;
    _listeningToPointerScroll = listening;
    if (listening) {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_pointerScroll);
    } else {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_pointerScroll);
    }
  }

  void _scrollChanged() => _afterBuild(_dismiss);

  void _pointerScroll(PointerEvent event) {
    if (event is! PointerScrollEvent ||
        event.viewId != _viewId ||
        !_top ||
        !_inputStack!.isTopmostForEvent(_closed!, event)) {
      return;
    }
    final render = _panelKey.currentContext?.findRenderObject();
    if (render is RenderBox && render.attached && render.hasSize) {
      final rect = MatrixUtils.transformRect(render.getTransformTo(null), Offset.zero & render.size);
      if (rect.contains(event.position)) return;
    }
    _dismiss();
  }

  // Overlay 的视口不能表达嵌套滚动区裁剪，需沿原触发物的绘制链求交。
  bool _targetClipped(RenderObject overlay, Rect rect) {
    final target = _targetKey.currentContext?.findRenderObject();
    if (target == null) return false;
    var child = target;
    var parent = child.parent;
    while (parent != null) {
      final clip = parent.describeApproximatePaintClip(child);
      if (clip != null) {
        final visible = MatrixUtils.transformRect(parent.getTransformTo(overlay), clip);
        if (rect.isEmpty ? !visible.contains(rect.topLeft) : !rect.overlaps(visible)) return true;
        if (!rect.isEmpty) rect = rect.intersect(visible);
      }
      if (identical(parent, overlay)) break;
      child = parent;
      parent = child.parent;
    }
    return false;
  }

  void _show() {
    if (!mounted || _open) return;
    if (_closed != null) {
      _queued = true;
      return;
    }
    final target = popupOverlayOf(context, rootOverlay: widget.rootOverlay);
    if (target == null) return;
    final root = Overlay.maybeOf(context, rootOverlay: true) ?? target.overlay;
    final host = popupHostOf(context);
    final owner = popupLayerOf(context);
    if (!identical(host?.frontPanel, owner)) return;
    _host = host;
    _owner = owner;
    _host?.layerChanges.addListener(_hostChanged);
    _overlay = target.overlay;
    _stack = PopupStack.forOverlay(target.overlay);
    // 同一根 Overlay 下的局部 TapRegion 可能同时收到外点，统一选择本次接收者。
    _inputStack = PopupStack.forOverlay(root);
    _viewId = target.viewId;
    _closed = Completer<void>();
    _layoutGeometry = null;
    _exitGeometry = null;
    _root = widget.rootOverlay;
    _rememberFocus();
    _content = widget.panel ?? Builder(builder: widget.overlayBuilder!);
    _focus
      ..canRequestFocus = true
      ..skipTraversal = !widget.captureFocus
      ..descendantsAreFocusable = true
      ..descendantsAreTraversable = true;
    setState(() {
      _open = true;
      _phase = ElPortalPhase.entering;
    });
    _syncStack();
    _syncScrollObservers();
    _afterBuild(() {
      if (!mounted || !_open) return;
      _portal.show();
      _attachBack();
      _requestFocus();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) setState(() => _phase = ElPortalPhase.visible);
    });
    widget.controller?._changed();
  }

  void _hide() {
    _queued = false;
    if (!_open) return;
    _outsideDown = null;
    if (_panelKey.currentContext?.findRenderObject() case final RenderObject panel) {
      EventDispatcher.terminateActivePointerSequencesIn(panel);
    }
    _exitGeometry = _layoutGeometry;
    _detachBack();
    _host?.layerChanges.removeListener(_hostChanged);
    _releaseFocus();
    _focus
      ..canRequestFocus = false
      ..descendantsAreFocusable = false
      ..descendantsAreTraversable = false;
    setState(() {
      _open = false;
      _phase = ElPortalPhase.exiting;
    });
    _syncStack();
    _syncScrollObservers();
    if (widget.exitDuration == Duration.zero) {
      _finishExit();
    } else {
      _exit = Timer(widget.exitDuration, _finishExit);
    }
    widget.controller?._changed();
  }

  void _finishExit() {
    if (!mounted) return;
    setState(() => _content = null);
    _afterBuild(_portal.hide);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!(_closed?.isCompleted ?? true)) _closed!.complete();
      _closed = null;
      _stack = null;
      _inputStack = null;
      _overlay = null;
      _viewId = null;
      _host = null;
      _owner = null;
      scheduleMicrotask(() {
        if (mounted && _queued) {
          _queued = false;
          _show();
        }
      });
    });
  }

  void _dismiss() {
    if (_top) (widget.onDismiss ?? _hide)();
  }

  void _hostChanged() {
    _syncBackRegistration();
    _syncGates();
    if (_open && !_canInteract) {
      _afterBuild(() {
        if (!_open || _canInteract) return;
        (widget.onDismiss ?? _hide)();
      });
    }
  }

  void _afterBuild(VoidCallback callback) {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) callback();
      });
    } else {
      callback();
    }
  }

  void _requestFocus() {
    if (widget.captureFocus && _focus.context != null) _focus.requestFocus();
  }

  void _rememberFocus() {
    final focused = FocusManager.instance.primaryFocus;
    final focusContext = focused?.context;
    _restore = focusContext != null && popupViewId(focusContext) == _viewId ? focused : null;
  }

  void _releaseFocus() {
    if (!_focus.hasFocus) return;
    final restoreContext = _restore?.context;
    if (widget.restoreFocus &&
        restoreContext != null &&
        popupViewId(restoreContext) == _viewId &&
        _restore!.canRequestFocus) {
      _restore!.requestFocus();
    } else {
      _focus.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    }
  }

  void _attachBack() {
    if (!_open || !widget.closeOnBack || _back != null || _host != null) return;
    _afterBuild(() {
      if (!_open || !widget.closeOnBack || _back != null || _host != null) return;
      final route = ModalRoute.of(context);
      if (route == null) return;
      late final LocalHistoryEntry entry;
      entry = LocalHistoryEntry(
        impliesAppBarDismissal: false,
        onRemove: () {
          if (!identical(_back, entry)) return;
          _back = null;
          if (_top) (widget.onBack ?? _dismiss)();
          scheduleMicrotask(() {
            if (mounted) _attachBack();
          });
        },
      );
      route.addLocalHistoryEntry(_back = entry);
    });
  }

  void _detachBack() {
    final back = _back;
    _back = null;
    back?.remove();
  }

  KeyEventResult _key(KeyEvent event, {bool fromScope = false}) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape ||
        !widget.closeOnEscape ||
        !_top ||
        !_isKeyboardInScope()) {
      return KeyEventResult.ignored;
    }
    final focus = FocusManager.instance.primaryFocus?.context;
    if ((fromScope || focus?.findAncestorStateOfType<_PortalState>() != this) &&
        _inputStack!.isTopmostForEvent(_closed!, event)) {
      _dismiss();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _isKeyboardInScope() {
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus == null) {
      return WidgetsBinding.instance.platformDispatcher.views.length == 1;
    }
    if (popupViewId(focus) != _viewId) return false;
    final root = Overlay.maybeOf(focus, rootOverlay: true);
    return root != null && identical(PopupStack.maybeOf(root), _inputStack);
  }

  Widget _region(Widget child) => _hover == null
      ? child
      : MouseRegion(onEnter: (_) => _hover!.pointerEntered(), onExit: (_) => _hover!.pointerExited(), child: child);
  Widget _shortcuts(Widget child) => CallbackShortcuts(
    bindings: {if (widget.closeOnEscape && _top) const SingleActivator(LogicalKeyboardKey.escape): _dismiss},
    child: child,
  );
  void _publish(ElOverlayAnchorGeometry geometry) {
    _layoutGeometry = geometry;
    if (geometry == _geometry) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && geometry != _geometry) setState(() => _geometry = geometry);
    });
  }

  @override
  Widget build(BuildContext context) {
    _bindController();
    _syncScrollObservers();
    Widget buildOverlay(BuildContext context, Matrix4 targetTransform, Size targetSize, Size overlaySize) {
      if (_content == null) return const SizedBox.shrink();
      if (_open && widget.captureFocus && !_focus.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _open) _requestFocus();
        });
      }
      final targetRect = MatrixUtils.transformRect(targetTransform, Offset.zero & targetSize);
      final hostOverlay = _overlay;
      if (hostOverlay == null || !hostOverlay.mounted) return const SizedBox.shrink();
      final overlay = hostOverlay.context.findRenderObject()! as RenderBox;
      final rect = widget.anchorPosition == null
          ? targetRect
          : overlay.globalToLocal(widget.anchorPosition!) & Size.zero;
      final viewport = Offset.zero & overlaySize;
      final lost =
          (targetRect.isEmpty ? !viewport.contains(targetRect.topLeft) : !targetRect.overlaps(viewport)) ||
          ((widget.hideWhenUnlinked || widget.closeWhenUnlinked) && _targetClipped(overlay, targetRect));
      if (lost && !_lost && widget.closeWhenUnlinked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _dismiss();
        });
      }
      _lost = lost;
      return IgnorePointer(
        key: _ignoreKey,
        ignoring: !_open,
        child: Offstage(
          offstage: lost && widget.hideWhenUnlinked,
          child: CustomSingleChildLayout(
            delegate: _PopupLayout(rect, widget.anchor, _publish, frozen: _open ? null : _exitGeometry),
            child: TapRegion(
              key: _tapKey,
              groupId: this,
              behavior: _top ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
              consumeOutsideTaps: _top && widget.consumeOutsideTap,
              onTapOutside: (event) {
                if (event.viewId == _viewId && _top && _inputStack!.isTopmostForEvent(_closed!, event)) {
                  _outsideDown = (event.pointer, event.position);
                  if (widget.closeOnOutsideTap && widget.closeOnOutsidePointerDown) {
                    _outsideDown = null;
                    _dismiss();
                  }
                }
              },
              onTapUpOutside: (event) {
                final down = _outsideDown;
                _outsideDown = null;
                if (down != null &&
                    event.viewId == _viewId &&
                    down.$1 == event.pointer &&
                    (event.position - down.$2).distance <= kTouchSlop &&
                    widget.closeOnOutsideTap &&
                    _top &&
                    _inputStack!.isTopmostForEvent(_closed!, event)) {
                  scheduleMicrotask(_dismiss);
                }
              },
              child: _PortalScope(
                geometry: _geometry,
                phase: _phase,
                child: FocusScope(
                  node: _focus,
                  onKeyEvent: (_, event) => _key(event, fromScope: true),
                  canRequestFocus: _open,
                  skipTraversal: !widget.captureFocus,
                  descendantsAreFocusable: _open,
                  descendantsAreTraversable: _open,
                  child: KeyedSubtree(key: _panelKey, child: _shortcuts(_region(_content!))),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final child = TapRegion(key: _targetKey, groupId: this, child: _shortcuts(_region(widget.child)));
    final location = _root ? OverlayChildLocation.rootOverlay : OverlayChildLocation.nearestOverlay;
    // Follower 的坐标只在合成后有效，不能交给官方布局期目标变换查询。
    if (context.findAncestorRenderObjectOfType<RenderFollowerLayer>() != null) {
      return OverlayPortal(
        controller: _portal,
        overlayLocation: location,
        child: child,
        overlayChildBuilder: (context) => LayoutBuilder(
          builder: (context, constraints) {
            final target = _targetKey.currentContext!.findRenderObject()! as RenderBox;
            final hostOverlay = _overlay;
            if (hostOverlay == null || !hostOverlay.mounted) return const SizedBox.shrink();
            final overlay = hostOverlay.context.findRenderObject();
            return buildOverlay(context, target.getTransformTo(overlay), target.size, constraints.biggest);
          },
        ),
      );
    }
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayLocation: location,
      child: child,
      overlayChildBuilder: (context, info) =>
          buildOverlay(context, info.childPaintTransform, info.childSize, info.overlaySize),
    );
  }

  @override
  void dispose() {
    _exit?.cancel();
    _hover?.dispose();
    _host?.layerChanges.removeListener(_hostChanged);
    _open = false;
    _syncScrollObservers();
    _detachBack();
    _releaseFocus();
    _focus.dispose();
    FocusManager.instance.removeEarlyKeyEventHandler(_key);
    if (_closed case final session?) _unregisterStack(session);
    _syncBackRegistration();
    if (!(_closed?.isCompleted ?? true)) _closed!.complete();
    if (identical(widget.controller?._state, this)) widget.controller?._state = null;
    super.dispose();
  }
}

class _PortalScope extends InheritedWidget {
  const _PortalScope({required this.geometry, required this.phase, required super.child});
  final ElOverlayAnchorGeometry? geometry;
  final ElPortalPhase phase;
  @override
  bool updateShouldNotify(_PortalScope oldWidget) => geometry != oldWidget.geometry || phase != oldWidget.phase;
}

class _PopupLayout extends SingleChildLayoutDelegate {
  _PopupLayout(this.rect, this.config, this.onGeometry, {this.frozen});
  final Rect rect;
  final ElOverlayAnchor config;
  final ValueChanged<ElOverlayAnchorGeometry> onGeometry;
  final ElOverlayAnchorGeometry? frozen;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    if (frozen != null) return BoxConstraints.tight(frozen!.overlayRect.size);
    final width = (constraints.maxWidth - config.viewportPadding * 2).clamp(0.0, double.infinity);
    final anchorWidth = rect.width.clamp(0.0, width);
    return BoxConstraints(
      minWidth: config.matchWidth || config.matchMinWidth ? anchorWidth : 0,
      maxWidth: config.matchWidth ? anchorWidth : width,
      maxHeight: (constraints.maxHeight - config.viewportPadding * 2).clamp(0.0, double.infinity),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final geometry = frozen ?? config.resolve(rect, childSize, Offset.zero & size);
    onGeometry(geometry);
    return geometry.overlayRect.topLeft;
  }

  @override
  bool shouldRelayout(_PopupLayout oldDelegate) =>
      rect != oldDelegate.rect || config != oldDelegate.config || frozen != oldDelegate.frozen;
}
