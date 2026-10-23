part of 'dispatcher.dart';

/// Scale 状态机：维护焦点、跨度、旋转与指针增减基线。双指成立时预检后原子
/// 接管全部序列；已有 winner 只有显式允许 upgrade 才能让渡，单指 Pan 不独占。
/// terminal 速度取最后抬起指针的 tracker 并按 Flutter 阈值归零/钳制，up 位置
/// 不进入 tracker，避免平台合成跳变污染。
final class _ScaleMachine {
  _ScaleMachine(this.host);

  static const int _logScaleVelocityFreshMicros = 80000;

  final ElEventDispatcher host;

  final Map<int, Offset> _positions = <int, Offset>{};
  final Map<int, VelocityTracker> _velocityTrackers = <int, VelocityTracker>{};
  bool started = false;
  bool _rejected = false;
  Offset? _initialFocal;
  double _initialSpan = 0.0;
  double _initialAngle = 0.0;
  double _scaleBase = 1.0;
  double _rotationBase = 0.0;
  double _lastScale = 1.0;
  double _lastRotation = 0.0;
  Duration? _lastScaleSampleTime;
  Duration? _logScaleVelocityTime;
  double _logScaleVelocity = 0.0;
  Offset? _logScaleVelocityFocal;
  bool _clearLogScaleVelocityOnNextPan = false;
  Offset? lastFocalPoint;
  _PointerSequence? _deliverySequence;

  bool get hasPointers => _positions.isNotEmpty;

  int get pointerCount => _positions.length;

