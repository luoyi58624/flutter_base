import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../viewport/scroll_viewport.dart';

// 指针仍在接收视口内时，滚轮停顿满 500ms 才重新命中，边界空消费也续期。
const Duration _pointerScrollChainHoldDuration = Duration(milliseconds: 500);

// 指针留在接收视口内时，内→外、外→内共用同一期限。
const Duration _pointerScrollAncestorRetargetDelay = _pointerScrollChainHoldDuration;

const double _pointerScrollChainSlop = 10.0;

/// 普通和虚拟视口共用连续滚轮接收者，按原始输入轴维持 500ms 嵌套交接边界。
final class ScrollPointerChain {
  ScrollPointerChain._();

  static final Map<Axis, _ScrollPointerAxisState> _axisStates = <Axis, _ScrollPointerAxisState>{
    Axis.vertical: _ScrollPointerAxisState(),
    Axis.horizontal: _ScrollPointerAxisState(),
  };

  static Object? _pointerSignalBatchEvent;
  static final List<_ScrollPointerSignalBatchAction> _pointerSignalBatchActions = <_ScrollPointerSignalBatchAction>[];

  /// 当前尚在锁定期内的滚轮或拖拽接收者。
  @visibleForTesting
  static ScrollViewport? get debugOwner =>
      _stateFor(Axis.vertical).activeOwner ?? _stateFor(Axis.horizontal).activeOwner;

  /// 当前是否存在尚未结束的拖拽归属。
  @visibleForTesting
  static bool get debugGestureClaimActive => _axisStates.values.any((state) => state.gestureClaimActive);

  /// 从最后一次滚轮输入开始计算的交接停顿。
  @visibleForTesting
  static Duration get debugPointerScrollChainHoldDuration => _pointerScrollChainHoldDuration;

  /// 祖先向后代交接使用的同一停顿期限。
  @visibleForTesting
  static Duration get debugPointerScrollAncestorRetargetDelay => _pointerScrollAncestorRetargetDelay;

  /// 当前是否仍禁止把连续滚轮交给后代。
  @visibleForTesting
  static bool get debugAncestorRetargetBlocked => _axisStates.values.any((state) => state.ancestorRetargetBlocked);

  /// 清空测试中的接收者、计时器和未提交的信号批次。
  @visibleForTesting
  static void debugReset() {
    for (final state in _axisStates.values) {
      state.reset();
    }
    _clearPointerSignalBatch();
  }

  /// 当前指针位置下的滚轮链持有者；[querier] 是发起查询的视口。
  ///
  /// 滚轮按原始输入轴查询；指针留在接收视口内时，停顿满 500ms 才更换接收者。
  /// 移出视口立即释放；视口内移动或触及滚动边界仍保留归属和同接收者的平滑动画。
  static ScrollViewport? ownerAt(
    Offset globalPosition, {
    PointerScrollEvent? event,
    Axis? axis,
    ScrollViewport? querier,
  }) {
    if (axis != null) {
      return _ownerAtAxis(axis, globalPosition, event: event, querier: querier);
    }
    return _ownerAtAxis(Axis.vertical, globalPosition, event: event, querier: querier) ??
        _ownerAtAxis(Axis.horizontal, globalPosition, event: event, querier: querier);
  }

  /// 仅查询同轴拖拽归属，新 pan 手势不继承鼠标滚轮的 500ms 命中锁。
  static ScrollViewport? gestureOwnerAt(Offset globalPosition, {required Axis axis}) =>
      _stateFor(axis).gestureClaimActive ? _ownerAtAxis(axis, globalPosition) : null;

  static ScrollViewport? _ownerAtAxis(
    Axis axis,
    Offset globalPosition, {
    PointerScrollEvent? event,
    ScrollViewport? querier,
  }) {
    final state = _stateFor(axis);
    final current = state.activeOwner;
    if (current == null) return null;
    // 先检查接收区域，避免祖先关系绕过离开检测，也允许小于移动容差的跨边界交接。
    if (!current.attached || !current.containsGlobalPosition(globalPosition)) {
      _release(current, axis: axis, cancelPointerScrollActivity: true);
      return null;
    }
    if (event != null &&
        !state.gestureClaimActive &&
        querier != null &&
        (identical(querier, current) || current.isAncestorOf(querier) || querier.isAncestorOf(current))) {
      return current;
    }
    if (event != null && !identical(querier, current) && _isOutsideWheelSlop(state, event.position)) {
      _release(current, axis: axis, cancelPointerScrollActivity: true);
      return null;
    }
    return current;
  }

