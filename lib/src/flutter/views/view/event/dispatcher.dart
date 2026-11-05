import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../utils/internal/benchmark_probe.dart';
import 'event.dart';
import 'press.dart';

/// 为任意 Render 接入 ElEvent，复用独立识别器处理反馈、回调和拖拽代理。
///
/// 宿主转接命中、指针、MouseTracker 与 attach/dispose；普通几何无需额外配置。
class EventDispatcher {
  /// 注册宿主与事件声明；保存实例后由宿主调用 [attach]，构造期间不触发业务回调。
  EventDispatcher(this._render, {bool register = true}) : _registered = register {
    assert(!register || _registry[_render] == null || _registry[_render]!._disposing, '同一 Render 只能持有一个活动分发器');
    assert(() {
      BenchmarkProbe.eventDispatcherInstantiateCount++;
      return true;
    }());
    if (register) _registry[_render] = this;
    _hosts[_team] = this;
    _team.onPointerEvent = _handlePointer;
    _team.onPointerRemoved = (event) => onRoutedPointerRemoved?.call(event);
    _configureRecognizers();
  }

  final RenderBox _render;
  final bool _registered;
  static final _registry = Expando<EventDispatcher>('ElEvent dispatcher');
  static final _callbacks = Expando<ElEventDetails>('ElEvent callback');
  static final _hosts = Expando<EventDispatcher>('ElEvent host');
  final _releaseLocalPositions = Expando<Offset>('ElEvent release geometry');
  final _moveCallbacks = Expando<ElEventDetails>('ElEvent target move');
  final _team = GestureTeam()
    ..matchParentGestures = true
    ..transformOnDemand = true
    ..deferPointerMoves = true
    ..deferPointerReleases = true;
  late final _press = PressRecognizer(debugOwner: this)..team = _team;
  Set<PhysicalKeyboardKey>? _keyboardTapKeys;
  bool _reportedTapPressed = false;
  // 只在声明拖拽、缩放或作为后代变换链的祖先时创建，点击类节点不分配。
  TransformRecognizer? _transform;
  final _hoverDevices = <int>{};
  ElEvent? _event;
  bool _disposed = false;
  bool _disposing = false;
  int _configurationRevision = 0;
  Offset _lastPointerPosition = Offset.zero;
  Offset? _lastTrustedLocalPosition;
  Offset? _lastFocusLocalPosition;
  ElEventDetails? _activeCallback;

  bool get _isDispatchingPressRelease => switch (_activeCallback?.phase) {
    ElEventPhase.tapUp ||
    ElEventPhase.secondaryTapUp ||
    ElEventPhase.tertiaryTapUp ||
    ElEventPhase.forwardTapUp ||
    ElEventPhase.backTapUp => true,
    _ => false,
  };

  /// 启用没有业务回调的长按状态观察。
  bool enableLongPressedState = false;

  /// 启用没有业务回调的拖拽状态观察。
  bool enableDraggedState = false;

  /// 设备直接移除后的消费组件清理通知。
  void Function(PointerRemovedEvent event)? onRoutedPointerRemoved;

  /// 原生宿主补充的拖拽设备过滤。
  Set<PointerDeviceKind>? dragDevices;

  /// 滚动行为提供的多指位移合成策略。
  MultitouchDragStrategy multitouchDragStrategy = MultitouchDragStrategy.latestPointer;

  /// 由宿主提供速度估计器，不在事件适配层拟合速度。
  GestureVelocityTrackerBuilder velocityTrackerBuilder = (event) => VelocityTracker.withKind(event.kind);

  /// 查找该 Render 持有的分发器，不要求宿主继承特定组件。
  static EventDispatcher? of(RenderObject render) => _registry[render];

  /// 同步结清子树事件，强制模式用于禁用和关闭弹层。
  static void terminateActivePointerSequencesIn(RenderObject root, {bool force = false}) {
    void visit(RenderObject node) {
      node.visitChildren(visit);
      final member = _registry[node];
      if (member == null) return;
      member._team.terminateOwnedInputs(
        survives: (team) {
          final candidate = team == null ? null : _hosts[team];
          if (force || candidate == null || candidate._disposed || !candidate._render.attached) return false;
          for (RenderObject? current = candidate._render; current != null; current = current.parent) {
            if (identical(current, root)) return false;
          }
          return true;
        },
      );
      if (force) member.cancelAllPendingAtLastPosition();
    }

    visit(root);
  }

  /// 清理通用识别器的活动输入，供测试隔离。
  static void debugResetEagerGestureOwners() => GestureTeam.debugReset();

  /// 活动普通指针数量的测试入口。
  int get debugRoutedPointerCount => _team.pointerCount;

  /// 当前显示刷新率的测试入口。
  double? debugDisplayRefreshRateForTest() => _displayRefreshRate();

  double? _displayRefreshRate() {
    final root = _render.owner?.rootNode;
    if (root is RenderView) return root.flutterView.display.refreshRate;
    final views = ui.PlatformDispatcher.instance.views;
    return views.isEmpty ? null : views.first.display.refreshRate;
  }

  /// 指针与键盘共用的按压反馈变化通知；未设置时仍维护 [isTapPressed]。
  ValueChanged<bool>? onTapChanged;

  /// 真实鼠标悬停变化通知；禁用时保留位置事实，由使用方遮蔽反馈。
  ValueChanged<bool>? onHoverChanged;

  /// 覆盖全局到局部坐标的转换，仅特殊绘制坐标系需要设置。
  Offset Function(RenderBox target, Offset position, ElEventDetails? callback)? localPositionResolver;

  /// 覆盖全局坐标范围判断，仅非矩形或带自身绘制变换的宿主需要设置。
  bool Function(Offset position)? hitBoundsContainsGlobal;

  DeviceGestureSettings? _gestureSettings;

  /// 官方设备手势容差；更新环境不需要替换事件声明。
  DeviceGestureSettings? get gestureSettings => _gestureSettings;
  set gestureSettings(DeviceGestureSettings? value) {
    if (_disposed || _disposing || _gestureSettings == value) return;
    _gestureSettings = value;
    _press.gestureSettings = value;
    _transform?.gestureSettings = value;
  }

  /// 当前元素的局部配置声明。
  ElEventConfig get config => _event?.config ?? const ElEventConfig();

  /// 当前是否禁用。
  bool get disabled => _event?.disabled ?? false;

  /// 当前是否显示按压反馈。
  bool get isTapPressed => _press.isFeedbackActive || (_keyboardTapKeys?.isNotEmpty ?? false);

