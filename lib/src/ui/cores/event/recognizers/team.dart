part of 'index.dart';

/// 通过官方竞技场协调同次输入的识别器，不保存重复的手势阶段状态。
///
/// parent 连接元素关系，是否共享官方席位由成员自身的识别意图决定。
final class ElGestureArenaTeam extends GestureArenaTeam {
  /// 创建协作团队，识别器通过官方 team 属性加入。
  ElGestureArenaTeam({this.parent}) {
    captain = _captain;
  }

  /// 元素对应的祖先团队，已开始输入沿用原有官方席位。
  ElGestureArenaTeam? parent;

  /// 原始输入观察者，返回 false 截断后续祖先的开始事件；不会因此报名竞技场。
  bool Function(PointerEvent event, ElGestureCancelReason? reason)?
  onPointerEvent;

  /// 原始触控板消费者可预先保留席位，后续接受仍须服从官方结果。
  bool acceptsPanZoom = false;

  /// 根据点击意图、拖拽轴与阈值筛选自动挂接的父级，手工冒泡链默认不筛选。
  bool matchParentGestures = false;

  late final _CooperativeCaptain _captain = _CooperativeCaptain(this);
  final Map<int, _CooperativePointer> _pointers = {};
  final Set<_ElGestureRecognizer> _members = {};
  final Map<int, _PointerObservation> _observations = {};
  static final _dispatches = Expando<_PointerDispatch>('El raw input');
  PointerEvent? _currentEvent;
  _PointerObservation? _currentObservation;
  PointerEvent? _rawEvent;
  bool _disposed = false;

  /// 原始输入回调是否正在投递，供声明更新及时结清旧订阅。
  bool get isDispatching => _rawEvent != null;

  /// 当前是否正在投递物理终态。
  bool get isDispatchingTerminal => _terminal(_rawEvent);

  /// 当前元素尚未结束且未被排他的原始指针数。
  int get pointerCount => _observations.values
      .where((input) => input.active && !_terminal(input.event))
      .length;

  /// 当前指针的物理开始事件，可用于约束延后调用的独占请求。
  PointerEvent? downEventFor(int pointer) => _observations[pointer]?.down;

  bool _sharesArenaWith(ElGestureArenaTeam other) {
    if (!matchParentGestures || !other.matchParentGestures) return true;
    final press = _members.whereType<ElPressGestureRecognizer>().firstOrNull;
    final otherPress = other._members
        .whereType<ElPressGestureRecognizer>()
        .firstOrNull;
    if (press != null &&
        otherPress != null &&
        press.competeForTap != otherPress.competeForTap) {
      return false;
    }
    final transform = _members
        .whereType<ElTransformGestureRecognizer>()
        .firstOrNull;
    final otherTransform = other._members
        .whereType<ElTransformGestureRecognizer>()
        .firstOrNull;
    return transform == null ||
        otherTransform == null ||
        transform._compatibleWith(otherTransform);
  }

  ElGestureArenaTeam get _arenaRoot {
    final seen = <ElGestureArenaTeam>{};
    var result = this;
    while (result.parent != null) {
      if (!seen.add(result)) throw StateError('手势团队 parent 链不能循环。');
      if (!_sharesArenaWith(result.parent!)) break;
      result = result.parent!;
    }
    return result;
  }

  @override
  GestureArenaEntry add(int pointer, GestureArenaMember member) {
    final root = _arenaRoot;
    return root._add(pointer, member);
  }

  GestureArenaEntry _add(int pointer, GestureArenaMember member) {
    final source = switch (member) {
      _ElGestureRecognizer() =>
        member._cooperation?._observations[pointer]?.dispatch,
      _ObservedArenaMember() => member.team._observations[pointer]?.dispatch,
      _ => null,
    };
    final previous = _pointers[pointer];
    if (previous != null &&
        source != null &&
        !identical(source, previous.dispatch)) {
      _pointers.remove(pointer);
    }
    final state = _pointers.putIfAbsent(pointer, () {
      final state = _CooperativePointer()..dispatch = source;
      state.captainEntry = super.add(pointer, _captain);
      return state;
    });
    final delegate = _CooperativeMember(state, member);
    state.members.add(delegate);
    return _CooperativeEntry(super.add(pointer, delegate), delegate, pointer);
  }

