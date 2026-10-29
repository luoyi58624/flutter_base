part of '../virtual_pipeline.dart';

/// 本轴有限效果行程与正文共享的惯性生产者，simulation 只提供数值。
final class _ScrollMotionCoordinator {
  _ScrollMotionCoordinator(this.host, this.axis);
  final ElScrollViewState host;
  final Axis axis;
  ScrollEnginePosition? _position;
  List<_EffectTrackBinding> _tracks = const [];
  _CoordinatedBallisticActivity? _activity;

  RefreshScrollLink? get _refresh => axis == host._layoutAxis ? host._refreshLink : null;

  bool _live(_EffectTrackBinding binding) =>
      host._mixinCallbacksActive &&
      binding.client.mountedForScrollCallbacks &&
      identical(host._mixinClients?[binding.client], binding.registration);

  void configure(ScrollEnginePosition position, List<_EffectTrackBinding> tracks) {
    var sameMembers = tracks.length == _tracks.length;
    if (sameMembers) {
      for (var index = 0; index < tracks.length; index++) {
        if (!identical(tracks[index].client, _tracks[index].client) ||
            tracks[index].track.effectId != _tracks[index].track.effectId) {
          sameMembers = false;
          break;
        }
      }
    }
    if (!identical(position, _position) || !sameMembers) {
      _finish(cancelled: true);
    } else if (!listEquals(tracks, _tracks)) {
      _activity?.needsRebase = true;
    }
    if (!identical(position, _position)) _position?.ballisticHandler = null;
    _position = position;
    _tracks = tracks;
    position.ballisticHandler = _startBallistic;
  }

  double get _effectsPosition {
    var result = 0.0;
    for (final binding in _tracks) {
      if (_live(binding)) result += (binding.track.value - binding.track.minValue) * binding.track.pixelsPerUnit;
    }
    return result;
  }

  double get _effectsRange {
    var result = 0.0;
    for (final binding in _tracks) {
      if (_live(binding)) result += (binding.track.maxValue - binding.track.minValue) * binding.track.pixelsPerUnit;
    }
    return result;
  }

  double _contentOffset(ScrollPosition position) => axisDirectionIsReversed(position.axisDirection)
      ? position.maxScrollExtent - position.pixels
      : position.pixels - position.minScrollExtent;

  ScrollMetrics _metrics(ScrollEnginePosition position, {bool recoveringBody = false}) {
    final route = host._ancestorRouteFor(axis);
    final effectPosition = _effectsPosition + (route?.effectPosition ?? 0);
    final ancestorPosition = route?.contentPosition ?? 0;
    // 已越界正文拥有回位约束，不能把其他自由度的可用范围误当作它的弹簧终点。
    final bodyPhase = recoveringBody || position.outOfRange;
    final minimum = bodyPhase ? effectPosition + ancestorPosition : 0.0;
    final range =
        math.max(0, position.maxScrollExtent - position.minScrollExtent) +
        (bodyPhase
            ? effectPosition + ancestorPosition
            : _effectsRange + (route?.effectRange ?? 0) + (route?.contentRange ?? 0));
    final pixels = _contentOffset(position) + effectPosition + ancestorPosition;
    if (!range.isFinite || !pixels.isFinite) throw FlutterError('协同运动的总行程及当前位置必须有限。');
    return FixedScrollMetrics(
      minScrollExtent: minimum,
      maxScrollExtent: range,
      pixels: pixels,
      viewportDimension: position.viewportDimension,
      axisDirection: axis == Axis.vertical ? AxisDirection.down : AxisDirection.right,
      devicePixelRatio: position.devicePixelRatio,
    );
  }

  Simulation? _createSimulation(ScrollEnginePosition position, ScrollMetrics metrics, double velocity) {
    final physics = position.physics;
    if (!axisDirectionIsReversed(position.axisDirection)) return physics.createBallisticSimulation(metrics, velocity);
    // 输入预算保持视觉坐标，平台物理及刷新停靠仍读取真实 raw min/max 边。
    final physical = metrics.copyWith(
      pixels: metrics.minScrollExtent + (metrics.maxScrollExtent - metrics.pixels),
      axisDirection: position.axisDirection,
    );
    final simulation = physics.createBallisticSimulation(physical, -velocity);
    return simulation == null
        ? null
        : _ReflectedScrollSimulation(simulation, metrics.minScrollExtent, metrics.maxScrollExtent);
  }

