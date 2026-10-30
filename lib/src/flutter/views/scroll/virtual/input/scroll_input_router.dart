part of '../virtual_pipeline.dart';

typedef _InputParticipant = ({_ScrollMixinClient client, _ScrollMixinClientRegistration registration});

/// 每轴稳定的输入参与序列，只在配置提交时解析，不在滚动 tick 排序。
final class _ScrollInputRouter implements ScrollInputTransactionMember {
  _ScrollInputRouter(this.host);

  final ElScrollViewState host;
  Map<Axis, List<Object>> _order = const {};
  Map<Axis, List<_InputParticipant>> _participants = const {};
  Map<Axis, List<_EffectTrackBinding>> _tracks = const {};
  Map<Axis, double> _inputRanges = const {};
  final Map<Axis, ElScrollInputDetails> _inputs = {};
  ScrollInputTransaction? _transaction;
  Set<_ScrollMixinClient>? _pendingUpdates;
  Set<(_ScrollMixinClient, String)>? _reportedInvalid;
  Object? _configurationError;
  bool _dirty = false;
  bool _commitScheduled = false;
  bool _flushingUpdates = false;
  bool _flushScheduled = false;
  int _dispatchDepth = 0;
  int resolveCount = 0;
  List<({Object slot, String phase, double input, double remaining})>? trace;

  bool hasParticipants(Axis axis) => _participants[axis]?.isNotEmpty ?? false;
  bool get hasTracks => _tracks.isNotEmpty;
  List<_EffectTrackBinding> tracksFor(Axis axis) => _tracks[axis] ?? const [];
  bool hasMotionInputRange(Axis axis) => (_inputRanges[axis] ?? 0) > precisionErrorTolerance;

  // 滚轮命中只预测效果自身的余量；祖先正文不能冒充内层的可消费范围。
  bool canConsumePointerInput(Axis axis, double contentDelta) {
    for (final participant in _participants[axis] ?? const <_InputParticipant>[]) {
      if (!_isLive(participant)) continue;
      var hasInputTrack = false;
      for (final track in participant.registration.effectTracks) {
        if (track.pixelsPerUnit <= 0) continue;
        hasInputTrack = true;
        if (contentDelta > 0 ? track.value < track.maxValue : track.value > track.minValue) return true;
      }
      // 未声明有限行程的自定义 slot 仍由实际回调裁决，不预执行有副作用的钩子。
      if (!hasInputTrack) return true;
    }
    return false;
  }

  void setOrder(Map<Axis, List<Object>> value) {
    if (_order.length == value.length && value.entries.every((entry) => listEquals(_order[entry.key], entry.value))) {
      return;
    }
    final next = <Axis, List<Object>>{};
    for (final entry in value.entries) {
      if (entry.value.toSet().length != entry.value.length) {
        throw FlutterError('inputOrder 的 ${entry.key} 包含重复 slot。');
      }
      next[entry.key] = List<Object>.unmodifiable(entry.value);
    }
    _order = Map.unmodifiable(next);
    invalidate();
  }

  bool deferUpdate(_ScrollMixinClient client) {
    if (_dispatchDepth == 0 && _transaction == null) return false;
    (_pendingUpdates ??= LinkedHashSet<_ScrollMixinClient>.identity()).add(client);
    return true;
  }

