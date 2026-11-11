part of 'dispatcher.dart';

/// 显式认领才需要的成员资格，旧赢家离场后仍保留失权记录直到物理终态。
final class _PointerOwnership {
  EventDispatcher? owner;
  EventDispatcher? pendingOwner;
  bool cancelSelfTap = false;
  bool allowScaleUpgrade = false;
  final retired = <EventDispatcher>{};
  final scaleAllowed = <EventDispatcher>{};
  // 未收到按下或已收到取消的成员，不能再补发原始取消。
  final rawInactive = <EventDispatcher>{};
}

extension _OwnershipEvents on EventDispatcher {
  void _bindOwnership(ElEventDetails details) {
    final input = details.pointerEvent;
    if (input == null || input is PointerHoverEvent || input is PointerSignalEvent) return;
    final route = EventDispatcher._routes[input.pointer];
    if (route == null || !route.hosts.contains(this)) return;
    EventDetailsAccess.installEagerResolver(_resolveEagerGesture);
    EventDetailsAccess.installAncestorDragResolver(_resolveAncestorDragConsumer);
    details.bindEagerSource(this, route.down);
  }

  bool _canStartOwnedScale() {
    final points = _scaleState?.points;
    if (points == null || points.isEmpty) return false;
    if (EventDispatcher._routes.values.any(
      (route) =>
          !route._closed &&
          !route._ended &&
          (route._ownership?.retired.contains(this) ?? false) &&
          !(route._ownership?.scaleAllowed.contains(this) ?? false),
    )) {
      return false;
    }
    final routes = points.keys.map((pointer) => EventDispatcher._routes[pointer]).toList();
    if (!routes.any((route) => route?._ownership != null)) return true;
    return routes.every((route) => route != null && route._canTakeScale(this));
  }

  bool _commitOwnedScale() {
    final state = _scaleState;
    if (state == null || state.points.isEmpty) return false;
    final routes = state.points.keys.map((pointer) => EventDispatcher._routes[pointer]).toList();
    if (!routes.any((route) => route?._ownership != null)) return true;
    if (!routes.every((route) => route != null && route._canTakeScale(this))) return false;
    final notifications = <VoidCallback>[];
    for (final route in routes) {
      route!._commitOwnership(this, cancelSelfTap: true, allowScaleUpgrade: false, notifications: notifications);
    }
    for (final notify in notifications) {
      notify();
    }
    return _live && identical(_scaleState, state) && state.points.isNotEmpty;
  }
}

bool _resolveAncestorDragConsumer(ElEventDetails details) {
  final owner = details.eagerOwner;
  final down = details.eagerDown;
  if (owner is! EventDispatcher || down == null || !owner._live) return false;
  final route = EventDispatcher._routes[down.pointer];
  if (route == null || !identical(route.down, down) || route._closed || route._rejected || !route._allowsRaw(owner)) {
    return false;
  }
  final index = route.hosts.indexOf(owner);
  if (index < 0) return false;
  final axis = details.dragAxis;
  for (var i = index + 1; i < route.hosts.length; i++) {
    final host = route.hosts[i];
    if (!host._live || !route._allowsRaw(host) || host._scaling) continue;
    if (axis == null ? !host._shape.drag : !host._shape.acceptsDrag(axis)) continue;
    if (route.drags.contains(host) ||
        route._dragConfiguration?.deferredStarts?.containsKey(host) == true ||
        host._drag?.route == route) {
      return true;
    }
  }
  return false;
}

void _resolveEagerGesture(ElEventDetails details, bool cancelSelfTap, bool allowScaleUpgrade) {
  final owner = details.eagerOwner;
  final down = details.eagerDown;
  if (owner is! EventDispatcher || down == null || !owner._live) return;
  final route = EventDispatcher._routes[down.pointer];
  if (route == null || !identical(route.down, down) || route._closed || route._rejected) return;
  final points = owner._scaleState?.points;
  if (points != null &&
      points.length >= 2 &&
      (details.phase == .scaleStart || details.phase == .scaleUpdate || details.phase == .rotationUpdate)) {
    final routes = points.keys.map((pointer) => EventDispatcher._routes[pointer]).toList();
    if (!routes.every((route) => route != null && route._canTakeScale(owner))) return;
    final notifications = <VoidCallback>[];
    for (final route in routes) {
      route!._commitOwnership(
        owner,
        cancelSelfTap: cancelSelfTap,
        allowScaleUpgrade: allowScaleUpgrade,
        notifications: notifications,
      );
    }
    for (final notify in notifications) {
      notify();
    }
    return;
  }
  route._requestOwnership(owner, cancelSelfTap: cancelSelfTap, allowScaleUpgrade: allowScaleUpgrade);
}