  void _notifyTapChanged() {
    final pressed = isTapPressed;
    if (_reportedTapPressed == pressed) return;
    _reportedTapPressed = pressed;
    onTapChanged?.call(pressed);
  }

  void _cancelKeyboardTap() {
    final keys = _keyboardTapKeys;
    if (keys == null || keys.isEmpty) return;
    keys.clear();
    _notifyTapChanged();
  }

  /// 是否仍有鼠标位于宿主内，禁用不会清除真实悬停位置。
  bool get isHovered => _hoverDevices.isNotEmpty;

  /// 直接读取识别器的拖拽状态。
  bool get isDragged => _transform?.isDragging ?? false;

  /// 当前仍接收原始输入的指针数。
  int get activePointerCount => _team.ordinaryPointerCount;

  /// 当前是否仍有真实识别会话，取消后立即归零。
  bool get hasActivePointerSequence => _team.hasActiveInput || _team.pointerCount > _team.ordinaryPointerCount;

  /// 当前元素是否已销毁。
  bool get isDisposed => _disposed;

  /// 更新事件声明，识别器负责旧订阅的取消和回调失效。
  ElEvent? get event => _event;

  set event(ElEvent? value) {
    if (_disposed || _disposing || identical(_event, value)) return;
    final revision = ++_configurationRevision;
    final old = _event;
    if (old?.disabled != true && value?.disabled == true) {
      terminateActivePointerSequencesIn(_render, force: true);
      if (_disposed || revision != _configurationRevision) return;
    }
    final mouseChanged =
        old?.cursor != value?.cursor ||
        old?.disabled != value?.disabled ||
        old?.behavior != value?.behavior ||
        (old?.onPointerEnter == null) != (value?.onPointerEnter == null) ||
        (old?.onPointerExit == null) != (value?.onPointerExit == null);
    final sameGestureShape = old != null && value != null && old.hasSameGestureShape(value);
    if (sameGestureShape && old.disabled == value.disabled) {
      _event = value;
      _configureRecognizers();
      if (mouseChanged) _refreshMouseTracker();
      return;
    }
    final terminal = _team.isDispatchingTerminal || _isDispatchingPressRelease;
    final input = _team.currentPointerDetails?.originalEvent;
    final changedDuringRaw = _team.isDispatching && old != null && value != null && !sameGestureShape;
    if (old != null) {
      _press.cancelSideButtons();
      if (_disposed || revision != _configurationRevision) return;
      if (value == null || value.disabled || terminal) {
        _press.cancelMember();
      } else if (!old.hasSameNonDragShape(value)) {
        _press.invalidateDiscretePending();
      }
      if (_disposed || revision != _configurationRevision) return;
      final ending = value == null || value.disabled || terminal;
      final cancelDrag = ending || !_declaresDrag(value) || isDragged && !_canPreserveActiveDrag(old, value);
      final cancelScale = ending || _declaresScale(old) && !old.hasSameScaleShape(value);
      if (cancelDrag || cancelScale) {
        _transform?.cancelMember(null, cancelDrag: cancelDrag, cancelScale: cancelScale);
      }
      if (_disposed || revision != _configurationRevision) return;
      if (_declaresPanZoom(old) && !_declaresPanZoom(value)) {
        _team.cancel(where: (down) => revision == _configurationRevision && down is PointerPanZoomStartEvent);
        if (_disposed || revision != _configurationRevision) return;
      }
    }
    if (value == null || value.disabled) {
      _cancelDescendantEvents();
      if (_disposed || revision != _configurationRevision) return;
      cancelAllPendingAtLastPosition();
    }
    if (_disposed || revision != _configurationRevision) return;
    _event = value;
    _configureRecognizers(deferStartFor: changedDuringRaw && input is PointerMoveEvent ? input : null);
    if (mouseChanged) _refreshMouseTracker();
  }

  EventDispatcher? _parent;

  /// 宿主挂载或在已挂载的宿主上新增分发器后调用，重挂保留在途手势。
  void attach() {
    if (_disposed || _disposing) return;
    if (_registered) _registry[_render] = this;
    _syncParent();
    if (disabled) _cancelDescendantEvents();
    _refreshMouseTracker();
  }

  void _refreshMouseTracker() {
    if (!_disposed && _render.attached) {
      RendererBinding.instance.ensureVisualUpdate();
    }
  }

  // 注册表只关联宿主；当前输入的路线和所有权仍由识别器保存。
  void _syncParent() {
    if (_disposed || _disposing) return;
    var member = this;
    for (var node = _render.parent; node != null; node = node.parent) {
      final candidate = _registry[node];
      if (candidate == null || candidate._disposed || candidate._disposing) {
        continue;
      }
      member._connectParent(candidate);
      member = candidate;
    }
    member._connectParent(null);
  }

  void _connectParent(EventDispatcher? parent) {
    _parent = parent;
    _press.parent = _parent?._press;
    _transform?.parent = _parent?._ensureTransform();
    _team.parent = _parent?._team;
  }

  void _cancelDescendantEvents() {
    final revision = _configurationRevision;
    void cancel(RenderObject node) {
      if (_disposed || revision != _configurationRevision) return;
      node.visitChildren(cancel);
      if (_disposed || revision != _configurationRevision) return;
      _registry[node]?.cancelAllPendingAtLastPosition();
    }

    _render.visitChildren(cancel);
  }

  Offset _localPosition(Offset position, [ElEventDetails? callback]) {
    if (_render.attached) {
      try {
        final local = localPositionResolver?.call(_render, position, callback) ?? _render.globalToLocal(position);
        if (local.dx.isFinite && local.dy.isFinite) return _lastTrustedLocalPosition = local;
      } on FlutterError {
        if (_hasRenderRootPath) rethrow;
      }
    }
    // detach 先断开父链、后更新 attached，终态仍须使用最后可信的局部坐标。
    return _lastTrustedLocalPosition ?? position;
  }

  bool get _hasRenderRootPath {
    final root = _render.owner?.rootNode;
    for (RenderObject? node = _render; node != null; node = node.parent) {
      if (identical(node, root)) return true;
    }
    return false;
  }

  bool _contains(Offset position) {
    if (!_render.attached) return true;
    try {
      if (hitBoundsContainsGlobal case final contains?) return contains(position);
      final inverse = Matrix4.tryInvert(_render.getTransformTo(null));
      if (inverse == null) return false;
      return _render.hasSize && _render.size.contains(MatrixUtils.transformPoint(inverse, position));
    } on FlutterError {
      if (_hasRenderRootPath) rethrow;
      return true;
    }
  }

