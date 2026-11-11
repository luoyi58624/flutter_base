part of 'dispatcher.dart';

// 每个识别器只桥接 Flutter 回调。它的活动终态由宿主在卸载时结清。
final class _NativeGestures {
  _NativeGestures(this.host) {
    final event = host.event!;
    final serialTap =
        event.onDoubleTap != null ||
        event.onDoubleTapDown != null ||
        event.onTripleTap != null ||
        event.onTripleTapDown != null;
    if (serialTap) _recognizers.add(_makeSerialTap());
    if (event.onLongPress != null) _recognizers.add(_makeLongPress());
    final buttons = <int>[kPrimaryButton, kSecondaryButton, kTertiaryButton, kForwardMouseButton, kBackMouseButton]
        .where((button) {
          if (serialTap && button == kPrimaryButton) return false;
          final (down, up, tap) = _tapPhases(button)!;
          return event.handlerFor(down) != null ||
              event.handlerFor(up) != null ||
              event.handlerFor(tap) != null ||
              button == kPrimaryButton && event.onTapCancel != null;
        })
        .toSet();
    if (buttons.isNotEmpty) {
      final slop = host.config.tapCancelByDistance ? host.config.tapCancelDistance : null;
      _tap = slop == null ? _Tap(this) : _Tap(this, preAcceptSlopTolerance: slop, postAcceptSlopTolerance: slop);
      _tapButtons = buttons;
      _recognizers.add(_tap!);
    }
    for (final axis in <Axis?>[null, .horizontal, .vertical]) {
      if (ElEventPhase.dragPhases.any((phase) => event.handlerFor(phase, axis) != null)) {
        _recognizers.add(_makeDrag(axis));
      }
    }
    if (ElEventPhase.scalePhases.any((phase) => event.handlerFor(phase) != null)) {
      _recognizers.add(_makeScale());
    }
    assert(() {
      BenchmarkProbe.transformRecognizerInstantiateCount += _recognizers
          .where((r) => r is DragGestureRecognizer || r is ScaleGestureRecognizer)
          .length;
      return true;
    }());
  }

  final EventDispatcher host;
  final _recognizers = <GestureRecognizer>[];
  final _cancel = <GestureRecognizer, void Function(PointerEvent?, ElEventCancelReason)>{};
  final _tracking = <int>{};
  PointerEvent? _input;
  _Tap? _tap;
  Set<int> _tapButtons = const {};
  PointerDownEvent? _serialDown;

  bool get live => identical(host._gestures, this);
  bool tracks(int pointer) => _tracking.contains(pointer);

  void observe(PointerEvent input) {
    if (!tracks(input.pointer)) return;
    _input = input;
    if (input is PointerUpEvent || input is PointerCancelEvent || input is PointerPanZoomEndEvent) {
      _tracking.remove(input.pointer);
    }
  }

  void add(PointerEvent input, {required bool drag, required bool scale}) {
    for (final recognizer in _recognizers) {
      if (!live) break;
      switch (recognizer) {
        case DragGestureRecognizer() when !drag:
        case ScaleGestureRecognizer() when !scale:
        case _Tap() when !_tapButtons.contains(input.buttons):
        case SerialTapGestureRecognizer() || LongPressGestureRecognizer() when input.buttons != kPrimaryButton:
          continue;
      }
      final distance = host.config.dragStartDistance;
      recognizer.gestureSettings = distance != null && recognizer is DragGestureRecognizer
          ? DeviceGestureSettings(touchSlop: recognizer is PanGestureRecognizer ? distance / 2 : distance)
          : host.gestureSettings;
      if (input is PointerDownEvent) {
        _tracking.add(input.pointer);
        _input = input;
        recognizer.addPointer(input);
      } else if (input is PointerPanZoomStartEvent &&
          (recognizer is DragGestureRecognizer || recognizer is ScaleGestureRecognizer)) {
        _tracking.add(input.pointer);
        _input = input;
        recognizer.addPointerPanZoom(input);
      }
    }
  }

  static (ElEventPhase, ElEventPhase, ElEventPhase)? _tapPhases(int buttons) => switch (buttons) {
    kPrimaryButton => (.tapDown, .tapUp, .tap),
    kSecondaryButton => (.secondaryTapDown, .secondaryTapUp, .secondaryTap),
    kTertiaryButton => (.tertiaryTapDown, .tertiaryTapUp, .tertiaryTap),
    kForwardMouseButton => (.forwardTapDown, .forwardTapUp, .forwardTap),
    kBackMouseButton => (.backTapDown, .backTapUp, .backTap),
    _ => null,
  };

  static _PointerRoute? _route(PointerDownEvent down) => EventDispatcher._starts[down.original ?? down];

  void tapDown(PointerDownEvent down, int count) {
    host._send(host._pointer(_tapPhases(down.buttons)!.$1, down));
    if (live && (count == 2 || count == 3)) {
      host._send(host._pointer(count == 2 ? .doubleTapDown : .tripleTapDown, down, count: count));
    }
  }