  /// 判断指定祖先的当前输入归属是否仍有效。
  static bool shouldDeferToAncestor(ScrollViewport owner, {Axis? axis}) {
    if (axis != null) {
      final state = _stateFor(axis);
      return identical(state.activeOwner, owner) &&
          (state.ancestorRetargetBlocked || owner.hasActivePointerScrollActivity);
    }
    return _axisStates.entries.any((entry) {
      final state = entry.value;
      return identical(state.activeOwner, owner) &&
          (state.ancestorRetargetBlocked || owner.hasActivePointerScrollActivity);
    });
  }

  /// 判断命中视口是否必须让当前同轴接收者继续处理。
  static bool shouldDeferViewportToOwner(ScrollViewport viewport, ScrollViewport owner, {Axis? axis}) {
    if (identical(viewport, owner)) return false;
    if (viewport.isAncestorOf(owner)) return true;
    if (!owner.isAncestorOf(viewport)) return false;
    if (axis != null) {
      final state = _stateFor(axis);
      return state.gestureClaimActive || shouldDeferToAncestor(owner, axis: axis);
    }
    return _axisStates.values.any((state) => state.gestureClaimActive) || shouldDeferToAncestor(owner);
  }

  /// 认领指定轴的短期归属，不记录鼠标起点。
  static void claim(ScrollViewport owner, {Axis? axis}) {
    if (axis == null) {
      for (final item in _axisStates.entries) {
        _claim(owner, axis: item.key, wheelPosition: null);
      }
      return;
    }
    _claim(owner, axis: axis, wheelPosition: null);
  }

  /// 以原始输入轴认领并续期滚轮归属，目标滚动轴可以与输入轴不同。
  static void claimForPointerScroll(ScrollViewport owner, PointerScrollEvent event, {Axis? axis}) {
    _claim(owner, axis: axis ?? _dominantAxis(event.scrollDelta), wheelPosition: event.position);
  }

  static void _claim(ScrollViewport owner, {required Axis axis, required Offset? wheelPosition}) {
    final state = _stateFor(axis);
    final previousOwner = state.owner;
    if (previousOwner != null && !identical(previousOwner, owner)) {
      previousOwner.cancelPointerScrollActivity();
    }
    state.timer?.cancel();
    state.owner = owner;
    state.gestureClaimActive = false;
    if (wheelPosition == null) {
      state.wheelStartPosition = null;
    } else if (!identical(previousOwner, owner) || state.wheelStartPosition == null) {
      state.wheelStartPosition = wheelPosition;
    }
    state.timer = Timer(_pointerScrollChainHoldDuration, () {
      if (!identical(state.owner, owner)) return;
      // 到期只解除命中锁；保留旧接收者，真正换目标时才取消其尚未结束的长动画。
      state.timer = null;
      state.wheelStartPosition = null;
    });
  }

  /// 认领拖拽归属直到手势释放，不受滚轮停顿计时影响。
  static void claimGesture(ScrollViewport owner, {Axis? axis}) {
    if (axis == null) {
      for (final item in _axisStates.entries) {
        _claimGestureAxis(owner, item.key);
      }
      return;
    }
    _claimGestureAxis(owner, axis);
  }

  static void _claimGestureAxis(ScrollViewport owner, Axis axis) {
    final state = _stateFor(axis);
    final previousOwner = state.owner;
    if (previousOwner != null && !identical(previousOwner, owner)) {
      previousOwner.cancelPointerScrollActivity();
    }
    state.timer?.cancel();
    state.timer = null;
    state.owner = owner;
    state.gestureClaimActive = true;
    state.wheelStartPosition = null;
  }

