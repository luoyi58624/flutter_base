// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback, precisionErrorTolerance, visibleForTesting;
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../utils/platform/index.dart' show ElPlatform;
import '../common/pointer/scroll_pointer_motion.dart';
import '../common/viewport/scroll_engine_position.dart';
import '../scroll_state.dart';
import 'smooth_scroll.dart';

const Duration _pointerScrollTouchpadWindow = Duration(milliseconds: 80);
const Duration _wheelScrollBurstWindow = Duration(milliseconds: 90);

/// 段落抵达目标后的续接宽限:慢速逐格滚轮(常见阅读节奏 150ms+/格)下,
/// 上一段结束与下一格之间保持活动不拆除,避免滚动条淡出与
/// isScrolling 通知逐格抖动;宽限内新事件无缝续接,
/// 期满无输入才真正结算(浏览器同款:滚动停止后延迟恢复 hover)。
const Duration _wheelSettleGrace = Duration(milliseconds: 150);
const double _pointerScrollTouchpadDelta = 20.0;
const double _wheelScrollEpsilon = 0.01;

typedef ScrollPositionGetter = ScrollPosition Function();
typedef ScrollTargetOffsetForDelta = double Function(double delta, {double? from});

/// Shared smooth wheel-scroll state for El scroll viewports.
///
/// The render objects keep event routing and axis math, while this controller
/// owns the retargetable wheel animation, burst bookkeeping, and touchpad
/// direct-scroll detection used by both normal and virtual scroll views.
/// 手感数值（步长/时长/缓动）全部委托 [algorithm]（[ElSmoothScroll]
/// 策略，Windows 默认使用 [ElWindowsSmoothScroll]）——编排与算法解耦，
/// 换算法零编排改动。
final class SmoothPointerScrollController {
  SmoothPointerScrollController({
    required ScrollPositionGetter position,
    required ScrollTargetOffsetForDelta targetOffsetForDelta,
    this.algorithm,
    this.pointerMotion,
    String debugLabel = 'ElScrollView pointer scroll',
  }) : _position = position,
       _targetOffsetForDelta = targetOffsetForDelta,
       _debugLabel = debugLabel;

  final ScrollPositionGetter _position;
  final ScrollTargetOffsetForDelta _targetOffsetForDelta;
  final String _debugLabel;

  /// 平滑滚动算法；null = 关闭平滑动画（滚轮直滚）。可运行时替换，对进行
  /// 中的动画段不生效，下一段生效。
  ElSmoothScroll? algorithm;

  /// 启用输入协同时的真实会话入口，普通视口保持 null。
  ScrollPointerMotionInput? pointerMotion;
  ScrollPointerMotionSession? _pointerSession;

  /// 当前输入是否由统一路线处理。
  bool get hasCoordinatedMotion => pointerMotion?.supportsPointerMotion ?? false;

  double get _currentInputPosition => _pointerSession?.inputPosition ?? _position().pixels;

  double _targetForDelta(double delta, {double? from}) =>
      _pointerSession == null ? _targetOffsetForDelta(delta, from: from) : (from ?? _currentInputPosition) + delta;

  Ticker? _ticker;

  _WheelScrollActivity? _activity;
  Duration _elapsed = Duration.zero;
  Duration? _frameTimeOrigin;
  Duration _lastRetarget = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Duration? _graceUntil;
  double _initialPixels = 0.0;
  double? _target;
  double _velocity = 0.0;
  Curve _curve = Curves.easeInOut;
  Duration? _lastWheelTimeStamp;
  double? _lastWheelDirection;
  int _wheelBurstTicks = 0;

  /// 现役动画段的目标像素；null = 无在途动画段。retarget 累加口径的测试探针。
  @visibleForTesting
  double? get debugTargetPixels => _target;

  @visibleForTesting
  static bool get debugTouchpadSessionActive => _PointerScrollTouchpadSession.active;

  @visibleForTesting
  static void debugResetTouchpadSession() {
    _PointerScrollTouchpadSession.reset();
  }

  bool get isActive {
    final activity = _activity;
    return _target != null || (_ticker?.isActive ?? false) || (activity != null && !activity.disposed);
  }

  double targetOffsetForDelta(double delta, {double? from}) {
    return _targetOffsetForDelta(delta, from: from);
  }

  bool canConsumeDelta(double delta) {
    if (hasCoordinatedMotion) return pointerMotion!.canConsumePointerDelta(delta);
    final position = _position();
    final pixels = position.pixels;
    final immediateTarget = _targetOffsetForDelta(delta, from: pixels);
    if ((immediateTarget - pixels).abs() > precisionErrorTolerance) {
      return true;
    }

    final activeTarget = _target;
    if (activeTarget == null) return false;
    final target = _targetOffsetForDelta(delta, from: activeTarget);
    return (target - activeTarget).abs() > precisionErrorTolerance;
  }