  void tapUp(PointerDownEvent down, PointerEvent up, int count) {
    final phases = _tapPhases(down.buttons)!;
    final details = host._pointer(phases.$2, up, buttons: down.buttons);
    host._send(details);
    final route = _route(down);
    final canBubble = down.buttons == kPrimaryButton && route != null;
    if (live) {
      host._send(
        host._pointer(phases.$3, up, buttons: down.buttons, count: count),
        route: route,
        bubble: canBubble,
      );
    }
    if (live && (count == 2 || count == 3)) {
      host._send(
        host._pointer(count == 2 ? .doubleTap : .tripleTap, up, buttons: down.buttons, count: count),
        route: route,
        bubble: canBubble,
      );
    }
  }

  void tapCancel(PointerDownEvent down, PointerEvent? cancel, ElEventCancelReason reason) {
    if (host._pressed?.pointer == down.pointer) host._releaseFeedback();
    if (down.buttons == kPrimaryButton) {
      final input = cancel ?? _route(down)?.last ?? down;
      host._send(host._pointer(.tapCancel, input, reason: input is PointerCancelEvent ? .pointerCanceled : reason));
    }
  }

  SerialTapGestureRecognizer _makeSerialTap() => SerialTapGestureRecognizer(debugOwner: host)
    ..onSerialTapDown = (details) {
      final down = _input;
      if (!live || down is! PointerDownEvent) return;
      _serialDown = down;
      tapDown(down, details.count);
    }
    ..onSerialTapUp = (details) {
      final down = _serialDown;
      _serialDown = null;
      if (live && down != null) tapUp(down, _route(down)?.last ?? down, details.count);
    }
    ..onSerialTapCancel = (_) {
      final down = _serialDown;
      _serialDown = null;
      if (live && down != null) {
        tapCancel(down, null, _route(down)?.last is PointerCancelEvent ? .pointerCanceled : .tapRejected);
      }
    };

  LongPressGestureRecognizer _makeLongPress() {
    final recognizer = LongPressGestureRecognizer(debugOwner: host, duration: host.config.longPressDelay);
    recognizer.onLongPressStart = (_) {
      final route = EventDispatcher._pointers[recognizer.primaryPointer];
      final down = route?.down;
      if (!live || down is! PointerDownEvent) return;
      host._releaseFeedback();
      if (live) host._send(host._pointer(.longPress, down), route: route, bubble: true);
    };
    return recognizer;
  }

  DragGestureRecognizer _makeDrag(Axis? axis) {
    final recognizer = switch (axis) {
      Axis.horizontal => HorizontalDragGestureRecognizer(debugOwner: host),
      Axis.vertical => VerticalDragGestureRecognizer(debugOwner: host),
      null => PanGestureRecognizer(debugOwner: host),
    };
    var offset = Offset.zero;
    var position = Offset.zero;
    AxisDirection? direction;
    void emit(
      ElEventPhase phase,
      PointerEvent input, {
      Offset delta = Offset.zero,
      Offset velocity = Offset.zero,
      double? primaryVelocity,
      ElEventCancelReason? reason,
    }) {
      host._send(
        ElEventDetails(
          phase: phase,
          originalEvent: input,
          globalPosition: position,
          localPosition: host._local(position, input),
          delta: delta,
          localDelta: host._localDelta(position, delta, input),
          dragOffset: offset,
          dragAxis: axis,
          dragDirection: direction,
          buttons: input.buttons,
          pointerCount: host.activePointerCount,
          velocity: Velocity(pixelsPerSecond: velocity),
          primaryVelocity: primaryVelocity,
          cancelReason: reason,
        )..resolveLocalDelta((value) => host._localDelta(position, value, input)),
        axis: axis,
      );
    }

    recognizer
      ..onlyAcceptDragOnThreshold = true
      ..minFlingDistance = host.config.dragMinFlingDistance
      ..minFlingVelocity = host.config.dragMinFlingVelocity
      ..maxFlingVelocity = host.config.dragMaxFlingVelocity
      ..onStart = (details) {
        final input = _input;
        if (!live || input == null) return;
        offset = Offset.zero;
        position = details.globalPosition;
        final down = EventDispatcher._pointers[input.pointer]?.down;
        final moved = host._localDelta(position, position - (down?.position ?? position), input);
        final horizontal =
            axis == .horizontal ||
            axis == null && moved.dx.abs() * math.tan(host.config.dragHorizontalAngle) >= moved.dy.abs();
        direction = horizontal ? (moved.dx < 0 ? .left : .right) : (moved.dy < 0 ? .up : .down);
        host._releaseFeedback();
        if (!live) return;
        _cancel[recognizer] = (last, reason) => emit(.dragCancel, last ?? input, reason: reason);
        emit(.dragStart, input);
      }
      ..onUpdate = (details) {
        final input = _input;
        if (!live || input == null || !_cancel.containsKey(recognizer)) return;
        position = details.globalPosition;
        final delta = _globalDelta(input, details.localPosition, details.delta);
        offset += delta;
        emit(.dragUpdate, input, delta: delta);
      }
      ..onEnd = (details) {
        final input = _input;
        if (!live || input == null || _cancel.remove(recognizer) == null) return;
        if (input is PointerUpEvent || input is PointerPanZoomEndEvent) {
          if (input is PointerUpEvent) position = input.position;
          emit(
            .dragEnd,
            input,
            velocity: _globalDelta(input, recognizer.lastPosition.local, details.velocity.pixelsPerSecond),
            primaryVelocity: axis == null ? null : details.primaryVelocity,
          );
        } else {
          emit(.dragCancel, input, reason: .pointerCanceled);
        }
      };
    return recognizer;
  }

