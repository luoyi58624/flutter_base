import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../utils/internal/benchmark_probe.dart';
import 'details.dart' show EventDetailsAccess;
import 'drag_pointer_lock.dart';
import 'event.dart';
import 'shape.dart';

part 'tap.dart';
part 'drag.dart';
part 'scale.dart';
part 'keyboard.dart';
part 'pointer_route.dart';
part 'ownership.dart';

/// 基于原始指针实现 ElEvent。
///
/// 一次按下命中的宿主由内向外组成一条 [_Route]。点击、连击、长按、拖拽和缩放都沿路线默认冒泡，
/// 回调调用 stopPropagation 即可截断外层；在按下阶段截断时，外层不再参与本次手势。
/// 路线只协调成员、原始输入与认领，三类手势分别由 [_RouteTaps]、[_RouteDrags]、[_RouteScales] 承担，按声明创建。
/// 路线以一个竞技场成员与 Flutter 手势协作：双指缩放预留触点，其余手势开始时认领指针，官方手势胜出时取消本路线。
class EventDispatcher {
  /// 为宿主注册事件入口。
  EventDispatcher(this._render) {
    _hosts[_render] = this;
    assert(() {
      BenchmarkProbe.eventDispatcherInstantiateCount++;
      return true;
    }());
  }

  static final _hosts = Expando<EventDispatcher>('ElEvent host');
  static final _raw = Expando<ElEventDetails>('ElEvent input');
  static final _routes = <int, _Route>{};

  // 路线之外仍持有按压、连击或键盘状态的宿主；子树结清只需查它们和在途路线。
  static final _retaining = Set<EventDispatcher>.identity();

  final RenderBox _render;
  ElEvent? _event;

  // 当前声明的回调位图，与 [_event] 同步更新；候选筛选和换形比较都读它。
  EventShape _shape = EventShape.none;
  bool _disposed = false;
  bool _disposing = false;
  int _revision = 0;
  ElEventDetails? _activeCallback;
  PointerEvent? _lastInput;
  Offset _position = Offset.zero;
  Offset? _focusPosition;

  // 能力状态只在实际输入时建立，宿主挂载和读取状态不会分配集合或计时器。
  _PressState? _pressState;
  _TapSequence? _tapSequence;
  _KeyboardState? _keyboard;
  _Drag? _drag;
  _ScaleState? _scaleState;

  int? get _pressed => _pressState?.pointer;
  bool get _scaling => _scaleState?.active ?? false;
  int get _tapCount => _tapSequence?.count ?? 1;
  set _deferred(VoidCallback? callback) => _tapSequence?.deferred = callback;

  /// 当前仍保留的交互状态，仅用于检查按需分配与清理。
  @visibleForTesting
  Set<String> get debugRetainedStates => {
    if (_pressState != null) 'press',
    if (_tapSequence != null) 'tapSequence',
    if (_keyboard != null) 'keyboard',
    if (_drag != null) 'drag',
    if (_scaleState != null) 'scale',
    if (_lastInput != null) 'input',
  };

  /// 向宿主同步按压样式。
  ValueChanged<bool>? onTapChanged;

  /// 特殊绘制宿主可调整事件的局部坐标。
  Offset Function(RenderBox, Offset, ElEventDetails?)? localPositionResolver;

  /// 宿主的点击边界（圆角、裁剪与变换），默认使用布局盒。
  bool Function(Offset global)? hitBoundsContainsGlobal;

  /// 获取对应 RenderBox 的事件入口。
  static EventDispatcher? of(RenderObject render) => _hosts[render];

  /// 结清关闭或禁用的子树里的事件。
  ///
  /// 空闲宿主的结清没有任何效果，这里只下钻到持有活动输入的分支，仍按子先于父的顺序结清。
  static void terminateActivePointerSequencesIn(RenderObject root) {
    final branch = Set<RenderObject>.identity();
    bool mark(RenderObject? node) {
      if (node == null) return false;
      if (identical(node, root) || branch.contains(node)) return true;
      if (!mark(node.parent)) return false;
      branch.add(node);
      return true;
    }

    var active = false;
    for (final host in _retaining) {
      active = mark(host._render) || active;
    }
    for (final route in _routes.values) {
      for (final host in route.hosts) {
        active = mark(host._render) || active;
      }
    }
    if (!active) return;
    void visit(RenderObject node) {
      assert(() {
        BenchmarkProbe.eventTerminateVisitCount++;
        return true;
      }());
      node.visitChildren((child) {
        if (branch.contains(child)) visit(child);
      });
      of(node)?.cancelAllPendingAtLastPosition();
    }

    visit(root);
  }

