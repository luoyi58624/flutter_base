part of '../virtual_pipeline.dart';

/// 一次解析的真实同轴祖先路线；各宿主的输入顺序仍由自身 inputOrder 决定。
final class _ScrollInputRoute implements ScrollInputTransactionMember {
  _ScrollInputRoute(this.source, this.axis, this.ancestors);
  final ElScrollViewState source;
  final Axis axis;
  final List<ElScrollViewState> ancestors;
  List<_NestedRegionParent> _regions = const [];
  Set<NestedScrollNode>? _inputRegions;
  bool _inputStarted = false;
  bool _inputEnded = false;
  final Map<ScrollEnginePosition, ScrollMotionOwner> _owners = Map.identity();
  final Map<ScrollEnginePosition, Drag> _drags = Map.identity();
  ScrollInputTransaction? _transaction;
  int? _sessionId;
  _ScrollSession? _settlingLifecycle;
  _ScrollSession? _lifecycleSession;
  List<({ElScrollViewState host, RefreshScrollLink link})>? _refreshCandidates;
  RefreshScrollLink? _refreshOwner;
  bool _refreshReleased = false;
  void Function(int? sessionId)? _onInputCancelled;
  bool _active = false;
  bool _ballistic = false;
  bool _retired = false;
  bool _initialized = false;

  /// 是否仍持有进行中的触摸、触控板或惯性；忙时不得回收本路线。
  bool get isBusy => _active || _settlingLifecycle != null;

  /// 被动需求消失后置位：只登记待回收，等本路线自然到达终态再摘除，
  /// 绝不因为观察者增减而中途取消正在进行的手势。
  bool retireWhenIdle = false;
  int? _preTransaction;
  int? _postTransaction;
  double? _initialBodyPixels;
  bool _bodyConsumedInput = false;

  ScrollEnginePosition get position => source.positionFor(axis)! as ScrollEnginePosition;
  ScrollMotionOwner? get sourceOwner => _owners[source.positionFor(axis)];
  // 任一 position 退役会同步取消整组；每次真实写入仍单独校验其令牌。
  bool get isCurrent => _active && !_retired;
  bool get hasInputRange => ancestors.any((host) {
    final target = host.positionFor(axis);
    return (axis == host._layoutAxis && host._refreshLink != null) ||
        (host._inputRouter?.hasMotionInputRange(axis) ?? false) ||
        (target != null &&
            target.hasContentDimensions &&
            target.physics.shouldAcceptUserOffset(target) &&
            target.maxScrollExtent > target.minScrollExtent);
  });

  void updateRegions(List<_NestedRegionParent> regions) {
    if (!listEquals(_regions, regions)) _regions = List.unmodifiable(regions);
  }

  bool containsRegion(NestedScrollNode node, int? sessionId) {
    return isCurrent && _sessionId == sessionId && !node.detached && (_inputRegions?.contains(node) ?? false);
  }

  void _start(
    int? sessionId, {
    void Function(int? sessionId)? onInputCancelled,
    ElScrollUpdateCause cause = ElScrollUpdateCause.userInput,
  }) {
    finish(cancelled: true);
    _owners.clear();
    _initialized = true;
    _sessionId = sessionId;
    _onInputCancelled = onInputCancelled;
    _inputRegions = null;
    for (final parent in _regions) {
      final node = parent.owner._nestedNode;
      if (node != null && !node.detached && node.axis == axis) {
        (_inputRegions ??= Set.identity()).add(node);
      }
    }
    _inputStarted = false;
    _inputEnded = false;
    _retired = false;
    _active = true;
    _refreshCandidates = null;
    _refreshOwner = null;
    _refreshReleased = false;
    _initialBodyPixels = position.hasPixels ? position.pixels : null;
    _bodyConsumedInput = false;
    for (final host in [source, ...ancestors]) {
      if (axis == host._layoutAxis && host._refreshLink != null) {
        (_refreshCandidates ??= []).add((host: host, link: host._refreshLink!));
      }
      final target = host.positionFor(axis);
      if (target is! ScrollEnginePosition || !host._mixinCallbacksActive) {
        finish(cancelled: true);
        return;
      }
      final owner = target.claimMotion(cause: cause, onCancelled: _cancel, sessionId: sessionId);
      _owners[target] = owner;
      if (!_active || !target.startOwnedActivity(owner, _RouteHoldActivity(target, owner))) {
        finish(cancelled: true);
        return;
      }
    }
    if (isCurrent) {
      final lifecycle = _ScrollSession(this, ScrollInputTransaction.current);
      _lifecycleSession = lifecycle;
      lifecycle.begin();
    }
  }

