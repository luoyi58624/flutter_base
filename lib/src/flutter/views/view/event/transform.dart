part of 'press.dart';

/// 同次拖拽的承接成员与外层竞争边界，不包含宿主、几何或业务事件。
final class DragCooperation {
  /// 冻结参与成员；[cutoff] 团队及更外层不再激活本次主键手势。
  DragCooperation(Iterable<TransformRecognizer> members, {this.cutoff}) : members = List.unmodifiable(members);

  /// 共享本次 Start/End、通过调用方余量管线接收 Update 的祖先成员。
  final List<TransformRecognizer> members;

  /// 第一个不参与合作的外层竞争团队，成员本身始终保留结算资格。
  final GestureTeam? cutoff;
}

/// 在官方竞技场内统一识别拖拽、缩放和旋转。
///
/// 每根指针分别参赛，只有获胜的指针才能驱动正式手势；新增指针落败不会
/// 撤销已经获胜的拖拽；多指策略与速度估计器可独立配置。
/// 缩放、旋转只使用已获胜的触点，减少为单指后保留本轮变换。
///
/// [parent] 负责同类手势冒泡；本类只接收指针数据，不处理元素范围或样式状态。
class TransformRecognizer extends _GestureRecognizer {
  /// 创建独立变换识别器；[axis] 为空时自由拖拽，[lockAxis] 可按起手方向锁轴。
  TransformRecognizer({super.debugOwner, super.supportedDevices, AllowedButtonsFilter? allowedButtonsFilter})
    : super(allowedButtonsFilter: allowedButtonsFilter ?? _primaryTransformButton);

  static bool _primaryTransformButton(int buttons) => buttons == kPrimaryButton;

  /// 开始拖拽的全局移动阈值；为空时采用官方设备与轴向容差。
  double? startDistance;

  /// 水平起手方向的捕获半角，默认 45 度。
  double? horizontalAngle = math.pi / 4;

  /// 产生释放速度的最小移动距离；为空时采用官方设备容差。
  double? minFlingDistance;

  /// 未达到起拖阈值时允许短扫救援的最小距离；为空时沿用正常甩动距离。
  double? preAcceptFlingDistance;

  /// 产生甩动的最小速度。
  double? minFlingVelocity = kMinFlingVelocity;

  /// 释放速度的最大值。
  double? maxFlingVelocity = kMaxFlingVelocity;

  /// 允许纯旋转达到设备跨度阈值后启动缩放通道。
  bool rotationStartEnabled = false;

  /// 普通候选是否允许在 Down 公开 Scale；已起拖或获准让渡的升级不受此项限制。
  bool startScaleOnPointerDown = true;

  /// 多指拖动采用最新触点、位移累加或同帧边界平均。
  MultitouchDragStrategy multitouchDragStrategy = MultitouchDragStrategy.latestPointer;

  /// 为每个物理触点创建速度估计器，合成输入和 Up 不加入拟合。
  GestureVelocityTrackerBuilder velocityTrackerBuilder = _defaultVelocityTrackerBuilder;

  /// 空闲期按显示刷新率划分同帧输入；未提供时使用 16ms。
  double? Function()? displayRefreshRate;

  /// 正式起拖前解析承接名单；拦截提案不会调用，名单在本次会话内冻结。
  DragCooperation? Function(int pointer, Axis? axis)? dragCooperation;

  /// 冻结名单中仍有资格的承接成员，显式传播边界始终优先于合作豁免。
  Iterable<TransformRecognizer> dragCooperationMembers(int pointer) {
    final route = _routes[pointer];
    final owner = route?.owner;
    if (route == null || owner is! TransformRecognizer) return const [];
    return owner._session?.cooperation?.members.where((member) {
          final index = route.members.indexOf(member);
          return !identical(member, owner) &&
              !member._disposed &&
              index >= 0 &&
              index <= (route.cutoffs[_GestureFamily.drag] ?? route.members.length - 1) &&
              !route.subscription(member).phase(_GestureFamily.drag).excluded &&
              member._registeredFor(route, pointer) &&
              member._participates(pointer);
        }) ??
        const [];
  }

  /// 是否接收普通 Update；承接成员只走调用方的统一余量管线。
  bool receivesDragUpdates(int pointer) {
    final route = _routes[pointer];
    final owner = route?.owner;
    return owner is TransformRecognizer &&
        (identical(owner, this) || owner._session?.cooperation?.members.contains(this) != true);
  }

  static VelocityTracker _defaultVelocityTrackerBuilder(PointerEvent event) => VelocityTracker.withKind(event.kind);

  _TransformSettings get _settings {
    final settings = (
      startDistance: startDistance,
      horizontalAngle: horizontalAngle ?? math.pi / 4,
      minFlingDistance: minFlingDistance,
      preAcceptFlingDistance: preAcceptFlingDistance,
      minFlingVelocity: minFlingVelocity ?? kMinFlingVelocity,
      maxFlingVelocity: maxFlingVelocity ?? kMaxFlingVelocity,
      rotationStartEnabled: rotationStartEnabled,
      startScaleOnPointerDown: startScaleOnPointerDown,
      multitouchDragStrategy: multitouchDragStrategy,
      velocityTrackerBuilder: velocityTrackerBuilder,
      displayRefreshRate: displayRefreshRate,
      gestureSettings: gestureSettings,
    );
    assert(settings.startDistance == null || settings.startDistance! >= 0);
    assert(settings.horizontalAngle > 0 && settings.horizontalAngle < math.pi / 2);
    assert(settings.minFlingDistance == null || settings.minFlingDistance! >= 0);
    assert(settings.preAcceptFlingDistance == null || settings.preAcceptFlingDistance! >= 0);
    assert(settings.minFlingVelocity >= 0);
    assert(settings.maxFlingVelocity >= 0);
    return settings;
  }

  /// El 冒泡父级；在一次指针序列开始时冻结路线。
  TransformRecognizer? parent;

  /// 拖拽轴；为空时允许二维拖拽，不限制缩放与旋转。
  Axis? axis;

  /// [axis] 为空时，是否按照起手方向锁定水平或垂直轴。
  bool lockAxis = false;

  /// 进入缩放前是否结清拖拽家族，默认允许两者继续并行。
  bool cancelDragOnScale = false;

  /// 当前成员是否仍有已开始且未被取消的拖拽。
  bool get isDragging => _routes.values.any(
    (route) =>
        route.owner is TransformRecognizer &&
        ((route.owner as TransformRecognizer)._session?.dragStarted == true ||
            route.dragStartRecipients.contains(this)) &&
        !route.subscription(this).phase(_GestureFamily.drag).excluded,
  );

  /// 当前成员是否仍持有有效拖拽或变换输入，取消后立即更新。
  @override
  bool get hasActiveInput => _routes.values.any((route) {
    final owner = route.owner;
    if (owner is! TransformRecognizer || owner._session?.pointers.isNotEmpty != true) return false;
    return _hasOwnDrag && !route.subscription(this).phase(_GestureFamily.drag).excluded ||
        _scalePhases.any((phase) => _handlerFor(phase) != null) &&
            !route.subscription(this).phase(_GestureFamily.scale).excluded;
  });

  bool get _hasOwnDrag => dragPhases.any((phase) => _handlerFor(phase) != null);

  /// 当前指针的拖拽路线是否仍允许本成员接收该轴，供通用余量分配筛选。
  bool canReceiveDrag(int pointer, Axis? dragAxis) {
    final route = _routes[pointer];
    if (_disposed || route == null || !route.active || !_hasOwnDrag) return false;
    final index = route.members.indexOf(this);
    if (index < 0 || index > (route.cutoffs[_GestureFamily.drag] ?? route.members.length - 1)) return false;
    if (route.subscription(this).phase(_GestureFamily.drag).excluded) return false;
    if (dragAxis == null ? axis != null : axis != null && axis != dragAxis) return false;
    return _registeredFor(route, pointer) && _participates(pointer);
  }

  bool _compatibleWith(TransformRecognizer other) =>
      _hasOwnDrag == other._hasOwnDrag &&
      (!_hasOwnDrag ||
          axis == other.axis &&
              lockAxis == other.lockAxis &&
              _settings.startDistance == other._settings.startDistance &&
              _settings.horizontalAngle == other._settings.horizontalAngle);

  /// 拖拽、缩放与旋转阶段的业务订阅，空值取消订阅，其他阶段不参与识别。
  ///
  /// DragStart 可通过详情标记区分接受前提案，End 保留本轮配置过滤后的释放速度。
  Map<ElEventPhase, TransformGestureCallback?> callbacks = {};

  /// 当前输入已越过拖拽阈值但 Start 延后公开时通知，可提前结清竞争候选。
  void Function(PointerEvent event)? onDeferredDragAccepted;

  /// 在变换开始前检查全部指针资格，失败时不取消已有拖拽或公开 Start。
  bool Function(Iterable<int> pointers)? canStartScale;