  Iterable<EventDispatcher> get _ancestors sync* {
    var node = _parent;
    while (node != null) {
      if (!node._disposed) yield node;
      node = node._parent;
    }
  }

  Offset? _ancestorOrigin() {
    if (!_render.attached) return null;
    try {
      final transform = _render.parent?.getTransformTo(null);
      if (transform == null) return Offset.zero;
      return transform.determinant() == 0 ? null : MatrixUtils.transformPoint(transform, Offset.zero);
    } on FlutterError {
      if (_hasRenderRootPath) rethrow;
      return null;
    }
  }

  /// 接收保留命中路径变换的原始输入，后续手势输入由官方指针路由投递。
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (_disposed || _disposing) return;
    if (event is! PointerPanZoomEndEvent) {
      _lastPointerPosition = event is PointerPanZoomUpdateEvent ? event.position + event.pan : event.position;
    }
    if (event is PointerHoverEvent || event is PointerSignalEvent) {
      if (!disabled && _event != null) _team.observePointer(event);
      return;
    }
    final before = _event;
    final start = event is PointerDownEvent || event is PointerPanZoomStartEvent;
    if (start && disabled) return;
    if (start) {
      _syncParent();
      _configureRecognizers();
    }
    if (!_team.observePointer(event) || disabled) return;
    if (event is PointerDownEvent) {
      if (_sameTransformShape(before, _event) && (_hasDrag || _hasScale)) {
        _ensureTransform().addPointer(event);
      }
      if (before == null && _event == null || before != null && _event != null && before.hasSameNonDragShape(_event!)) {
        _press.addPointer(event);
      }
    }
  }

  bool _handlePointer(PointerEvent input, PressCancelReason? reason) {
    if (input is PointerPanZoomEndEvent && GestureTeam.isDeviceRemoval(input)) return true;
    final phase = switch (input) {
      PointerDownEvent() => ElEventPhase.pointerDown,
      PointerMoveEvent() => ElEventPhase.pointerMove,
      PointerUpEvent() => ElEventPhase.pointerUp,
      PointerCancelEvent() => ElEventPhase.pointerCancel,
      PointerHoverEvent() => ElEventPhase.pointerHover,
      PointerSignalEvent() => ElEventPhase.pointerSignal,
      PointerPanZoomStartEvent() => ElEventPhase.pointerPanZoomStart,
      PointerPanZoomUpdateEvent() => ElEventPhase.pointerPanZoomUpdate,
      PointerPanZoomEndEvent() => ElEventPhase.pointerPanZoomEnd,
      _ => null,
    };
    if (phase == null) return true;
    final handler = _handlerFor(phase);
    final callback = _rawCallback(
      phase,
      input,
      reason: phase != ElEventPhase.pointerCancel || reason == null ? null : _cancelReason(reason),
    )..pointerCount = activePointerCount;
    if (input is PointerPanZoomEndEvent && reason != null) callback.preventDefault();
    _invoke(handler, callback);
    if (input is PointerSignalEvent &&
        (callback.defaultPrevented || callback.remainingDelta == Offset.zero && callback.delta != Offset.zero)) {
      GestureBinding.instance.pointerSignalResolver.register(
        input,
        (event) => event.respond(allowPlatformDefault: false),
      );
    }
    return !callback.propagationStopped;
  }

  static ElEventCancelReason _cancelReason(PressCancelReason? reason) => switch (reason) {
    PressCancelReason.arenaRejected => ElEventCancelReason.otherGestureAccepted,
    PressCancelReason.pointerCanceled => ElEventCancelReason.pointerCanceled,
    PressCancelReason.longPressAccepted => ElEventCancelReason.selfGestureAccepted,
    PressCancelReason.rejected || PressCancelReason.ineligible => ElEventCancelReason.tapRejected,
    _ => ElEventCancelReason.external,
  };

  void _handlePress(PressGestureDetails details) {
    final phase = details.phase;
    if (_disposed) return;
    if (!details.isActive) return;
    if (phase == ElEventPhase.tapCancel && details.downEvent.buttons != kPrimaryButton) return;
    if (phase == ElEventPhase.tapCancel &&
        (_team.isDispatchingTerminal && _team.currentPointerDetails?.originalEvent.pointer == details.pointer ||
            _isDispatchingPressRelease && _activeCallback?.pointer == details.pointer)) {
      return;
    }
    final up = details.originalEvent;
    if (phase == ElEventPhase.tapUp && up is PointerUpEvent) {
      // 延迟点击沿用释放时的几何，不能在计时器触发后重新读取位置或业务回调元数据。
      _releaseLocalPositions[up.original ?? up] = _localPosition(details.globalPosition);
    }
    final callback = _gestureCallback(details);
    _invoke(_handlerFor(phase), callback);
    // 长按默认独占必须在整条回调链完成后由通用识别器触发，不能逐宿主抢跑。
  }

  void _handleTransform(TransformGestureDetails details) {
    final phase = details.phase;
    if (_disposed) return;
    if (phase == ElEventPhase.scaleCancel && GestureTeam.isDeviceRemoval(details.originalEvent)) return;
    if (phase == ElEventPhase.dragCancel && !details.started && _event?.onDragDown == null) {
      return;
    }
    if (phase == ElEventPhase.dragUpdate) {
      _dispatchDragUpdate(details);
      return;
    }
    if (phase == ElEventPhase.dragEnd || phase == ElEventPhase.dragCancel) {
      DragPointerLock.release(_render);
    }
    final callback = _gestureCallback(details);
    callback.hasAncestorDragConsumer = _hasAncestorDragConsumer(details.pointer, details.dragAxis);
    callback.dragPipelineActive = _proxyMembers(details.pointer).isNotEmpty;

    _invoke(_handlerFor(callback.phase, axis: _dragCallbackAxis(details)), callback);
    if (phase == ElEventPhase.dragStart &&
        details.isPrimaryTarget &&
        details.isActive &&
        !callback.propagationStopped &&
        callback.dragPipelineActive) {
      _press.rejectTap(details.pointer, reason: PressCancelReason.longPressAccepted);
      _team.rejectDescendantPress(details.pointer);
      for (final proxy in _proxyMembers(details.pointer)) {
        proxy._team.cancelPress(details.pointer, reason: PressCancelReason.arenaRejected);
      }
      if (details.originalEvent.kind == PointerDeviceKind.mouse) DragPointerLock.claim(_render);
    }
  }

  Offset _localDelta(Offset position, Offset delta) {
    final previous = _localPosition(position - delta);
    return _localPosition(position) - previous;
  }

  /// 当前光标；禁用时显示禁止操作。
  MouseCursor get cursor => disabled ? SystemMouseCursors.forbidden : _event?.cursor ?? MouseCursor.defer;

  /// 接收官方鼠标进入通知。
  void handlePointerEnter(PointerEnterEvent event) => _handleHover(event, true);

  /// 接收官方鼠标离开通知。
  void handlePointerExit(PointerExitEvent event) => _handleHover(event, false);

  void _handleHover(PointerEvent event, bool entered) {
    if (_disposed || _disposing) return;
    final wasHovered = isHovered;
    entered ? _hoverDevices.add(event.device) : _hoverDevices.remove(event.device);
    if (wasHovered != isHovered) onHoverChanged?.call(isHovered);
    if (!disabled && !_disposed) {
      final phase = entered ? ElEventPhase.pointerEnter : ElEventPhase.pointerExit;
      _invoke(_handlerFor(phase), _rawCallback(phase, event));
    }
  }

  /// 结清当前元素，原始输入和手势终态由团队与识别器负责。
  void cancelAllPending(PointerEvent event) {
    if (_disposed) return;
    _lastPointerPosition = event.position;
    final revision = _configurationRevision;
    try {
      _cancelKeyboardTap();
      if (_disposed || revision != _configurationRevision) return;
      _press.cancelMember();
      if (_disposed || revision != _configurationRevision) return;
      _transform?.cancelMember(null, event: event);
      if (_disposed || revision != _configurationRevision) return;
      _team.cancel();
    } finally {
      DragPointerLock.release(_render);
    }
  }

  /// 使用最后可信位置结清当前输入。
  void cancelAllPendingAtLastPosition() => cancelAllPending(PointerCancelEvent(position: _lastPointerPosition));

  /// 当前声明是否提供自身命中入口。
  bool hitTestSelf(Offset position) => _event?.hasAnyCallback ?? false;

  /// 样式状态订阅改变后刷新通用识别器的观察配置。
  void syncRecognizersForStateVariants() => _configureRecognizers();

  /// 临时离树保留会话，最终离树则释放声明和注册。
  void detach({bool preserveEvent = false}) {
    if (_disposed || preserveEvent) return;
    cancelAllPendingAtLastPosition();
    _event = null;
    onRoutedPointerRemoved = null;
    if (_registered && identical(_registry[_render], this)) _registry[_render] = null;
    _configureRecognizers();
  }

  /// 在指针焦点请求前保留本次物理落点。
  void rememberPointerPosition(PointerEvent event, BoxHitTestEntry entry) => _lastPointerPosition = event.position;

  /// 更新没有命中条目的全局落点。
  void rememberGlobalPosition(Offset position) => _lastPointerPosition = position;

  /// 保留焦点通知使用的全局和内容坐标。
  void rememberFocusPosition(Offset globalPosition, Offset localPosition) {
    _lastPointerPosition = globalPosition;
    _lastFocusLocalPosition = localPosition;
  }

  /// 将现有焦点系统的状态变化沿当前逻辑父链派发。
  void notifyFocusChanged(
    bool focused, {
    ElFocusReason reason = ElFocusReason.programmatic,
    Offset? globalPosition,
    Offset? localPosition,
  }) {
    if (!_render.attached || _disposed) return;
    if (!focused) _cancelKeyboardTap();
    if (globalPosition != null) _lastPointerPosition = globalPosition;
    final position = localPosition ?? _lastFocusLocalPosition;
    if (focused) _lastFocusLocalPosition = null;
    final callback = ElEventDetails(
      phase: focused ? .focus : .blur,
      globalPosition: _lastPointerPosition,
      localPosition: position ?? _localPosition(_lastPointerPosition),
      focusReason: reason,
    );
    _deliverLive(callback);
  }

  /// 将主焦点节点收到的按键沿父链派发，激活键同时驱动自身按压样式。
  ElEventDetails? notifyKeyEvent(KeyEvent event) {
    if (!_render.attached || disabled || _disposed) return null;
    final phase = switch (event) {
      KeyDownEvent() => ElEventPhase.keyDown,
      KeyRepeatEvent() => ElEventPhase.keyRepeat,
      KeyUpEvent() => ElEventPhase.keyUp,
      _ => null,
    };
    if (phase == null) return null;
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.space) {
        (_keyboardTapKeys ??= {}).add(event.physicalKey);
        _notifyTapChanged();
      } else if (key == LogicalKeyboardKey.escape) {
        _cancelKeyboardTap();
      }
      if (_disposed || disabled || !_render.attached) return null;
    }
    final callback = ElEventDetails(
      phase: phase,
      globalPosition: _lastPointerPosition,
      localPosition: _localPosition(_lastPointerPosition),
      logicalKey: event.logicalKey,
      physicalKey: event.physicalKey,
      character: event.character,
      originalEvent: event,
    );
    try {
      _deliverLive(callback);
    } finally {
      // 按物理键结清，焦点迁移后的孤立 keyup 和取消后的 repeat 都不会重启反馈。
      if (event is KeyUpEvent && (_keyboardTapKeys?.remove(event.physicalKey) ?? false)) _notifyTapChanged();
    }
    return callback;
  }

  void _deliverLive(ElEventDetails callback) {
    _invoke(_handlerFor(callback.phase), callback);
    if (callback.propagationStopped) return;
    for (var render = _render.parent; render != null; render = render.parent) {
      final member = _registry[render];
      if (member == null || member._disposed || member.disabled || !render.attached) continue;
      callback.localPosition = member._localPosition(callback.globalPosition, callback);
      member._invoke(member._handlerFor(callback.phase), callback);
      if (callback.propagationStopped) return;
    }
  }

  /// 结清当前输入并释放识别器；宿主的 detach 不应调用此方法。
  void dispose() {
    if (_disposed || _disposing) return;
    _disposing = true;
    cancelAllPendingAtLastPosition();
    _disposed = true;
    _team.dispose();
    _press.dispose();
    _transform?.dispose();
    _hoverDevices.clear();
    onTapChanged = null;
    onHoverChanged = null;
    onRoutedPointerRemoved = null;
    _event = null;
    if (identical(_registry[_render], this)) _registry[_render] = null;
  }
}