  bool shouldLatchBoundaryPointerScroll(PointerScrollEvent event, double delta) {
    if (delta.abs() <= precisionErrorTolerance) return false;
    final position = _position();
    if (!position.hasPixels || !position.hasContentDimensions) return false;
    final pixels = position.pixels;
    final immediateTarget = _targetOffsetForDelta(delta, from: pixels);
    if ((immediateTarget - pixels).abs() > precisionErrorTolerance) return false;
    return _isDirectPointerScroll(event, delta);
  }

  void applyPointerScroll(PointerScrollEvent event, double delta) {
    final position = _position();
    final direct = algorithm == null || _shouldApplyDirectly(event, delta);
    if (hasCoordinatedMotion) {
      if (direct) reset();
      var session = _pointerSession;
      if (session == null || !session.isCurrent) {
        session = pointerMotion!.beginPointerMotion(event, reset);
        if (!session.isCurrent) return;
        _pointerSession = session;
      } else {
        session.updateEvent(event);
      }
      if (direct) {
        try {
          if (_ensureActivity()) session.applyDelta(delta, event.timeStamp);
        } finally {
          _finishAnimation(settle: true);
        }
      } else {
        _retarget(event, delta);
      }
      return;
    }
    // 算法为 null（平台默认关闭 / 显式关闭）恒直滚，不建动画段。
    if (direct) {
      reset();
      position.pointerScroll(delta);
    } else {
      _retarget(event, delta);
    }
  }

  void reset() {
    _finishAnimation(settle: false);
  }

  void dispose() {
    reset();
    _ticker?.dispose();
    _ticker = null;
    _PointerScrollTouchpadSession.release(this);
  }

  bool _shouldApplyDirectly(PointerScrollEvent event, double delta) {
    if (!_isDirectPointerScroll(event, delta)) return false;

    if (event.kind == PointerDeviceKind.mouse &&
        ElPlatform.isDesktop &&
        !ElPlatform.isMacOS &&
        (delta.abs() <= _pointerScrollTouchpadDelta || _PointerScrollTouchpadSession.active)) {
      _PointerScrollTouchpadSession.markActive(this);
    }
    return true;
  }

  /// 平台口径必须是 [ElPlatform.isDesktop]（含桌面浏览器）：桌面 Web 的真实
  /// 滚轮同样是 mouse-kind + 大 delta，触控板启发式一体适用；用
  /// isDesktopClient 会把桌面 Web 全量判成直滚，平滑滚动在浏览器失效。
  bool _isDirectPointerScroll(PointerScrollEvent event, double delta) {
    if (event.kind != PointerDeviceKind.mouse) return true;
    if (!ElPlatform.isDesktop || ElPlatform.isMacOS) return true;
    return delta.abs() <= _pointerScrollTouchpadDelta || _PointerScrollTouchpadSession.active;
  }

  void _retarget(PointerScrollEvent event, double delta) {
    final algorithm = this.algorithm;
    if (algorithm == null) return;
    final position = _position();
    if (!position.hasPixels || !position.hasContentDimensions) return;

    final wheelDelta = _wheelDeltaForAnimation(algorithm, event, delta);
    final currentPixels = _currentInputPosition;
    final activeTarget = _target;
    // Chromium 始终在目标上累积增量，反向输入先抵消尚未走完的距离。
    final breakTarget = algorithm is! ElChromiumSmoothScroll && _shouldBreakTarget(wheelDelta, activeTarget);
    final base = breakTarget ? currentPixels : (activeTarget ?? currentPixels);
    final target = _targetForDelta(wheelDelta, from: base);
    final currentTarget = activeTarget ?? currentPixels;
    // 已钳到同一边界时继续跑原段，重启会使尾段一再延长。
    if ((target - currentTarget).abs() <= _wheelScrollEpsilon) {
      return;
    }

    if (!_ensureActivity()) {
      // 不支持 activity 才同步兜底；开始通知中的新命令已经接管时直接结束旧请求。
      if (position is! ScrollActivityDelegate) _fallbackApply(target);
      return;
    }

    final wasAnimating = _ticker?.isActive ?? false;
    final now = wasAnimating ? _animationTime : Duration.zero;
    final current = wasAnimating ? _valueAt(now) : currentPixels;
    _velocity = wasAnimating ? _velocityAt(now) : 0.0;
    final newDelta = target - current;
    if (newDelta.abs() <= _wheelScrollEpsilon) {
      _applyPixels(target);
      _finishAnimation(settle: true);
      return;
    }

    final duration = algorithm.segmentDuration(newDelta, _velocity);
    if (duration <= Duration.zero ||
        (wasAnimating && algorithm is ElChromiumSmoothScroll && duration < const Duration(milliseconds: 10))) {
      _applyPixels(target);
      _finishAnimation(settle: true);
      return;
    }

    final durationSeconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
    final initialSlope = wasAnimating ? _velocity * durationSeconds / newDelta : 0.0;
    _initialPixels = current;
    _target = target;
    _curve = algorithm.curveFor(initialSlope);
    _graceUntil = null;
    _lastRetarget = now;
    _totalDuration = now + duration;
    _activity?.velocity = _velocity;

    final ticker = _ticker ??= Ticker(_handleTick, debugLabel: _debugLabel);
    if (!ticker.isActive) {
      _elapsed = Duration.zero;
      ticker.start();
    }
  }