  /// 预检通过后、公开 Start 前通知，可结清自身点击；排他默认动作仍等待整链处理。
  void Function(Iterable<int> pointers)? beforeScaleStart;

  /// 整条 Start 路线完成且未取消默认动作时调用，可统一提交多指所有权。
  TransformGestureCallback? onScaleStartDefault;

  _TransformSession? _session;
  bool _disposing = false;
  int _configurationEpoch = 0;

  @override
  TransformRecognizer? get _bubbleParent {
    if (_cooperation?.matchParentGestures != true) return parent;
    var candidate = parent;
    while (candidate != null && !_compatibleWith(candidate)) {
      candidate = candidate.parent;
    }
    return candidate;
  }

  @override
  _GestureCallback? _handlerFor(ElEventPhase phase) {
    if (!dragPhases.contains(phase) && !_scalePhases.contains(phase)) return null;
    final handler = callbacks[phase];
    return handler == null ? null : (details) => handler(details as TransformGestureDetails);
  }

  /// 包含候选按下的拖拽阶段，供识别器与宿主共用回调表。
  @internal
  static const dragPhases = <ElEventPhase>[ElEventPhase.dragDown, ...ElEventPhase.dragPhases];
  static const _zoomPhases = ElEventPhase.zoomPhases;
  static const _scalePhases = ElEventPhase.scalePhases;

  bool get _hasHandlers => dragPhases.any(_hasHandlerInChain) || _scalePhases.any(_hasHandlerInChain);

  // 新建与待定重配覆盖快照，补挂和合作仅增补本轮已冻结的能力。
  _TransformCapabilities _routeCapabilities(_GestureRoute route, [_TransformCapabilities? including]) =>
      _capabilities((phase) => _routeHasHandler(route, phase), including);

  static _TransformCapabilities _capabilities(
    bool Function(ElEventPhase) hasHandler, [
    _TransformCapabilities? including,
  ]) => (
    drag: including?.drag == true || dragPhases.any(hasHandler),
    zoom: including?.zoom == true || _zoomPhases.any(hasHandler),
    rotate: including?.rotate == true || hasHandler(ElEventPhase.rotationUpdate),
  );

  /// 刷新尚未公开开始的会话，保留原触点和竞技场席位；可将当前输入的 Start 延至下一次移动。
  void refreshPendingConfiguration({PointerEvent? deferStartFor}) {
    _configurationEpoch++;
    if (_disposed || _disposing || _canceling) return;
    for (final route in _routes.values.toSet()) {
      final owner = route.owner;
      if (owner is! TransformRecognizer) continue;
      final session = owner._session;
      if (session == null || !owner._isPending(session)) continue;
      final settings = owner._settings;
      final cooperation = _cooperation;
      final index = route.members.indexOf(this);
      final eligible = route.subscription(this).downs.keys.any((pointer) {
        final input = cooperation?._observations[pointer];
        return input?.active == true &&
            !GestureTeam._terminal(input!.event) &&
            cooperation!._participates(pointer) &&
            cooperation.canClaimPointers([pointer]);
      });
      if (eligible && index >= 0) {
        for (final family in [_GestureFamily.drag, _GestureFamily.scale]) {
          if (index <= (route.cutoffs[family] ?? route.members.length - 1) &&
              !route.subscription(this).phase(family).canceling) {
            route.subscription(this).phase(family).excluded = false;
          }
        }
      }
      if (settings.velocityTrackerBuilder != session.settings.velocityTrackerBuilder) {
        for (final pointer in session.pointers.values.toList()) {
          final tracker = settings.velocityTrackerBuilder(pointer.down);
          if (!owner._isPending(session)) return;
          pointer.velocityTracker = tracker;
          for (final (time, position) in pointer.velocitySamples) {
            pointer.velocityTracker.addPosition(time, position);
          }
        }
      }
      session.settings = settings;
      session.axis = owner.axis;
      session.lockAxis = owner.lockAxis;
      session.rotationStartEnabled = settings.rotationStartEnabled;
      session.capabilities = owner._routeCapabilities(route);
      session.dragThresholdMet = false;
      session.scaleThresholdMet = false;
      session.acceptedAxis = null;
      session.direction = null;
      session.deferredStartEvent = deferStartFor ?? session.deferredStartEvent;
      for (final pointer in session.pointers.values) {
        pointer.dragThresholdMet = false;
        pointer.candidateAxis = null;
        pointer.direction = null;
      }
    }
  }

  bool _isPending(_TransformSession session) =>
      _isCurrent(session) && !session.dragStarted && !session.scaleStarted && session.route.dragStartRecipients.isEmpty;