  /// 记录真实命中输入并投递原始回调，返回当前元素是否可以接收该输入。
  bool observePointer(PointerEvent event) {
    final start =
        event is PointerDownEvent || event is PointerPanZoomStartEvent;
    if (_disposed) return false;
    if (start) {
      final key = event.original ?? event;
      var dispatch = _dispatches[key];
      if (dispatch == null ||
          dispatch.members.isEmpty ||
          !identical(
            dispatch.members.first._observations[event.pointer]?.dispatch,
            dispatch,
          )) {
        dispatch = _PointerDispatch();
        _dispatches[key] = dispatch;
      }
      if (dispatch.stopped) return false;
      final input = _PointerObservation(dispatch, event, _arenaRoot);
      _observations[event.pointer] = input;
      dispatch.members.add(this);
      dispatch.arenas.add(input.arena);
      if (event is PointerPanZoomStartEvent && acceptsPanZoom) {
        input.entry = add(event.pointer, _ObservedArenaMember(this));
      }
      if (!_hasPendingOther(input)) {
        input.notified = true;
        if (!_deliver(event, null)) dispatch.stopped = true;
      }
      return input.active;
    }
    final input = _observations[event.pointer];
    if (input == null) return false;
    input.event = event;
    if (_terminal(event)) {
      scheduleMicrotask(() => _releaseObservation(event.pointer, input));
    }
    if (!input.active) return false;
    _deliver(
      event,
      event is PointerCancelEvent
          ? ElGestureCancelReason.pointerCanceled
          : null,
    );
    return input.active;
  }

  bool _deliver(PointerEvent event, ElGestureCancelReason? reason) {
    var proceed = true;
    _during(event, () {
      proceed = onPointerEvent?.call(event, reason) ?? true;
    }, raw: true);
    return proceed;
  }

  void _during(
    PointerEvent event,
    void Function() callback, {
    bool raw = false,
  }) {
    final previousEvent = _currentEvent;
    final previousInput = _currentObservation;
    final previousRaw = _rawEvent;
    if (raw) _rawEvent = event;
    _currentEvent = event;
    _currentObservation = _observations[event.pointer];
    try {
      callback();
    } finally {
      _currentEvent = previousEvent;
      _currentObservation = previousInput;
      _rawEvent = previousRaw;
    }
  }

  bool _hasPendingOther(_PointerObservation input) =>
      input.dispatch.members.any(
        (member) =>
            !identical(member, this) &&
            member._observations[input.down.pointer]?.request != null,
      );

  bool _participates(int pointer) {
    if (onPointerEvent == null) return true;
    final input = _observations[pointer];
    return input != null && !_hasPendingOther(input);
  }

  /// 请求当前元素独占输入，成员失权直接通过识别器取消，不复制其阶段状态。
  ///
  /// 延后调用时传入 [downEvent]，避免指针编号复用后请求作用于下一次输入。
  void claimPointer(
    int pointer, {
    PointerEvent? downEvent,
    bool cancelTap = false,
    bool allowScaleUpgrade = false,
  }) {
    final input = _observations[pointer];
    if (input == null ||
        downEvent != null && !identical(input.down, downEvent) ||
        !input.active ||
        _disposed ||
        input.arena._pointers[pointer]?.result == GestureDisposition.rejected ||
        _currentObservation != null &&
            _currentObservation!.down.pointer == pointer &&
            !identical(_currentObservation, input)) {
      return;
    }
    final accepted = input.dispatch.arenas.any(
      (arena) =>
          arena._pointers[pointer]?.result == GestureDisposition.accepted,
    );
    final canEnroll =
        (_currentEvent is PointerDownEvent ||
            _currentEvent is PointerPanZoomStartEvent) &&
        input.arena._pointers[pointer]?.result == null;
    if (!accepted && input.arena._pointers[pointer] == null && !canEnroll) {
      return;
    }
    input.request = (
      cancelTap: cancelTap || (input.request?.cancelTap ?? false),
      allowScale: allowScaleUpgrade,
    );
    if (!accepted && input.entry == null && canEnroll) {
      input.entry = add(pointer, _ObservedArenaMember(this));
    }
    for (final member in _members.toList()) {
      member.acceptPointer(pointer);
    }
    input.entry?.resolve(GestureDisposition.accepted);
    _settleRequests(pointer, input.dispatch);
  }