  double _wheelDeltaForAnimation(ElSmoothScroll algorithm, PointerScrollEvent event, double delta) {
    // burst 连击记账是编排层的事件节奏观测（窗口 90ms、同向递增、变向/断流
    // 归零）；是否消费它做加速属算法语义。
    final direction = delta.sign;
    final lastTimeStamp = _lastWheelTimeStamp;
    final sameDirection = _lastWheelDirection == direction;
    final withinBurst =
        lastTimeStamp != null &&
        event.timeStamp >= lastTimeStamp &&
        event.timeStamp - lastTimeStamp <= _wheelScrollBurstWindow;

    _wheelBurstTicks = sameDirection && withinBurst ? _wheelBurstTicks + 1 : 0;
    _lastWheelTimeStamp = event.timeStamp;
    _lastWheelDirection = direction;

    return algorithm.stepForEvent(delta, _wheelBurstTicks);
  }

  bool _shouldBreakTarget(double delta, double? activeTarget) {
    if (activeTarget == null) return false;
    final remaining = activeTarget - _currentInputPosition;
    if (remaining.abs() <= _wheelScrollEpsilon) return false;
    return delta.sign != remaining.sign;
  }

  bool _ensureActivity() {
    final current = _activity;
    if (current != null && !current.disposed) return true;

    final position = _position();
    if (position is! ScrollActivityDelegate) return false;
    final delegate = position as ScrollActivityDelegate;

    late final _WheelScrollActivity activity;
    void onDisposed() {
      if (!identical(_activity, activity)) return;
      _activity = null;
      _clearAnimationState(stopTicker: true);
      final session = _pointerSession;
      _pointerSession = null;
      session?.finish(cancelled: true);
    }

    final session = _pointerSession;
    activity = session == null
        ? _WheelScrollActivity(delegate, onDisposed: onDisposed)
        : _OwnedWheelScrollActivity(delegate, session.motionOwner, onDisposed: onDisposed);
    _activity = activity;
    if (session == null) {
      position.beginActivity(activity);
    } else {
      session.startActivity(activity);
    }
    return !activity.disposed;
  }

  void _fallbackApply(double target) {
    final position = _position();
    if ((target - position.pixels).abs() <= _wheelScrollEpsilon) return;
    _applyPixels(target);
    _clearAnimationState(stopTicker: true);
  }

  void _handleTick(Duration elapsed) {
    _elapsed = elapsed;
    _frameTimeOrigin = SchedulerBinding.instance.currentFrameTimeStamp - elapsed;
    final target = _target;
    final activity = _activity;
    if (target == null || activity == null || activity.disposed) {
      _clearAnimationState(stopTicker: true);
      return;
    }

    final value = _valueAt(elapsed);
    if (activity.disposed || !identical(_activity, activity)) return;
    final overscroll = _applyPixels(value);
    if (activity.disposed || !identical(_activity, activity)) return;
    _velocity = _velocityAt(elapsed);
    activity.velocity = _velocity;

    // 顶到边界立即结算,不给宽限(边缘处 hover 应立刻恢复可用)。
    if (overscroll.abs() > precisionErrorTolerance) {
      _finishAnimation(settle: true);
      return;
    }
    final done = elapsed >= _totalDuration || (_currentInputPosition - target).abs() <= _wheelScrollEpsilon;
    if (done) {
      _applyPixels(target);
      if (activity.disposed || !identical(_activity, activity)) return;
      // 抵达目标不立即结算:保持活动一个续接宽限,慢速逐格滚动不再逐格
      // 拆建 activity;宽限内 retarget 会清掉 _graceUntil 无缝续接。
      final graceUntil = _graceUntil ??= elapsed + _wheelSettleGrace;
      if (elapsed >= graceUntil) {
        _finishAnimation(settle: true);
      }
    }
  }