/// 将声明映射到原生识别器及业务回调，不维护另一套手势路线。
extension _EventBinding on EventDispatcher {
  static const _dragPhases = ElEventPhase.dragPhases;
  static const _scalePhases = ElEventPhase.scalePhases;

  bool get _hasPrimaryTap =>
      _event?.onTap != null ||
      _event?.onDoubleTap != null ||
      _event?.onDoubleTapDown != null ||
      _event?.onTripleTap != null ||
      _event?.onTripleTapDown != null;

  bool get _hasFreeDrag => _hasDragHandlers(_event, null, fallback: false);

  bool get _hasVertical => _hasDragHandlers(_event, Axis.vertical, fallback: false);

  bool get _hasHorizontal => _hasDragHandlers(_event, Axis.horizontal, fallback: false);

  bool get _hasDrag =>
      enableDraggedState || _hasFreeDrag || _hasVertical || _hasHorizontal || _event?.onDragDown != null;

  bool get _hasScale => _declaresScale(_event);

  Axis? get _axis => _hasFreeDrag || _hasHorizontal && _hasVertical
      ? null
      : _hasVertical
      ? Axis.vertical
      : _hasHorizontal
      ? Axis.horizontal
      : null;

  void _configureRecognizers({PointerEvent? deferStartFor}) {
    final proxyOnly =
        _event?.dragProxy?.hasAnyHandler == true &&
        _event?.hasAnyCallback == false &&
        onTapChanged == null &&
        !enableLongPressedState &&
        !enableDraggedState;
    _team.onPointerEvent = proxyOnly ? null : _handlePointer;
    final press = _press;
    final observePress =
        onTapChanged != null ||
        enableLongPressedState ||
        _event?.hasTapLikeCallback == true ||
        _event?.onTapCancel != null;
    press
      ..onFeedbackChanged = onTapChanged == null && !(_event?.hasTapLikeCallback ?? false)
          ? null
          : ((_) => _notifyTapChanged())
      ..feedbackDelay = config.delayTouchDown
      ..minimumFeedbackDuration = config.delayTouchUp
      ..ancestorOriginResolver = _ancestorOrigin
      ..bubbleSideButtons = false
      ..bubbleReleaseAfterStop = false
      ..allowMultiplePointers = _hasScale
      // 动态启用 Drag 时可能仍在等待归属，接受后再补接同一指针。
      ..onAccepted = (_) {
        if (_hasDrag || _hasScale) _ensureTransform().resumeFromTeam();
      }
      ..gestureSettings = gestureSettings
      ..doubleTapInterval = config.doubleTapInterval
      ..tripleTapInterval = config.tripleTapInterval
      ..longPressDelay = config.longPressDelay
      ..tapSlopTolerance = config.tapCancelByDistance == true ? config.tapCancelDistance : double.infinity
      ..secondaryTapSlopTolerance = config.tapCancelDistance
      ..longPressSlopTolerance = config.longPressCancelDistance
      ..consecutiveTapDistance = config.tapCancelDistance
      ..deferTap = config.deferTap
      ..cancelTapOnLongPress = false
      ..onLongPressDefault = _event?.onLongPress == null && !enableLongPressedState
          ? null
          : (details) {
              if (!details.isActive) return;

              _team.claimPointer(details.pointer, cancelTap: true);
            }
      ..isEligible = (phase, event) {
        return config.tapCancelByDistance == true || _contains(event.position);
      }
      ..competeForTap = _hasPrimaryTap
      // 反馈通知可能同步替换声明，派发时再读取当前业务闭包。
      ..callbacks = {
        for (final phase in PressRecognizer.callbackPhases)
          if (_handlerFor(phase) != null ||
              observePress && const <ElEventPhase>[.tapDown, .tapUp, .tapCancel].contains(phase) ||
              enableLongPressedState && phase == .longPress)
            phase: _handlePress,
      };
    press.refreshActiveSubscription();

    final needsTransform = _hasDrag || _hasScale;
    if (_transform case final transform?) {
      _configureTransform(transform);
    } else if (needsTransform) {
      _ensureTransform();
    }
    _team.acceptsPanZoom = _event?.onPointerPanZoomUpdate != null;
    if (needsTransform) {
      final transform = _transform!;
      transform.resumeFromTeam();
      transform.refreshPendingConfiguration(deferStartFor: deferStartFor);
    }
  }