  void join(ScrollInputTransaction transaction) {
    if (identical(_transaction, transaction)) return;
    transaction.establishOrigin(source);
    final startsInput =
        transaction.source != ElScrollInputSource.ballistic &&
        (_sessionId != transaction.sessionId || (!_active && transaction.sessionId == null) || !_initialized);
    _transaction = transaction;
    transaction.join(this);
    source._inputRouter?._joinTransaction(transaction);
    for (final ancestor in ancestors) {
      ancestor._inputRouter?._joinTransaction(transaction);
    }
    if (startsInput) _start(transaction.sessionId, onInputCancelled: transaction.onInputCancelled);
    _lifecycleSession?.observeSample(transaction);
    for (final entry in _owners.entries) {
      transaction.bindWriter(entry.key, entry.value);
    }
    _beginNestedInput();
  }

  void _beginNestedInput() {
    final session = _sessionId;
    if (_inputStarted || session == null || !isCurrent) return;
    _inputStarted = true;
    if (_inputRegions == null) return;
    final snapshots = <ElScrollViewState, ElScrollInputDetails>{};
    for (final ancestor in ancestors.reversed) {
      for (final participant in ancestor._inputRouter?._participants[axis] ?? const <_InputParticipant>[]) {
        if (!isCurrent) return;
        final client = participant.client;
        if (client is! ElNestedScrollMixin) continue;
        final node = client._nestedNode;
        if (node == null || !containsRegion(node, session)) continue;
        final details = snapshots[ancestor] ??= client._nestedInputDetails(0, ElScrollDeltaSource.touchDrag)!;
        client._nestedStart(session, details);
      }
    }
  }

  static void _endNestedRegions(Set<NestedScrollNode>? regions, int? session) {
    if (regions == null || session == null) return;
    for (final node in regions) {
      if (node.parent case final _NestedRegionParent parent) parent.owner._nestedEnd(session);
    }
  }

  @override
  void finishInputTransaction() {
    final transaction = _transaction!;
    _transaction = null;
    final event = transaction.rawEvent;
    final endsInput = event is PointerUpEvent || event is PointerCancelEvent || event is PointerPanZoomEndEvent;
    if (endsInput) endInput();
    if (!_ballistic &&
        (event is PointerUpEvent ||
            event is PointerCancelEvent ||
            event is PointerPanZoomEndEvent ||
            transaction.sessionId == null)) {
      finish(cancelled: event is PointerCancelEvent);
    }
  }

  void _cancel() => finish(cancelled: true);

  void endInput() {
    if (_inputEnded) return;
    _inputEnded = true;
    _onInputCancelled = null;
    try {
      if (!_refreshReleased) _releaseRefresh(0);
      _lifecycleSession?.endInput();
    } finally {
      _endNestedRegions(_inputRegions, _sessionId);
    }
  }

  void finish({required bool cancelled}) {
    if (!_active) {
      if (cancelled) _settlingLifecycle?.cancelSettling();
      return;
    }
    _active = false;
    _retired = true;
    _ballistic = false;
    final lifecycle = _lifecycleSession;
    _lifecycleSession = null;
    final refresh = !_inputEnded ? _activeRefresh : null;
    final owners = _owners.entries.toList(growable: false);
    _owners.clear();
    _drags.clear();
    final regions = _inputEnded ? null : _inputRegions;
    final session = _sessionId;
    final onInputCancelled = cancelled && !_inputEnded ? _onInputCancelled : null;
    _onInputCancelled = null;
    _inputRegions = null;
    _inputEnded = true;
    // 先整组失效，释放任一 position 时的同步通知不能再次推进剩余成员。
    onInputCancelled?.call(session);
    if (cancelled) refresh?.cancelCoordinatedInput();
    void releaseOwners(bool wasCancelled) {
      _settlingLifecycle = null;
      for (final entry in owners) {
        if (wasCancelled) {
          entry.key.cancelMotion(entry.value);
        } else {
          entry.key.completeMotion(entry.value);
        }
      }
    }

    if (cancelled || lifecycle == null) releaseOwners(cancelled);
    try {
      _endNestedRegions(regions, session);
    } finally {
      if (lifecycle != null) {
        final retired = cancelled || owners.any((entry) => !entry.value.isCurrent);
        _settlingLifecycle = lifecycle;
        lifecycle.finish(cancelled: retired, beforeTerminal: cancelled ? null : releaseOwners);
        // 正文停止产出位移，令牌保留到效果收尾；新输入或任意 raw 命令仍走原所有权取消。
        if (lifecycle._settling) {
          for (final entry in owners) {
            if (!entry.key.startOwnedActivity(entry.value, _RouteHoldActivity(entry.key, entry.value))) {
              lifecycle.cancelSettling();
              break;
            }
          }
        }
        if (!lifecycle._settling) _settlingLifecycle = null;
      }
    }
    _scheduleRetireIfIdle();
  }