extension _RouteOwnership on _Route {
  bool _allowsRaw(EventDispatcher host) {
    final state = _ownership;
    return state == null ||
        !state.retired.contains(host) && (state.pendingOwner == null || identical(state.pendingOwner, host));
  }

  bool interceptRaw(EventDispatcher host, ElEventPhase phase, PointerEvent input) {
    if (!_allowsRaw(host)) {
      final state = _ownership!;
      if (phase == .pointerDown || phase == .pointerPanZoomStart) state.rawInactive.add(host);
      // 未决认领失败时恢复真实命中输入；已经失权的成员不再排队。
      if (state.pendingOwner != null && !state.retired.contains(host)) (_pendingRaw ??= []).add((host, phase, input));
      return true;
    }
    if (phase != .pointerMove && phase != .pointerPanZoomUpdate) return false;
    final index = hosts.indexOf(host);
    final innerGesture =
        index > 0 &&
        hosts
            .take(index)
            .any(
              (inner) =>
                  _allowsRaw(inner) && (drags.contains(inner) || scales.contains(inner) || inner._drag?.route == this),
            );
    if (!innerGesture) return false;
    (_pendingRaw ??= []).add((host, phase, input));
    return true;
  }

  void _flushRawFor(EventDispatcher host, PointerEvent event) {
    final pending = _pendingRaw;
    if (pending == null) return;
    final original = event.original ?? event;
    final index = pending.indexWhere(
      (entry) => identical(entry.$1, host) && identical(entry.$3.original ?? entry.$3, original),
    );
    if (index < 0) return;
    final entry = pending.removeAt(index);
    if (host._live && hosts.contains(host) && _allowsRaw(host)) host._dispatchRaw(entry.$2, entry.$3);
    if (pending.isEmpty && identical(_pendingRaw, pending)) _pendingRaw = null;
  }

  void _abandonPendingOwnership() {
    final state = _ownership;
    if (state?.pendingOwner == null) return;
    state!.pendingOwner = null;
    if (state.owner == null) _ownership = null;
    final pending = _pendingRaw;
    _pendingRaw = null;
    if (pending == null) return;
    for (final (host, phase, input) in pending) {
      if (host._live && hosts.contains(host) && !interceptRaw(host, phase, input)) host._dispatchRaw(phase, input);
    }
  }

  bool _canTakeScale(EventDispatcher host) {
    if (_closed || _rejected || _ended || !_accepted || !hosts.contains(host) || !host._live) return false;
    final state = _ownership;
    if (state == null) return true;
    if (state.owner != null && (!state.owner!._live || !hosts.contains(state.owner))) return false;
    return identical(state.owner, host) ||
        state.owner == null && (state.pendingOwner == null || identical(state.pendingOwner, host)) ||
        state.scaleAllowed.contains(host);
  }

  void _requestOwnership(EventDispatcher owner, {required bool cancelSelfTap, required bool allowScaleUpgrade}) {
    if (!hosts.contains(owner) || !_allowsRaw(owner) || _closed || _rejected || !owner._live) return;
    final state = _ownership ??= _PointerOwnership();
    if (state.owner != null && !state.owner!._live) return;
    if (_accepted) {
      final notifications = <VoidCallback>[];
      _commitOwnership(
        owner,
        cancelSelfTap: cancelSelfTap,
        allowScaleUpgrade: allowScaleUpgrade,
        notifications: notifications,
      );
      for (final notify in notifications) {
        notify();
      }
      return;
    }
    state.pendingOwner = owner;
    state.cancelSelfTap = state.cancelSelfTap || cancelSelfTap;
    state.allowScaleUpgrade = allowScaleUpgrade;
    if (!_begun) _entry ??= GestureBinding.instance.gestureArena.add(pointer, this);
    claim();
  }