  void _settleRequests(int pointer, _PointerDispatch? dispatch) {
    if (dispatch == null ||
        !dispatch.arenas.any(
          (arena) =>
              arena._pointers[pointer]?.result == GestureDisposition.accepted,
        )) {
      return;
    }
    for (final owner in dispatch.members.toList()) {
      final input = owner._observations[pointer];
      if (input == null ||
          !identical(input.dispatch, dispatch) ||
          !input.active) {
        continue;
      }
      final request = input.request;
      if (request == null) continue;
      input.request = null;
      for (final target in dispatch.members.toList()) {
        final other = target._observations[pointer];
        if (other == null ||
            !identical(other.dispatch, dispatch) ||
            !other.active) {
          continue;
        }
        if (identical(target, owner)) {
          if (request.cancelTap) {
            for (final press
                in target._members
                    .whereType<ElPressGestureRecognizer>()
                    .toList()) {
              press.rejectTap(
                pointer,
                reason: ElGestureCancelReason.longPressAccepted,
              );
            }
          }
        } else {
          other.active = false;
          if (other.notified) {
            target._deliver(
              _cancelEvent(other),
              ElGestureCancelReason.arenaRejected,
            );
          }
          for (final member in target._members.toList()) {
            if (member is ElPressGestureRecognizer) {
              member._cancelMember(
                pointer,
                ElGestureCancelReason.arenaRejected,
              );
            }
            if (member is ElTransformGestureRecognizer) {
              member.cancelMember(pointer, cancelScale: !request.allowScale);
            }
          }
        }
      }
    }
  }

  void _cancelDragForScale(Iterable<int> pointers) {
    final transforms = <ElTransformGestureRecognizer>{};
    for (final pointer in pointers) {
      for (final team in _observations[pointer]?.dispatch.members ?? [this]) {
        transforms.addAll(
          team._members.whereType<ElTransformGestureRecognizer>(),
        );
      }
    }
    for (final member in transforms) {
      if (member.cancelDragOnScale) {
        member.cancelMember(null, cancelScale: false);
      }
    }
  }

  /// 结清当前团队成员的按压订阅，并明确取消原因。
  void cancelPress(
    int pointer, {
    ElGestureCancelReason reason = ElGestureCancelReason.canceled,
  }) {
    for (final member
        in _members.whereType<ElPressGestureRecognizer>().toList()) {
      member._cancelMember(pointer, reason);
    }
  }

  /// 结清当前元素的输入观察与识别订阅，不取消其他元素。
  void cancel() {
    for (final input in _observations.values.toList()) {
      if (!input.active) continue;
      input.active = false;
      if (!_terminal(input.event) && input.notified) {
        _deliver(_cancelEvent(input), ElGestureCancelReason.canceled);
      }
      input.entry?.resolve(GestureDisposition.rejected);
    }
    for (final member in _members.toList()) {
      if (member is ElPressGestureRecognizer) member.cancelMember();
      if (member is ElTransformGestureRecognizer) member.cancelMember(null);
    }
  }

  /// 销毁团队自己的观察记录，官方席位仍按既有规则结算。
  void dispose() {
    if (_disposed) return;
    cancel();
    _disposed = true;
    for (final entry in _observations.entries.toList()) {
      _releaseObservation(entry.key, entry.value);
    }
  }

  void _releaseObservation(int pointer, _PointerObservation input) {
    if (!identical(_observations[pointer], input)) return;
    _observations.remove(pointer);
    final dispatch = input.dispatch;
    if (dispatch.members.every(
      (member) => !identical(member._observations[pointer]?.dispatch, dispatch),
    )) {
      for (final arena in dispatch.arenas) {
        if (identical(arena._pointers[pointer]?.dispatch, dispatch)) {
          arena._pointers.remove(pointer);
        }
      }
    }
  }

