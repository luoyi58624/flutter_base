part of 'sliver_bibi.dart';

// 这里不修改 ScrollPosition 的 pixels，也不借助 Notification 在滚动后纠偏：
// 先在官方 ScrollPhysics 的用户位移入口分账，未消费的部分才进入 Viewport。
final class _SliverPullPhysics extends ClampingScrollPhysics {
  const _SliverPullPhysics(this.motion, {super.parent});

  final _SliverPullMotion motion;

  @override
  _SliverPullPhysics applyTo(ScrollPhysics? ancestor) => _SliverPullPhysics(motion, parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      motion.consume(position, super.applyPhysicsToUserOffset(position, offset));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) =>
      motion.shouldSuppressBallistic ? null : super.createBallisticSimulation(position, velocity);
}

/// Sliver 对照版的刷新数据：原始拖拽像素直接决定拉出距离。
final class _SliverPullMotion {
  _SliverPullMotion({required TickerProvider vsync, required this.canStart, required this.onRefresh})
    : _offset = AnimationController.unbounded(vsync: vsync) {
    _offset.addListener(_publish);
    snapshot = ValueNotifier(_snapshot());
  }

  static const double triggerExtent = 128.0;
  final bool Function() canStart;
  final Future<void> Function() onRefresh;
  final AnimationController _offset;
  late final ValueNotifier<ElRefreshSnapshot> snapshot;
  RefreshIndicatorStatus? _status;
  bool _reversed = false;
  bool _gestureConsumed = false;
  bool _suppressBallistic = false;
  bool _disposed = false;
  int _pointers = 0;
  int _revision = 0;

  bool get shouldSuppressBallistic => _suppressBallistic;
  double get pulled => _offset.value;

  ElRefreshSnapshot _snapshot() => ElRefreshSnapshot(
    status: _status,
    pulledExtent: _offset.value,
    triggerExtent: triggerExtent,
    edge: ElRefreshEdge.leading,
    axisDirection: AxisDirection.down,
  );

  void _publish() {
    if (!_disposed) snapshot.value = _snapshot();
  }

  void pointerDown() {
    if (_pointers++ == 0) {
      _gestureConsumed = false;
      // 只吞掉拉刷新那一笔 fling；刷新期间的新手势照常使用官方惯性。
      _suppressBallistic = false;
    }
  }

  void pointerUp() {
    if (_pointers == 0 || --_pointers > 0) return;
    if (_gestureConsumed) _release();
  }

  void pointerCancel() {
    if (_pointers == 0 || --_pointers > 0) return;
    if (_gestureConsumed) cancel();
  }

  double consume(ScrollMetrics metrics, double offset) {
    if (_disposed) return offset;
    if (_status == RefreshIndicatorStatus.refresh || _status == RefreshIndicatorStatus.done) {
      _suppressBallistic = false;
      return offset;
    }
    if (offset == 0) return 0;

    final current = _offset.value;
    if (offset > 0 && canStart()) {
      // 同一事件先把正文/搜索栏送到 min，再将剩余位移交给刷新；不能丢掉跨边界的那一段。
      final toEdge = math.max(0.0, metrics.pixels - metrics.minScrollExtent);
      if (offset <= toEdge) return offset;
      final pullDelta = offset - toEdge;
      _offset.stop();
      _gestureConsumed = true;
      _suppressBallistic = true;
      _reversed = false;
      _status = RefreshIndicatorStatus.drag;
      _offset.value = current + pullDelta;
      _status = _offset.value >= triggerExtent ? RefreshIndicatorStatus.armed : RefreshIndicatorStatus.drag;
      _publish();
      return toEdge;
    }
    if (offset < 0 && current > 0) {
      _offset.stop();
      _gestureConsumed = true;
      _reversed = true;
      final absorbed = math.min(current, -offset);
      _offset.value = math.max(0, current - absorbed);
      if (_offset.value == 0) _suppressBallistic = false;
      _status = _offset.value > 0 ? RefreshIndicatorStatus.drag : null;
      _publish();
      // 收回到零后，只有剩余输入才能真正移动列表。
      return offset + absorbed;
    }
    return offset;
  }

  void _release() {
    _gestureConsumed = false;
    if (_status == RefreshIndicatorStatus.drag || _status == RefreshIndicatorStatus.armed) {
      if (_offset.value >= triggerExtent && !_reversed && canStart()) {
        _status = RefreshIndicatorStatus.refresh;
        _publish();
        unawaited(_settle(triggerExtent));
        unawaited(_performRefresh());
      } else {
        cancel();
      }
    }
  }

  Future<void> _performRefresh() async {
    try {
      await onRefresh();
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'Sliver Bibi refresh'));
    }
    if (_disposed || _status != RefreshIndicatorStatus.refresh) return;
    _status = RefreshIndicatorStatus.done;
    _publish();
    await _settle(0);
    if (!_disposed && _status == RefreshIndicatorStatus.done) {
      _status = null;
      _publish();
    }
  }

  Future<void> _settle(double target) async {
    final revision = ++_revision;
    try {
      await _offset
          .animateTo(
            target,
            duration: Duration(milliseconds: target == 0 ? 150 : 200),
            curve: target == 0 ? Curves.easeInOutSine : Curves.easeOutQuart,
          )
          .orCancel;
    } on TickerCanceled {
      return;
    }
    if (_disposed || revision != _revision) return;
    if (target == 0 && _status == RefreshIndicatorStatus.canceled) {
      _status = null;
      _publish();
    }
  }

  void cancel() {
    if (_disposed || _status == RefreshIndicatorStatus.refresh || _status == RefreshIndicatorStatus.done) return;
    _gestureConsumed = false;
    _reversed = false;
    if (_offset.value == 0) {
      _status = null;
      _publish();
      return;
    }
    _status = RefreshIndicatorStatus.canceled;
    _publish();
    unawaited(_settle(0));
  }

  void onPageDeactivated() {
    _pointers = 0;
    cancel();
  }

  void dispose() {
    _disposed = true;
    _revision++;
    _offset.dispose();
    snapshot.dispose();
  }
}

final class _SliverRefreshDetails extends ElRefreshDetails {
  _SliverRefreshDetails(this.motion, this.physics);

  final _SliverPullMotion motion;

  @override
  final ScrollPhysics physics;

  @override
  ValueListenable<ElRefreshSnapshot> get snapshot => motion.snapshot;

  @override
  Listenable get repaint => motion.snapshot;

  @override
  double? get contentGap => 0;

  @override
  void requestRefresh() {
    // 本对照版只响应真实手势松开，不提供绕过阈值的程序触发。
  }
}