  void _onLifecycleTerminated() => _scheduleRetireIfIdle();

  // 需求已消失且本路线到达终态时，在下一个微任务里通知宿主摘除自己。
  // 用微任务延迟是为了让同步紧跟的惯性重开（_start 会先 finish）先复活路线。
  void _scheduleRetireIfIdle() {
    if (!retireWhenIdle || isBusy) return;
    final host = source;
    final routeAxis = axis;
    scheduleMicrotask(() {
      if (!retireWhenIdle || isBusy) return;
      if (host._needsLocalInputRoute(routeAxis)) {
        retireWhenIdle = false;
        return;
      }
      host._dropInputRoute(routeAxis, this);
      host._syncMixinInputInterceptors();
    });
  }

  ScrollMotionOwner? beginBallistic() {
    if (!_active) {
      final transaction = ScrollInputTransaction.current;
      // 旧设备尾段不能复活；没有旧输入事务的程序化回位则是新的运动组。
      if (_initialized && transaction?.sessionId != null && transaction!.sessionId == _sessionId) return null;
      _start(null, cause: ElScrollUpdateCause.ballistic);
    }
    if (!isCurrent) return null;
    _ballistic = true;
    for (final entry in _owners.entries) {
      entry.key.setMotionCause(entry.value, ElScrollUpdateCause.ballistic);
    }
    return sourceOwner;
  }

  void installBallisticMembers({required bool ignorePointer}) {
    for (final entry in _owners.entries.toList(growable: false)) {
      if (!identical(entry.key, position) && isCurrent) {
        entry.key.startOwnedActivity(entry.value, _RouteBallisticActivity(this, entry.key, entry.value, ignorePointer));
      }
    }
    _drags.clear();
  }

  double _normalized(double delta, ElScrollDeltaSource kind) =>
      delta * _ScrollInputRouter._inputScale(kind, position.axisDirection);
  double _local(double normalized, ElScrollDeltaSource kind, ScrollPosition target) =>
      normalized / _ScrollInputRouter._inputScale(kind, target.axisDirection);

  RefreshScrollLink? get _activeRefresh {
    if (_refreshOwner?.hasActivePull ?? false) return _refreshOwner;
    for (final candidate in _refreshCandidates ?? const <({ElScrollViewState host, RefreshScrollLink link})>[]) {
      if (candidate.host._mixinCallbacksActive &&
          identical(candidate.host._refreshLink, candidate.link) &&
          candidate.link.hasActivePull) {
        return _refreshOwner = candidate.link;
      }
    }
    return null;
  }

  double _releaseRefresh(double velocity) {
    _refreshReleased = true;
    final refresh = _activeRefresh ?? (axis == source._layoutAxis ? source._refreshLink : null);
    return refresh?.releaseInput(velocity) ?? velocity;
  }

  double pre(double delta, ElScrollDeltaSource kind) {
    final transaction = ScrollInputTransaction.current!;
    join(transaction);
    if (!isCurrent || _preTransaction == transaction.id) return delta;
    _preTransaction = transaction.id;
    _bodyConsumedInput |= _initialBodyPixels != null && position.pixels != _initialBodyPixels;
    final original = _normalized(delta, kind);
    var remaining = original;
    final refresh = _activeRefresh;
    if (refresh != null) remaining += refresh.consumeActive(-remaining, kind);
    // 内层刷新边已经能消费的触摸行程，不得先让祖先的 pre 阶段抢走。
    final ownRefresh = axis == source._layoutAxis ? source._refreshLink : null;
    final reserved = kind == ElScrollDeltaSource.touchDrag && ancestors.isNotEmpty
        ? -(ownRefresh?.boundaryPullInput(-remaining) ?? 0)
        : 0.0;
    remaining -= reserved;
    for (final ancestor in ancestors.reversed) {
      if (!isCurrent) return delta;
      if (remaining.abs() <= precisionErrorTolerance) break;
      final target = ancestor.positionFor(axis)!;
      remaining -=
          ancestor._dispatchMixinPreScroll(
            axis,
            _local(remaining, kind, target),
            kind,
            requestedDelta: _local(original, kind, target),
          ) *
          _ScrollInputRouter._inputScale(kind, target.axisDirection);
    }
    return isCurrent ? _local(original - remaining - reserved, kind, position) : delta;
  }