  static bool _terminal(PointerEvent? event) =>
      event is PointerUpEvent ||
      event is PointerCancelEvent ||
      event is PointerPanZoomEndEvent;
  static PointerCancelEvent _cancelEvent(_PointerObservation input) =>
      PointerCancelEvent(
        pointer: input.down.pointer,
        position: input.event.position,
        timeStamp: input.event.timeStamp,
        kind: input.down.kind == PointerDeviceKind.trackpad
            ? PointerDeviceKind.unknown
            : input.down.kind,
      );
}

/// 只冻结原始输入的实际投递成员，官方结果保存在对应的竞技场团队状态中。
final class _PointerDispatch {
  final members = <ElGestureArenaTeam>[];
  final arenas = <ElGestureArenaTeam>{};
  bool stopped = false;
}

final class _PointerObservation {
  _PointerObservation(this.dispatch, this.down, this.arena) : event = down;
  final _PointerDispatch dispatch;
  final PointerEvent down;
  final ElGestureArenaTeam arena;
  PointerEvent event;
  bool active = true;
  bool notified = false;
  GestureArenaEntry? entry;
  ({bool cancelTap, bool allowScale})? request;
}

final class _ObservedArenaMember extends GestureArenaMember {
  _ObservedArenaMember(this.team);
  final ElGestureArenaTeam team;
  @override
  void acceptGesture(int pointer) =>
      team._settleRequests(pointer, team._observations[pointer]?.dispatch);
  @override
  void rejectGesture(int pointer) {
    team._observations[pointer]?.entry = null;
  }
}

final class _CooperativePointer {
  late final GestureArenaEntry captainEntry;
  final List<_CooperativeMember> members = [];
  GestureDisposition? result;
  _PointerDispatch? dispatch;
}

final class _CooperativeCaptain extends GestureArenaMember {
  _CooperativeCaptain(this.team);
  final ElGestureArenaTeam team;

  void _finish(int pointer, GestureDisposition result) {
    final state = team._pointers[pointer];
    if (state == null) return;
    state.result = result;
    if (state.dispatch == null) team._pointers.remove(pointer);
    for (final member in state.members.toList()) {
      member.finish(pointer, result);
    }
    team._settleRequests(pointer, state.dispatch);
  }

  @override
  void acceptGesture(int pointer) =>
      _finish(pointer, GestureDisposition.accepted);

  @override
  void rejectGesture(int pointer) =>
      _finish(pointer, GestureDisposition.rejected);
}

final class _CooperativeMember extends GestureArenaMember {
  _CooperativeMember(this.state, this.member);
  final _CooperativePointer state;
  final GestureArenaMember member;
  bool withdrawn = false;
  bool notified = false;

  void finish(int pointer, GestureDisposition disposition) {
    if (notified) return;
    notified = true;
    if (!withdrawn && disposition == GestureDisposition.accepted) {
      member.acceptGesture(pointer);
    } else {
      member.rejectGesture(pointer);
    }
  }

  @override
  void acceptGesture(int pointer) =>
      finish(pointer, GestureDisposition.accepted);

  @override
  void rejectGesture(int pointer) {
    // 官方团队先拒绝队长以外的成员，再通知队长获胜；等队长给出团队最终结果。
    if (withdrawn || state.result != null) {
      finish(pointer, state.result ?? GestureDisposition.rejected);
    }
  }
}

final class _CooperativeEntry implements GestureArenaEntry {
  _CooperativeEntry(this.entry, this.delegate, this.pointer);
  final GestureArenaEntry entry;
  final _CooperativeMember delegate;
  final int pointer;
  bool resolved = false;

  @override
  void resolve(GestureDisposition disposition) {
    if (resolved || delegate.state.result != null) return;
    resolved = true;
    if (disposition == GestureDisposition.rejected) delegate.withdrawn = true;
    entry.resolve(disposition);
    final state = delegate.state;
    if (state.result == null &&
        state.members.every((member) => member.withdrawn)) {
      state.captainEntry.resolve(GestureDisposition.rejected);
    }
  }
}