  void _commitPendingOwnership() {
    final state = _ownership;
    final owner = state?.pendingOwner;
    if (state == null || owner == null) return;
    if (!owner._live || !hosts.contains(owner)) {
      _abandonPendingOwnership();
      return;
    }
    final notifications = <VoidCallback>[];
    _commitOwnership(
      owner,
      cancelSelfTap: state.cancelSelfTap,
      allowScaleUpgrade: state.allowScaleUpgrade,
      notifications: notifications,
    );
    for (final notify in notifications) {
      notify();
    }
  }

  void _commitOwnership(
    EventDispatcher owner, {
    required bool cancelSelfTap,
    required bool allowScaleUpgrade,
    required List<VoidCallback> notifications,
  }) {
    final state = _ownership ??= _PointerOwnership();
    state.owner = owner;
    state.pendingOwner = null;
    state.retired.remove(owner);
    state.scaleAllowed.remove(owner);
    final losers = hosts.where((host) => host != owner && !state.retired.contains(host)).toList();
    // 多指认领先提交全部资格，再调用任意业务取消，避免取消回调观察到半提交状态。
    for (final host in losers) {
      state.retired.add(host);
      if (allowScaleUpgrade && host._shape.scale && host._canTransform(down)) {
        state.scaleAllowed.add(host);
        if (!scales.contains(host)) {
          scales.add(host);
          host._ensureScale().points[pointer] = position;
          host._rebase();
        }
      }
    }
    _pendingRaw?.removeWhere((entry) => state.retired.contains(entry.$1));
    if (_pendingRaw?.isEmpty == true) _pendingRaw = null;
    for (final host in losers) {
      notifications.add(() => _cancelOwnedMember(host, preserveScale: state.scaleAllowed.contains(host)));
    }
    if (cancelSelfTap) notifications.add(() => _cancelTap(owner, .selfGestureAccepted));
  }

  void _cancelOwnedMember(EventDispatcher host, {required bool preserveScale}) {
    if (!hosts.contains(host)) return;
    final revision = host._revision;
    if (host._live && _ownership!.rawInactive.add(host)) {
      final input = PointerCancelEvent(
        pointer: pointer,
        device: down.device,
        kind: down.kind == PointerDeviceKind.trackpad ? PointerDeviceKind.unknown : down.kind,
        position: position,
        timeStamp: last.timeStamp,
        viewId: down.viewId,
      );
      host._invoke(host._pointer(.pointerCancel, input, reason: .otherGestureAccepted));
    }
    if (host._revision == revision) {
      _cancelTap(host, .otherGestureAccepted);
    } else {
      taps.remove(host);
    }
    pressed.remove(host);
    drags.remove(host);
    _dragConfiguration?.deferredStarts?.remove(host);
    _dragConfiguration?.deferMoves?.remove(host);
    if (host._drag?.route == this) host._endDrag(last, null);
    if (!preserveScale && scales.remove(host) && host._scaleState?.points.remove(pointer) != null) {
      host._endScale(last, null);
      host._pruneScale();
    }
    if (host._pressed == pointer) host._release();
  }

  void stopDragPropagation(EventDispatcher owner, ElEventPhase phase) {
    if (phase != .dragStart) return;
    final outside = hosts.skip(hosts.indexOf(owner) + 1).toList();
    drags.removeWhere(outside.contains);
    for (final host in outside) {
      _dragConfiguration?.deferredStarts?.remove(host);
      if (host._drag?.route == this) host._endDrag(last, null);
    }
  }

  void _tryOwnedScaleUpgrades() {
    for (final host in scales.toList()) {
      final points = host._scaleState?.points;
      if (!host._live || host._scaling || points == null || points.length < 2) continue;
      final upgrading = points.keys.any(
        (pointer) => EventDispatcher._routes[pointer]?._ownership?.scaleAllowed.contains(host) ?? false,
      );
      if (upgrading && host._canStartOwnedScale()) host._startScale(last);
    }
  }
}
