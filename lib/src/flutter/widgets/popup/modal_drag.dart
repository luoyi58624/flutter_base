part of 'modal.dart';

class _ModalDragMotion extends ChangeNotifier {
  double offset = 0;
  double distance = 0;
  bool dismissed = false;

  void update(double offset, double distance, {bool dismissed = false}) {
    this.offset = offset;
    this.distance = distance.clamp(0.0, 1.0);
    this.dismissed = dismissed;
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
    required this.layout,
    required this.child,
  });

  final Axis axis;
  final double sign;
  final _ModalDragMotion motion;
  final bool reduced;
  final Animation<double> animation;
  final Widget Function(Widget panel) layout;
  final Widget child;

  @override
  State<_ModalDrag> createState() => _ModalDragState();
}

class _ModalDragState extends State<_ModalDrag> with SingleTickerProviderStateMixin {
  final _panelKey = GlobalKey();
  final _scrollables = <ScrollableState>{};
  late final _settle = AnimationController(vsync: this);
  late final _ModalSwipeRecognizer _swipe;

  RenderBox? get _panel => _panelKey.currentContext?.findRenderObject() as RenderBox?;

  double get _extent => switch (_panel?.size) {
    Size(:final width, :final height) => widget.axis == .horizontal ? width : height,
    null => 0,
  };

  bool _canStart(PointerDownEvent event) {
    final panel = _panel;
    if (!widget.animation.isCompleted || _settle.isAnimating || panel == null || !panel.hasSize) return false;
    // 遮罩区直接登记手势，面板内起手才检查输入和滚动控件。
    final position = panel.globalToLocal(event.position);
    if (!(Offset.zero & panel.size).contains(position)) return true;
    final result = BoxHitTestResult();
    panel.hitTest(result, position: position);
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

  void _move(double distance) {
    final extent = _extent;
    if (extent > 0) widget.motion.update(distance, distance / extent);
  }

  Future<void> _end(double velocity, {bool cancelled = false}) async {
    final route = ModalRoute.of(context);
    final from = widget.motion.offset;
    final extent = _extent;
    if (extent <= 0) {
      widget.motion.update(0, 0);
      return;
    }
    final dismiss =
        !cancelled && from >= 12 && velocity >= -300 && (from >= math.min(88, extent * .28) || velocity >= 550);
    final to = dismiss ? math.max(from, extent + 32) : 0.0;
    if (to == from && !dismiss) return;
    // 松手的速度决定回弹曲线起点，收尾沿用 Web 面板的阻尼曲线。
    final slope = to == from ? 0.0 : (.174 * velocity * .22 / (to - from)).clamp(-.35, .9).toDouble();
    final curve = Cubic(.174, slope, .185, 1);
    void tick() {
      if (route?.isCurrent != true) return;
      final progress = curve.transform(_settle.value);
      final distance = math.max(0.0, from + (to - from) * progress);
      widget.motion.update(distance, distance / extent, dismissed: dismiss && _settle.isCompleted);
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
    fit: .expand,
    children: [
      widget.layout(
        AnimatedBuilder(
          animation: widget.motion,
          child: NotificationListener<ScrollMetricsNotification>(onNotification: _trackScroll, child: widget.child),
          builder: (context, child) {
            final offset = widget.sign * widget.motion.offset;
            return Transform.translate(
              key: _panelKey,
              offset: widget.axis == .horizontal ? Offset(offset, 0) : Offset(0, offset),
              child: child,
            );
          },
        ),
      ),
      // 先于正文滚动器登记手势，遮罩空白仍由下层 ModalBarrier 接收点击。
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