  void _applyTouchDelta(ScrollEnginePosition target, double delta) {
    final transaction = ScrollInputTransaction.current!;
    final owner = _owners[target]!;
    final raw = transaction.rawEvent;
    final global = raw?.position ?? Offset.zero;
    var drag = _drags[target];
    if (drag == null) {
      Drag? created;
      created = target.dragOwned(
        owner,
        DragStartDetails(sourceTimeStamp: transaction.timeStamp, globalPosition: global, kind: raw?.kind),
        () {
          if (created != null && identical(_drags[target], created)) _drags.remove(target);
        },
      );
      drag = created;
      if (owner.isCurrent && isCurrent) _drags[target] = drag;
    }
    drag.update(
      DragUpdateDetails(
        sourceTimeStamp: transaction.timeStamp,
        globalPosition: global,
        delta: axis == Axis.vertical ? Offset(0, delta) : Offset(delta, 0),
        primaryDelta: delta,
        kind: raw?.kind,
      ),
    );
  }

  double post(double delta, ElScrollDeltaSource kind) {
    final transaction = ScrollInputTransaction.current!;
    join(transaction);
    if (!isCurrent || _postTransaction == transaction.id) return delta;
    _postTransaction = transaction.id;
    final original = _normalized(delta, kind);
    var remaining = original;
    _bodyConsumedInput |= _initialBodyPixels != null && position.pixels != _initialBodyPixels;
    // 源视口先处理自己的刷新边界，外层正文只接未被内层刷新接收的余量。
    if (axis == source._layoutAxis) {
      final link = source._refreshLink;
      // 内容让位式刷新由源 Drag 写入真实位置，不能把该行程继续交给祖先。
      if (kind == ElScrollDeltaSource.touchDrag &&
          link != null &&
          link.movesContent &&
          link.boundaryPullInput(-remaining) != 0) {
        return 0;
      }
      final accepted = link?.consumeBoundaryPull(-remaining, kind) ?? 0;
      if (accepted != 0) {
        _refreshOwner = link;
        remaining += accepted;
      }
    }
    for (final ancestor in ancestors) {
      if (!isCurrent) return delta;
      if (remaining.abs() <= precisionErrorTolerance) break;
      // 普通嵌套仍保持同一手势的正文锁；刷新不能授权途中撞界后改推祖先。
      if (!_canMoveAncestor(ancestor)) continue;
      final target = ancestor.positionFor(axis)! as ScrollEnginePosition;
      final owner = _owners[target]!;
      final acceptsBodyInput = target.physics.shouldAcceptUserOffset(target);
      if (acceptsBodyInput && kind == ElScrollDeltaSource.touchDrag) {
        final step = ScrollInputStep.resolve(target, target.physics, -remaining, clampToRange: true);
        if (step.acceptedInput.abs() > precisionErrorTolerance) {
          _applyTouchDelta(target, step.acceptedInput);
          remaining += step.acceptedInput;
        }
      } else if (acceptsBodyInput && kind != ElScrollDeltaSource.pointerScroll) {
        // 滚轮的正文接收者由 500ms 输入锁决定；效果分账不能绕锁推动祖先正文。
        final direction = axisDirectionIsReversed(target.axisDirection) ? -1.0 : 1.0;
        final offset = direction > 0 ? target.pixels - target.minScrollExtent : target.maxScrollExtent - target.pixels;
        final range = target.maxScrollExtent - target.minScrollExtent;
        final accepted = remaining.clamp(-math.max(0, offset), math.max(0, range - offset));
        if (accepted != 0) {
          target.setPixelsOwned(owner, target.pixels + accepted * direction);
          remaining -= accepted;
        }
      }
      if (!isCurrent) return delta;
      remaining -=
          ancestor._dispatchMixinPostScroll(axis, _local(remaining, kind, target), kind) *
          _ScrollInputRouter._inputScale(kind, target.axisDirection);
      // 每层正文及自己的效果处理后，先尝试该层刷新，再交给更外层。
      final link = axis == ancestor._layoutAxis ? ancestor._refreshLink : null;
      if (kind == ElScrollDeltaSource.touchDrag && link != null && isCurrent) {
        final pull = link.boundaryPullInput(-remaining);
        if (pull != 0) {
          _refreshOwner = link;
          if (link.movesContent) {
            _applyTouchDelta(target, pull);
            remaining += pull;
          } else {
            remaining += link.consumeBoundaryPull(-remaining, kind);
          }
        }
      }
    }
    return isCurrent ? _local(original - remaining, kind, position) : delta;
  }