  /// 路线之外仍持有交互状态的宿主数量，仅用于检查登记与释放成对。
  @visibleForTesting
  static int get debugRetainingHostCount => _retaining.length;

  /// 状态全部释放后退出登记；分配处直接加入 [_retaining]。
  void _settle() {
    if (_pressState == null && _tapSequence == null && _keyboard == null) _retaining.remove(this);
  }

  /// 读取按下路径上对焦点默认动作的保留标记。
  static bool preservesFocus(PointerDownEvent input) => _raw[input.original ?? input]?.focusPreserved ?? false;

  /// 测试结束后清理残留指针。
  @visibleForTesting
  static void debugReset() {
    for (final route in _routes.values.toList()) {
      route.cancel(.external);
      route.close();
    }
  }

  /// 当前事件声明，闭包变化不影响进行中的手势。
  ElEvent? get event => _event;
  set event(ElEvent? value) {
    final old = _event;
    if (_disposed || _disposing || identical(old, value)) return;
    final revision = ++_revision;
    final was = _shape;
    final next = value?.shape ?? EventShape.none;
    final reshaped = old != null && value != null && was != next;
    final routes = _myRoutes;
    if (old != null && value != null && !(_sameTapSettings(old, value) && was.sameDiscrete(next))) {
      _resetTaps();
      for (final route in routes) {
        route._taps?.longPressTargets?.remove(this);
      }
    }
    if (value?.disabled == true && old?.disabled != true) {
      terminateActivePointerSequencesIn(_render);
    } else if (value == null) {
      cancelAllPendingAtLastPosition();
    } else if (_drag case final drag? when reshaped) {
      // 回调结构变化：新声明接得住的拖拽继续；接不住或指针已在结束时，由旧回调取消。
      final accepted = drag.axis == null ? next.pan : next.acceptsDrag(drag.axis!);
      if (!accepted || drag.route._ended) _endDrag(drag.route.last, null);
    }
    if (revision != _revision || _disposed) return;
    if (reshaped) {
      for (final route in routes) {
        if (route._ended) {
          route._taps
            ?..eligible.remove(this)
            ..pressed.remove(this);
        }
        if (!was.sameScale(next) && (route._scales?.members.remove(this) ?? false)) {
          _scaleState?.points.remove(route.pointer);
          _endScale(route.last, null);
        }
        if (revision != _revision) return;
        if (route.down is PointerPanZoomStartEvent &&
            value.onPointerPanZoomStart == null &&
            value.onPointerPanZoomUpdate == null &&
            value.onPointerPanZoomEnd == null) {
          route.leave(this);
        }
        if (revision != _revision) return;
      }
    }
    _event = value;
    _shape = next;
    if (reshaped) {
      for (final route in _myRoutes) {
        route.reseed(this);
      }
    }
    if (_render.attached &&
        (old?.cursor != value?.cursor ||
            old?.behavior != value?.behavior ||
            old?.disabled != value?.disabled ||
            (old?.onPointerEnter == null) != (value?.onPointerEnter == null) ||
            (old?.onPointerExit == null) != (value?.onPointerExit == null))) {
      RendererBinding.instance.ensureVisualUpdate();
    }
  }

  // 拖拽订阅独立更新，不清除点击历史；点击识别条件改变才让旧连击和延迟回调失效。
  static bool _sameTapSettings(ElEvent a, ElEvent b) =>
      a.doubleTapInterval == b.doubleTapInterval &&
      a.deferTap == b.deferTap &&
      a.longPressDelay == b.longPressDelay &&
      a.tapCancelDistance == b.tapCancelDistance;

  /// 当前是否禁用。
  bool get disabled => _event?.disabled == true;

  /// 指针或键盘是否处于按压状态。
  bool get isTapPressed => (_pressState?.shown ?? false) || (_keyboard?.held?.isNotEmpty ?? false);

  /// 当前按在本节点上的指针数量。
  int get activePointerCount => _routes.values
      .where(
        (route) =>
            route.down is PointerDownEvent && !route._ended && route.hosts.contains(this) && route._allowsRaw(this),
      )
      .length;