  Simulation? _continueSimulation(ScrollEnginePosition position, ScrollMetrics metrics, double velocity) {
    final physics = position.physics;
    final simulation = _createSimulation(position, metrics, velocity);
    final basis = physics is RefreshDockPhysics && physics.getLink() == null ? physics.parent : physics;
    // 浏览器首段弦斜率不等于请求初速；仅续接已知样条时校准时间，保留首次释放及自定义物理的策略。
    if (simulation != null && basis.runtimeType == ElBrowserScrollPhysics && !metrics.outOfRange) {
      final initial = simulation.dx(0);
      if (initial != 0 && initial.sign == velocity.sign) {
        return _VelocityContinuousSimulation(simulation, velocity / initial);
      }
    }
    return simulation;
  }

  ({bool handled, bool launched}) startReleasedMotion(DragEndDetails details) {
    final position = _position;
    if (position == null) return (handled: false, launched: false);
    final owner = host._ancestorRouteFor(axis)?.sourceOwner;
    if (owner == null || !owner.isCurrent) return (handled: true, launched: false);
    final transaction = ScrollInputTransaction.current;
    final launched = position.endInputDragOwned(
      owner,
      details,
      DragStartDetails(
        sourceTimeStamp: transaction?.timeStamp,
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
        kind: transaction?.rawEvent?.kind,
      ),
    );
    return (handled: true, launched: launched);
  }

  bool _startBallistic(double rawVelocity) => _tryBallistic(rawVelocity).handled;

  ({bool handled, bool launched}) _tryBallistic(double rawVelocity) {
    final position = _position;
    if (position == null || !position.hasPixels || !position.hasContentDimensions || !host._mixinCallbacksActive) {
      return (handled: false, launched: false);
    }
    if (rawVelocity.abs() <= precisionErrorTolerance && !position.outOfRange) return (handled: false, launched: false);
    final metrics = _metrics(position);
    if (metrics.maxScrollExtent <= precisionErrorTolerance && !metrics.outOfRange) {
      return (handled: false, launched: false);
    }
    final velocity = axisDirectionIsReversed(position.axisDirection) ? -rawVelocity : rawVelocity;
    final simulation = _createSimulation(position, metrics, velocity);
    if (simulation == null) return (handled: false, launched: false);
    final ignorePointer = switch (ScrollInputTransaction.current?.source) {
      ElScrollInputSource.touch || ElScrollInputSource.stylus || ElScrollInputSource.mouseDrag => true,
      ElScrollInputSource.trackpad || ElScrollInputSource.pointerSignal => false,
      // 未声明设备时保留原活动的原生策略。
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      _ => position.activity?.shouldIgnorePointer ?? false,
    };
    _finish(cancelled: true);
    final route = host._ancestorRouteFor(axis);
    final owner = route == null
        ? position.claimMotion(
            cause: ElScrollUpdateCause.ballistic,
            onCancelled: _lostOwner,
            sessionId: ScrollInputTransaction.current?.sessionId,
          )
        : route.beginBallistic();
    if (owner == null) return (handled: true, launched: false);
    final next = _CoordinatedBallisticActivity(
      this,
      position,
      owner,
      simulation,
      metrics,
      ignorePointer: ignorePointer,
      sessionId: ScrollInputTransaction.current?.sessionId ?? route?._sessionId,
    );
    _activity = next;
    if (!position.startOwnedActivity(owner, next)) {
      _finish(cancelled: true);
      // 活动开始通知内的新命令已经接管，旧释放不得再回落启动另一段原生 fling。
      return (handled: true, launched: false);
    }
    route?.installBallisticMembers(ignorePointer: ignorePointer);
    if (!owner.isCurrent) return (handled: true, launched: false);
    next.start();
    return (handled: true, launched: true);
  }

  void _lostOwner() => _finish(cancelled: true);