  void invalidate() {
    _dirty = true;
    if (_dispatchDepth != 0 || _transaction != null || _flushingUpdates || _flushScheduled) return;
    // 同一次 Widget build 内允许多个 State 一起换轴或交换 slot，完整收集后再校验。
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (_commitScheduled) return;
      _commitScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _commitScheduled = false;
        if (host.mounted && identical(host._inputRouter, this)) _commit();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    } else {
      _commit();
    }
  }

  void _commit() {
    if (!_dirty || _dispatchDepth != 0 || _transaction != null || _flushingUpdates) return;
    _dirty = false;
    try {
      final groups = <Axis, Map<Object, _InputParticipant>>{};
      final trackGroups = <Axis, List<_EffectTrackBinding>>{};
      final ranges = <Axis, double>{};
      final clients = host._mixinClients;
      if (clients != null) {
        for (final entry in clients.entries) {
          final registration = entry.value;
          if (!entry.key.mountedForScrollCallbacks) continue;
          for (final track in registration.effectTracks) {
            (trackGroups[registration.axis] ??= []).add((client: entry.key, registration: registration, track: track));
            final range = (track.maxValue - track.minValue) * track.pixelsPerUnit;
            ranges[registration.axis] = (ranges[registration.axis] ?? 0) + range;
          }
          final slot = registration.scrollInputSlot;
          if (slot == null || !entry.key.mountedForScrollCallbacks) continue;
          final group = groups.putIfAbsent(registration.axis, () => {});
          if (group.containsKey(slot)) {
            throw FlutterError(
              '${registration.axis} 不能登记重复 input slot：$slot；'
              '${group[slot]!.client.runtimeType} 与 ${entry.key.runtimeType} 应使用不同 slot 并配置 inputOrder。',
            );
          }
          group[slot] = (client: entry.key, registration: registration);
        }
      }
      final resolved = <Axis, List<_InputParticipant>>{};
      for (final entry in groups.entries) {
        final order = _order[entry.key];
        if (order == null) {
          if (entry.value.length > 1) throw FlutterError('同一轴多个 input slot 必须通过 inputOrder 显式列出消费顺序。');
          resolved[entry.key] = List.unmodifiable(entry.value.values);
        } else {
          for (final slot in entry.value.keys) {
            if (!order.contains(slot)) throw FlutterError('inputOrder 的 ${entry.key} 遗漏已登记 slot：$slot。');
          }
          resolved[entry.key] = List.unmodifiable([for (final slot in order) ?entry.value[slot]]);
        }
      }
      if (ranges.values.any((range) => !range.isFinite)) throw FlutterError('同一轴的效果总输入行程必须有限。');
      final membershipChanged = Axis.values.any((axis) {
        final previous = _participants[axis] ?? const <_InputParticipant>[];
        final next = resolved[axis] ?? const <_InputParticipant>[];
        if (previous.length != next.length) return true;
        for (var index = 0; index < next.length; index++) {
          if (!identical(previous[index].client, next[index].client)) return true;
        }
        return false;
      });
      _participants = resolved;
      _tracks = trackGroups;
      _inputRanges = ranges;
      _configurationError = null;
      resolveCount++;
      if (membershipChanged) host._scopeElement?.inputChanged();
      if (resolved.isEmpty &&
          trackGroups.isEmpty &&
          _order.isEmpty &&
          !(host._mixinClients?.values.any((entry) => entry.wantsScrollSessions) ?? false) &&
          identical(host._inputRouter, this)) {
        host._inputRouter = null;
      }
      assert(() {
        _reportedInvalid?.removeWhere((entry) => !(host._mixinClients?.containsKey(entry.$1) ?? false));
        return true;
      }());
    } catch (error) {
      _configurationError = error;
      rethrow;
    } finally {
      host._syncMixinInputInterceptors();
    }
  }

  bool _isLive(_InputParticipant participant) =>
      host._mixinCallbacksActive &&
      participant.client.mountedForScrollCallbacks &&
      identical(host._mixinClients?[participant.client], participant.registration);

  double _validate(_InputParticipant participant, String phase, double input, double remaining) {
    if (_ScrollMixinInputLink._isValidRemaining(input, remaining)) {
      _trace(participant, phase, input, remaining);
      return remaining;
    }
    assert(() {
      final reported = _reportedInvalid ??= {};
      if (reported.add((participant.client, phase))) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: FlutterError(
              '${participant.registration.scrollInputSlot}.$phase 必须返回有限、同号且不放大的剩余量；输入 $input，返回 $remaining。',
            ),
          ),
        );
      }
      return true;
    }());
    _trace(participant, phase, input, input);
    return input;
  }

  void _trace(_InputParticipant participant, String phase, double input, double remaining) {
    final records = trace;
    if (records == null || records.length >= 2048) return;
    records.add((slot: participant.registration.scrollInputSlot!, phase: phase, input: input, remaining: remaining));
  }

  void _finishDispatch() {
    _dispatchDepth--;
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (_dispatchDepth != 0 || _transaction != null || _flushScheduled || (_pendingUpdates == null && !_dirty)) return;
    _flushScheduled = true;
    // 一个设备事件内的 pre/content/post 共用已提交配置，退出整个调用栈后才换代。
    // 即使业务回调抛错，也先恢复分派状态，配置提交不能覆盖原始异常。
    scheduleMicrotask(() {
      _flushScheduled = false;
      if (!host.mounted || !identical(host._inputRouter, this)) return;
      _flushUpdates();
    });
  }

  void _joinTransaction(ScrollInputTransaction transaction) {
    if (identical(_transaction, transaction)) return;
    assert(_transaction == null);
    // 连续同步输入也必须从下一事务使用新配置，不能依赖 microtask 已经获得执行机会。
    _flushScheduled = false;
    _flushUpdates();
    _transaction = transaction;
    transaction.join(this);
  }

  @override
  void finishInputTransaction() {
    _transaction = null;
    _inputs.clear();
    _scheduleFlush();
  }

  void _flushUpdates() {
    final pending = _pendingUpdates;
    _pendingUpdates = null;
    if (pending != null) {
      _flushingUpdates = true;
      try {
        for (final client in pending) {
          if (client.mountedForScrollCallbacks && (host._mixinClients?.containsKey(client) ?? false)) {
            host._updateMixinClient(client);
          }
        }
      } finally {
        _flushingUpdates = false;
      }
    }
    if (_dirty) invalidate();
  }

  double dispatch(Axis axis, double delta, ElScrollDeltaSource source, {required bool post, double? requestedDelta}) {
    final ownTransaction = ScrollInputTransaction.current == null
        ? ScrollInputTransaction.begin(source: _legacySource(source))
        : null;
    try {
      _joinTransaction(ScrollInputTransaction.current!);
      return _dispatch(axis, delta, source, post: post, requestedDelta: requestedDelta);
    } finally {
      ownTransaction?.close();
    }
  }

  double _dispatch(Axis axis, double delta, ElScrollDeltaSource source, {required bool post, double? requestedDelta}) {
    if (!host._mixinCallbacksActive) return 0;
    if (_configurationError case final error?) throw error;
    if (_dispatchDepth != 0) throw FlutterError('滚动输入事务不得同步重入。');
    final participants = _participants[axis];
    if (participants == null || participants.isEmpty) return 0;
    final position = host.positionFor(axis);
    if (position == null) return 0;
    final scale = _inputScale(source, position.axisDirection);
    final transaction = _transaction!;
    var input = _inputs[axis];
    if (input == null) {
      final snapshot = host._readMixinSnapshotFor(axis);
      input = _inputs[axis] = ElScrollInputDetails(
        scrollView: host,
        sourceScrollView: transaction.origin is ElScrollViewState ? transaction.origin! as ElScrollViewState : host,
        axis: axis,
        axisDirection: position.axisDirection,
        source: transaction.source,
        sessionId: transaction.sessionId,
        transactionId: transaction.id,
        sampleId: host._takeMixinSampleId(axis),
        timeStamp: transaction.timeStamp,
        rawEvent: transaction.rawEvent,
        rawDelta: requestedDelta ?? delta,
        requestedDelta: (requestedDelta ?? delta) * scale,
        snapshot: snapshot,
      );
    }
    final normalized = delta * scale;
    var remaining = normalized;
    _dispatchDepth++;
    try {
      for (
        var index = post ? participants.length - 1 : 0;
        index >= 0 && index < participants.length;
        index += post ? -1 : 1
      ) {
        if (remaining.abs() <= precisionErrorTolerance) break;
        final participant = participants[index];
        if (!_isLive(participant)) continue;
        final next = post
            ? participant.client.handlePostScroll(input, remaining)
            : participant.client.handlePreScroll(input, remaining);
        remaining = _validate(participant, post ? 'onPostScroll' : 'onPreScroll', remaining, next);
      }
    } finally {
      _finishDispatch();
    }
    return (normalized - remaining) / scale;
  }

  double fling(Axis axis, double velocity, {double? requestedVelocity}) {
    final ownTransaction = ScrollInputTransaction.current == null
        ? ScrollInputTransaction.begin(source: ElScrollInputSource.unknown)
        : null;
    try {
      _joinTransaction(ScrollInputTransaction.current!);
      return _fling(axis, velocity, requestedVelocity: requestedVelocity ?? velocity);
    } finally {
      ownTransaction?.close();
    }
  }

  double _fling(Axis axis, double velocity, {required double requestedVelocity}) {
    if (!host._mixinCallbacksActive) return velocity;
    if (_configurationError case final error?) throw error;
    if (_dispatchDepth != 0) throw FlutterError('滚动释放事务不得同步重入。');
    final participants = _participants[axis];
    final position = host.positionFor(axis);
    if (participants == null || participants.isEmpty || position == null) return velocity;
    final snapshot = host._readMixinSnapshotFor(axis);
    final details = ElScrollReleaseDetails(
      scrollView: host,
      sourceScrollView: _transaction!.origin is ElScrollViewState ? _transaction!.origin! as ElScrollViewState : host,
      axis: axis,
      axisDirection: position.axisDirection,
      source: _transaction!.source,
      sessionId: _transaction!.sessionId,
      transactionId: _transaction!.id,
      sampleId: host._takeMixinSampleId(axis),
      timeStamp: _transaction!.timeStamp,
      rawEvent: _transaction!.rawEvent,
      rawVelocity: requestedVelocity,
      releaseVelocity: -requestedVelocity,
      snapshot: snapshot,
    );
    var remaining = -velocity;
    _dispatchDepth++;
    try {
      for (final participant in participants) {
        if (!_isLive(participant)) continue;
        remaining = _validate(
          participant,
          'onPreFling',
          remaining,
          participant.client.handlePreFling(details, remaining),
        );
      }
    } finally {
      _finishDispatch();
    }
    return -remaining;
  }

  // 只在保留的低层协议边界换算：拖拽是物理手指位移，pointer 是 pixels，旧 fling 是 -pixels。
  static double _inputScale(ElScrollDeltaSource source, AxisDirection direction) => switch (source) {
    ElScrollDeltaSource.touchDrag => -1,
    ElScrollDeltaSource.pointerScroll => axisDirectionIsReversed(direction) ? -1 : 1,
    ElScrollDeltaSource.fling => axisDirectionIsReversed(direction) ? 1 : -1,
  };

  // 旧直接入口没有原始指针，不能仅凭 touchDrag 枚举推断真实设备。
  static ElScrollInputSource _legacySource(ElScrollDeltaSource source) => switch (source) {
    ElScrollDeltaSource.touchDrag => ElScrollInputSource.unknown,
    ElScrollDeltaSource.pointerScroll => ElScrollInputSource.pointerSignal,
    ElScrollDeltaSource.fling => ElScrollInputSource.ballistic,
  };
}
