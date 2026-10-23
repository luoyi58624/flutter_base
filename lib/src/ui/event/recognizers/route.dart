part of 'recognizers.dart';

/// 将同一 El 路线的订阅者与参加官方竞技场的所有者分开。
abstract class _ElGestureRecognizer extends OneSequenceGestureRecognizer {
  _ElGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  final Map<int, _GestureRoute> _routes = <int, _GestureRoute>{};
  bool _disposed = false;
  bool _canceling = false;

  _ElGestureRecognizer? get _bubbleParent;

  _ElGestureCallback? _handlerFor(ElGesturePhase phase);

  void _requestAccept(_GestureRoute route, int pointer);

  void _cancelRoutePointer(
    _GestureRoute route,
    int pointer,
    PointerEvent? event,
  );

  /// 请求接受指定指针的官方竞技场归属；不会覆盖已经确认的其他赢家。
  void acceptPointer(int pointer) {
    if (_disposed || _canceling) return;
    final route = _routes[pointer];
    if (route != null && route.active && !route.owner._disposed) {
      route.owner._requestAccept(route, pointer);
    }
  }

  /// 取消指定指针；宿主判断越界时可传入当前输入，不需要向识别器提供元素尺寸。
  void cancelPointer(int pointer, {PointerEvent? event}) {
    assert(event == null || event.pointer == pointer);
    if (_disposed || _canceling) return;
    final route = _routes[pointer];
    if (route != null && route.active && !route.owner._disposed) {
      route.owner._cancelRoutePointer(route, pointer, event);
    }
  }

  /// 取消自身拥有的全部活动手势和待发通知，取消后仍可识别新序列。
  void cancel();

  bool _isDelegated(int pointer) {
    final route = _routes[pointer];
    return route != null && route.active && !identical(route.owner, this);
  }

  /// 祖先只登记自己的坐标，实际指针由最内层所有者跟踪与参赛。
  bool _delegatePointer(PointerEvent event) {
    final route = _routes[event.pointer];
    if (route == null || !route.active || identical(route.owner, this)) {
      return false;
    }
    (route.downEvents[this] ??= <int, PointerEvent>{})[event.pointer] = event;
    return true;
  }

  _GestureRoute _beginRoute(PointerEvent event, {_GestureRoute? route}) {
    assert(!_disposed);
    final result = route ?? _newRoute(event.pointer);
    assert(result.active && identical(result.owner, this));
    result.pointers.add(event.pointer);
    (result.downEvents[this] ??= <int, PointerEvent>{})[event.pointer] = event;
    for (final member in result.members) {
      if (member._disposed) continue;
      final previous = member._routes[event.pointer];
      // 同一指针可能命中多个透明分支；已参赛或已委托的路线不能被后来者偷换。
      if (previous != null && previous.active && !identical(previous, result)) {
        continue;
      }
      member._routes[event.pointer] = result;
    }
    return result;
  }

  _GestureRoute _newRoute(int pointer) {
    final members = _snapshotChain();
    final conflict = members.indexWhere((member) {
      final previous = member._routes[pointer];
      return previous != null && previous.active;
    });
    if (conflict == 0) {
      throw StateError('同一识别器不能为同一指针重复创建路线。');
    }
    // 透明重叠分支可以分别参赛，共享祖先只订阅首次命中的那条路线。
    if (conflict > 0) members.removeRange(conflict, members.length);
    return _GestureRoute(this, pointer, members);
  }

  List<_ElGestureRecognizer> _snapshotChain() {
    final result = <_ElGestureRecognizer>[];
    final seen = <_ElGestureRecognizer>{};
    _ElGestureRecognizer? current = this;
    while (current != null) {
      if (!seen.add(current)) {
        throw StateError('手势 parent 链不能包含循环引用。');
      }
      if (!current._disposed) result.add(current);
      current = current._bubbleParent;
    }
    return result;
  }

  bool _hasHandlerInChain(ElGesturePhase phase) =>
      _snapshotChain().any((member) => member._handlerFor(phase) != null);