  /// 释放所属视口的输入归属和计时器。
  static void release(ScrollViewport owner, {Axis? axis}) {
    if (axis == null) {
      for (final item in _axisStates.entries) {
        _release(owner, axis: item.key, cancelPointerScrollActivity: false);
      }
      return;
    }
    _release(owner, axis: axis, cancelPointerScrollActivity: false);
  }

  static void _release(ScrollViewport owner, {required Axis axis, required bool cancelPointerScrollActivity}) {
    final state = _stateFor(axis);
    if (!identical(state.owner, owner)) return;
    if (cancelPointerScrollActivity) {
      owner.cancelPointerScrollActivity();
    }
    state.reset();
  }

  /// 按原始输入轴登记一次信号处理，同一分量只能由一个视口消费。
  static void registerPointerScrollAction(
    PointerScrollEvent event,
    bool Function(PointerScrollEvent event) action, {
    required Axis axis,
    ScrollViewport? owner,
  }) {
    final canonicalEvent = _canonicalSignalEvent(event);
    if (!identical(_pointerSignalBatchEvent, canonicalEvent)) {
      _clearPointerSignalBatch();
      _pointerSignalBatchEvent = canonicalEvent;
      GestureBinding.instance.pointerSignalResolver.register(event, _resolvePointerScrollBatch);
    }
    _pointerSignalBatchActions.add(
      _ScrollPointerSignalBatchAction(
        axis: axis,
        owner: owner,
        order: _pointerSignalBatchActions.length,
        action: action,
      ),
    );
  }

  static void _resolvePointerScrollBatch(PointerSignalEvent event) {
    final actions = List<_ScrollPointerSignalBatchAction>.of(_pointerSignalBatchActions);
    _clearPointerSignalBatch();
    if (event is! PointerScrollEvent) return;
    actions.sort(_comparePointerSignalActions);
    var handled = false;
    final handledAxes = <Axis>{};
    for (final action in actions) {
      if (handledAxes.contains(action.axis)) continue;
      final actionHandled = action.action(event);
      handled = actionHandled || handled;
      if (actionHandled) {
        handledAxes.add(action.axis);
      }
    }
    event.respond(allowPlatformDefault: !handled);
  }

  static int _comparePointerSignalActions(_ScrollPointerSignalBatchAction a, _ScrollPointerSignalBatchAction b) {
    final aOwner = a.owner;
    final bOwner = b.owner;
    if (aOwner != null && bOwner != null) {
      if (aOwner.isAncestorOf(bOwner)) return 1;
      if (bOwner.isAncestorOf(aOwner)) return -1;
    }
    return a.order.compareTo(b.order);
  }

  static void _clearPointerSignalBatch() {
    _pointerSignalBatchEvent = null;
    _pointerSignalBatchActions.clear();
  }

  static Object _canonicalSignalEvent(PointerSignalEvent event) => event.original ?? event;

  static Axis _dominantAxis(Offset delta) => delta.dx.abs() > delta.dy.abs() ? Axis.horizontal : Axis.vertical;

  static _ScrollPointerAxisState _stateFor(Axis axis) => _axisStates[axis]!;

  static bool _isOutsideWheelSlop(_ScrollPointerAxisState state, Offset position) {
    final start = state.wheelStartPosition;
    if (start == null) return false;
    return (position - start).distanceSquared >= _pointerScrollChainSlop * _pointerScrollChainSlop;
  }
}

final class _ScrollPointerSignalBatchAction {
  const _ScrollPointerSignalBatchAction({
    required this.axis,
    required this.owner,
    required this.order,
    required this.action,
  });

  final Axis axis;
  final ScrollViewport? owner;
  final int order;
  final bool Function(PointerScrollEvent event) action;
}

final class _ScrollPointerAxisState {
  ScrollViewport? owner;
  Timer? timer;
  bool gestureClaimActive = false;
  Offset? wheelStartPosition;

  ScrollViewport? get activeOwner => gestureClaimActive || timer != null ? owner : null;
  bool get ancestorRetargetBlocked => timer != null && wheelStartPosition != null;

  void reset() {
    timer?.cancel();
    timer = null;
    owner = null;
    gestureClaimActive = false;
    wheelStartPosition = null;
  }
}
