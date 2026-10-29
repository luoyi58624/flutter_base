import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../presence/presence.dart';
import '../view/event/dispatcher.dart' show EventDispatcher;
import 'anchor.dart';
import 'hover_intent.dart';
import 'popup_stack.dart';

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
    this.rootOverlay = false,
    this.exitDuration = Duration.zero,
    this.consumeOutsideTap = false,
    this.closeOnOutsideTap = true,
    this.closeOnEscape = true,
    this.closeOnBack = false,
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

  /// 是否使用根 Overlay，显示期间保持挂载点不变。
  final bool rootOverlay;

  /// 关闭后保留退场内容的时长。
  final Duration exitDuration;

  /// 外点是否阻止背景响应。
  final bool consumeOutsideTap;

  /// 是否通过外点关闭。
  final bool closeOnOutsideTap;

  /// 是否通过 Escape 关闭。
  final bool closeOnEscape;

  /// 是否消费页面返回以关闭面板。
  final bool closeOnBack;

  /// 目标离开视口时隐藏，返回后恢复。
  final bool hideWhenUnlinked;

  /// 目标离开视口时请求关闭。
  final bool closeWhenUnlinked;

  /// 自定义关闭请求，省略时直接关闭。
  final VoidCallback? onDismiss;

  /// 打开时是否聚焦面板。
  final bool captureFocus;

  /// 关闭时是否归还焦点。
  final bool restoreFocus;

  /// 悬停开闭与安全区域配置。
  final ElHoverIntent? hoverIntent;

  /// 最近面板的定位结果。
  static ElOverlayAnchorGeometry? geometryOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PortalScope>()?.geometry;

  /// 最近面板的进退场阶段。
  static ElPresencePhase phaseOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PortalScope>()?.phase ?? ElPresencePhase.visible;
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
  (int, Offset)? _outsideDown;
  FocusNode? _restore;
  Widget? _content;
  Completer<void>? _closed;
  Timer? _exit;
  LocalHistoryEntry? _back;
  HoverIntentMachine? _hover;
  ElOverlayAnchorGeometry? _geometry;
  ElPresencePhase _phase = ElPresencePhase.entering;
  bool _open = false, _queued = false, _root = false, _lost = false;
  bool get _top => _open && ElPopupStack.isTopmost(this);

  @override
  void initState() {
    super.initState();
    _syncHover();
    FocusManager.instance.addEarlyKeyEventHandler(_key);
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
    }
    if (_open && oldWidget.captureFocus != widget.captureFocus) {
      if (widget.captureFocus) {
        _restore = FocusManager.instance.primaryFocus;
        _requestFocus();
      } else {
        _releaseFocus();
      }
    }
    _syncStack();
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
    if (_open && (widget.consumeOutsideTap || widget.controller != null || widget.onDismiss != null)) {
      ElPopupStack.register(this, onChanged: _syncGates);
    } else {
      ElPopupStack.unregister(this);
    }
    _syncGates();
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

  void _show() {
    if (_open) return;
    if (_closed != null) {
      _queued = true;
      return;
    }
    _closed = Completer<void>();
    _root = widget.rootOverlay;
    _restore = FocusManager.instance.primaryFocus;
    _content = widget.panel ?? Builder(builder: widget.overlayBuilder!);
    _focus
      ..canRequestFocus = true
      ..descendantsAreFocusable = true
      ..descendantsAreTraversable = true;
    setState(() {
      _open = true;
      _phase = ElPresencePhase.entering;
    });
    _syncStack();
    _afterBuild(() {
      if (!mounted || !_open) return;
      _portal.show();
      _attachBack();
      _requestFocus();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) setState(() => _phase = ElPresencePhase.visible);
    });
    widget.controller?._changed();
  }

  void _hide() {
    _queued = false;
    if (!_open) return;
    if (_panelKey.currentContext?.findRenderObject() case final RenderObject panel) {
      EventDispatcher.terminateActivePointerSequencesIn(panel, force: true);
    }
    _detachBack();
    _releaseFocus();
    _focus
      ..canRequestFocus = false
      ..descendantsAreFocusable = false
      ..descendantsAreTraversable = false;
    setState(() {
      _open = false;
      _phase = ElPresencePhase.exiting;
    });
    _syncStack();
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
      if (!(_closed?.isCompleted ?? true)) _closed!.complete();
      _closed = null;
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

  void _releaseFocus() {
    if (!_focus.hasFocus) return;
    if (widget.restoreFocus && (_restore?.context?.mounted ?? false) && _restore!.canRequestFocus) {
      _restore!.requestFocus();
    } else {
      _focus.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    }
  }

  void _attachBack() {
    if (!_open || !widget.closeOnBack || _back != null) return;
    _afterBuild(() {
      if (!_open || _back != null) return;
      final route = ModalRoute.of(context);
      if (route == null) return;
      late final LocalHistoryEntry entry;
      entry = LocalHistoryEntry(
        impliesAppBarDismissal: false,
        onRemove: () {
          if (!identical(_back, entry)) return;
          _back = null;
          _dismiss();
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

  KeyEventResult _key(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        widget.closeOnEscape &&
        _top &&
        FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<_PortalState>() != this &&
        ElPopupStack.isTopmostForEvent(this, event)) {
      _dismiss();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _region(Widget child) => _hover == null
      ? child
      : MouseRegion(onEnter: (_) => _hover!.pointerEntered(), onExit: (_) => _hover!.pointerExited(), child: child);
  Widget _shortcuts(Widget child) => CallbackShortcuts(
    bindings: {if (widget.closeOnEscape && _top) const SingleActivator(LogicalKeyboardKey.escape): _dismiss},
    child: child,
  );
  void _publish(ElOverlayAnchorGeometry geometry) {
    if (geometry == _geometry) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && geometry != _geometry) setState(() => _geometry = geometry);
    });
  }

  @override
  Widget build(BuildContext context) {
    _bindController();
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayLocation: _root ? OverlayChildLocation.rootOverlay : OverlayChildLocation.nearestOverlay,
      child: TapRegion(key: _targetKey, groupId: this, child: _shortcuts(_region(widget.child))),
      overlayChildBuilder: (context, info) {
        if (_content == null) return const SizedBox.shrink();
        if (_open && widget.captureFocus && !_focus.hasFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _open) _requestFocus();
          });
        }
        final rect = MatrixUtils.transformRect(info.childPaintTransform, Offset.zero & info.childSize);
        final viewport = Offset.zero & info.overlaySize;
        final lost = rect.isEmpty ? !viewport.contains(rect.topLeft) : !rect.overlaps(viewport);
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
              delegate: _PopupLayout(rect, widget.anchor, _publish),
              child: TapRegion(
                key: _tapKey,
                groupId: this,
                behavior: _top ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
                consumeOutsideTaps: _top && widget.consumeOutsideTap,
                onTapOutside: (event) {
                  if (_top && ElPopupStack.isTopmostForEvent(this, event)) {
                    _outsideDown = (event.pointer, event.position);
                  }
                },
                onTapUpOutside: (event) {
                  final down = _outsideDown;
                  _outsideDown = null;
                  if (down != null &&
                      down.$1 == event.pointer &&
                      (event.position - down.$2).distance <= kTouchSlop &&
                      widget.closeOnOutsideTap &&
                      _top &&
                      ElPopupStack.isTopmostForEvent(this, event)) {
                    scheduleMicrotask(_dismiss);
                  }
                },
                child: _PortalScope(
                  geometry: _geometry,
                  phase: _phase,
                  child: FocusScope(
                    node: _focus,
                    child: KeyedSubtree(key: _panelKey, child: _shortcuts(_region(_content!))),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _exit?.cancel();
    _hover?.dispose();
    _open = false;
    _detachBack();
    _releaseFocus();
    _focus.dispose();
    FocusManager.instance.removeEarlyKeyEventHandler(_key);
    ElPopupStack.unregister(this);
    if (!(_closed?.isCompleted ?? true)) _closed!.complete();
    if (identical(widget.controller?._state, this)) widget.controller?._state = null;
    super.dispose();
  }
}

class _PortalScope extends InheritedWidget {
  const _PortalScope({required this.geometry, required this.phase, required super.child});
  final ElOverlayAnchorGeometry? geometry;
  final ElPresencePhase phase;
  @override
  bool updateShouldNotify(_PortalScope oldWidget) => geometry != oldWidget.geometry || phase != oldWidget.phase;
}

class _PopupLayout extends SingleChildLayoutDelegate {
  _PopupLayout(this.rect, this.config, this.onGeometry);
  final Rect rect;
  final ElOverlayAnchor config;
  final ValueChanged<ElOverlayAnchorGeometry> onGeometry;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
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
    final geometry = config.resolve(rect, childSize, size);
    onGeometry(geometry);
    return geometry.overlayRect.topLeft;
  }

  @override
  bool shouldRelayout(_PopupLayout oldDelegate) => rect != oldDelegate.rect || config != oldDelegate.config;
}