  bool _routeHasHandler(_GestureRoute route, ElGesturePhase phase) {
    if (!route.active) return false;
    final end = route.cutoffs[_familyFor(phase)] ?? route.members.length - 1;
    for (var index = 0; index <= end; index++) {
      final member = route.members[index];
      if (!member._disposed && member._handlerFor(phase) != null) return true;
    }
    return false;
  }

  void _endRoute(_GestureRoute route) {
    if (!route.active) return;
    // Cancel 回调可重入销毁所有者，坐标快照须等已公开的终态全部投递后再释放。
    if (route.terminalDispatchDepth > 0) {
      route.closeRequested = true;
      _releaseRoutePointers(route);
      return;
    }
    route.active = false;
    _releaseRoutePointers(route);
    route.downEvents.clear();
  }

  /// 物理序列结束即解除报名委托，延迟业务通知仍可保留冻结路线。
  void _releaseRoutePointers(_GestureRoute route) {
    for (final member in route.members) {
      for (final pointer in route.pointers) {
        if (identical(member._routes[pointer], route)) {
          member._routes.remove(pointer);
        }
      }
    }
  }

  void _dispatchGesture(
    _GestureRoute route,
    ElGestureDetails callback, {
    int firstMember = 0,
    int? lastMember,
  }) {
    final terminal = _isTerminalPhase(callback.phase);
    if (!route.active || _disposed && !terminal) return;
    if (terminal) route.terminalDispatchDepth++;
    try {
      final family = _familyFor(callback.phase);
      final revision = (route.revisions[family] ?? 0) + 1;
      route.revisions[family] = revision;
      final candidate = _isCandidatePhase(callback.phase);
      if (candidate) route.observedEnds[family] = -1;
      var end = lastMember ?? route.cutoffs[family] ?? route.members.length - 1;
      if (!candidate && lastMember == null) {
        end = math.min(end, route.observedEnds[family] ?? end);
      }
      for (var index = firstMember; index <= end; index++) {
        // 同家族重入可能已取消当前阶段，不能再把旧 Down/Start 送给后续祖先。
        if (!route.active ||
            !terminal && (_disposed || route.revisions[family] != revision)) {
          break;
        }
        final member = route.members[index];
        if (member._disposed) continue;
        if (candidate) route.observedEnds[family] = index;
        final handler = member._handlerFor(callback.phase);
        if (handler == null) continue;
        member.invokeCallback<void>(callback.phase.name, () {
          final down = route.downEvents[member]?[callback.pointer];
          callback._updateTransform(down?.transform);
          handler(callback);
        });
        // 终态是已公开生命周期的清理义务，不能由子回调吞掉祖先的唯一结算。
        if (callback.propagationStopped) {
          // Up 之后的业务点击仍遵守最早截断点，已经公开的释放通知继续结清。
          if (terminal) {
            if (_establishesBoundary(callback.phase)) {
              route.cutoffs[family] = math.min(
                route.cutoffs[family] ?? index,
                index,
              );
            }
            continue;
          }
          if (_establishesBoundary(callback.phase)) {
            route.cutoffs[family] = index;
            final cancellation = _boundaryCancellation(callback);
            if (cancellation != null &&
                route.active &&
                route.revisions[family] == revision) {
              final observed = route.observedEnds[family] ?? index;
              route.observedEnds[family] = index;
              if (observed > index) {
                _dispatchGesture(
                  route,
                  cancellation,
                  firstMember: index + 1,
                  lastMember: observed,
                );
              }
            }
          }
          break;
        }
      }
    } finally {
      if (terminal) {
        route.terminalDispatchDepth--;
        if (route.closeRequested && route.terminalDispatchDepth == 0) {
          _endRoute(route);
        }
      }
    }
  }