  /// 从团队仍有效且已获官方归属的触点补挂新能力，不重新报名或复活失权输入。
  void resumeFromTeam() {
    final cooperation = _cooperation;
    if (_disposed || _disposing || _canceling || cooperation == null || !_hasHandlers) return;
    for (final input in cooperation._observations.values.toList()) {
      final down = input.down;
      final seat = input.arena._pointers[down.pointer];
      final accepted = cooperation.canClaimPointers([down.pointer]);
      final pending =
          seat != null &&
          seat.result == null &&
          identical(seat.dispatch, input.dispatch) &&
          seat.members.any((member) => !member.withdrawn);
      if (down is! PointerDownEvent ||
          !input.active ||
          GestureTeam._terminal(input.event) ||
          !cooperation._participates(down.pointer) ||
          !accepted && !pending ||
          !super.isPointerAllowed(down)) {
        continue;
      }
      final route = _routes[down.pointer];
      if (route != null) {
        _delegatePointer(down);
        final owner = route.owner;
        if (owner is! TransformRecognizer) continue;
        final session = owner._session;
        if (session != null) {
          session.capabilities = owner._routeCapabilities(route, session.capabilities);
        }
        continue;
      }
      if (!_addTransformPointer(down)) continue;
      // 未决能力复用原团队席位，绝不在原生竞技场另开报名位置。
      final source = seat?.members
          .map((member) => member.member)
          .whereType<_GestureInput>()
          .where(
            (member) =>
                member.tracking &&
                identical(member.source?.dispatch, input.dispatch) &&
                identical(member.source?.arena, input.arena),
          )
          .firstOrNull
          ?.source;
      _trackPointer(down.pointer, down.transform, compete: !accepted, source: source ?? input);
      handleEvent(down);
      if (accepted && _session?.pointers.containsKey(down.pointer) == true) acceptGesture(down.pointer);
    }
  }

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (_disposed || _disposing || _canceling) return false;
    if (_isDelegated(event.pointer)) return true;
    return _hasHandlers && super.isPointerAllowed(event);
  }

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) {
    if (_disposed || _disposing || _canceling) return false;
    if (_isDelegated(event.pointer)) return true;
    return _hasHandlers && super.isPointerPanZoomAllowed(event);
  }

  @override
  void handleNonAllowedPointer(PointerDownEvent event) {
    // 不支持的额外按钮或设备不能否决另一根已在拖动的指针。
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_delegatePointer(event)) return;
    if (_session?.pointers.containsKey(event.pointer) == true) {
      _session!.route.subscription(this).downs[event.pointer] = event;
      return;
    }
    _attachScaleUpgradePointer(event);
    if (_session == null) {
      for (final route in _routes.values.toSet()) {
        final owner = route.owner;
        if (!route.active ||
            identical(owner, this) ||
            owner is! TransformRecognizer ||
            owner._session?.route != route ||
            !_scalePhases.any((phase) => _handlerFor(phase) != null) &&
                owner._session?.cooperation?.members.contains(this) != true ||
            !_scalePhases.any((phase) => owner._routeHasHandler(route, phase))) {
          continue;
        }
        // 共同祖先收到兄弟节点的新触点，仍由原识别器逐指参加官方竞技场。
        if (!owner._addTransformPointer(event)) return;
        // 共同祖先可把第二指接回首指冻结的 Scale 订阅，无需伪造子节点 raw Down。
        for (final member in route.members.whereType<TransformRecognizer>()) {
          if (route.subscription(member).phase(_GestureFamily.scale).excluded ||
              !_scalePhases.any((phase) => member._handlerFor(phase) != null)) {
            continue;
          }
          final originalDown = route.subscription(member).downs.values.firstOrNull;
          if (originalDown != null) {
            route.subscription(member).downs[event.pointer] = event.transformed(originalDown.transform);
          }
        }
        if (_cooperation != null &&
            owner._cooperation?._observations[event.pointer] == null &&
            !_scalePhases.any((phase) => owner._handlerFor(phase) != null)) {
          route.subscription(owner).downs.remove(event.pointer);
        }
        route.subscription(this).downs[event.pointer] = event;
        owner._trackPointer(event.pointer, event.transform, source: _cooperation?._observations[event.pointer]);
        return;
      }
    }
    if (!_addTransformPointer(event)) return;
    super.addAllowedPointer(event);
  }

  void _attachScaleUpgradePointer(PointerDownEvent event) {
    final session = _session;
    final team = _cooperation;
    final source = team?._observations[event.pointer];
    if (session == null || !session.dragStarted || source?.active != true) return;
    for (final pointer in session.pointers.values.toList()) {
      final current = team!._observations[pointer.down.pointer];
      if (!pointer.accepted || current?.active != true) continue;
      for (final target in current!.dispatch.members) {
        if (!target.isCurrent || identical(target.team, team) || !target.scaleAllowed) continue;
        for (final member in target.team._members.whereType<TransformRecognizer>()) {
          final route = member._routes[pointer.down.pointer];
          final owner = route?.owner;
          if (route == null || owner is! TransformRecognizer) continue;
          final pending = owner._session;
          if (member._disposed ||
              pending == null ||
              !owner._isCurrent(pending) ||
              route.subscription(member).phase(_GestureFamily.scale).excluded ||
              !_scalePhases.any((phase) => member._handlerFor(phase) != null)) {
            continue;
          }
          final down = route.subscription(member).downs[pointer.down.pointer];
          if (down == null) continue;
          final canonical = event.original ?? event;
          if (!identical(owner, this) && !pending.pointers.containsKey(event.pointer)) {
            final ownerDown = route.subscription(owner).downs[pointer.down.pointer] ?? down;
            final input = canonical.transformed(ownerDown.transform);
            if (!owner._addTransformPointer(input)) return;
            if (!identical(owner, member) && owner._cooperation?._observations[event.pointer] == null) {
              route.subscription(owner).downs.remove(event.pointer);
            }
            owner._trackPointer(event.pointer, input.transform, source: source);
          }
          // 让渡仅补回冻结名单中最早的 Scale 订阅，不制造新的原始 Down。
          route.subscription(member).downs[event.pointer] = canonical.transformed(down.transform);
          return;
        }
      }
    }
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    if (_delegatePointer(event)) return;
    if (!_addTransformPointer(event)) return;
    super.addAllowedPointerPanZoom(event);
    startTrackingPointer(event.pointer, event.transform);
  }

  bool _addTransformPointer(PointerEvent event) {
    var session = _session;
    if (session != null &&
        (event.kind == PointerDeviceKind.mouse &&
                session.pointers.values.any(
                  (pointer) =>
                      pointer.down.kind == PointerDeviceKind.mouse &&
                      pointer.down.device == event.device &&
                      pointer.down.pointer != event.pointer,
                ) ||
            !dragPhases.any((phase) => _routeHasHandler(session!.route, phase)) &&
                !_scalePhases.any((phase) => _routeHasHandler(session!.route, phase)))) {
      cancel();
      if (_disposed || _disposing || _canceling) return false;
      session = _session;
    }
    if (session == null) {
      final route = _beginRoute(event);
      session = _TransformSession(route, _settings, axis, lockAxis, _routeCapabilities(route));
      _session = session;
    } else {
      _beginRoute(event, route: session.route);
    }
    session.pointers[event.pointer] = _TransformPointer(event, session.settings.velocityTrackerBuilder(event));
    session.candidateGeometry = _geometry(session, acceptedOnly: false);
    return true;
  }

  @override
  void handleEvent(PointerEvent event) {
    final session = _session;
    final pointer = session?.pointers[event.pointer];
    if (session == null || pointer == null || _disposed || _disposing) return;
    session.lastEvent = event;
    pointer.event = event;
    if (event is PointerDownEvent || event is PointerPanZoomStartEvent) {
      pointer.delivered = true;
      _applyDragCooperation(session, event.pointer);
      if (!session.downDispatched && session.capabilities.drag) {
        session.downDispatched = true;
        _emit(session, ElEventPhase.dragDown, event);
        if (!_isCurrent(session)) return;
      }
      if (session.dragStarted || session.scaleStarted) {
        // 新指针必须先赢得自己的竞技场，不能直接加入已有变换。
        resolvePointer(event.pointer, GestureDisposition.accepted);
        if (!_isCurrent(session)) return;
      }
      if (pointer.accepted) _acceptedRosterChanged(session, event);
      return;
    }

    if (event is PointerMoveEvent) {
      if (event.buttons != pointer.down.buttons) {
        _removePointer(session, pointer, event, canceled: true);
        return;
      }
      pointer.position = event.position;
      pointer.localPosition = event.localPosition;
    } else if (event is PointerPanZoomUpdateEvent) {
      pointer.position = event.position + event.pan;
      pointer.localPosition = event.localPosition + event.localPan;
      pointer.panScale = event.scale;
      pointer.panRotation = event.rotation;
    } else if (event is PointerUpEvent || event is PointerPanZoomEndEvent) {
      if (!session.dragStarted &&
          session.deferredStartEvent == null &&
          session.capabilities.drag &&
          session.pointers.length == 1) {
        final velocity = _flingVelocity(session, pointer, event);
        if (velocity != Velocity.zero) {
          session.upFling = true;
          pointer.dragThresholdMet = true;
          pointer.candidateAxis = session.acceptedAxis;
          pointer.direction = session.direction;
          if (pointer.accepted) _acceptDragThreshold(session, pointer);
          if (!_isCurrent(session)) return;
          resolvePointer(event.pointer, GestureDisposition.accepted);
          if (!_isCurrent(session)) return;
          _startReadyGestures(session, event);
          if (!_isCurrent(session)) return;
        }
      }
      _removePointer(session, pointer, event, canceled: false);
      return;
    } else if (event is PointerCancelEvent) {
      _removePointer(session, pointer, event, canceled: true);
      return;
    } else {
      return;
    }

    if (!event.synthesized) {
      pointer.addVelocitySample(event.timeStamp, pointer.localPosition);
    }
    final wasDragging = session.dragStarted;
    final wasScaling = session.scaleStarted;
    final resumesDeferredStart = session.deferredStartEvent != null && !_sameInput(session.deferredStartEvent!, event);
    _considerThresholds(session, pointer, event);
    if (!_isCurrent(session) || !pointer.accepted) return;

    _startReadyGestures(session, event);
    if (!_isCurrent(session)) return;

    if ((wasDragging || resumesDeferredStart) && session.dragStarted) {
      final projected = _dragDelta(session, pointer, event);
      final delta = _toGlobalDelta(event, pointer.localPosition, projected);
      if (delta != Offset.zero) {
        session.dragOffset += delta;
        _emit(session, ElEventPhase.dragUpdate, event, delta: delta);
        if (!_isCurrent(session)) return;
      }
    }
    if (wasScaling && session.scaleStarted) {
      _updateScale(session, event);
    }
  }

  bool _isCurrent(_TransformSession session) => identical(_session, session) && session.route.active && !_disposed;

  static bool _sameInput(PointerEvent first, PointerEvent second) =>
      identical(first.original ?? first, second.original ?? second);

  bool _hasConflictingDragStart(_TransformSession session, int pointer, Axis? candidateAxis) {
    if (candidateAxis == null) return false;
    final dispatch = _inputs[pointer]?.source?.dispatch ?? _cooperation?._observations[pointer]?.dispatch;
    if (dispatch == null) return false;
    for (final input in dispatch.members) {
      for (final member in input.team._members.whereType<TransformRecognizer>()) {
        final route = member._routes[pointer];
        final owner = route?.owner;
        final other = owner is TransformRecognizer ? owner._session : null;
        if (route != null &&
            route.active &&
            !identical(route, session.route) &&
            route.dragStartRecipients.isNotEmpty &&
            other?.acceptedAxis != null &&
            other!.acceptedAxis != candidateAxis) {
          return true;
        }
      }
    }
    return false;
  }

  TransformRecognizer? _scaleActionOwner(_TransformSession session, int pointer) => session.route.members
      .whereType<TransformRecognizer>()
      .where(
        (member) =>
            !member._disposed &&
            member._registeredFor(session.route, pointer) &&
            !session.route.subscription(member).phase(_GestureFamily.scale).excluded &&
            _scalePhases.any((phase) => member._handlerFor(phase) != null),
      )
      .firstOrNull;

  bool _hasActiveReceiver(int pointer) {
    final session = _session;
    if (session == null || !session.route.active) return false;
    final route = session.route;
    final source = _inputs[pointer]?.source;
    for (final (index, member) in route.members.indexed) {
      if (member is! TransformRecognizer || member._disposed) continue;
      final team = member._cooperation;
      final input = team?._observations[pointer];
      final down = route.subscription(member).downs[pointer];
      final observed =
          index <= (route.observedEnds[_GestureFamily.drag] ?? -1) &&
          (member.callbacks[ElEventPhase.dragUpdate] != null || member.callbacks[ElEventPhase.dragEnd] != null);
      if (session.dragStarted &&
          session.pointers[pointer]?.accepted == true &&
          member._hasOwnDrag &&
          index <= (route.cutoffs[_GestureFamily.drag] ?? route.members.length - 1) &&
          !route.subscription(member).phase(_GestureFamily.drag).excluded &&
          (route.dragStartRecipients.contains(member) || observed) &&
          team?.onPointerEvent != null &&
          input?.active == true &&
          !GestureTeam._terminal(input!.event) &&
          source != null &&
          identical(input.dispatch, source.dispatch) &&
          down != null &&
          _sameInput(down, input.down) &&
          _sameInput(input.down, source.down) &&
          member._registeredFor(route, pointer)) {
        return true;
      }
      final shadow = input == null && source != null && session.pointers[pointer]?.accepted == true && down != null;
      if (session.scaleStarted &&
          !route.subscription(member).phase(_GestureFamily.scale).excluded &&
          _scalePhases.any((phase) => member._handlerFor(phase) != null) &&
          (input?.active == true || input?.scaleAllowed == true || shadow)) {
        return true;
      }
    }
    return false;
  }

  bool _prepareDragCooperation(_TransformSession session, PointerEvent event) {
    final resolver = dragCooperation;
    if (resolver == null || session.cooperation != null) return true;
    final plan = invokeCallback<DragCooperation?>(
      'dragCooperation',
      () => resolver(event.pointer, session.acceptedAxis),
    );
    if (!_isCurrent(session)) return false;
    if (plan == null) return true;
    final chain = <TransformRecognizer>[];
    for (var node = this; !chain.contains(node);) {
      chain.add(node);
      final next = node.parent;
      if (next == null) break;
      node = next;
    }
    final route = session.route;
    final explicit = route.cutoffs[_GestureFamily.drag];
    final boundary = explicit == null
        ? chain.length
        : chain.indexOf(route.members[explicit] as TransformRecognizer) + 1;
    final members = plan.members
        .where((member) => !member._disposed && chain.indexOf(member) > 0 && chain.indexOf(member) < boundary)
        .toSet();
    if (members.isEmpty) return true;
    final oldEnds = route.observedEnds.map(
      (family, index) => MapEntry(family, index < 0 ? null : route.members[index]),
    );
    final oldCuts = route.cutoffs.map((family, index) => MapEntry(family, route.members[index]));
    for (final member in members) {
      final previous = member._session;
      final previousRoute = member._routes[event.pointer];
      final downs = Map<int, PointerEvent>.of(previousRoute?.subscription(member).downs ?? {});
      if (previous != null && !identical(previous, session)) {
        member._session = null;
        route.dragStartRecipients.addAll(previous.route.dragStartRecipients);
        for (final tracked in previous.pointers.values) {
          final pointer = tracked.down.pointer;
          if (session.pointers.containsKey(pointer)) {
            member.stopTrackingPointer(pointer);
            member.resolvePointer(pointer, GestureDisposition.rejected);
          } else {
            member._transferTrackingTo(this, pointer);
            session.pointers[pointer] = tracked;
            if (tracked.accepted) session.acceptedOrder.add(pointer);
            route.pointers.add(pointer);
          }
        }
        member._endRoute(previous.route);
      }
      if (!route.members.contains(member)) route.members.add(member);
      route.subscription(member).downs = {
        ...route.subscription(member).downs,
        ...downs,
        for (final pointer in session.pointers.values)
          if (!downs.containsKey(pointer.down.pointer))
            pointer.down.pointer: member._cooperation?._observations[pointer.down.pointer]?.down ?? pointer.down,
      };
      session.capabilities = _capabilities((phase) => member._handlerFor(phase) != null, session.capabilities);
      session.rotationStartEnabled |= previous?.settings.rotationStartEnabled ?? member.rotationStartEnabled;
    }
    route.members.sort(
      (a, b) => chain.indexOf(a as TransformRecognizer).compareTo(chain.indexOf(b as TransformRecognizer)),
    );
    for (final entry in oldCuts.entries) {
      route.cutoffs[entry.key] = route.members.indexOf(entry.value);
    }
    for (final entry in oldEnds.entries) {
      route.observedEnds[entry.key] = entry.value == null ? -1 : route.members.indexOf(entry.value!);
    }
    for (final member in route.members) {
      for (final pointer in route.pointers) {
        member._routes[pointer] = route;
      }
      _GestureInputRegistry.recognizers.add(member);
    }
    session.cooperation = DragCooperation(members, cutoff: plan.cutoff);
    for (final pointer in route.pointers) {
      _applyDragCooperation(session, pointer);
    }
    _GestureInputRegistry.sync();
    return _isCurrent(session);
  }

  void _applyDragCooperation(_TransformSession session, int pointer) {
    final plan = session.cooperation;
    final dispatch = _cooperation?._observations[pointer]?.dispatch;
    if (plan == null || dispatch == null) return;
    final previous = dispatch.primaryCutoff;
    final next = plan.cutoff;
    if (next != null && (previous == null || dispatch.indexOfTeam(next) < dispatch.indexOfTeam(previous))) {
      dispatch.primaryCutoff = next;
    }
    dispatch.primaryExempt.addAll([?_cooperation, for (final member in plan.members) ?member._cooperation]);
    final cutoff = dispatch.primaryCutoff;
    if (cutoff == null) return;
    final boundary = dispatch.indexOfTeam(cutoff);
    if (boundary < 0) return;
    for (final input in dispatch.members.skip(boundary).toList()) {
      if (!input.isCurrent || !input.active || dispatch.primaryExempt.contains(input.team)) continue;
      input.active = false;
      input.scaleAllowed = true;
      if (input.notified) {
        input.team._deliver(GestureTeam._cancelEvent(input, rejected: true), PressCancelReason.arenaRejected);
      }
      for (final member in input.team._members.toList()) {
        if (member is PressRecognizer) member._cancelMember(pointer, PressCancelReason.arenaRejected);
        if (member is TransformRecognizer) member.cancelMember(pointer, cancelScale: false);
      }
    }
  }

  Offset _dragDelta(_TransformSession session, _TransformPointer pointer, PointerEvent event) {
    final localDelta = _project(pointer.localPosition - pointer.lastOutputLocal, session.acceptedAxis);
    pointer.lastOutputLocal = pointer.localPosition;
    final strategy = session.settings.multitouchDragStrategy;
    if (strategy == MultitouchDragStrategy.latestPointer) {
      return session.driver == event.pointer ? localDelta : Offset.zero;
    }
    if (strategy == MultitouchDragStrategy.sumAllPointers) return localDelta;
    final scheduler = SchedulerBinding.instance;
    final currentFrame = scheduler.schedulerPhase == SchedulerPhase.idle
        ? Duration.zero
        : scheduler.currentSystemFrameTimeStamp;
    final rate = session.settings.displayRefreshRate?.call();
    final frameMicros = rate != null && rate.isFinite && rate > 0
        ? math.max(1, (Duration.microsecondsPerSecond / rate).round())
        : 16000;
    final frame = currentFrame == Duration.zero
        ? Duration(microseconds: event.timeStamp.inMicroseconds ~/ frameMicros * frameMicros)
        : currentFrame;
    if (session.frameTimeStamp != frame) {
      session.frameTimeStamp = frame;
      session.frameDeltas.clear();
      session.lastPanFrameDelta = Offset.zero;
    }
    final previous = session.frameDeltas[event.pointer] ?? Offset.zero;
    if (session.acceptedAxis == null) {
      session.frameDeltas[event.pointer] = previous + localDelta;
      var total = Offset.zero;
      for (final value in session.frameDeltas.values) {
        total += value;
      }
      final count = session.pointers.values.where((value) => value.accepted && value.delivered).length;
      final average = total / count.toDouble();
      final delta = average - session.lastPanFrameDelta;
      session.lastPanFrameDelta = average;
      return delta;
    }
    final vertical = session.acceptedAxis == Axis.vertical;
    final primary = vertical ? localDelta.dy : localDelta.dx;
    final before = vertical ? previous.dy : previous.dx;
    var boundary = 0.0;
    for (final value in session.frameDeltas.values) {
      final position = vertical ? value.dy : value.dx;
      boundary = primary > 0 ? math.max(boundary, position) : math.min(boundary, position);
    }
    session.frameDeltas[event.pointer] = previous + localDelta;
    final delta = primary > 0 ? math.max(0.0, before + primary - boundary) : math.min(0.0, before + primary - boundary);
    return vertical ? Offset(0, delta) : Offset(delta, 0);
  }

  void _considerThresholds(_TransformSession session, _TransformPointer pointer, PointerEvent event) {
    if (session.capabilities.drag && !session.dragThresholdMet) {
      final moved = pointer.localPosition - pointer.down.localPosition;
      final candidateAxis =
          session.axis ?? (session.lockAxis ? _axisFor(moved, session.settings.horizontalAngle) : null);
      final intendedAxis = _axisFor(moved, session.settings.horizontalAngle);
      if ((candidateAxis == null || candidateAxis == intendedAxis) &&
          !_hasConflictingDragStart(session, event.pointer, candidateAxis)) {
        final projected = _project(moved, candidateAxis);
        final globalMoved = _toGlobalDelta(event, pointer.localPosition, projected);
        final threshold =
            session.settings.startDistance ??
            (candidateAxis == Axis.vertical || session.axis != null
                ? computeHitSlop(event.kind, session.settings.gestureSettings)
                : computePanSlop(event.kind, session.settings.gestureSettings));
        if (globalMoved.distance > threshold) {
          if (!_proposeDragStart(
            session,
            event,
            candidateAxis,
            _directionFor(moved, session.settings.horizontalAngle),
          )) {
            return;
          }
          pointer.dragThresholdMet = true;
          pointer.candidateAxis = candidateAxis;
          pointer.direction = _directionFor(moved, session.settings.horizontalAngle);
          if (pointer.accepted) _acceptDragThreshold(session, pointer);
          if (!_isCurrent(session)) return;
          resolvePointer(event.pointer, GestureDisposition.accepted);
        }
      }
    }
    if (!_isCurrent(session) || !session.hasScale || session.scaleThresholdMet) {
      return;
    }
    final geometry = _geometry(session, acceptedOnly: false);
    if (geometry.count == 0 || geometry.count < 2 && session.dragStarted) return;
    final initial = session.candidateGeometry;
    if (initial == null || initial.count == 0) {
      session.candidateGeometry = geometry;
      return;
    }
    final changed =
        session.capabilities.zoom &&
            ((geometry.span - initial.span).abs() > computeScaleSlop(event.kind) ||
                (geometry.panScale / initial.panScale - 1).abs() > 0.05) ||
        (session.capabilities.drag || session.capabilities.zoom) &&
            (geometry.focal - initial.focal).distance > computePanSlop(event.kind, session.settings.gestureSettings) ||
        session.capabilities.rotate &&
            (_angleDelta(geometry.angle - initial.angle).abs() > 0.05 ||
                (geometry.panRotation - initial.panRotation).abs() > 0.05) ||
        session.rotationStartEnabled &&
            (initial.span * _angleDelta(geometry.angle - initial.angle).abs() > computeScaleSlop(event.kind) ||
                (geometry.panRotation - initial.panRotation).abs() > 0.05);
    if (changed) {
      session.scaleThresholdMet = true;
      for (final id in session.pointers.keys.toList()) {
        if (!_isCurrent(session)) return;
        resolvePointer(id, GestureDisposition.accepted);
      }
    }
  }

  @override
  void acceptGesture(int pointer) {
    final session = _session;
    final tracked = session?.pointers[pointer];
    if (session == null || tracked == null || tracked.accepted) return;
    tracked.accepted = true;
    _notifyAccepted(session.route, pointer);
    if (!_isCurrent(session)) return;
    if (tracked.dragThresholdMet) _acceptDragThreshold(session, tracked);
    if (!_isCurrent(session)) return;
    session.acceptedOrder.add(pointer);
    session.driver = pointer;
    tracked.lastOutputLocal = tracked.localPosition;
    if (tracked.delivered) _acceptedRosterChanged(session, tracked.event);
  }

  void _acceptDragThreshold(_TransformSession session, _TransformPointer pointer) {
    if (session.dragStarted) return;
    final first = !session.dragThresholdMet;
    session.dragThresholdMet = true;
    if (session.route.dragStartRecipients.isEmpty) {
      session.acceptedAxis = pointer.candidateAxis;
      session.direction = pointer.direction;
    }
    final deferred = session.deferredStartEvent;
    final accepted = onDeferredDragAccepted;
    if (first && deferred != null && _sameInput(deferred, pointer.event) && accepted != null) {
      invokeCallback<void>('deferredDragAccepted', () => accepted(pointer.event));
    }
  }

  bool _proposeDragStart(_TransformSession session, PointerEvent event, Axis? dragAxis, AxisDirection direction) {
    if (session.route.subscription(this).phase(_GestureFamily.drag).excluded) return false;
    final team = _cooperation;
    final dispatch = team?._observations[event.pointer]?.dispatch;
    if (team == null || dispatch == null) return true;
    final end = dispatch.indexOfTeam(team);
    for (final candidate in dispatch.members.take(end < 0 ? 0 : end)) {
      for (final member in candidate.team._members.whereType<TransformRecognizer>().toList()) {
        final target = member._session;
        if (member._disposed ||
            target == null ||
            identical(target.route, session.route) ||
            target.route.dragStartRecipients.contains(member) ||
            !member.canReceiveDrag(event.pointer, dragAxis)) {
          continue;
        }
        final proposal = TransformGestureDetails(
          phase: ElEventPhase.dragStart,
          originalEvent: event,
          globalPosition: event.position,
          dragAxis: dragAxis,
          dragDirection: direction,
          pointerCount: _geometry(target, acceptedOnly: false).count,
          pointerIds: target.pointers.keys.toList(),
          started: true,
        )..isProposal = true;
        if (target.route.dragStartRecipients.isEmpty) {
          target.acceptedAxis = dragAxis;
          target.direction = direction;
        }
        member._dispatchGesture(target.route, proposal);
        if (!_isCurrent(session) || proposal.propagationStopped || team._observations[event.pointer]?.active != true) {
          cancelMember(event.pointer, cancelScale: false);
          return false;
        }
      }
    }
    return true;
  }

  void _acceptedRosterChanged(_TransformSession session, PointerEvent event) {
    if (!_isCurrent(session)) return;
    event = session.lastEvent ?? event;
    if (session.scaleStarted) {
      session.logScaleVelocity = 0;
      session.logScaleVelocityTime = null;
      session.lastScaleSampleTime = event.timeStamp;
    }
    _rebaseScale(session);
    _startReadyGestures(session, event);
  }

  bool _isScaleUpgrade(_TransformSession session, int pointer) {
    if (_geometry(session).count < 2) return false;
    if (session.dragStarted && dragPhases.any((phase) => _routeHasHandler(session.route, phase))) return true;
    final team = _scaleActionOwner(session, pointer)?._cooperation;
    return session.acceptedOrder.any((id) => team?._observations[id]?.scaleAllowed == true);
  }

  bool _hasUnfinishedScaleLoss(_TransformSession session) {
    final team = _cooperation;
    return team?.matchParentGestures == true &&
        team!._observations.values.any(
          (input) =>
              !input.active &&
              !input.scaleAllowed &&
              !GestureTeam._terminal(input.event) &&
              !session.pointers.containsKey(input.down.pointer),
        );
  }

  bool _isScaleConfigurationCurrent(
    _TransformSession session,
    TransformRecognizer member,
    int epoch,
    PointerEvent event,
  ) {
    if (!_isCurrent(session)) return false;
    if (!member._disposed && member._configurationEpoch == epoch) return true;
    // 起手回调换声明后，本轮候选不能在下一条输入重新定向到新处理器。
    member.cancelMember(null, cancelDrag: false, event: event);
    return false;
  }

  void _startReadyGestures(_TransformSession session, PointerEvent event) {
    final owned = session.pointers.values.where((pointer) => pointer.accepted && pointer.delivered).toList();
    if (owned.isEmpty) return;
    final deferred = session.deferredStartEvent;
    if (deferred != null) {
      if (_sameInput(deferred, event) || event is! PointerMoveEvent && event is! PointerPanZoomUpdateEvent) {
        for (final pointer in owned) {
          pointer.lastOutputLocal = pointer.localPosition;
        }
        return;
      }
      session.deferredStartEvent = null;
    }
    if (session.capabilities.drag &&
        session.dragThresholdMet &&
        !session.dragStarted &&
        !(cancelDragOnScale && session.hasScale && _geometry(session).count > 1 && !session.scaleStarted)) {
      if (_hasConflictingDragStart(session, event.pointer, session.acceptedAxis)) return;
      session.dragStarted = true;
      if (!_prepareDragCooperation(session, event)) return;
      if (deferred == null) {
        for (final pointer in session.pointers.values.where((pointer) => pointer.accepted)) {
          pointer.lastOutputLocal = pointer.localPosition;
        }
      }
      _emit(session, ElEventPhase.dragStart, event);
      if (!_isCurrent(session)) return;
    }
    final scaleUpgrade = session.hasScale && _isScaleUpgrade(session, event.pointer);
    if (scaleUpgrade) session.scaleThresholdMet = true;
    if (session.hasScale &&
        session.scaleThresholdMet &&
        !session.scaleStarted &&
        !_hasUnfinishedScaleLoss(session) &&
        (event is! PointerDownEvent || session.settings.startScaleOnPointerDown || scaleUpgrade) &&
        session.pointers.values.every((pointer) => !pointer.delivered || pointer.accepted) &&
        _scalePhases.any((phase) => _routeHasHandler(session.route, phase)) &&
        _geometry(session).count > 0) {
      final actionOwner = _scaleActionOwner(session, event.pointer);
      if (actionOwner == null) return;
      final epoch = actionOwner._configurationEpoch;
      if (actionOwner.canStartScale?.call(session.acceptedOrder) == false ||
          !_isScaleConfigurationCurrent(session, actionOwner, epoch, event)) {
        return;
      }
      final before = actionOwner.beforeScaleStart;
      if (before != null) {
        actionOwner.invokeCallback<void>('beforeScaleStart', () => before(List.unmodifiable(session.acceptedOrder)));
        if (!_isCurrent(session) ||
            !session.scaleThresholdMet ||
            !_scalePhases.any((phase) => _routeHasHandler(session.route, phase)) ||
            !_isScaleConfigurationCurrent(session, actionOwner, epoch, event) ||
            actionOwner.canStartScale?.call(session.acceptedOrder) == false ||
            !_isScaleConfigurationCurrent(session, actionOwner, epoch, event)) {
          return;
        }
      }
      final cooperation = _cooperation;
      if (_geometry(session).count < 2) {
        if (cancelDragOnScale) cancelMember(null, cancelScale: false, event: event);
      } else if (cooperation != null) {
        cooperation._cancelDragForScale(session.acceptedOrder.toList(), event: event);
      } else {
        for (final member in session.route.members.cast<TransformRecognizer>()) {
          if (member.cancelDragOnScale) {
            member.cancelMember(null, cancelScale: false, event: event);
          }
        }
      }
      if (!_isScaleConfigurationCurrent(session, actionOwner, epoch, event)) return;
      session.scaleStarted = true;
      session.scale = 1;
      session.rotation = 0;
      session.lastScaleSampleTime = event.timeStamp;
      session.logScaleVelocity = 0;
      session.logScaleVelocityTime = null;
      _rebaseScale(session);
      final details = _emit(session, ElEventPhase.scaleStart, event);
      if (_isCurrent(session) &&
          !details.defaultPrevented &&
          !actionOwner._disposed &&
          actionOwner._configurationEpoch == epoch) {
        actionOwner.invokeCallback<void>('scaleStartDefault', () => actionOwner.onScaleStartDefault?.call(details));
      }
    }
  }

  void _updateScale(_TransformSession session, PointerEvent event) {
    final current = _geometry(session);
    final initial = session.scaleGeometry;
    if (initial == null || current.count == 0) return;
    final previousScale = session.scale;
    final pointerFactor = initial.span > 0 ? current.span / initial.span : 1.0;
    session.scale = session.scaleAtRebase * pointerFactor * current.panScale / initial.panScale;
    session.rotation +=
        _angleDelta(current.angle - session.lastRotationAngle) + current.panRotation - session.lastPanRotation;
    session.lastRotationAngle = current.angle;
    session.lastPanRotation = current.panRotation;
    final delta = current.focal - session.lastScaleFocal;
    session.lastScaleFocal = current.focal;
    if (!event.synthesized && (!session.scale.isFinite || session.scale <= 0)) {
      session.logScaleVelocity = 0;
      session.logScaleVelocityTime = null;
      session.logScaleVelocityFocal = null;
    } else if (!event.synthesized && current.count >= 2) {
      final elapsed = event.timeStamp - (session.lastScaleSampleTime ?? event.timeStamp);
      if (elapsed > Duration.zero && previousScale > 0 && session.scale > 0 && previousScale != session.scale) {
        final velocity =
            math.log(session.scale / previousScale) * Duration.microsecondsPerSecond / elapsed.inMicroseconds;
        session.logScaleVelocity = velocity.isFinite ? velocity : 0;
        session.logScaleVelocityTime = event.timeStamp;
        session.logScaleVelocityFocal = current.focal;
        session.clearScaleVelocityOnPan = false;
      }
    } else if (session.clearScaleVelocityOnPan && delta != Offset.zero) {
      session.logScaleVelocity = 0;
      session.logScaleVelocityTime = null;
    }
    session.lastScaleSampleTime = event.timeStamp;
    _emit(session, ElEventPhase.scaleUpdate, event, delta: delta);
    if (!_isCurrent(session)) return;
    _emit(session, ElEventPhase.rotationUpdate, event, delta: delta);
  }

  void _rebaseScale(_TransformSession session) {
    final geometry = _geometry(session);
    session.scaleGeometry = geometry;
    session.scaleAtRebase = session.scale;
    session.lastRotationAngle = geometry.angle;
    session.lastPanRotation = geometry.panRotation;
    session.lastScaleFocal = geometry.focal;
  }

  @override
  void rejectGesture(int pointer) {
    final session = _session;
    final tracked = session?.pointers[pointer];
    if (session == null || tracked == null) return;
    _removePointer(session, tracked, tracked.event, canceled: true);
  }

  void _removePointer(
    _TransformSession session,
    _TransformPointer pointer,
    PointerEvent event, {
    required bool canceled,
  }) {
    final wasAccepted = pointer.accepted;
    session.pointers.remove(event.pointer);
    session.acceptedOrder.remove(event.pointer);
    if (!session.scaleStarted) session.scaleThresholdMet = false;
    if (!session.dragStarted && pointer.dragThresholdMet) {
      session.dragThresholdMet = false;
      for (final remaining in session.pointers.values) {
        if (remaining.accepted && remaining.dragThresholdMet) {
          _acceptDragThreshold(session, remaining);
          break;
        }
      }
    }
    stopTrackingPointer(event.pointer);
    resolvePointer(event.pointer, GestureDisposition.rejected);
    if (!_isCurrent(session)) return;
    if (session.pointers.isEmpty ||
        (session.dragStarted || session.scaleStarted) && !session.pointers.values.any((pointer) => pointer.accepted)) {
      _finishSession(session, event, canceled: canceled, lastPointer: pointer);
      return;
    }
    for (final member in session.route.members.whereType<TransformRecognizer>().toList()) {
      final route = session.route;
      final downs = route.subscription(member).downs;
      if (member._disposed ||
          downs.containsKey(event.pointer) != true ||
          session.pointers.keys.any((id) => downs.containsKey(id)) ||
          route.subscription(member).phase(_GestureFamily.drag).excluded ||
          !session.dragStarted && !route.dragStartRecipients.contains(member)) {
        continue;
      }
      _terminateMember(session, member, canceled ? .dragCancel : .dragEnd, event, tracked: pointer);
      if (!_isCurrent(session)) return;
    }
    if (session.driver == event.pointer) {
      session.driver = session.acceptedOrder.lastOrNull;
      final next = session.pointers[session.driver];
      if (next != null) next.lastOutputLocal = next.localPosition;
    }
    if (session.scaleStarted && wasAccepted) {
      session.clearScaleVelocityOnPan = _geometry(session).count == 1;
      session.lastScaleSampleTime = event.timeStamp;
      if (canceled) {
        session.logScaleVelocity = 0;
        session.logScaleVelocityTime = null;
      }
    }
    if (wasAccepted) {
      session.frameDeltas.clear();
      session.lastPanFrameDelta = Offset.zero;
      _rebaseScale(session);
    }
    session.candidateGeometry = _geometry(session, acceptedOnly: false);
  }

  void _finishSession(
    _TransformSession session,
    PointerEvent event, {
    required bool canceled,
    _TransformPointer? lastPointer,
  }) {
    if (!identical(_session, session)) return;
    _session = null;
    // 最新 driver 可能尚未产生 Update，终态仍须使用它最后可信的位置。
    session.lastDriverPosition =
        session.pointers[session.driver]?.position ?? lastPointer?.position ?? session.lastDriverPosition;
    final pending = session.pointers.keys.toList();
    session.pointers.clear();
    for (final id in pending) {
      stopTrackingPointer(id);
      resolvePointer(id, GestureDisposition.rejected);
    }
    _releaseRoutePointers(session.route);
    for (final scale in [true, false]) {
      if (scale ? !session.scaleStarted : !session.dragStarted && !session.downDispatched) continue;
      final end = !canceled && (scale || session.dragStarted || session.route.dragStartRecipients.isNotEmpty);
      final phases = scale
          ? (ElEventPhase.scaleEnd, ElEventPhase.scaleCancel)
          : (ElEventPhase.dragEnd, ElEventPhase.dragCancel);
      _emit(
        session,
        end ? phases.$1 : phases.$2,
        event,
        velocity: end && lastPointer != null
            ? _flingVelocity(session, lastPointer, event, scale: scale)
            : Velocity.zero,
      );
    }
    _endRoute(session.route);
  }

  Velocity _flingVelocity(
    _TransformSession session,
    _TransformPointer pointer,
    PointerEvent event, {
    bool scale = false,
  }) {
    final samples = pointer.velocitySamples;
    // 停顿按输入时间判断；不能把 UI 线程排队时间误当成手指停顿。
    if (samples.length < 2 || event.timeStamp - samples.last.$1 > const Duration(milliseconds: 80)) {
      return Velocity.zero;
    }
    var tracker = pointer.velocityTracker;
    if (identical(session.settings.velocityTrackerBuilder, _defaultVelocityTrackerBuilder)) {
      tracker = VelocityTracker.withKind(pointer.down.kind);
      for (final (time, position) in samples) {
        tracker.addPosition(time, position);
      }
    }
    final estimate = tracker.getVelocityEstimate();
    var measuredSpeed = estimate?.pixelsPerSecond ?? Offset.zero;
    var measuredOffset = estimate?.offset ?? samples.last.$2 - pointer.down.localPosition;
    // 官方二次拟合不足三个连续样本时，仅用最近真实末段恢复平移速度。
    if (scale && measuredSpeed == Offset.zero && tracker.runtimeType == VelocityTracker) {
      final newest = samples.last;
      final previous = samples[samples.length - 2];
      final elapsed = newest.$1 - previous.$1;
      // 两个相邻间隔均不超过 40ms 时必有三个连续样本，不走末段恢复。
      if (elapsed > Duration.zero &&
          elapsed <= const Duration(milliseconds: 40) &&
          (samples.length == 2 || previous.$1 - samples[samples.length - 3].$1 > const Duration(milliseconds: 40))) {
        measuredOffset = newest.$2 - previous.$2;
        measuredSpeed = measuredOffset * (Duration.microsecondsPerSecond / elapsed.inMicroseconds);
      }
    }
    // 稀疏 Drag 保留有界 Up 救援，不能把远离真实轨迹的终点加入拟合。
    if (measuredSpeed == Offset.zero) {
      if (scale) return Velocity.zero;
      final elapsed = event.timeStamp - pointer.down.timeStamp;
      if (elapsed <= Duration.zero) return Velocity.zero;
      var end = samples.last.$2;
      if (event is PointerUpEvent &&
          _toGlobalDelta(event, event.localPosition, event.localPosition - end).distance <= kTouchSlop * 4) {
        end = event.localPosition;
      }
      measuredOffset = end - pointer.down.localPosition;
      measuredSpeed = measuredOffset * (2 * Duration.microsecondsPerSecond / elapsed.inMicroseconds);
    }
    final velocityAxis = scale
        ? null
        : session.dragStarted
        ? session.acceptedAxis
        : session.axis ?? (session.lockAxis ? _axisFor(measuredSpeed, session.settings.horizontalAngle) : null);
    if (!scale && !session.dragStarted && _hasConflictingDragStart(session, event.pointer, velocityAxis)) {
      return Velocity.zero;
    }
    if (!scale &&
        !session.dragStarted &&
        velocityAxis != null &&
        _axisFor(measuredSpeed, session.settings.horizontalAngle) != velocityAxis) {
      return Velocity.zero;
    }
    var speed = _project(measuredSpeed, velocityAxis);
    final offset = _project(measuredOffset, velocityAxis);
    final distance = offset.distance;
    final rescued = !scale && (!session.dragStarted || session.upFling);
    if (rescued && offset.dx * speed.dx + offset.dy * speed.dy <= 0) return Velocity.zero;
    final minDistance =
        (rescued ? session.settings.preAcceptFlingDistance : null) ??
        session.settings.minFlingDistance ??
        computeHitSlop(pointer.down.kind, session.settings.gestureSettings);
    if ((!scale && distance <= minDistance) ||
        speed.distance <= (scale ? kMinFlingVelocity : session.settings.minFlingVelocity)) {
      return Velocity.zero;
    }
    final maximum = scale ? kMaxFlingVelocity : session.settings.maxFlingVelocity;
    if (speed.distance > maximum) speed = speed / speed.distance * maximum;
    if (!scale && !session.dragStarted) {
      session.acceptedAxis = velocityAxis;
      session.direction = _directionFor(
        measuredOffset == Offset.zero ? measuredSpeed : measuredOffset,
        session.settings.horizontalAngle,
      );
    }
    return Velocity(pixelsPerSecond: _toGlobalDelta(event, pointer.localPosition, speed));
  }

  TransformGestureDetails _emit(
    _TransformSession session,
    ElEventPhase phase,
    PointerEvent event, {
    Offset delta = Offset.zero,
    Velocity velocity = Velocity.zero,
    TransformRecognizer? onlyMember,
    int? routingPointer,
    Offset? positionOverride,
  }) {
    final scalePhase = _scalePhases.contains(phase);
    final geometry = _geometry(session);
    final logVelocity =
        scalePhase &&
            phase != ElEventPhase.scaleCancel &&
            session.logScaleVelocityTime != null &&
            event.timeStamp >= session.logScaleVelocityTime! &&
            event.timeStamp - session.logScaleVelocityTime! <= const Duration(milliseconds: 80)
        ? session.logScaleVelocity
        : 0.0;
    final position =
        positionOverride ??
        (scalePhase
            ? phase == ElEventPhase.scaleEnd && logVelocity != 0
                  ? session.logScaleVelocityFocal ?? session.lastScaleFocal
                  : geometry.count > 0
                  ? geometry.focal
                  : session.lastScaleFocal
            : phase == ElEventPhase.dragUpdate &&
                  session.settings.multitouchDragStrategy != MultitouchDragStrategy.latestPointer
            ? session.pointers[event.pointer]?.position ?? event.position
            : session.pointers[session.driver]?.position ?? session.lastDriverPosition ?? event.position);
    if (!scalePhase) session.lastDriverPosition = position;
    final details = TransformGestureDetails(
      phase: phase,
      started: scalePhase
          ? session.scaleStarted || phase == ElEventPhase.scaleEnd || phase == ElEventPhase.scaleCancel
          : onlyMember == null
          ? session.dragStarted || session.route.dragStartRecipients.isNotEmpty
          : session.route.dragStartRecipients.contains(onlyMember),
      pointerIds: session.acceptedOrder.toList(),
      globalPosition: position,
      // 单成员终态沿用原独立详情的默认变换值，不能混入整条路线的增量。
      delta: onlyMember == null ? delta : Offset.zero,
      dragOffset: session.dragOffset,
      dragDirection: session.direction,
      dragAxis: session.acceptedAxis,
      velocity: onlyMember == null ? velocity : Velocity.zero,
      pointerCount: geometry.count,
      scale: onlyMember == null ? session.scale : 1,
      rotation: onlyMember == null ? session.rotation : 0,
      logScaleVelocity: onlyMember == null ? logVelocity : 0,
      originalEvent: event,
    );
    _dispatchGesture(
      session.route,
      details,
      routingPointer: routingPointer,
      skipCancelingMembers: onlyMember == null,
      prepare: onlyMember == null ? null : (member) => identical(member, onlyMember) ? details : null,
    );
    return details;
  }

  /// 终止当前成员的家族订阅，其他成员及已接受的指针继续识别。
  void cancelMember(int? pointer, {bool cancelDrag = true, bool cancelScale = true, PointerEvent? event}) {
    if (pointer == null) {
      for (final tracked in _routes.keys.toList()) {
        _cancelMemberPointer(tracked, cancelDrag: cancelDrag, cancelScale: cancelScale, event: event, wholeRoute: true);
      }
      return;
    }
    _cancelMemberPointer(pointer, cancelDrag: cancelDrag, cancelScale: cancelScale, event: event);
  }

  void _cancelMemberPointer(
    int pointer, {
    required bool cancelDrag,
    required bool cancelScale,
    PointerEvent? event,
    bool wholeRoute = false,
  }) {
    final route = _routes[pointer];
    final owner = route?.owner;
    if (route == null || owner is! TransformRecognizer) return;
    final session = owner._session;
    if (session == null || !identical(session.route, route)) return;
    final source = event ?? session.pointers[pointer]?.event;
    if (source == null) return;
    final input = _cooperation?._observationFor(pointer);
    final downs = route.subscription(this).downs;
    if (!wholeRoute &&
        input != null &&
        !input.active &&
        (!input.scaleAllowed || !_scalePhases.any((phase) => _routeHasHandler(route, phase))) &&
        downs.keys.any((id) => id != pointer && session.pointers[id]?.accepted == true) == true) {
      // 新触点失权只退出自己的订阅，不能结束另一根仍已获准的拖拽。
      downs.remove(pointer);
      final tracked = session.pointers[pointer];
      if (identical(owner, this) && tracked != null && !owner._hasActiveReceiver(pointer)) {
        owner._removePointer(session, tracked, source, canceled: true);
      }
      return;
    }
    for (final family in [if (cancelDrag) _GestureFamily.drag, if (cancelScale) _GestureFamily.scale]) {
      final ElEventPhase phase = family == .drag ? .dragCancel : .scaleCancel;
      owner._terminateMember(session, this, phase, source, routingPointer: pointer);
    }
  }

  void _terminateMember(
    _TransformSession session,
    TransformRecognizer member,
    ElEventPhase phase,
    PointerEvent event, {
    _TransformPointer? tracked,
    int? routingPointer,
  }) {
    final route = session.route;
    final family = phase._family;
    // 显式取消须先使旧回调失效，物理退出则只在取得终态锁后失效。
    if (tracked == null) route.invalidate(member, family);
    final state = route.subscription(member).phase(family);
    if (state.excluded || state.canceling) return;
    state.canceling = true;
    if (tracked != null) route.invalidate(member, family);
    try {
      if (tracked != null || route.members.indexOf(member) <= (route.observedEnds[family] ?? -1)) {
        _emit(
          session,
          phase,
          event,
          onlyMember: member,
          routingPointer: routingPointer ?? event.pointer,
          positionOverride: tracked?.position,
          velocity: phase == .dragEnd && tracked != null ? _flingVelocity(session, tracked, event) : Velocity.zero,
        );
      }
    } finally {
      state.excluded = true;
      state.canceling = false;
    }
  }

  @override
  void _stopOtherRoutes(_GestureRoute route, GestureDetails details) {
    if (details.phase != ElEventPhase.dragStart) return;
    final cooperation = _cooperation;
    final dispatch = cooperation?._observations[details.pointer]?.dispatch;
    if (cooperation == null || dispatch == null) return;
    final start = dispatch.indexOfTeam(cooperation);
    for (final input in dispatch.members.skip(start + 1).toList()) {
      for (final ancestor in input.team._members.whereType<TransformRecognizer>().toList()) {
        if (!route.members.contains(ancestor)) {
          ancestor.cancelMember(details.pointer, cancelScale: false, event: details.originalEvent);
        }
      }
    }
  }

  @override
  void _requestAccept(_GestureRoute route, int pointer) {
    final session = _session;
    if (!_canceling && session != null && identical(session.route, route) && session.pointers.containsKey(pointer)) {
      resolvePointer(pointer, GestureDisposition.accepted);
    }
  }

  @override
  void _cancelRoutePointer(_GestureRoute route, int pointer, PointerEvent? event) {
    final session = _session;
    final tracked = session?.pointers[pointer];
    if (session != null && tracked != null && identical(session.route, route)) {
      _removePointer(session, tracked, event ?? tracked.event, canceled: true);
    }
  }

  @override
  void cancel() {
    if (_disposed || _canceling) return;
    _canceling = true;
    try {
      final session = _session;
      if (session != null) {
        _finishSession(session, session.pointers.values.last.event, canceled: true);
      }
    } finally {
      _canceling = false;
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'El transform';

  @override
  void dispose() {
    if (_disposed || _disposing || _canceling) return;
    _disposing = true;
    final session = _session;
    if (session == null) {
      super.dispose();
      return;
    }
    final successor = session.route.members
        .whereType<TransformRecognizer>()
        .where(
          (member) =>
              !identical(member, this) &&
              !member._disposed &&
              member._session == null &&
              member.hasActiveInput &&
              (!session.dragStarted ||
                  member.callbacks[ElEventPhase.dragStart] == null ||
                  session.route.dragStartRecipients.contains(member)),
        )
        .firstOrNull;
    if (successor != null) {
      if (_isCurrent(session)) {
        cancelMember(null);
        if (_isCurrent(session) && !successor._disposed) {
          _session = null;
          successor._session = session;
          session.route.owner = successor;
          for (final pointer in session.pointers.values) {
            _transferTrackingTo(successor, pointer.down.pointer);
          }
        }
      }
    }
    if (_session != null) cancel();
    super.dispose();
  }

  static Axis _axisFor(Offset delta, double horizontalAngle) =>
      math.atan2(delta.dy.abs(), delta.dx.abs()) <= horizontalAngle ? Axis.horizontal : Axis.vertical;

  static AxisDirection _directionFor(Offset delta, double horizontalAngle) =>
      switch (_axisFor(delta, horizontalAngle)) {
        Axis.horizontal => delta.dx < 0 ? AxisDirection.left : AxisDirection.right,
        Axis.vertical => delta.dy < 0 ? AxisDirection.up : AxisDirection.down,
      };

  static Offset _project(Offset delta, Axis? axis) => switch (axis) {
    Axis.horizontal => Offset(delta.dx, 0),
    Axis.vertical => Offset(0, delta.dy),
    null => delta,
  };

  static Offset _toGlobalDelta(PointerEvent event, Offset position, Offset delta) =>
      transformGestureDelta(event.transform == null ? null : Matrix4.tryInvert(event.transform!), position, delta);

  static double _angleDelta(double value) => math.atan2(math.sin(value), math.cos(value));

  static _TransformGeometry _geometry(_TransformSession session, {bool acceptedOnly = true}) {
    final pointers = session.pointers.values
        .where((pointer) => !acceptedOnly || pointer.accepted && pointer.delivered)
        .toList();
    if (pointers.isEmpty) return const _TransformGeometry();
    final touch = pointers.where((pointer) => !pointer.panZoom).toList();
    final panZoom = pointers.where((pointer) => pointer.panZoom).toList();
    final focal = pointers.fold(Offset.zero, (sum, pointer) => sum + pointer.position) / pointers.length.toDouble();
    final touchFocal = touch.isEmpty
        ? Offset.zero
        : touch.fold(Offset.zero, (sum, pointer) => sum + pointer.position) / touch.length.toDouble();
    final span = touch.isEmpty
        ? 0.0
        : touch.fold(0.0, (sum, pointer) => sum + (pointer.position - touchFocal).distance) / touch.length;
    final line = touch.length < 2 ? Offset.zero : touch[1].position - touch[0].position;
    return _TransformGeometry(
      focal: focal,
      span: span,
      angle: line.direction,
      panScale: panZoom.fold(1.0, (scale, pointer) => scale * pointer.panScale),
      panRotation: panZoom.fold(0.0, (sum, pointer) => sum + pointer.panRotation),
      count: touch.length + 2 * panZoom.length,
    );
  }
}

class _TransformSession {
  _TransformSession(this.route, this.settings, this.axis, this.lockAxis, this.capabilities)
    : rotationStartEnabled = settings.rotationStartEnabled;

  final _GestureRoute route;
  _TransformSettings settings;
  Axis? axis;
  bool lockAxis;
  _TransformCapabilities capabilities;
  bool get hasScale => capabilities.zoom || capabilities.rotate;
  bool rotationStartEnabled;
  DragCooperation? cooperation;
  PointerEvent? lastEvent;
  PointerEvent? deferredStartEvent;
  final Map<int, _TransformPointer> pointers = <int, _TransformPointer>{};
  final List<int> acceptedOrder = <int>[];
  int? driver;
  bool downDispatched = false;
  bool dragThresholdMet = false;
  bool scaleThresholdMet = false;
  bool dragStarted = false;
  bool upFling = false;
  bool scaleStarted = false;
  Axis? acceptedAxis;
  AxisDirection? direction;
  Offset dragOffset = Offset.zero;
  Offset? lastDriverPosition;
  _TransformGeometry? candidateGeometry;
  _TransformGeometry? scaleGeometry;
  Offset lastScaleFocal = Offset.zero;
  double scale = 1;
  double scaleAtRebase = 1;
  double rotation = 0;
  double lastRotationAngle = 0;
  double lastPanRotation = 0;
  Duration? lastScaleSampleTime;
  Duration? logScaleVelocityTime;
  double logScaleVelocity = 0;
  Offset? logScaleVelocityFocal;
  bool clearScaleVelocityOnPan = false;
  Duration? frameTimeStamp;
  final Map<int, Offset> frameDeltas = {};
  Offset lastPanFrameDelta = Offset.zero;
}

class _TransformPointer {
  _TransformPointer(this.down, this.velocityTracker)
    : event = down,
      position = down.position,
      localPosition = down.localPosition,
      lastOutputLocal = down.localPosition {
    addVelocitySample(down.timeStamp, down.localPosition);
  }

  final PointerEvent down;
  PointerEvent event;
  Offset position;
  Offset localPosition;
  Offset lastOutputLocal;
  final List<(Duration, Offset)> velocitySamples = [];
  VelocityTracker velocityTracker;

  // 只保存官方拟合器需要的有限真实样本，释放时再拟合，避免逐帧求解开销。
  void addVelocitySample(Duration time, Offset position) {
    velocityTracker.addPosition(time, position);
    velocitySamples.add((time, position));
    if (velocitySamples.length > 20) velocitySamples.removeAt(0);
  }

  bool accepted = false;
  bool delivered = false;
  bool dragThresholdMet = false;
  Axis? candidateAxis;
  AxisDirection? direction;
  double panScale = 1;
  double panRotation = 0;
  bool get panZoom => down is PointerPanZoomStartEvent;
}

class _TransformGeometry {
  const _TransformGeometry({
    this.focal = Offset.zero,
    this.span = 0,
    this.angle = 0,
    this.panScale = 1,
    this.panRotation = 0,
    this.count = 0,
  });

  final Offset focal;
  final double span;
  final double angle;
  final double panScale;
  final double panRotation;
  final int count;
}

typedef _TransformCapabilities = ({bool drag, bool zoom, bool rotate});

typedef _TransformSettings = ({
  double? startDistance,
  double horizontalAngle,
  double? minFlingDistance,
  double? preAcceptFlingDistance,
  double minFlingVelocity,
  double maxFlingVelocity,
  bool rotationStartEnabled,
  bool startScaleOnPointerDown,
  MultitouchDragStrategy multitouchDragStrategy,
  GestureVelocityTrackerBuilder velocityTrackerBuilder,
  double? Function()? displayRefreshRate,
  DeviceGestureSettings? gestureSettings,
});