  void feedDown(_PointerSequence seq, PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse) {
      final dragDevices =
          host._configOf(host._event).dragDevices ?? host.dragDevices;
      if (dragDevices != null && !dragDevices.contains(PointerDeviceKind.mouse)) {
        return;
      }
    }
    if (seq.contains(host)) _deliverySequence ??= seq;
    _positions[event.pointer] = event.position;
    _velocityTrackers[event.pointer] = host.velocityTrackerBuilder(event)
      ..addPosition(event.timeStamp, event.position);
    _rebaseline();
    if (started) {
      _clearLogScaleVelocity();
      _lastScaleSampleTime = event.timeStamp;
    }
    // 已 started 的手势中途补指凑满两指（单指焦点平移起步后第二指落下）：
    // 此刻捏合成立，立即对全部参与序列独占。
    if (started && _positions.length >= 2) {
      final startGeneration = host._configGeneration;
      if (!host._claimEagerForScalePointers()) {
        _velocityTrackers.remove(event.pointer);
        _positions.remove(event.pointer);
        _rebaseline();
        return;
      }
      if (!host._cancelPrimaryGesturesForScalePointers(
        _focalPoint(),
        startGeneration: startGeneration,
        originalEvent: event,
      )) {
        resetSilently();
      }
      return;
    }
    if (!_rejected && _positions.length >= 2 && _hasScaleUpgradePointer) {
      final focal = _focalPoint();
      final span = _span(focal);
      final angle = _angle();
      final delivery = _deliveryFor(seq);
      if (!host._handleScaleStart(
        delivery,
        focal,
        originalEvent: event,
        selfOnly: delivery == null,
      )) {
        _rejected = _positions.isNotEmpty;
        return;
      }
      _setStartBaseline(focal, span, angle, event.timeStamp);
    }
  }

  void feedMove(_PointerSequence seq, PointerMoveEvent event) {
    if (!_positions.containsKey(event.pointer)) return;
    _positions[event.pointer] = event.position;
    _velocityTrackers[event.pointer]?.addPosition(
      event.timeStamp,
      event.position,
    );
    if (_rejected) return;
    final focal = _focalPoint();
    final span = _span(focal);
    final angle = _angle();

    if (!started) {
      final eager = seq.eagerMember;
      if (eager != null && !identical(eager, host)) {
        if (identical(seq.scaleUpgradeTarget, host)) _rebaseline();
        return;
      }
      // 单指起步让位于**同宿主已接受**的拖拽：宿主自己的 drag 机已经拥有
      // 这个手势（如 ElZoomView 已缩放平移），单指焦点平移的二次起步只会
      // 中途夺权、白丢一帧交棒位移（对齐官方"arena 已判给 drag 的指针
      // scale 抢不回"）。双指捏合（span 参与）仍可接管拖拽。
      if (_positions.length < 2 &&
          ((host._dragMachine?._dragStarted ?? false) ||
              host._passiveDragPipeline?.active == true)) {
        return;
      }
      final initialFocal = _initialFocal;
      if (initialFocal == null) return;
      final focalMoved = (focal - initialFocal).distance;
      final spanChanged = (span - _initialSpan).abs();
      final panSlop = computePanSlop(event.kind, host.gestureSettings);
      final scaleSlop = computeScaleSlop(event.kind);
      var rotationMoved = false;
      if (host._event?.rotationStartEnabled == true) {
        var angleChanged = (angle - _initialAngle).abs();
        if (angleChanged > math.pi) angleChanged = math.pi * 2 - angleChanged;
        rotationMoved = _initialSpan * angleChanged > scaleSlop;
      }
      if (focalMoved <= panSlop && spanChanged <= scaleSlop && !rotationMoved) {
        return;
      }
      final delivery = _deliveryFor(seq);
      if (!host._handleScaleStart(
        delivery,
        focal,
        originalEvent: event,
        selfOnly: delivery == null,
      )) {
        _rejected = _positions.isNotEmpty;
        return;
      }
      // 起步瞬间重定基线，起始 scale = 1.0。
      _setStartBaseline(focal, span, angle, event.timeStamp);
      return;
    }

    final focalDelta = focal - (lastFocalPoint ?? focal);
    lastFocalPoint = focal;
    final previousScale = _lastScale;
    final scale = _initialSpan > precisionErrorTolerance
        ? _scaleBase * (span / _initialSpan)
        : _scaleBase;
    var angleDelta = angle - _initialAngle;
    if (angleDelta > math.pi) {
      angleDelta -= math.pi * 2;
    } else if (angleDelta < -math.pi) {
      angleDelta += math.pi * 2;
    }
    final rotation = _rotationBase + angleDelta;
    _lastScale = scale;
    _lastRotation = rotation;
    _rotationBase = rotation;
    _initialAngle = angle;
    if (_positions.length >= 2) {
      _trackLogScaleVelocity(previousScale, scale, focal, event.timeStamp);
    } else if (_clearLogScaleVelocityOnNextPan && focalDelta != Offset.zero) {
      _clearLogScaleVelocity();
    }
    final delivery = _deliveryFor(seq);
    if (delivery != null && !identical(delivery, seq)) {
      // shadow/多指聚合可能借另一根 pointer 的序列投递；该序列也必须切到
      // 当前物理 move 周期，否则 scaleUpdate 会被上一帧 delivery 位图去重。
      // owner 入口已经解析过 canonical token，直接复用，避免逐帧重走
      // PointerEvent.original 链。
      delivery.beginCycle(seq._cycleEvent ?? event);
    }
    host._fireScaleUpdate(
      delivery,
      focal,
      scale,
      rotation,
      delta: focalDelta,
      pointerCount: _positions.length,
      originalEvent: event,
      selfOnly: delivery == null,
    );
  }

  void feedUp(_PointerSequence seq, PointerUpEvent event) {
    final delivery = _deliveryFor(seq);
    final tracker = _velocityTrackers.remove(event.pointer);
    if (_positions.remove(event.pointer) == null) return;
    _refreshDeliverySequence(seq);
    _releaseSequenceClaim(event.pointer);
    if (started && _positions.isEmpty) {
      _rejected = false;
      final logScaleVelocity = _freshLogScaleVelocity(event.timeStamp);
      final scaleVelocityFocal = logScaleVelocity == 0.0
          ? null
          : _logScaleVelocityFocal;
      _clearLogScaleVelocity();
      host._handleScaleEnd(
        delivery,
        _endVelocityFor(tracker),
        logScaleVelocity: logScaleVelocity,
        scaleVelocityFocalPoint: scaleVelocityFocal,
        originalEvent: event,
        selfOnly: identical(seq.scaleShadowTarget, host) && !seq.contains(host),
      );
      return;
    }
    if (_positions.isEmpty) _rejected = false;
    if (_positions.length == 1) _clearLogScaleVelocityOnNextPan = true;
    _lastScaleSampleTime = event.timeStamp;
    _rebaseline();
  }

  void feedCancel(_PointerSequence seq, PointerCancelEvent event) {
    final delivery = _deliveryFor(seq);
    _velocityTrackers.remove(event.pointer);
    if (_positions.remove(event.pointer) == null) return;
    _refreshDeliverySequence(seq);
    _releaseSequenceClaim(event.pointer);
    if (started && _positions.isEmpty) {
      _rejected = false;
      _clearLogScaleVelocity();
      host._cancelActiveScale(
        deliverySequence: delivery,
        originalEvent: event,
        selfOnly: identical(seq.scaleShadowTarget, host) && !seq.contains(host),
      );
      return;
    }
    if (_positions.isEmpty) _rejected = false;
    _clearLogScaleVelocity();
    _lastScaleSampleTime = event.timeStamp;
    _rebaseline();
  }

  void feedRemoved(int pointer) {
    _velocityTrackers.remove(pointer);
    if (_positions.remove(pointer) == null) return;
    final delivery = _deliverySequence;
    if (delivery != null && delivery.pointer == pointer) {
      _selectDeliverySequence();
    }
    _releaseSequenceClaim(pointer);
    if (started && _positions.isEmpty) {
      started = false;
      _rejected = false;
      lastFocalPoint = null;
      _clearLogScaleVelocity();
      return;
    }
    if (_positions.isEmpty) _rejected = false;
    _clearLogScaleVelocity();
    _rebaseline();
  }

  bool get _hasScaleUpgradePointer {
    for (final pointer in _positions.keys) {
      if (identical(
        _PointerSequenceRegistry.of(pointer)?.scaleUpgradeTarget,
        host,
      )) {
        return true;
      }
    }
    return false;
  }

  void _setStartBaseline(
    Offset focal,
    double span,
    double angle,
    Duration timeStamp,
  ) {
    _initialFocal = focal;
    _initialSpan = span;
    _initialAngle = angle;
    _scaleBase = 1.0;
    _rotationBase = 0.0;
    _lastScale = 1.0;
    _lastRotation = 0.0;
    _clearLogScaleVelocity();
    _lastScaleSampleTime = timeStamp;
  }

  void _trackLogScaleVelocity(
    double previousScale,
    double scale,
    Offset focal,
    Duration timeStamp,
  ) {
    final previousTime = _lastScaleSampleTime;
    _lastScaleSampleTime = timeStamp;
    if (previousTime == null || scale == previousScale) return;
    if (previousScale <= 0 ||
        !previousScale.isFinite ||
        scale <= 0 ||
        !scale.isFinite) {
      _clearLogScaleVelocity();
      _lastScaleSampleTime = timeStamp;
      return;
    }
    final elapsedMicros = (timeStamp - previousTime).inMicroseconds;
    if (elapsedMicros <= 0) return;
    final velocity =
        math.log(scale / previousScale) *
        Duration.microsecondsPerSecond /
        elapsedMicros;
    if (!velocity.isFinite) {
      _clearLogScaleVelocity();
      _lastScaleSampleTime = timeStamp;
      return;
    }
    _logScaleVelocity = velocity;
    _logScaleVelocityTime = timeStamp;
    _logScaleVelocityFocal = focal;
    _clearLogScaleVelocityOnNextPan = false;
  }

  double _freshLogScaleVelocity(Duration terminalTime) {
    final sampleTime = _logScaleVelocityTime;
    if (sampleTime == null) return 0.0;
    final age = (terminalTime - sampleTime).inMicroseconds;
    return age >= 0 && age <= _logScaleVelocityFreshMicros
        ? _logScaleVelocity
        : 0.0;
  }

  void _clearLogScaleVelocity() {
    _lastScaleSampleTime = null;
    _logScaleVelocityTime = null;
    _logScaleVelocity = 0.0;
    _logScaleVelocityFocal = null;
    _clearLogScaleVelocityOnNextPan = false;
  }

  void _releaseSequenceClaim(int pointer) {
    final seq = _PointerSequenceRegistry.of(pointer);
    if (seq == null) return;
    if (identical(seq.scaleUpgradeTarget, host)) seq.scaleUpgradeTarget = null;
    if (!seq.scaleWon || !identical(seq.eagerMember, host)) return;
    seq.scaleWon = false;
  }

  void _refreshDeliverySequence(_PointerSequence removed) {
    if (identical(_deliverySequence, removed)) _selectDeliverySequence();
  }

  _PointerSequence? _deliveryFor(_PointerSequence fallback) {
    final fallbackIndex = fallback.indexOf(host);
    if (fallbackIndex >= 0 && fallback.memberActiveAt(fallbackIndex)) {
      return _deliverySequence = fallback;
    }
    final current = _deliverySequence;
    final currentIndex = current?.indexOf(host) ?? -1;
    if (current != null &&
        currentIndex >= 0 &&
        current.memberActiveAt(currentIndex) &&
        identical(_PointerSequenceRegistry.of(current.pointer), current)) {
      return current;
    }
    _selectDeliverySequence();
    return _deliverySequence;
  }

  void _selectDeliverySequence() {
    _deliverySequence = null;
    for (final pointer in _positions.keys) {
      final candidate = _PointerSequenceRegistry.of(pointer);
      final index = candidate?.indexOf(host) ?? -1;
      if (candidate != null && index >= 0 && candidate.memberActiveAt(index)) {
        _deliverySequence = candidate;
        return;
      }
    }
  }

  /// scaleEnd 速度 = 最后抬起手指的 tracker 估计（官方 ScaleGestureRecognizer
  /// 同款门限）：|v| ≤ [kMinFlingVelocity] 归零；|v| > [kMaxFlingVelocity]
  /// 等比钳制到上限。up 位置不喂 tracker（见类文档契约）。
  Velocity _endVelocityFor(VelocityTracker? tracker) {
    final velocity = tracker?.getVelocity() ?? Velocity.zero;
    final pixelsPerSecond = velocity.pixelsPerSecond;
    if (pixelsPerSecond.distanceSquared <=
        kMinFlingVelocity * kMinFlingVelocity) {
      return Velocity.zero;
    }
    if (pixelsPerSecond.distanceSquared >
        kMaxFlingVelocity * kMaxFlingVelocity) {
      return Velocity(
        pixelsPerSecond:
            (pixelsPerSecond / pixelsPerSecond.distance) * kMaxFlingVelocity,
      );
    }
    return velocity;
  }

  void _rebaseline() {
    if (_positions.isEmpty) {
      _initialFocal = null;
      _initialSpan = 0.0;
      _initialAngle = 0.0;
      return;
    }
    final focal = _focalPoint();
    // 已 started 时保留累计 scale/rotation，从当前姿态继续。
    if (started) {
      _scaleBase = _lastScale;
      _rotationBase = _lastRotation;
    }
    _initialFocal = focal;
    _initialSpan = _span(focal);
    _initialAngle = _angle();
    lastFocalPoint = started ? focal : lastFocalPoint;
  }

  Offset _focalPoint() {
    var sum = Offset.zero;
    for (final position in _positions.values) {
      sum += position;
    }
    return sum / _positions.length.toDouble();
  }

  double _span(Offset focal) {
    if (_positions.length < 2) return 0.0;
    var total = 0.0;
    for (final position in _positions.values) {
      total += (position - focal).distance;
    }
    return total / _positions.length;
  }

  double _angle() {
    if (_positions.length < 2) return 0.0;
    final iterator = _positions.values.iterator..moveNext();
    final first = iterator.current;
    iterator.moveNext();
    final second = iterator.current;
    final delta = second - first;
    return math.atan2(delta.dy, delta.dx);
  }

  /// 静默清空（eager 失权 / 链截断 / detach / dispose）。
  void resetSilently() {
    for (final pointer in _positions.keys) {
      _releaseSequenceClaim(pointer);
    }
    _positions.clear();
    _velocityTrackers.clear();
    started = false;
    _rejected = false;
    lastFocalPoint = null;
    _initialFocal = null;
    _initialSpan = 0.0;
    _initialAngle = 0.0;
    _scaleBase = 1.0;
    _rotationBase = 0.0;
    _lastScale = 1.0;
    _lastRotation = 0.0;
    _clearLogScaleVelocity();
    _deliverySequence = null;
  }
}