  // 输入可能在本帧 ticker 回调之前到达；使用同一帧时钟，避免回到上一帧换段。
  // PointerEvent 时间戳可来自外部转发，不拿它与 Scheduler 的 epoch 混算。
  Duration get _animationTime {
    final origin = _frameTimeOrigin;
    final scheduler = SchedulerBinding.instance;
    if (origin == null || scheduler.schedulerPhase == SchedulerPhase.idle) return _elapsed;
    final now = scheduler.currentFrameTimeStamp - origin;
    return now > _elapsed ? now : _elapsed;
  }

  double _velocityAt(Duration elapsed) {
    final target = _target;
    final duration = _totalDuration - _lastRetarget;
    if (target == null || duration <= Duration.zero || elapsed >= _totalDuration) return 0.0;
    final progress = (elapsed - _lastRetarget).inMicroseconds / duration.inMicroseconds;
    return smoothScrollCurveSlope(_curve, progress) *
        (target - _initialPixels) *
        Duration.microsecondsPerSecond /
        duration.inMicroseconds;
  }

  double _valueAt(Duration elapsed) {
    final target = _target;
    if (target == null) return _currentInputPosition;

    final duration = _totalDuration - _lastRetarget;
    final t = elapsed - _lastRetarget;
    if (duration <= Duration.zero || t >= duration) return target;
    if (t <= Duration.zero) return _initialPixels;

    final progress = (t.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0).toDouble();
    final eased = _curve.transform(progress);
    return _initialPixels + (target - _initialPixels) * eased;
  }

  double _applyPixels(double value) {
    final session = _pointerSession;
    if (session != null) {
      return session.applyDelta(value - session.inputPosition, SchedulerBinding.instance.currentSystemFrameTimeStamp);
    }
    final position = _position();
    final target = _targetOffsetForDelta(value - position.pixels);
    if ((target - position.pixels).abs() <= precisionErrorTolerance) return 0.0;
    return position.setPixels(target);
  }

  void _finishAnimation({required bool settle}) {
    _clearAnimationState(stopTicker: true);
    final activity = _activity;
    _activity = null;
    final session = _pointerSession;
    _pointerSession = null;
    if (session != null) {
      session.finish(cancelled: !settle);
      return;
    }
    if (activity == null || activity.disposed) return;
    if (settle) {
      activity.delegate.goBallistic(0.0);
    } else {
      activity.delegate.goIdle();
    }
  }

  void _clearAnimationState({required bool stopTicker}) {
    if (stopTicker) _ticker?.stop();
    _elapsed = Duration.zero;
    _frameTimeOrigin = null;
    _lastRetarget = Duration.zero;
    _totalDuration = Duration.zero;
    _graceUntil = null;
    _initialPixels = 0.0;
    _target = null;
    _velocity = 0.0;
    _curve = Curves.easeInOut;
    _lastWheelTimeStamp = null;
    _lastWheelDirection = null;
    _wheelBurstTicks = 0;
  }
}

final class _PointerScrollTouchpadSession {
  _PointerScrollTouchpadSession._();

  static bool active = false;
  static Timer? _timer;
  static final Set<SmoothPointerScrollController> _owners = <SmoothPointerScrollController>{};

  static void markActive(SmoothPointerScrollController owner) {
    active = true;
    _owners.add(owner);
    _timer?.cancel();
    _timer = Timer(_pointerScrollTouchpadWindow, reset);
  }

  static void release(SmoothPointerScrollController owner) {
    _owners.remove(owner);
    if (_owners.isEmpty) reset();
  }

  static void reset() {
    active = false;
    _owners.clear();
    _timer?.cancel();
    _timer = null;
  }
}

final class _OwnedWheelScrollActivity extends _WheelScrollActivity implements ScrollCoordinatedActivity {
  _OwnedWheelScrollActivity(super.delegate, this.motionOwner, {required super.onDisposed});
  @override
  final ScrollMotionOwner motionOwner;
  @override
  ElScrollActivityType get activityType => ElScrollActivityType.pointerScroll;
  @override
  void didCorrectPixels() {}
}

class _WheelScrollActivity extends ScrollActivity {
  _WheelScrollActivity(super.delegate, {required this.onDisposed});

  final VoidCallback onDisposed;

  bool disposed = false;

  @override
  bool get shouldIgnorePointer => false;

  @override
  bool get isScrolling => true;

  @override
  double velocity = 0.0;

  @override
  void dispose() {
    disposed = true;
    onDisposed();
    super.dispose();
  }
}