  void _finish({required bool cancelled}) {
    final activity = _activity;
    if (activity == null) return;
    _activity = null;
    activity.stop();
    final position = activity.position;
    final link = _refresh;
    if (!cancelled &&
        activity.motionOwner.isCurrent &&
        position.outOfRange &&
        (link == null || (link.dockMinExtension == 0 && link.dockMaxExtension == 0))) {
      final boundary = position.pixels.clamp(position.minScrollExtent, position.maxScrollExtent);
      if ((boundary - position.pixels).abs() <= position.physics.toleranceFor(position).distance) {
        position.setPixelsOwned(activity.motionOwner, boundary);
      }
    }
    final route = host._ancestorRouteFor(axis);
    if (identical(route?.sourceOwner, activity.motionOwner)) {
      route!.finish(cancelled: cancelled);
    } else if (cancelled) {
      activity.position.cancelMotion(activity.motionOwner);
    } else {
      activity.position.completeMotion(activity.motionOwner);
    }
  }

  void _disposedActivity(_CoordinatedBallisticActivity activity) {
    if (identical(_activity, activity)) _activity = null;
    activity.stop();
  }

  void tick(_CoordinatedBallisticActivity activity, Duration stamp) {
    try {
      _tick(activity, stamp);
    } catch (_) {
      _finish(cancelled: true);
      rethrow;
    }
  }

  void _tick(_CoordinatedBallisticActivity activity, Duration stamp) {
    if (!identical(activity, _activity) || !activity.motionOwner.isCurrent) {
      // 通知异常可能中断 position 的活动替换，失效 Ticker 必须自行停止，不能每帧空转。
      _disposedActivity(activity);
      return;
    }
    if (activity.lastStamp != null && stamp <= activity.lastStamp!) return;
    final transaction = ScrollInputTransaction.begin(
      source: ElScrollInputSource.ballistic,
      timeStamp: stamp,
      sessionId: activity.sessionId,
    );
    try {
      final route = host._ancestorRouteFor(axis);
      route?.join(transaction);
      host._inputRouter?._joinTransaction(transaction);
      if (!activity.motionOwner.isCurrent) return;
      final position = activity.position;
      activity.recoveringBody |= position.outOfRange;
      final metrics = _metrics(position, recoveringBody: activity.recoveringBody);
      if (activity.needsRebase ||
          activity.refreshPhysicsChanged ||
          metrics.minScrollExtent != activity.minimum ||
          metrics.maxScrollExtent != activity.range ||
          (metrics.pixels - activity.expectedPosition).abs() > precisionErrorTolerance) {
        final simulation = _continueSimulation(position, metrics, activity.sampleVelocity);
        if (simulation == null) {
          _finish(cancelled: false);
          return;
        }
        activity.rebase(simulation, metrics);
      }
      activity.startStamp ??= stamp;
      final time = (stamp - activity.startStamp!).inMicroseconds / Duration.microsecondsPerSecond;
      final nextValue = activity.simulation.x(time);
      activity.sampleVelocity = activity.simulation.dx(time);
      final done = activity.simulation.isDone(time);
      if (!nextValue.isFinite || !activity.sampleVelocity.isFinite) throw FlutterError('运动采样必须产生有限的位置和速度。');
      final delta = nextValue - activity.lastSimulationValue;
      activity.lastSimulationValue = nextValue;
      activity.lastStamp = stamp;
      var remaining = delta;
      if (activity.recoveringBody && activity.resumeAfterBoundary) {
        final offset = _contentOffset(position);
        final range = position.maxScrollExtent - position.minScrollExtent;
        final recovery = offset.clamp(0.0, range) - offset;
        if (recovery == 0 || recovery.sign == remaining.sign && remaining.abs() >= recovery.abs()) {
          // 反向摩擦惯性先精确收回正文；跨界这一帧的余量继续走效果分账，不能漏掉头部行程。
          position.setPixelsOwned(
            activity.motionOwner,
            position.pixels.clamp(position.minScrollExtent, position.maxScrollExtent),
          );
          if (!activity.motionOwner.isCurrent) return;
          remaining -= recovery;
          activity.recoveringBody = false;
          activity.resumeAfterBoundary = false;
          activity.needsRebase = true;
        }
      }
      if (activity.recoveringBody) {
        // 弹簧穿过边界后的尾段仍归正文，否则反弹的余速会反向驱动头部。
        remaining = _applyBody(activity, remaining);
        if (!activity.motionOwner.isCurrent) return;
        if (remaining.abs() > precisionErrorTolerance) _finish(cancelled: false);
      } else if (remaining.abs() > precisionErrorTolerance) {
        final scale = axisDirectionIsReversed(position.axisDirection) ? 1.0 : -1.0;
        final input = host._mixinInputLinkFor(axis);
        final consumed = input.interceptScrollDelta(remaining * scale, ElScrollDeltaSource.fling);
        if (!activity.motionOwner.isCurrent) return;
        remaining -= consumed * scale;
        remaining = _applyBody(activity, remaining, legalOnly: route != null);
        if (!activity.motionOwner.isCurrent) return;
        if (remaining.abs() > precisionErrorTolerance) {
          final postAccepted = input.interceptPostScroll(remaining * scale, ElScrollDeltaSource.fling);
          remaining -= postAccepted * scale;
          if (!activity.motionOwner.isCurrent) return;
          if (route != null && remaining.abs() > precisionErrorTolerance) {
            remaining = _applyBody(activity, remaining);
          }
          if (remaining.abs() > precisionErrorTolerance) {
            position.didOverscrollBy(-remaining * scale);
            _finish(cancelled: false);
          }
        }
      }
      if (!identical(activity, _activity)) return;
      activity.expectedPosition = _metrics(position, recoveringBody: activity.recoveringBody).pixels;
      // 消费预算不保证产生几何位移；按真实增量续接，避免标量先撞上正文尚未到达的边界。
      if (!activity.recoveringBody &&
          (activity.expectedPosition - metrics.pixels - delta).abs() >
              math.max(precisionErrorTolerance, metrics.pixels.abs() * 1e-12)) {
        activity.needsRebase = true;
      }
      if (done && !activity.needsRebase && !activity.refreshPhysicsChanged) _finish(cancelled: false);
    } finally {
      transaction.close();
    }
  }