  bool get _live => !_disposed && !disabled;

  List<_Route> get _myRoutes => _routes.values.where((route) => route.hosts.contains(this)).toList();

  ElEvent get _e => _event ?? const ElEvent();

  /// 刷新渲染宿主注册。
  void attach() => _hosts[_render] = this;

  /// 离树时结束输入，临时重挂沿用原宿主。
  void detach({bool preserveEvent = false}) {
    if (!preserveEvent) dispose();
  }

  /// 是否具有自身命中回调。
  bool hitTestSelf(Offset position) => _shape.isNotEmpty;

  /// 按 Flutter 命中顺序接收原始输入。
  void handleEvent(PointerEvent input, HitTestEntry entry) {
    if (!_live) return;
    final phase = switch (input) {
      PointerDownEvent() => ElEventPhase.pointerDown,
      PointerMoveEvent() => ElEventPhase.pointerMove,
      PointerUpEvent() => ElEventPhase.pointerUp,
      PointerCancelEvent() || PointerRemovedEvent() => ElEventPhase.pointerCancel,
      PointerPanZoomStartEvent() => ElEventPhase.pointerPanZoomStart,
      PointerPanZoomUpdateEvent() => ElEventPhase.pointerPanZoomUpdate,
      PointerPanZoomEndEvent() => ElEventPhase.pointerPanZoomEnd,
      PointerHoverEvent() => ElEventPhase.pointerHover,
      PointerSignalEvent() => ElEventPhase.pointerSignal,
      _ => null,
    };
    if (phase == null) return;
    final original = input.original ?? input;
    if (_raw[original]?.propagationStopped == true) return;
    if (input is PointerDownEvent || input is PointerPanZoomStartEvent) {
      _Route.join(original, this);
      if (_routes[input.pointer]?.interceptRaw(this, phase, input) == true) return;
    } else if (input is! PointerHoverEvent && input is! PointerSignalEvent) {
      final route = _routes[input.pointer];
      if (route == null || !route.hosts.contains(this)) return;
      route.last = input;
      if (route.interceptRaw(this, phase, input)) return;
    }
    _dispatchRaw(phase, input);
  }

  /// 交付一次真实命中输入；认领期间暂缓的祖先输入仍从这里结算。
  void _dispatchRaw(ElEventPhase phase, PointerEvent input) {
    if (!_live) return;
    final original = input.original ?? input;
    final previous = _raw[original];
    if (previous?.propagationStopped == true) return;
    // 只有路线内的输入需要身份比对，随路线结束清空；悬停与指针信号不保留事件对象。
    if (input is! PointerHoverEvent && input is! PointerSignalEvent) _lastInput = original;
    _position = _pointerPosition(input);
    var details = previous;
    // 没有原始事件监听时只更新输入位置，点击节点不为每次 Move 构建无用详情与坐标闭包。
    if (_handler(phase) != null) {
      details = _pointer(phase, input, position: _position);
      if (previous != null) {
        if (previous.defaultPrevented) details.preventDefault();
        if (previous.focusPreserved) details.preserveFocus();
        if (input is! PointerMoveEvent) {
          details.remainingDelta = previous.remainingDelta;
          details.remainingLocalDelta = _localDelta(_position, previous.remainingDelta);
        }
      }
      _raw[original] = details;
      _invoke(details);
    }
    // 原始回调可能已移除或替换事件，仍在路线上才点亮按压反馈。
    if (input is PointerDownEvent &&
        _live &&
        _routes[input.pointer]?.hosts.contains(this) == true &&
        (onTapChanged != null || _shape.wantsTap(input.buttons))) {
      _press(input);
    }
    if (input is PointerSignalEvent &&
        details != null &&
        (details.defaultPrevented || details.delta != Offset.zero && details.remainingDelta == Offset.zero)) {
      GestureBinding.instance.pointerSignalResolver.register(
        input,
        (event) => event.respond(allowPlatformDefault: false),
      );
    }
  }

  /// 交付鼠标进入事件。
  void handlePointerEnter(PointerEnterEvent event) => _invoke(_pointer(.pointerEnter, event));

  /// 交付鼠标离开事件。
  void handlePointerExit(PointerExitEvent event) => _invoke(_pointer(.pointerExit, event));