  static ElGestureDetails? _boundaryCancellation(ElGestureDetails details) {
    if (details is ElTransformGestureDetails &&
        details.phase == ElGesturePhase.dragStart) {
      return ElTransformGestureDetails(
        phase: ElGesturePhase.dragCancel,
        globalPosition: details.globalPosition,
        dragOffset: details.dragOffset,
        dragAxis: details.dragAxis,
        dragDirection: details.dragDirection,
        pointerCount: details.pointerCount,
        originalEvent: details.originalEvent,
      );
    }
    if (details is ElPressGestureDetails &&
        (details.phase == ElGesturePhase.doubleTapDown ||
            details.phase == ElGesturePhase.tripleTapDown)) {
      return ElPressGestureDetails(
        phase: ElGesturePhase.tapCancel,
        globalPosition: details.globalPosition,
        originalEvent: details.originalEvent,
        buttons: details.buttons,
        cancelReason: ElGestureCancelReason.canceled,
      );
    }
    return null;
  }

  static bool _isTerminalPhase(ElGesturePhase phase) => switch (phase) {
    ElGesturePhase.tapUp ||
    ElGesturePhase.secondaryTapUp ||
    ElGesturePhase.tertiaryTapUp ||
    ElGesturePhase.forwardTapUp ||
    ElGesturePhase.backTapUp ||
    ElGesturePhase.tapCancel ||
    ElGesturePhase.dragCancel ||
    ElGesturePhase.dragEnd ||
    ElGesturePhase.scaleCancel ||
    ElGesturePhase.scaleEnd => true,
    _ => false,
  };

  static bool _isCandidatePhase(ElGesturePhase phase) => switch (phase) {
    ElGesturePhase.tapDown ||
    ElGesturePhase.secondaryTapDown ||
    ElGesturePhase.tertiaryTapDown ||
    ElGesturePhase.forwardTapDown ||
    ElGesturePhase.backTapDown ||
    ElGesturePhase.dragDown ||
    ElGesturePhase.scaleStart => true,
    _ => false,
  };

  static bool _establishesBoundary(ElGesturePhase phase) => switch (phase) {
    ElGesturePhase.tapCancel ||
    ElGesturePhase.dragCancel ||
    ElGesturePhase.dragEnd ||
    ElGesturePhase.dragUpdate ||
    ElGesturePhase.scaleCancel ||
    ElGesturePhase.scaleEnd ||
    ElGesturePhase.scaleUpdate ||
    ElGesturePhase.rotationUpdate => false,
    _ => true,
  };

  static _GestureFamily _familyFor(ElGesturePhase phase) => switch (phase) {
    ElGesturePhase.dragDown ||
    ElGesturePhase.dragStart ||
    ElGesturePhase.dragUpdate ||
    ElGesturePhase.dragEnd ||
    ElGesturePhase.dragCancel => _GestureFamily.drag,
    ElGesturePhase.scaleStart ||
    ElGesturePhase.scaleUpdate ||
    ElGesturePhase.scaleEnd ||
    ElGesturePhase.scaleCancel ||
    ElGesturePhase.rotationUpdate => _GestureFamily.scale,
    _ => _GestureFamily.press,
  };

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final route in _routes.values.toSet()) {
      if (identical(route.owner, this)) _endRoute(route);
    }
    _routes.clear();
    super.dispose();
  }
}

enum _GestureFamily { press, drag, scale }

class _GestureRoute {
  _GestureRoute(this.owner, this.pointer, this.members);

  final _ElGestureRecognizer owner;
  final int pointer;
  final List<_ElGestureRecognizer> members;
  final Set<int> pointers = <int>{};
  final Map<_ElGestureRecognizer, Map<int, PointerEvent>> downEvents =
      <_ElGestureRecognizer, Map<int, PointerEvent>>{};
  final Map<_GestureFamily, int> cutoffs = <_GestureFamily, int>{};
  final Map<_GestureFamily, int> revisions = <_GestureFamily, int>{};
  final Map<_GestureFamily, int> observedEnds = <_GestureFamily, int>{};
  int terminalDispatchDepth = 0;
  bool closeRequested = false;
  bool active = true;
}