  double _applyBody(_CoordinatedBallisticActivity activity, double delta, {bool legalOnly = false}) {
    if (delta.abs() <= precisionErrorTolerance) return 0;
    final position = activity.position;
    final scale = axisDirectionIsReversed(position.axisDirection) ? -1.0 : 1.0;
    if (legalOnly && !position.outOfRange) {
      final offset = _contentOffset(position);
      final range = position.maxScrollExtent - position.minScrollExtent;
      final accepted = delta.clamp(-offset, range - offset);
      position.setPixelsOwned(activity.motionOwner, position.pixels + accepted * scale);
      return delta - accepted;
    }
    final candidate = position.pixels + delta * scale;
    final overscroll = position.physics.applyBoundaryConditions(position, candidate);
    position.setPixelsOwned(activity.motionOwner, candidate - overscroll);
    return overscroll * scale;
  }

  void dispose() {
    _finish(cancelled: true);
    _position?.ballisticHandler = null;
    _position = null;
    _tracks = const [];
  }
}

/// 有限坐标轴的纯数值反射，不在查询中修改实际 position 或消费预算。
final class _ReflectedScrollSimulation extends Simulation {
  _ReflectedScrollSimulation(this.inner, this.minimum, this.maximum) : super(tolerance: inner.tolerance);
  final Simulation inner;
  final double minimum;
  final double maximum;
  @override
  double x(double time) => minimum + (maximum - inner.x(time));
  @override
  double dx(double time) => -inner.dx(time);
  @override
  bool isDone(double time) => inner.isDone(time);
}

/// 仅校准续接样条的时间尺度，查询仍是无业务副作用的纯计算。
final class _VelocityContinuousSimulation extends Simulation {
  _VelocityContinuousSimulation(this.inner, this.timeScale) : super(tolerance: inner.tolerance);
  final Simulation inner;
  final double timeScale;
  @override
  double x(double time) => inner.x(time * timeScale);
  @override
  double dx(double time) => inner.dx(time * timeScale) * timeScale;
  @override
  bool isDone(double time) => inner.isDone(time * timeScale);
}