  /// 变换链须连续：竞技场分组和拖拽合作都沿祖先识别器判断，后代创建时祖先一并补齐。
  TransformRecognizer _ensureTransform() {
    final existing = _transform;
    if (existing != null) return existing;
    assert(() {
      BenchmarkProbe.transformRecognizerInstantiateCount++;
      return true;
    }());
    final transform = _transform = TransformRecognizer(debugOwner: this)..team = _team;
    _configureTransform(transform);
    final parent = _parent;
    if (parent != null && !parent._disposed && !parent._disposing) transform.parent = parent._ensureTransform();
    return transform;
  }

  void _configureTransform(TransformRecognizer transform) {
    transform
      ..gestureSettings = gestureSettings
      ..supportedDevices = config.dragDevices ?? dragDevices
      ..multitouchDragStrategy = multitouchDragStrategy
      ..velocityTrackerBuilder = velocityTrackerBuilder
      ..displayRefreshRate = _displayRefreshRate
      ..rotationStartEnabled = _event?.rotationStartEnabled ?? false
      ..startDistance = config.dragStartDistance
      ..horizontalAngle = config.dragHorizontalAngle
      ..minFlingDistance = config.dragMinFlingDistance
      ..preAcceptFlingDistance = config.tapCancelDistance / 2
      ..minFlingVelocity = config.dragMinFlingVelocity
      ..maxFlingVelocity = config.dragMaxFlingVelocity
      ..axis = _axis
      ..lockAxis = _hasHorizontal && _hasVertical
      ..dragCooperation = _collectDragProxies
      ..cancelDragOnScale = true
      ..startScaleOnPointerDown = false
      ..canStartScale = _team.canClaimPointers
      ..onDeferredDragAccepted = (event) {
        _press.rejectTap(event.pointer, notify: false);
      }
      ..beforeScaleStart = (pointers) {
        final revision = _configurationRevision;
        for (final pointer in pointers) {
          _press.rejectTap(pointer, reason: PressCancelReason.longPressAccepted);
          if (_disposed || revision != _configurationRevision) return;
        }
      }
      ..onScaleStartDefault = (details) {
        if (!details.isActive || details.pointerCount < 2) return;

        _team.claimPointers(details.pointerIds, cancelTap: true);
      }
      ..callbacks = {
        if (_hasDrag)
          for (final phase in TransformRecognizer.dragPhases) phase: _handleTransform,
        for (final phase in _scalePhases)
          if (phase == .rotationUpdate ? _event?.onRotationUpdate != null : _hasScale) phase: _handleTransform,
      };
  }