  double preFling(double velocity) {
    _bodyConsumedInput |= _initialBodyPixels != null && position.pixels != _initialBodyPixels;
    _lifecycleSession?.releaseVelocity = -velocity;
    var remaining = _releaseRefresh(velocity);
    for (final ancestor in ancestors.reversed) {
      if (!isCurrent) return 0;
      remaining = ancestor._dispatchMixinPreFling(axis, remaining, requestedVelocity: velocity);
    }
    return remaining;
  }

  bool _canMoveAncestor(ElScrollViewState ancestor) =>
      !_bodyConsumedInput || (ancestor._inputRouter?.hasParticipants(axis) ?? false);

  double get contentPosition => ancestors.fold(0.0, (sum, host) {
    if (!_canMoveAncestor(host)) return sum;
    final target = host.positionFor(axis)!;
    if (!target.physics.shouldAcceptUserOffset(target)) return sum;
    return sum +
        (axisDirectionIsReversed(target.axisDirection)
            ? target.maxScrollExtent - target.pixels
            : target.pixels - target.minScrollExtent);
  });
  double get contentRange => ancestors.fold(0.0, (sum, host) {
    if (!_canMoveAncestor(host)) return sum;
    final target = host.positionFor(axis)!;
    if (!target.physics.shouldAcceptUserOffset(target)) return sum;
    return sum + math.max(0, target.maxScrollExtent - target.minScrollExtent);
  });
  double get effectPosition => ancestors.fold<double>(
    0.0,
    (sum, host) =>
        sum +
        (host._inputRouter
                ?.tracksFor(axis)
                .fold<double>(
                  0.0,
                  (value, binding) =>
                      value + (binding.track.value - binding.track.minValue) * binding.track.pixelsPerUnit,
                ) ??
            0),
  );
  double get effectRange => ancestors.fold<double>(
    0.0,
    (sum, host) =>
        sum +
        (host._inputRouter
                ?.tracksFor(axis)
                .fold<double>(
                  0.0,
                  (value, binding) =>
                      value + (binding.track.maxValue - binding.track.minValue) * binding.track.pixelsPerUnit,
                ) ??
            0),
  );
}

final class _RouteHoldActivity extends ScrollActivity implements ScrollCoordinatedActivity {
  _RouteHoldActivity(super.delegate, this.motionOwner);
  @override
  final ScrollMotionOwner motionOwner;
  @override
  ElScrollActivityType get activityType => ElScrollActivityType.hold;
  @override
  bool get isScrolling => false;
  @override
  bool get shouldIgnorePointer => false;
  @override
  double get velocity => 0;
  @override
  void didCorrectPixels() {}
}

final class _RouteBallisticActivity extends ScrollActivity implements ScrollCoordinatedActivity {
  _RouteBallisticActivity(this.route, super.delegate, this.motionOwner, this._ignorePointer);
  final bool _ignorePointer;
  final _ScrollInputRoute route;
  @override
  final ScrollMotionOwner motionOwner;
  @override
  ElScrollActivityType get activityType => ElScrollActivityType.ballistic;
  @override
  bool get isScrolling => true;
  @override
  bool get shouldIgnorePointer => _ignorePointer;
  @override
  double get velocity => 0;
  @override
  void didCorrectPixels() => _rebase();
  @override
  void applyNewDimensions() => _rebase();
  void _rebase() {
    if (motionOwner.isCurrent) route.source._motionCoordinatorFor(route.axis)?._activity?.needsRebase = true;
  }
}