  ScaleGestureRecognizer _makeScale() {
    final recognizer = ScaleGestureRecognizer(debugOwner: host, dragStartBehavior: .start);
    var position = Offset.zero;
    double scale = 1, rotation = 0;
    void emit(
      ElEventPhase phase,
      PointerEvent input,
      int count, {
      Offset delta = Offset.zero,
      Velocity velocity = Velocity.zero,
      double scaleVelocity = 0,
      ElEventCancelReason? reason,
    }) => host._send(
      ElEventDetails(
        phase: phase,
        originalEvent: input,
        globalPosition: position,
        localPosition: host._local(position, input),
        delta: delta,
        localDelta: host._localDelta(position, delta, input),
        pointerCount: count,
        scale: scale,
        rotation: rotation,
        buttons: input.buttons,
        velocity: velocity,
        logScaleVelocity: scaleVelocity,
        cancelReason: reason,
      ),
    );
    recognizer
      ..onStart = (details) {
        final input = _input;
        if (!live || input == null) return;
        position = details.focalPoint;
        scale = 1;
        rotation = 0;
        host._releaseFeedback();
        if (!live) return;
        _cancel[recognizer] = (last, reason) => emit(.scaleCancel, last ?? input, 0, reason: reason);
        emit(.scaleStart, input, details.pointerCount);
      }
      ..onUpdate = (details) {
        final input = _input;
        if (!live || input == null || !_cancel.containsKey(recognizer)) return;
        final delta = details.focalPoint - position;
        final rotated = rotation != details.rotation;
        position = details.focalPoint;
        scale = details.scale;
        rotation = details.rotation;
        emit(.scaleUpdate, input, details.pointerCount, delta: delta);
        if (live && rotated) emit(.rotationUpdate, input, details.pointerCount, delta: delta);
      }
      ..onEnd = (details) {
        final input = _input;
        if (!live || input == null || _cancel.remove(recognizer) == null) return;
        if (input is PointerCancelEvent) {
          emit(.scaleCancel, input, details.pointerCount, reason: .pointerCanceled);
        } else {
          emit(
            .scaleEnd,
            input,
            details.pointerCount,
            velocity: details.velocity,
            scaleVelocity: scale > 0 ? details.scaleVelocity / scale : 0,
          );
        }
      };
    return recognizer;
  }

  static Offset _globalDelta(PointerEvent input, Offset position, Offset delta) {
    final inverse = input.transform == null ? null : Matrix4.tryInvert(input.transform!);
    return PointerEvent.transformDeltaViaPositions(
      transform: inverse,
      untransformedDelta: delta,
      untransformedEndPosition: position,
    );
  }

  void dispose(PointerEvent? input, ElEventCancelReason reason) {
    // Flutter 可能仍在执行当前回调，先失效回调，再释放它的路由。
    scheduleMicrotask(() {
      for (final recognizer in _recognizers) {
        recognizer.dispose();
      }
    });
    for (final down in [_tap?.down, _serialDown].whereType<PointerDownEvent>()) {
      tapCancel(down, input, reason);
    }
    for (final cancel in _cancel.values) {
      cancel(input ?? _input, reason);
    }
  }
}

// BaseTap 提供原始 Down 和 Up，识别与竞技场全部由 Flutter 处理。
final class _Tap extends BaseTapGestureRecognizer {
  _Tap(this.owner, {super.preAcceptSlopTolerance, super.postAcceptSlopTolerance});
  final _NativeGestures owner;
  PointerDownEvent? down;

  @override
  void handleTapDown({required PointerDownEvent down}) {
    if (!owner.live) return;
    this.down = down;
    owner.tapDown(down, 1);
  }

  @override
  void handleTapUp({required PointerDownEvent down, required PointerUpEvent up}) {
    this.down = null;
    if (owner.live) owner.tapUp(down, up, 1);
  }

  @override
  void handleTapCancel({required PointerDownEvent down, PointerCancelEvent? cancel, required String reason}) {
    this.down = null;
    if (owner.live) {
      owner.tapCancel(
        down,
        cancel,
        cancel != null
            ? .pointerCanceled
            : reason == 'forced'
            ? .otherGestureAccepted
            : .tapRejected,
      );
    }
  }
}