  ElEventDetails _gestureCallback(GestureDetails details) {
    final phase = details.phase;
    final transform = details is TransformGestureDetails ? details : null;
    final press = details is PressGestureDetails ? details : null;
    final up = details.originalEvent;
    final endCorrection = phase == ElEventPhase.dragEnd && up is PointerUpEvent
        ? up.position - details.globalPosition
        : Offset.zero;
    final position = details.globalPosition + endCorrection;
    final callback = EventDispatcher._callbacks[details.dispatchIdentity] ??= (ElEventDetails(
      phase: phase,
      globalPosition: position,
      localPosition: details.localPosition,
      delta: transform?.delta ?? Offset.zero,
      localDelta: transform?.localDelta ?? Offset.zero,
      dragOffset: (transform?.dragOffset ?? Offset.zero) + endCorrection,
      dragAxis: transform?.dragAxis,
      dragDirection: transform?.dragDirection,
      velocity: transform?.velocity ?? Velocity.zero,
      primaryVelocity: transform?.primaryVelocity,
      buttons: press != null && press.downEvent.buttons != kPrimaryButton && phase != ElEventPhase.tapCancel
          ? press.buttons
          : details.originalEvent.buttons,
      tapCount: _tapCountFor(phase),
      pointerCount: transform?.pointerCount ?? 0,
      scale: transform?.scale ?? 1,
      rotation: transform?.rotation ?? 0,
      logScaleVelocity: transform?.logScaleVelocity ?? 0,
      originalEvent: details.originalEvent,
      cancelReason: phase == ElEventPhase.tapCancel ? EventDispatcher._cancelReason(press?.cancelReason) : null,
    )..shareControl(details));
    final currentDown = press == null ? null : _team.downEventFor(press.pointer);
    final deferredRelease =
        phase == ElEventPhase.tap &&
            up is PointerUpEvent &&
            press != null &&
            !identical(currentDown?.original ?? currentDown, press.downEvent.original ?? press.downEvent)
        ? _releaseLocalPositions[up.original ?? up]
        : null;
    callback.localPosition =
        deferredRelease ??
        (localPositionResolver == null && endCorrection == Offset.zero
            ? details.localPosition
            : _localPosition(position, callback));
    callback.localDelta = localPositionResolver == null
        ? transform?.localDelta ?? Offset.zero
        : _localDelta(position, transform?.delta ?? Offset.zero);
    callback.pointerCount = _dragPhases.contains(phase) ? activePointerCount : transform?.pointerCount ?? 0;
    callback.updateLocalDeltaResolver((delta) => _localDelta(details.globalPosition, delta));
    _bindEagerGesture(callback, details.pointer, details);
    return callback;
  }

  ElEventDetails _rawCallback(ElEventPhase phase, PointerEvent event, {ElEventCancelReason? reason}) {
    final current = _team.currentPointerDetails;
    final data =
        current != null && identical(current.originalEvent.original ?? current.originalEvent, event.original ?? event)
        ? current
        : PointerGestureDetails(event);
    final position = event is PointerPanZoomEndEvent ? _lastPointerPosition : data.globalPosition;
    // Move 是各命中目标的独立位移，传播控制仍共用同一物理输入。
    final callbacks = phase == ElEventPhase.pointerMove ? _moveCallbacks : EventDispatcher._callbacks;
    final callback = callbacks[data] ??= (ElEventDetails(
      phase: phase,
      globalPosition: position,
      localPosition: _localPosition(position),
      delta: data.delta,
      localDelta: _localDelta(position, data.delta),
      buttons: event.buttons,
      originalEvent: event,
      cancelReason: reason,
      scale: event is PointerPanZoomUpdateEvent ? event.scale : 1,
      rotation: event is PointerPanZoomUpdateEvent ? event.rotation : 0,
    )..shareControl(data));
    callback.localPosition = localPositionResolver == null
        ? PointerEvent.transformPosition(event.transform, position)
        : _localPosition(position, callback);
    callback.localDelta = localPositionResolver == null
        ? transformGestureDelta(event.transform, position, data.delta)
        : _localDelta(position, data.delta);
    callback.updateLocalDeltaResolver((delta) => _localDelta(position, delta));

    _bindEagerGesture(callback, event.pointer);
    return callback;
  }

  void _bindEagerGesture(ElEventDetails callback, int pointer, [GestureDetails? details]) {
    final down = _team.downEventFor(pointer);
    callback.updateEagerGestureHandler((callback, cancelTap, allowScale) {
      if (details?.isActive == false) return;
      final transform = details is TransformGestureDetails ? details : null;
      if (transform != null &&
          transform.pointerIds.length >= 2 &&
          (callback.phase == ElEventPhase.scaleStart ||
              callback.phase == ElEventPhase.scaleUpdate ||
              callback.phase == ElEventPhase.rotationUpdate)) {
        _team.claimPointers(transform.pointerIds, cancelTap: cancelTap, allowScaleUpgrade: allowScale);
        return;
      }
      if (down == null) return;

      _team.claimPointer(pointer, downEvent: down, cancelTap: cancelTap, allowScaleUpgrade: allowScale);
    });
  }

  Iterable<EventDispatcher> _proxyMembers(int pointer) =>
      (_transform?.dragCooperationMembers(pointer) ?? const <TransformRecognizer>[])
          .map((member) => member.team == null ? null : EventDispatcher._hosts[member.team!])
          .whereType<EventDispatcher>();

  DragCooperation _collectDragProxies(int pointer, Axis? axis) {
    final proxies = <TransformRecognizer>[];
    GestureTeam? cutoff;
    for (final member in _ancestors) {
      if (member.disabled || member._disposed) continue;
      final registered = member._team.downEventFor(pointer) != null;
      final proxy = member.event?.dragProxy;
      if (proxy != null &&
          proxy.hasAnyHandler &&
          (proxy.axis == null || proxy.axis == axis) &&
          (registered || member._team.onPointerEvent == null)) {
        proxies.add(member._ensureTransform());
      } else if (registered &&
          (member._hasPrimaryTap ||
              member._hasDragForAxis(axis) && member._transform?.canReceiveDrag(pointer, axis) == true)) {
        cutoff = member._team;
        break;
      }
    }
    return DragCooperation(proxies, cutoff: cutoff);
  }