final class _CoordinatedBallisticActivity extends ScrollActivity implements ScrollCoordinatedActivity {
  _CoordinatedBallisticActivity(
    this.coordinator,
    this.position,
    this.motionOwner,
    this.simulation,
    ScrollMetrics metrics, {
    required this._ignorePointer,
    required this.sessionId,
  }) : minimum = metrics.minScrollExtent,
       range = metrics.maxScrollExtent,
       expectedPosition = metrics.pixels,
       recoveringBody = position.outOfRange,
       resumeAfterBoundary =
           position.outOfRange &&
           _startsWithFriction(simulation) &&
           (metrics.pixels < metrics.minScrollExtent && simulation.dx(0) > 0 ||
               metrics.pixels > metrics.maxScrollExtent && simulation.dx(0) < 0),
       lastSimulationValue = simulation.x(0),
       sampleVelocity = simulation.dx(0),
       super(position) {
    _captureRefreshPhysics();
    _ticker = position.context.vsync.createTicker(
      (_) => coordinator.tick(this, SchedulerBinding.instance.currentSystemFrameTimeStamp),
    );
  }
  final _ScrollMotionCoordinator coordinator;
  final ScrollEnginePosition position;
  @override
  final ScrollMotionOwner motionOwner;
  final int? sessionId;
  final bool _ignorePointer;
  late final Ticker _ticker;
  Simulation simulation;
  double minimum;
  double range;
  double expectedPosition;
  double lastSimulationValue;
  double sampleVelocity;
  Duration? startStamp;
  Duration? lastStamp;
  bool needsRebase = false;
  bool recoveringBody;
  bool resumeAfterBoundary;
  RefreshScrollLink? _refreshLink;
  double _dockMin = 0;
  double _dockMax = 0;
  bool _finishDocking = false;
  ElRefreshEdge? _refreshEdge;
  SpringDescription? _refreshSpring;

  bool get refreshPhysicsChanged {
    final link = coordinator._refresh;
    if (!identical(link, _refreshLink)) return true;
    if (link == null) return false;
    final spring = link.refreshSpring;
    return link.dockMinExtension != _dockMin ||
        link.dockMaxExtension != _dockMax ||
        link.finishBallisticDocking != _finishDocking ||
        link.refreshEdge != _refreshEdge ||
        spring?.mass != _refreshSpring?.mass ||
        spring?.stiffness != _refreshSpring?.stiffness ||
        spring?.damping != _refreshSpring?.damping;
  }

  void _captureRefreshPhysics() {
    final link = _refreshLink = coordinator._refresh;
    _dockMin = link?.dockMinExtension ?? 0;
    _dockMax = link?.dockMaxExtension ?? 0;
    _finishDocking = link?.finishBallisticDocking ?? false;
    _refreshEdge = link?.refreshEdge;
    _refreshSpring = link?.refreshSpring;
  }

  void start() => _ticker.start();
  void stop() {
    if (_ticker.isActive) _ticker.stop();
  }

  void rebase(Simulation value, ScrollMetrics metrics) {
    simulation = value;
    // 刷新完成等原因改用停靠弹簧后，不再把送回位移交给效果。
    resumeAfterBoundary = resumeAfterBoundary && _startsWithFriction(value);
    lastSimulationValue = value.x(0);
    startStamp = lastStamp;
    minimum = metrics.minScrollExtent;
    range = metrics.maxScrollExtent;
    expectedPosition = metrics.pixels;
    needsRebase = false;
    _captureRefreshPhysics();
  }

  @override
  ElScrollActivityType get activityType => ElScrollActivityType.ballistic;
  @override
  bool get isScrolling => true;
  @override
  bool get shouldIgnorePointer => _ignorePointer;
  @override
  double get velocity => axisDirectionIsReversed(position.axisDirection) ? -sampleVelocity : sampleVelocity;
  @override
  void didCorrectPixels() => needsRebase = true;
  @override
  void applyNewDimensions() => needsRebase = true;
  @override
  void resetActivity() => needsRebase = true;
  @override
  void dispatchOverscrollNotification(ScrollMetrics metrics, BuildContext context, double overscroll) {
    OverscrollNotification(
      metrics: metrics,
      context: context,
      overscroll: overscroll,
      velocity: velocity,
    ).dispatch(context);
  }

  @override
  void dispose() {
    coordinator._disposedActivity(this);
    _ticker.dispose();
    super.dispose();
  }
}

// 读取实际 simulation 的起始段，普通弹簧即使反穿边界也不能伪装成用户的反向惯性。
bool _startsWithFriction(Simulation simulation) {
  if (simulation is _ReflectedScrollSimulation) return _startsWithFriction(simulation.inner);
  if (simulation is _VelocityContinuousSimulation) return _startsWithFriction(simulation.inner);
  if (simulation is BouncingScrollSimulation) {
    final start = simulation.x(0);
    final epsilon = math.max(precisionErrorTolerance, start.abs() * 1e-12);
    return start >= simulation.leadingExtent - epsilon && start <= simulation.trailingExtent + epsilon;
  }
  return simulation is FrictionSimulation;
}