  static (ElEventPhase, ElEventPhase, ElEventPhase)? _tapPhases(int buttons) => switch (buttons) {
    kPrimaryButton => (.tapDown, .tapUp, .tap),
    kSecondaryButton => (.secondaryTapDown, .secondaryTapUp, .secondaryTap),
    kTertiaryButton => (.tertiaryTapDown, .tertiaryTapUp, .tertiaryTap),
    kForwardMouseButton => (.forwardTapDown, .forwardTapUp, .forwardTap),
    kBackMouseButton => (.backTapDown, .backTapUp, .backTap),
    _ => null,
  };

  static Offset _pointerPosition(PointerEvent input) => switch (input) {
    PointerPanZoomUpdateEvent() => input.position + input.pan,
    PointerPanZoomEndEvent() => _routes[input.pointer]?._lastPosition ?? input.position,
    _ => input.position,
  };

  ElEventDetails _pointer(
    ElEventPhase phase,
    PointerEvent input, {
    Offset? position,
    int? buttons,
    int count = 0,
    ElEventCancelReason? reason,
  }) {
    final global = position ?? _pointerPosition(input);
    final delta = switch (input) {
      PointerScrollEvent() => input.scrollDelta,
      PointerPanZoomUpdateEvent() => input.panDelta,
      _ => input.delta,
    };
    return ElEventDetails(
      phase: phase,
      originalEvent: input,
      globalPosition: global,
      localPosition: _local(global),
      delta: delta,
      localDelta: _localDelta(global, delta),
      buttons: buttons ?? input.buttons,
      tapCount: count,
      pointerCount: activePointerCount,
      cancelReason: phase == .tapCancel || phase == .pointerCancel ? reason : null,
      scale: input is PointerPanZoomUpdateEvent ? input.scale : 1,
      rotation: input is PointerPanZoomUpdateEvent ? input.rotation : 0,
    )..resolveLocalDelta((value) => _localDelta(global, value));
  }

  Offset _local(Offset position, [ElEventDetails? details]) {
    if (!_render.attached) return details?.localPosition ?? position;
    return localPositionResolver?.call(_render, position, details) ?? _render.globalToLocal(position);
  }

  Offset _localDelta(Offset end, Offset delta) =>
      delta == Offset.zero ? Offset.zero : _local(end) - _local(end - delta);

  void _invoke(ElEventDetails details, {_Drag? drag}) {
    if (_disposed) return;
    final phase = details.phase;
    final axis = ElEventPhase.dragPhases.contains(phase) ? (drag ?? _drag)?.axis : null;
    final handler = _handler(phase, axis);
    if (handler == null) return;
    _bindOwnership(details);
    final previous = _activeCallback;
    _activeCallback = details;
    try {
      handler(details);
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'ElEvent'));
    } finally {
      _activeCallback = previous;
    }
  }

  ElEventHandler? _handler(ElEventPhase phase, [Axis? axis]) =>
      _event?.handlerFor(phase, axis) ?? (phase == .keyRepeat ? _event?.onKeyDown : null);

  /// 保存指针请求焦点时的坐标。
  void rememberFocusPosition(Offset global, Offset local) => _rememberFocusPosition(global, local);

  /// 沿当前渲染祖先链派发焦点变化。
  void notifyFocusChanged(
    bool focused, {
    ElFocusReason reason = .programmatic,
    Offset? globalPosition,
    Offset? localPosition,
  }) => _notifyFocusChanged(focused, reason: reason, globalPosition: globalPosition, localPosition: localPosition);

  /// 转发键盘事件与激活键的按压状态。
  ElEventDetails? notifyKeyEvent(KeyEvent event) => _notifyKeyEvent(event);

  /// 结束宿主跟踪的输入和反馈。
  void cancelAllPendingAtLastPosition() {
    final routes = _myRoutes;
    final revision = _revision;
    _resetTaps();
    _release();
    _pressState?.holdTimer?.cancel();
    _show(false);
    _releaseKeys();
    DragPointerLock.release(_render);
    for (final route in routes) {
      route.leave(this, notify: revision == _revision);
    }
  }

  /// 释放宿主注册。
  void dispose() {
    if (_disposed || _disposing) return;
    _disposing = true;
    cancelAllPendingAtLastPosition();
    _disposed = true;
    if (identical(_hosts[_render], this)) _hosts[_render] = null;
    _retaining.remove(this);
    _event = null;
    _shape = EventShape.none;
    _lastInput = null;
    onTapChanged = null;
  }
}