  void _dispatchDragUpdate(TransformGestureDetails details) {
    final pipeline = _proxyMembers(details.pointer).toList();
    bool isActive() => details.isActive;
    final callback = _gestureCallback(details)
      ..dragPipelineActive = pipeline.isNotEmpty
      ..hasAncestorDragConsumer = _hasAncestorDragConsumer(details.pointer, details.dragAxis);
    bool exhausted() => details.dragAxis == null
        ? callback.remainingDelta == Offset.zero
        : callback.remainingPrimaryDelta(details.dragAxis!) == 0;
    try {
      for (final member in pipeline.reversed) {
        if (!isActive()) return;
        if (exhausted()) break;
        _invokeDragProxy(member, member.event?.dragProxy?.onDragPreUpdate, callback, pre: true);
      }
      if (!isActive()) return;
      // 主段承担生命周期，即使预处理耗尽余量也必须投递。
      if (pipeline.isNotEmpty) _gestureCallback(details);
      _invoke(_handlerFor(callback.phase, axis: _dragCallbackAxis(details)), callback);
      for (final member in pipeline) {
        if (!isActive() || exhausted()) break;
        _invokeDragProxy(member, member.event?.dragProxy?.onDragOverflow, callback, pre: false);
      }
    } finally {
      callback.dragPipelineActive = false;
      callback.dragBoundaryHandoff = false;
    }
  }

  void _invokeDragProxy(EventDispatcher member, ElEventHandler? handler, ElEventDetails callback, {required bool pre}) {
    if (member._disposed || member.disabled) return;
    final proxy = member._event?.dragProxy;
    final axis = callback.dragAxis;
    if (pre && proxy?.onDragOverflow != null && proxy!.boundaryHandoff.isNotEmpty && axis != null) {
      final delta = callback.remainingPrimaryDelta(axis);
      final direction = axis == Axis.vertical
          ? delta > 0
                ? AxisDirection.down
                : AxisDirection.up
          : delta > 0
          ? AxisDirection.right
          : AxisDirection.left;
      if (delta != 0 && proxy.boundaryHandoff.contains(direction)) callback.dragBoundaryHandoff = true;
    }
    if (handler == null) return;
    callback.localPosition = member._localPosition(callback.globalPosition);
    callback.localDelta = member._localDelta(callback.globalPosition, callback.delta);
    callback.updateLocalDeltaResolver((delta) => member._localDelta(callback.globalPosition, delta));
    callback.updateEagerGestureHandler(null);
    member._invoke(handler, callback);
    callback.resetPropagation();
  }

  bool _hasAncestorDragConsumer(int pointer, Axis? axis) => _ancestors.any(
    (member) =>
        !member.disabled && member._transform?.canReceiveDrag(pointer, axis) == true && member._hasDragForAxis(axis),
  );

  bool _hasDragForAxis(Axis? axis) =>
      _hasFreeDrag ||
      switch (axis) {
        Axis.horizontal => _hasHorizontal,
        Axis.vertical => _hasVertical,
        null => _hasHorizontal || _hasVertical,
      };

  /// 自由拖拽的合作祖先按起手方向分派轴向回调，保留自由拖拽本身的二维语义。
  Axis? _dragCallbackAxis(TransformGestureDetails details) =>
      details.dragAxis ??
      (!_hasFreeDrag && details.dragDirection != null ? axisDirectionToAxis(details.dragDirection!) : null);

  ElEventHandler? _dragHandler(
    Axis? axis,
    ElEventHandler? free,
    ElEventHandler? horizontal,
    ElEventHandler? vertical,
  ) => switch (axis) {
    Axis.horizontal => horizontal ?? free,
    Axis.vertical => vertical ?? free,
    null => free,
  };

  ElEventHandler? _handlerFor(ElEventPhase phase, {ElEvent? configuration, Axis? axis, bool fallback = true}) {
    final value = configuration ?? _event;
    if (value == null) return null;
    final free = fallback || axis == null ? value : null;
    return switch (phase) {
      .pointerEnter => value.onPointerEnter,
      .pointerHover => value.onPointerHover,
      .pointerExit => value.onPointerExit,
      .pointerDown => value.onPointerDown,
      .pointerMove => value.onPointerMove,
      .pointerUp => value.onPointerUp,
      .pointerCancel => value.onPointerCancel,
      .pointerPanZoomStart => value.onPointerPanZoomStart,
      .pointerPanZoomUpdate => value.onPointerPanZoomUpdate,
      .pointerPanZoomEnd => value.onPointerPanZoomEnd,
      .pointerSignal => value.onPointerSignal,
      .tapDown => value.onTapDown,
      .tapUp => value.onTapUp,
      .tap => value.onTap,
      .doubleTap => value.onDoubleTap,
      .doubleTapDown => value.onDoubleTapDown,
      .tripleTap => value.onTripleTap,
      .tripleTapDown => value.onTripleTapDown,
      .secondaryTapDown => value.onSecondaryTapDown,
      .secondaryTapUp => value.onSecondaryTapUp,
      .secondaryTap => value.onSecondaryTap,
      .tertiaryTapDown => value.onTertiaryTapDown,
      .tertiaryTapUp => value.onTertiaryTapUp,
      .tertiaryTap => value.onTertiaryTap,
      .forwardTapDown => value.onForwardTapDown,
      .forwardTapUp => value.onForwardTapUp,
      .forwardTap => value.onForwardTap,
      .backTapDown => value.onBackTapDown,
      .backTapUp => value.onBackTapUp,
      .backTap => value.onBackTap,
      .longPress => value.onLongPress,
      .tapCancel => value.onTapCancel,
      .dragDown => value.onDragDown,
      .dragStart => _dragHandler(axis, free?.onDragStart, value.onHorizontalDragStart, value.onVerticalDragStart),
      .dragUpdate => _dragHandler(axis, free?.onDragUpdate, value.onHorizontalDragUpdate, value.onVerticalDragUpdate),
      .dragEnd => _dragHandler(axis, free?.onDragEnd, value.onHorizontalDragEnd, value.onVerticalDragEnd),
      .dragCancel => _dragHandler(axis, free?.onDragCancel, value.onHorizontalDragCancel, value.onVerticalDragCancel),
      .scaleStart => value.onScaleStart,
      .scaleUpdate => value.onScaleUpdate,
      .scaleEnd => value.onScaleEnd,
      .scaleCancel => value.onScaleCancel,
      .rotationUpdate => value.onRotationUpdate,
      .keyDown => value.onKeyDown,
      // keyRepeat 未声明时回退到 onKeyDown：按钮/链接/表格的「按住连续触发」
      // 只注入 onKeyDown，dispatcher 不补回退会让 repeat 静默丢失。
      .keyRepeat => value.onKeyRepeat ?? value.onKeyDown,
      .keyUp => value.onKeyUp,
      .focus => value.onFocus,
      .blur => value.onBlur,
    };
  }

