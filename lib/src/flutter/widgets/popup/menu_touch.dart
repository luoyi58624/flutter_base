part of 'context_menu.dart';

/// 只在不可滚动的菜单内竞争普通拖拽，可滚动菜单保留原生滚动手势。
class _MenuPanRecognizer extends PanGestureRecognizer {
  _MenuPanRecognizer() : super(supportedDevices: {PointerDeviceKind.touch, PointerDeviceKind.stylus});

  late bool Function() allows;
  PointerDownEvent? down;

  @override
  bool isPointerAllowed(PointerEvent event) => allows() && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    down = event;
    super.addAllowedPointer(event);
  }
}

/// 复用菜单链的指针监听，触摸移动仅命中测试并更新前后两项的样式；可滚动菜单不滑选。
class _MenuTouchSelection {
  _MenuTouchSelection(this.chain);

  final _MenuChain chain;
  final _haptics = TouchHaptics();
  int? _pointer;
  int? _completedPointer;
  int _viewId = 0;
  Offset _origin = Offset.zero;
  Offset _position = Offset.zero;
  bool _armed = false;
  _MenuItemHostState? _target;

  bool get isTracking => _pointer != null;

  bool suppresses(Object? event) => isTracking || (event is PointerEvent && event.pointer == _completedPointer);

  bool begin(PointerDownEvent event, {Offset? position, bool armed = false}) {
    if (isTracking || !TouchHaptics.accepts(event) || chain._entries.isEmpty) return false;
    _pointer = event.pointer;
    _completedPointer = null;
    _viewId = event.viewId;
    _origin = event.position;
    _position = position ?? event.position;
    _armed = armed;
    _haptics.reset();
    if (armed) _update();
    // ElEvent 长按回调返回后会释放原按压态，在同一帧内恢复滑选高亮。
    scheduleMicrotask(() {
      if (_pointer == event.pointer) _target?._setTouchHighlighted(true);
    });
    return isTracking;
  }

  void handlePointer(PointerEvent event) {
    if (event is PointerDownEvent && !isTracking) _completedPointer = null;
    if (event.pointer != _pointer || event.viewId != _viewId) return;
    if (event is PointerCancelEvent) {
      _stop();
      chain.closeAll();
      return;
    }
    if (event is! PointerMoveEvent && event is! PointerUpEvent) return;
    _position = event.position;
    // 长按刚打开时不选中指腹下新出现的菜单项，必须有主动滑动。
    _armed |= (_position - _origin).distance > kTouchSlop;
    if (_armed) _update();
    // 滑入可滚动菜单时已放弃滑选，松手不执行也不关闭。
    if (!isTracking || event is! PointerUpEvent) return;
    final target = _target;
    final select = _armed;
    _completedPointer = event.pointer;
    _stop();
    if (!select) return;
    if (target != null && target.mounted) {
      target._activate();
    } else {
      chain.closeAll();
    }
  }

  void _update() {
    final hits = HitTestResult();
    GestureBinding.instance.hitTestInView(hits, _position, _viewId);
    _MenuItemHostState? hit;
    for (final entry in hits.path) {
      final render = entry.target;
      if (render is RenderMetaData && render.metaData is _MenuItemHostState) {
        final item = render.metaData as _MenuItemHostState;
        if (identical(item.widget.chain, chain)) {
          hit = item;
          break;
        }
      }
    }
    if (hit != null && hit._scrollableMenu) {
      _stop();
      return;
    }
    _highlight(hit?.widget.item.enabled == true ? hit : null);
  }

  void _highlight(_MenuItemHostState? next) {
    if (identical(next, _target)) return;
    _target?._setTouchHighlighted(false);
    _target?._handleExit();
    _target = next;
    if (next == null) return;
    next._setTouchHighlighted(true);
    next._handleEnter(requestFocus: false);
    _haptics.selection();
  }

  void _stop() {
    _pointer = null;
    _highlight(null);
  }

  void removeItem(_MenuItemHostState item) {
    if (identical(_target, item)) _highlight(null);
  }

  void closeFrom(int level) {
    if (level == 0) {
      _stop();
    } else if (_target != null && _target!.widget.level >= level) {
      _highlight(null);
    }
  }
}
