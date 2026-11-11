part of 'dispatcher.dart';

// 识别器直接参加 Flutter 竞技场，适配层只补充 ElEvent 所需的数据和终态。
final class _NativeGestures {
  _NativeGestures(this.host);

  final EventDispatcher host;
  final _pointers = <int>{};
  final _drags = <_NativeDrag>[];
  ScaleGestureRecognizer? _scale;
  PointerEvent? _input;
  Offset? _focalPoint;
  double _scaleFactor = 1;
  double _rotation = 0;

  bool get _current => identical(host._gestures, this);
  bool get isDragging => _drags.any((drag) => drag.isDragging);
  bool get hasActiveInput => _pointers.isNotEmpty || isDragging || _focalPoint != null;

  bool observesPointer(int pointer) => _pointers.contains(pointer);

  void observe(PointerEvent event) {
    if (!_pointers.contains(event.pointer)) return;
    _input = event;
    if (event is PointerUpEvent || event is PointerCancelEvent || event is PointerPanZoomEndEvent) {
      _pointers.remove(event.pointer);
    }
  }

  void addPointer(PointerEvent event, {required bool drag, required bool scale}) {
    _input = event;
    _pointers.add(event.pointer);
    if (drag && _drags.isEmpty) {
      if (host._hasFreeDrag) _drags.add(_NativeDrag(this, PanGestureRecognizer(debugOwner: host)));
      if (host._hasHorizontal) {
        _drags.add(_NativeDrag(this, HorizontalDragGestureRecognizer(debugOwner: host), Axis.horizontal));
      }
      if (host._hasVertical) {
        _drags.add(_NativeDrag(this, VerticalDragGestureRecognizer(debugOwner: host), Axis.vertical));
      }
    }
    if (scale && _scale == null) {
      _scale = ScaleGestureRecognizer(debugOwner: host, dragStartBehavior: .start)
        ..onStart = _startScale
        ..onUpdate = _updateScale
        ..onEnd = _endScale;
      _countRecognizer();
    }
    configure();
    if (drag) {
      for (final binding in _drags) {
        if (!_current) return;
        _add(binding.recognizer, event);
      }
    }
    if (_current && scale) _add(_scale!, event);
  }

  void configure() {
    for (final drag in _drags) {
      drag.configure();
    }
    _scale?.gestureSettings = host.gestureSettings;
  }

  void _add(GestureRecognizer recognizer, PointerEvent event) {
    if (event is PointerDownEvent) recognizer.addPointer(event);
    if (event is PointerPanZoomStartEvent) recognizer.addPointerPanZoom(event);
  }

  void _countRecognizer() {
    assert(() {
      BenchmarkProbe.transformRecognizerInstantiateCount++;
      return true;
    }());
  }

  void _startScale(ScaleStartDetails details) {
    final input = _input;
    if (input == null || !_start(input)) return;
    _focalPoint = details.focalPoint;
    _scaleFactor = 1;
    _rotation = 0;
    _emitScale(.scaleStart, input, details.focalPoint, details.pointerCount);
  }

  void _updateScale(ScaleUpdateDetails details) {
    final input = _input;
    if (input == null || _focalPoint == null) return;
    final delta = details.focalPoint - _focalPoint!;
    final rotated = _rotation != details.rotation;
    _focalPoint = details.focalPoint;
    _scaleFactor = details.scale;
    _rotation = details.rotation;
    _emitScale(.scaleUpdate, input, details.focalPoint, details.pointerCount, delta: delta);
    if (rotated && _current && _focalPoint != null) {
      _emitScale(.rotationUpdate, input, details.focalPoint, details.pointerCount, delta: delta);
    }
  }

  void _endScale(ScaleEndDetails details) {
    final input = _input;
    final position = _focalPoint;
    if (input == null || position == null) return;
    _focalPoint = null;
    final canceled = input is PointerCancelEvent;
    _emitScale(
      canceled ? .scaleCancel : .scaleEnd,
      input,
      position,
      details.pointerCount,
      velocity: canceled ? Velocity.zero : details.velocity,
      logScaleVelocity: canceled || _scaleFactor <= 0 ? 0 : details.scaleVelocity / _scaleFactor,
      cancelReason: canceled ? .pointerCanceled : null,
    );
  }

  void _emitScale(
    ElEventPhase phase,
    PointerEvent input,
    Offset position,
    int count, {
    Offset delta = Offset.zero,
    Velocity velocity = Velocity.zero,
    double logScaleVelocity = 0,
    ElEventCancelReason? cancelReason,
    ElEvent? configuration,
  }) {
    final handler = host._handlerFor(phase, configuration: configuration);
    if (handler == null) return;
    final callback = ElEventDetails(
      phase: phase,
      globalPosition: position,
      localPosition: _localPosition(input, position),
      delta: delta,
      localDelta: _localDelta(input, position, delta),
      velocity: velocity,
      buttons: input.buttons,
      pointerCount: count,
      scale: _scaleFactor,
      rotation: _rotation,
      logScaleVelocity: logScaleVelocity,
      originalEvent: input,
      cancelReason: cancelReason,
    );
    _emit(handler, callback, input);
  }

  bool _start(PointerEvent input) {
    if (!_current) return false;
    // 仅订阅反馈的 Press 不参赛，Flutter 裁决后也要立即清理这类候选。
    host._press.rejectTap(input.pointer, reason: PressCancelReason.longPressAccepted);
    return _current;
  }

  Offset _localPosition(PointerEvent input, Offset position) => host.localPositionResolver == null
      ? PointerEvent.transformPosition(input.transform, position)
      : host._localPosition(position);

  Offset _localDelta(PointerEvent input, Offset position, Offset delta) => host.localPositionResolver == null
      ? transformGestureDelta(input.transform, position, delta)
      : host._localDelta(position, delta);