  bool _hasDragHandlers(ElEvent? value, Axis? axis, {bool fallback = true}) =>
      value != null &&
      _dragPhases.any((phase) => _handlerFor(phase, configuration: value, axis: axis, fallback: fallback) != null);

  bool _declaresDrag(ElEvent? value) =>
      enableDraggedState ||
      value != null &&
          (value.onDragDown != null ||
              const <Axis?>[null, Axis.horizontal, Axis.vertical].any((axis) => _hasDragHandlers(value, axis)));

  bool _canPreserveActiveDrag(ElEvent a, ElEvent b) {
    if (a.disabled != b.disabled || a.dragProxy != b.dragProxy) return false;
    // 已公开 Start 的同轴路线冻结本轮参数，换处理器后仍须能结清两种终态。
    for (final axis in const <Axis?>[null, Axis.horizontal, Axis.vertical]) {
      final before = _hasDragHandlers(a, axis);
      if (before != _hasDragHandlers(b, axis) ||
          before &&
              (_handlerFor(.dragEnd, configuration: b, axis: axis) == null ||
                  _handlerFor(.dragCancel, configuration: b, axis: axis) == null)) {
        return false;
      }
    }
    return true;
  }

  bool _declaresScale(ElEvent? value) =>
      value != null && _scalePhases.any((phase) => _handlerFor(phase, configuration: value) != null);

  bool _declaresPanZoom(ElEvent? value) =>
      value?.onPointerPanZoomStart != null ||
      value?.onPointerPanZoomUpdate != null ||
      value?.onPointerPanZoomEnd != null;

  bool _sameTransformShape(ElEvent? a, ElEvent? b) {
    if (identical(a, b)) return true;
    if (a == null ||
        b == null ||
        a.disabled != b.disabled ||
        a.dragProxy != b.dragProxy ||
        a.rotationStartEnabled != b.rotationStartEnabled) {
      return false;
    }
    final left = a.config ?? const ElEventConfig();
    final right = b.config ?? const ElEventConfig();
    if (left.dragStartDistance != right.dragStartDistance ||
        !setEquals(left.dragDevices, right.dragDevices) ||
        left.dragHorizontalAngle != right.dragHorizontalAngle ||
        left.dragMinFlingDistance != right.dragMinFlingDistance ||
        left.dragMinFlingVelocity != right.dragMinFlingVelocity ||
        left.dragMaxFlingVelocity != right.dragMaxFlingVelocity) {
      return false;
    }
    return a.hasSameTransformCallbacks(b);
  }

  static int _tapCountFor(ElEventPhase phase) => switch (phase) {
    .tap || .secondaryTap || .tertiaryTap || .forwardTap || .backTap => 1,
    .doubleTap || .doubleTapDown => 2,
    .tripleTap || .tripleTapDown => 3,
    _ => 0,
  };

  void _invoke(ElEventHandler? handler, ElEventDetails callback) {
    if (handler == null) return;
    callback.markCallbackInvoked();
    final previous = _activeCallback;
    _activeCallback = callback;
    try {
      handler(callback);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'ElEvent',
          context: ErrorDescription('处理 ${callback.phase.name}'),
        ),
      );
    } finally {
      _activeCallback = previous;
    }
  }
}

/// 保留框架操作使用的全局输入锁，不参与普通手势识别。
@internal
final class DragPointerLock {
  DragPointerLock._();

  static RenderObject? _owner;
  static int _hitTestBarrierBypassDepth = 0;
  static bool _mouseTrackerRefreshScheduled = false;
  static int _mouseTrackerRefreshGeneration = 0;

  /// 当前是否处于拖拽指针锁定期。
  static bool get isActive => _owner?.attached ?? false;

  /// 当前真实命中是否应由全局锁屏障接管。
  ///
  /// 内部只读空间查询必须读取本值；[isActive] 始终只表达锁归属，不因临时查询
  /// 作用域而变化。
  static bool get blocksHitTesting => isActive && _hitTestBarrierBypassDepth == 0;

  /// 同步执行一次忽略锁屏障的内部只读命中查询。
  ///
  /// 作用域可嵌套且异常安全，只跳过 [DragPointerLock] 注入的命中屏障，不释放
  /// 锁、不改变 cursor，也不允许真实平台事件借此穿透；调用方必须在 [action]
  /// 返回前完成查询，不能把异步工作带出作用域。
  static T runWithHitTestBarrierBypassed<T>(T Function() action) {
    final previousDepth = _hitTestBarrierBypassDepth;
    _hitTestBarrierBypassDepth = previousDepth + 1;
    try {
      return action();
    } finally {
      _hitTestBarrierBypassDepth = previousDepth;
    }
  }

  /// [owner]（拖拽宿主 render）声明拖拽激活；后声明者接管且永不改变光标。
  static void claim(RenderObject owner) => _owner = owner;

  /// 拖拽结束/取消/宿主销毁时释放；仅当前 owner 的释放生效。
  static void release(RenderObject owner) {
    if (!identical(_owner, owner)) return;
    final wasAttached = owner.attached;
    _owner = null;
    if (wasAttached) _scheduleMouseTrackerRefresh();
  }

  /// 把解锁后的 hover 重算延至 render tree 完成本帧挂卸载之后。
  static void _scheduleMouseTrackerRefresh() {
    if (_mouseTrackerRefreshScheduled) return;
    _mouseTrackerRefreshScheduled = true;
    final generation = _mouseTrackerRefreshGeneration;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (generation != _mouseTrackerRefreshGeneration) return;
      _mouseTrackerRefreshScheduled = false;
      RendererBinding.instance.mouseTracker.updateAllDevices();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @visibleForTesting
  static void debugReset() {
    _owner = null;
    _hitTestBarrierBypassDepth = 0;
    _mouseTrackerRefreshScheduled = false;
    _mouseTrackerRefreshGeneration++;
  }
}

/// 锁激活期放在命中结果最前的屏障：吞事件但不下发任何光标换形命令。
final HitTestTarget dragPointerLockBarrier = const _DragPointerLockBarrier();

final class _DragPointerLockBarrier extends MouseTrackerAnnotation implements HitTestTarget {
  const _DragPointerLockBarrier();

  @override
  MouseCursor get cursor => MouseCursor.uncontrolled;

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {}
}
