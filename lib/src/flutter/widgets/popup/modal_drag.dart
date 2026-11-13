part of 'modal.dart';

class _ModalDragMotion extends ChangeNotifier {
  double offset = 0;
  double distance = 0;
  double fade = 0;

  void update(double offset, double distance, {double fade = 0}) {
    this.offset = offset;
    this.distance = distance.clamp(0.0, 1.0);
    this.fade = fade;
    notifyListeners();
  }
}

class _ModalDrag extends StatefulWidget {
  const _ModalDrag({
    required this.axis,
    required this.sign,
    required this.motion,
    required this.reduced,
    required this.animation,
    required this.child,
  });

  final Axis axis;
  final double sign;
  final _ModalDragMotion motion;
  final bool reduced;
  final Animation<double> animation;
  final Widget child;

  @override
  State<_ModalDrag> createState() => _ModalDragState();
}

class _ModalDragState extends State<_ModalDrag> with SingleTickerProviderStateMixin {
  final _scrollables = <ScrollableState>{};
  late final _settle = AnimationController(vsync: this);
  late final _ModalSwipeRecognizer _swipe;

  double get _extent {
    final size = context.size!;
    return widget.axis == .horizontal ? size.width : size.height;
  }

  bool _canStart(PointerDownEvent event) {
    if (!widget.animation.isCompleted || _settle.isAnimating) return false;
    // 输入控件本身需要横向拖动或文字选择，面板手势在这一触点让位。
    final panel = context.findRenderObject()! as RenderBox;
    final result = BoxHitTestResult();
    panel.hitTest(result, position: panel.globalToLocal(event.position));
    final targets = <HitTestTarget>{};
    for (final entry in result.path) {
      final target = entry.target;
      targets.add(target);
      if (target is RenderEditable) return false;
      final semantics = switch (target) {
        ElRenderView() => target.semantics?.properties,
        RenderSemanticsAnnotations() => target.properties,
        _ => null,
      };
      if (semantics?.textField == true || semantics?.slider == true) return false;
    }
    _scrollables.removeWhere((scrollable) => !scrollable.mounted);
    for (final scrollable in _scrollables) {
      if (!targets.contains(scrollable.notificationContext?.findRenderObject())) continue;
      final position = scrollable.position;
      if (position is FixedExtentMetrics) return false;
      if (position.axis != widget.axis || !position.hasContentDimensions) continue;
      final reversed = axisDirectionIsReversed(position.axisDirection);
      final towardsMin = (widget.sign > 0) != reversed;
      if (towardsMin
          ? position.pixels > position.minScrollExtent + 1
          : position.pixels < position.maxScrollExtent - 1) {
        return false;
      }
    }
    return true;
  }

  bool _trackScroll(ScrollMetricsNotification notification) {
    final scrollable = Scrollable.maybeOf(notification.context);
    if (scrollable != null) {
      _scrollables.add(scrollable);
    }
    return false;
  }

  void _move(double distance) => widget.motion.update(distance, distance / _extent);

  Future<void> _end(double velocity, {bool cancelled = false}) async {
    final route = ModalRoute.of(context);
    final from = widget.motion.offset;
    final extent = _extent;
    final dismiss =
        !cancelled &&
        extent > 0 &&
        from >= 12 &&
        velocity >= -300 &&
        (from >= math.min(88, extent * .28) || velocity >= 550);
    final to = dismiss ? extent + 32 : 0.0;
    if (to == from) return;
    // 松手的速度决定回弹曲线起点，收尾沿用 Web 面板的阻尼曲线。
    final slope = (.174 * velocity * .22 / (to - from)).clamp(-.35, .9).toDouble();
    final curve = Cubic(.174, slope, .185, 1);
    void tick() {
      if (route?.isCurrent != true) return;
      final progress = curve.transform(_settle.value);
      final distance = math.max(0.0, from + (to - from) * progress);
      widget.motion.update(distance, distance / extent, fade: dismiss ? progress.clamp(0.0, 1.0) : 0);
    }

    _settle.addListener(tick);
    try {
      _settle.duration = widget.reduced ? Duration.zero : const Duration(milliseconds: 220);
      await _settle.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    } finally {
      if (mounted) _settle.removeListener(tick);
    }
    if (!mounted) return;
    if (dismiss && route?.isCurrent == true) {
      Navigator.of(context).pop();
      if (!route!.isCurrent) return;
    }
    if (mounted) widget.motion.update(0, 0);
  }