  void _emit(ElEventHandler handler, ElEventDetails callback, PointerEvent input) {
    callback.updateLocalDeltaResolver((delta) => _localDelta(input, callback.globalPosition, delta));
    if (_current && observesPointer(input.pointer)) host._bindEagerGesture(callback, input.pointer, accepted: true);
    host._invoke(handler, callback);
  }

  void cancel(ElEvent? configuration, {PointerEvent? input, required ElEventCancelReason reason}) {
    final lastInput = input ?? _input;
    for (final drag in _drags) {
      drag.dispose();
    }
    _scale
      ?..onStart = null
      ..onUpdate = null
      ..onEnd = null
      ..dispose();
    if (lastInput == null) return;
    for (final drag in _drags) {
      drag.cancel(configuration, lastInput, reason);
    }
    final position = _focalPoint;
    if (position != null) {
      _focalPoint = null;
      _emitScale(.scaleCancel, lastInput, position, 0, configuration: configuration, cancelReason: reason);
    }
  }
}

final class _NativeDrag {
  _NativeDrag(this._owner, this.recognizer, [this._axis]) {
    recognizer
      ..onlyAcceptDragOnThreshold = true
      ..onStart = _start
      ..onUpdate = _update
      ..onEnd = _end;
    _owner._countRecognizer();
  }

  final _NativeGestures _owner;
  final DragGestureRecognizer recognizer;
  final Axis? _axis;
  Offset? _position;
  Offset _offset = Offset.zero;
  AxisDirection? _direction;

  bool get isDragging => _position != null;

  void configure() {
    final host = _owner.host;
    final config = host.config;
    final distance = config.dragStartDistance;
    recognizer
      ..gestureSettings = distance == null
          ? host.gestureSettings
          : DeviceGestureSettings(touchSlop: _axis == null ? distance / 2 : distance)
      ..minFlingDistance = config.dragMinFlingDistance
      ..minFlingVelocity = config.dragMinFlingVelocity
      ..maxFlingVelocity = config.dragMaxFlingVelocity
      ..velocityTrackerBuilder = host.velocityTrackerBuilder
      ..multitouchDragStrategy = host.multitouchDragStrategy;
  }

  void _start(DragStartDetails details) {
    final input = _owner._input;
    if (input == null || !_owner._start(input)) return;
    _position = details.globalPosition;
    _offset = Offset.zero;
    final down = _owner.host._team.downEventFor(input.pointer);
    final global = down == null ? Offset.zero : details.globalPosition - down.position;
    final local = _owner._localDelta(input, details.globalPosition, global);
    final horizontal =
        _axis == Axis.horizontal ||
        _axis == null && local.dx.abs() * math.tan(_owner.host.config.dragHorizontalAngle) >= local.dy.abs();
    _direction = horizontal ? (local.dx < 0 ? .left : .right) : (local.dy < 0 ? .up : .down);
    _emit(.dragStart, input, details.globalPosition);
  }

  void _update(DragUpdateDetails details) {
    final input = _owner._input;
    if (input == null || !isDragging) return;
    final delta = _toGlobal(input, details.localPosition, details.delta);
    _offset += delta;
    _position = details.globalPosition;
    _emit(.dragUpdate, input, details.globalPosition, delta: delta);
  }

  void _end(DragEndDetails details) {
    final input = _owner._input;
    final position = _position;
    if (input == null || position == null) return;
    _position = null;
    if (input is PointerUpEvent || input is PointerPanZoomEndEvent) {
      final velocity = _toGlobal(input, recognizer.lastPosition.local, details.velocity.pixelsPerSecond);
      _emit(
        .dragEnd,
        input,
        input is PointerUpEvent ? input.position : position,
        velocity: Velocity(pixelsPerSecond: velocity),
        primaryVelocity: _axis == null ? null : details.primaryVelocity,
      );
    } else {
      // DragGestureRecognizer 也用 onEnd 通知已开始手势的 PointerCancel。
      _emit(.dragCancel, input, position, cancelReason: .pointerCanceled);
    }
  }

  void cancel(ElEvent? configuration, PointerEvent input, ElEventCancelReason reason) {
    final position = _position;
    if (position == null) return;
    _position = null;
    _emit(.dragCancel, input, position, configuration: configuration, cancelReason: reason);
  }

  void dispose() {
    recognizer
      ..onStart = null
      ..onUpdate = null
      ..onEnd = null
      ..dispose();
  }

  Offset _toGlobal(PointerEvent input, Offset localPosition, Offset delta) {
    final transform = input.transform;
    return transform == null ? delta : transformGestureDelta(Matrix4.tryInvert(transform), localPosition, delta);
  }

  void _emit(
    ElEventPhase phase,
    PointerEvent input,
    Offset position, {
    Offset delta = Offset.zero,
    Velocity velocity = Velocity.zero,
    double? primaryVelocity,
    ElEventCancelReason? cancelReason,
    ElEvent? configuration,
  }) {
    final host = _owner.host;
    final handler = host._handlerFor(phase, axis: _axis, configuration: configuration);
    if (handler == null) return;
    final callback = ElEventDetails(
      phase: phase,
      globalPosition: position,
      localPosition: _owner._localPosition(input, position),
      delta: delta,
      localDelta: _owner._localDelta(input, position, delta),
      dragOffset: _offset,
      dragAxis: _axis,
      dragDirection: _direction,
      velocity: velocity,
      primaryVelocity: primaryVelocity,
      buttons: input.buttons,
      pointerCount: host.activePointerCount,
      originalEvent: input,
      cancelReason: cancelReason,
    );
    _owner._emit(handler, callback, input);
  }
}