  @override
  void initState() {
    super.initState();
    _swipe = _ModalSwipeRecognizer(
      axis: widget.axis,
      sign: widget.sign,
      canStart: _canStart,
      onMove: _move,
      onEnd: _end,
    );
  }

  @override
  void dispose() {
    _swipe.dispose();
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      AnimatedBuilder(
        animation: widget.motion,
        child: NotificationListener<ScrollMetricsNotification>(onNotification: _trackScroll, child: widget.child),
        builder: (context, child) {
          final offset = widget.sign * widget.motion.offset;
          return Transform.translate(
            offset: widget.axis == .horizontal ? Offset(offset, 0) : Offset(0, offset),
            child: child,
          );
        },
      ),
      // 在正文滚动器之前登记手势，同时保留子内容的命中路径。
      Positioned.fill(
        child: Listener(behavior: .translucent, onPointerDown: _swipe.addPointer),
      ),
    ],
  );
}

// 起手方向和滚动边界决定是否进入竞技场，正文能滚动时由它消费整次手势。
class _ModalSwipeRecognizer extends OneSequenceGestureRecognizer {
  _ModalSwipeRecognizer({
    required this.axis,
    required this.sign,
    required this.canStart,
    required this.onMove,
    required this.onEnd,
  }) : super(supportedDevices: const {PointerDeviceKind.touch});

  final Axis axis;
  final double sign;
  final bool Function(PointerDownEvent event) canStart;
  final ValueChanged<double> onMove;
  final void Function(double velocity, {bool cancelled}) onEnd;
  int? _pointer;
  late Offset _origin;
  late VelocityTracker _velocity;
  late Duration _lastMovedAt;
  double _distance = 0;
  bool _active = false;
  bool _accepted = false;

  @override
  String get debugDescription => '模态面板滑动';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) {
      _finish(cancelled: true);
      return;
    }
    if (!canStart(event)) return;
    _pointer = event.pointer;
    _origin = event.position;
    _distance = 0;
    _lastMovedAt = event.timeStamp;
    _velocity = VelocityTracker.withKind(event.kind)..addPosition(event.timeStamp, event.position);
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      final moved = event.position - _origin;
      final main = axis == .horizontal ? moved.dx : moved.dy;
      final cross = axis == .horizontal ? moved.dy : moved.dx;
      _distance = math.max(0.0, main * sign);
      if (!event.synthesized) {
        _lastMovedAt = event.timeStamp;
        _velocity.addPosition(event.timeStamp, event.position);
      }
      if (!_active) {
        if (math.max(main.abs(), cross.abs()) < 6) return;
        if (main * sign <= 0 || main.abs() < cross.abs() * 1.15) {
          _finish(cancelled: true);
          return;
        }
        _active = true;
        if (!_accepted) {
          resolve(GestureDisposition.accepted);
          return;
        }
      }
      if (_accepted) onMove(_distance);
    } else if (event is PointerUpEvent) {
      _finish(cancelled: false, velocity: _releaseVelocity(event));
    } else if (event is PointerCancelEvent) {
      _finish(cancelled: true);
    }
  }

  @override
  void acceptGesture(int pointer) {
    if (pointer != _pointer) return;
    _accepted = true;
    if (_active) onMove(_distance);
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer == _pointer) _finish(cancelled: true);
  }

  double _releaseVelocity(PointerUpEvent event) {
    if (!_active || event.timeStamp - _lastMovedAt > const Duration(milliseconds: 100)) return 0;
    final estimate = _velocity.getVelocityEstimate();
    if (estimate == null) return 0;
    final elapsed = estimate.duration;
    // Flutter 至少需要三个采样点；稀疏的短促轻扫用采样区间的均速。
    final speed = estimate.pixelsPerSecond == Offset.zero && elapsed > Duration.zero
        ? estimate.offset * (Duration.microsecondsPerSecond / elapsed.inMicroseconds)
        : estimate.pixelsPerSecond;
    return (axis == .horizontal ? speed.dx : speed.dy) * sign;
  }

  void _finish({required bool cancelled, double velocity = 0}) {
    final pointer = _pointer;
    if (pointer == null) return;
    _pointer = null;
    final active = _active && _accepted;
    _active = false;
    _accepted = false;
    resolve(GestureDisposition.rejected);
    stopTrackingPointer(pointer);
    if (active) onEnd(velocity, cancelled: cancelled);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}
}
