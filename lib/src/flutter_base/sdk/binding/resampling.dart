import 'dart:math' as math;

import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';

/// 管理全局触摸生命周期与统一采样帧，不依赖任何业务手势或组件。
@internal
final class TouchEventResampler {
  // 与官方 VelocityTracker 的停顿窗口一致，迟到的帧输出不能重新激活旧速度。
  static const _stoppedInterval = Duration(milliseconds: 40);

  /// 通过绑定提供的分发与锁定状态接入官方事件管线。
  TouchEventResampler({
    required this.dispatch,
    required this.canDispatch,
    required this.isEnabled,
  });

  /// 继续执行官方命中测试与手势分发。
  final void Function(PointerEvent event) dispatch;

  /// 当前绑定是否允许分发事件。
  final bool Function() canDispatch;

  /// 当前是否仍应使用本采样管线。
  final bool Function() isEnabled;

  final Map<int, _TouchSequence> _touches = {};
  int? _frameCallbackId;
  int _idleGraceLeft = 0;

  /// 按下即时分发，移动按帧输出，结束前结清尚未输出的移动。
  void handleEvent(PointerEvent event) {
    final touch = _touches[event.pointer];
    if (event is PointerDownEvent && event.kind == PointerDeviceKind.touch) {
      _touches[event.pointer] = _TouchSequence(event);
      dispatch(event);
    } else if (event is PointerMoveEvent && touch != null) {
      if (event.timeStamp < touch.last.timeStamp) return;
      if (event.buttons != touch.last.buttons) {
        _flush(touch);
        _move(touch, event, event.position, event.timeStamp, realTail: true);
        if (identical(_touches[event.pointer], touch)) {
          _touches[event.pointer] = _TouchSequence(event);
        }
        return;
      }
      touch.last = event;
      if (!event.synthesized) touch.realVersion++;
      touch.sampler.push(event.timeStamp, event.position);
      _idleGraceLeft = 4;
      resume();
    } else if ((event is PointerUpEvent || event is PointerCancelEvent) &&
        touch != null) {
      // 先结束跟踪，避免业务回调重入时再次结算同一个触点。
      _touches.remove(event.pointer);
      if (event is PointerUpEvent) _flush(touch, endTime: event.timeStamp);
      dispatch(
        event.copyWith(
          device: touch.last.device,
          viewId: touch.last.viewId,
          kind: touch.last.kind,
          position: touch.position,
          timeStamp: _maxTime(event.timeStamp, touch.timeStamp),
        ),
      );
      if (_touches.isEmpty) _cancelFrame();
    } else if (event is PointerRemovedEvent && touch != null) {
      _touches.remove(event.pointer);
      dispatch(
        PointerCancelEvent(
          pointer: event.pointer,
          device: touch.last.device,
          viewId: touch.last.viewId,
          kind: touch.last.kind,
          position: touch.position,
          timeStamp: _maxTime(event.timeStamp, touch.timeStamp),
        ),
      );
      dispatch(event);
      if (_touches.isEmpty) _cancelFrame();
    } else {
      dispatch(event);
    }
  }

  /// 解锁或收到新移动后，最多只登记一个统一采样帧。
  void resume() {
    if (_frameCallbackId != null || _touches.isEmpty || !canDispatch()) return;
    _frameCallbackId = SchedulerBinding.instance.scheduleFrameCallback(
      _onFrame,
    );
  }

  void _onFrame(Duration _) {
    _frameCallbackId = null;
    if (!canDispatch()) return;
    if (!isEnabled()) {
      stop();
      return;
    }
    final touches = _touches.values.toList();
    if (touches.isEmpty) return;
    var offset = touches.first.sampler.effectiveOffset;
    for (final touch in touches.skip(1)) {
      final next = touch.sampler.effectiveOffset;
      if (next < offset) offset = next;
    }
    // 各手指共享采样时刻，避免不同触点节奏使缩放几何发生时间错位。
    final frameTime = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    final sampleTime = frameTime + offset;
    for (final touch in touches) {
      if (!canDispatch()) return;
      if (!identical(_touches[touch.last.pointer], touch)) continue;
      final sampled = touch.sampler.sample(sampleTime);
      if (sampled != null) {
        _move(
          touch,
          touch.last,
          sampled.position,
          sampled.timeStamp,
          stale: frameTime - touch.last.timeStamp > _stoppedInterval,
        );
      }
    }
    if (_touches.isEmpty) return;
    if (_touches.values.any((touch) => touch.sampler.hasPendingMotion)) {
      _idleGraceLeft = 4;
      resume();
    } else if (_idleGraceLeft > 0) {
      _idleGraceLeft--;
      resume();
    }
  }

  void _flush(_TouchSequence touch, {Duration? endTime}) {
    final last = touch.last;
    if (last is! PointerMoveEvent || last.position == touch.position) return;
    if (touch.sampler.isOvershootPayback(last.position - touch.position)) {
      return;
    }
    _move(
      touch,
      last,
      last.position,
      last.timeStamp,
      realTail: true,
      stale: endTime != null && endTime - last.timeStamp > _stoppedInterval,
    );
  }

  void _move(
    _TouchSequence touch,
    PointerEvent source,
    Offset position,
    Duration timeStamp, {
    bool realTail = false,
    bool stale = false,
  }) {
    final delta = position - touch.position;
    if (delta == Offset.zero && source.buttons == touch.last.buttons) return;
    timeStamp = _maxTime(timeStamp, touch.timeStamp);
    // 只有新真实输入驱动的输出参与官方估速，纯预测帧不伪造速度样本。
    final synthesized =
        source.synthesized ||
        stale ||
        (!realTail && touch.emittedVersion == touch.realVersion);
    touch.emittedVersion = touch.realVersion;
    touch.position = position;
    touch.timeStamp = timeStamp;
    dispatch(
      PointerMoveEvent(
        viewId: source.viewId,
        timeStamp: timeStamp,
        pointer: source.pointer,
        kind: source.kind,
        device: source.device,
        position: position,
        delta: delta,
        buttons: source.buttons,
        obscured: source.obscured,
        pressure: source.pressure,
        pressureMin: source.pressureMin,
        pressureMax: source.pressureMax,
        distanceMax: source.distanceMax,
        size: source.size,
        radiusMajor: source.radiusMajor,
        radiusMinor: source.radiusMinor,
        radiusMin: source.radiusMin,
        radiusMax: source.radiusMax,
        orientation: source.orientation,
        tilt: source.tilt,
        platformData: source.platformData,
        synthesized: synthesized,
        embedderId: source.embedderId,
      ).transformed(source.transform),
    );
  }

  static Duration _maxTime(Duration first, Duration second) =>
      first < second ? second : first;

  /// 让位官方采样前结清真实移动，并取消本管线的帧任务。
  void stop() {
    final touches = _touches.values.toList();
    clear();
    for (final touch in touches) {
      _flush(touch);
    }
  }

  /// 丢弃已结束或已重置绑定的状态，不额外派发事件。
  void clear() {
    _touches.clear();
    _cancelFrame();
  }

  void _cancelFrame() {
    final id = _frameCallbackId;
    _frameCallbackId = null;
    if (id != null) SchedulerBinding.instance.cancelFrameCallbackWithId(id);
    _idleGraceLeft = 0;
  }
}

final class _TouchSequence {
  _TouchSequence(PointerEvent event)
    : last = event,
      position = event.position,
      timeStamp = event.timeStamp,
      sampler = TouchPositionResampler(
        seedTime: event.timeStamp,
        seedPosition: event.position,
      );

  final TouchPositionResampler sampler;
  PointerEvent last;
  Offset position;
  Duration timeStamp;
  int realVersion = 0;
  int emittedVersion = 0;
}

/// 与事件分发解耦的触点采样内核：插值、自适应尾随及有界外推。
@internal
final class TouchPositionResampler {
  /// 以按下位置和时间建立采样序列，调参仅供内部算法回归使用。
  TouchPositionResampler({
    required Duration seedTime,
    required Offset seedPosition,
    this.samplingOffset = const Duration(milliseconds: -5),
    this.adaptive = true,
  }) : _lastSampledPosition = seedPosition,
       _lastSampleTime = seedTime {
    _samples.add((time: seedTime, position: seedPosition));
  }

  static const _maxPrediction = Duration(milliseconds: 8);
  static const _minDelta = Duration(milliseconds: 2);
  static const _maxDelta = Duration(milliseconds: 20);
  static const _reversalReleasePx = 2.0;

  /// 固定偏移或自适应尾随的下限。
  final Duration samplingOffset;

  /// 是否按真实触点周期调整尾随量。
  final bool adaptive;

  int _intervalEmaMicros = 0;
  final List<({Duration time, Offset position})> _samples = [];
  Offset _lastSampledPosition;
  Duration _lastSampleTime;
  Offset? _emittedOvershootDir;
  Offset? _holdDir;
  double _holdAnchorAlong = 0;

  /// 最近已经输出的位置。
  Offset get lastSampledPosition => _lastSampledPosition;

  /// 最近采样目标时刻，不随自适应偏移的变化回退。
  Duration get lastSampleTime => _lastSampleTime;

  /// 依据有效触点周期计算尾随量；同帧多指使用其中最大的尾随量。
  Duration get effectiveOffset {
    final base = samplingOffset.inMicroseconds;
    if (!adaptive || _intervalEmaMicros == 0) return samplingOffset;
    final trailing = _intervalEmaMicros + (_intervalEmaMicros >> 2) + 2000;
    final floor = -base;
    return Duration(
      microseconds: -math.min(
        math.max(trailing, floor),
        math.max(_maxDelta.inMicroseconds, floor),
      ),
    );
  }

  /// 接收真实坐标，拒绝倒序输入以免破坏插值区间。
  void push(Duration timeStamp, Offset position) {
    final interval = (timeStamp - _samples.last.time).inMicroseconds;
    if (interval < 0) return;
    if (interval == 0) {
      _samples[_samples.length - 1] = (time: timeStamp, position: position);
      return;
    }
    _samples.add((time: timeStamp, position: position));
    if (interval >= _minDelta.inMicroseconds &&
        interval <= _maxDelta.inMicroseconds) {
      _intervalEmaMicros = _intervalEmaMicros == 0
          ? interval
          : (_intervalEmaMicros * 3 + interval) ~/ 4;
    }
  }

  /// 在统一目标时刻采样；位置没变或需要抑制外推回收时不产生移动。
  ({Offset position, Offset delta, Duration timeStamp})? sample(
    Duration sampleTime,
  ) {
    if (sampleTime < _lastSampleTime) sampleTime = _lastSampleTime;
    _lastSampleTime = sampleTime;
    final sampled = _samplePosition(sampleTime);
    final position = _gateOvershootReversal(sampled.position);
    if (position == null || position == _lastSampledPosition) return null;
    final delta = position - _lastSampledPosition;
    _lastSampledPosition = position;
    _emittedOvershootDir = sampled.overshootDir;
    return (position: position, delta: delta, timeStamp: sampled.time);
  }

  ({Offset position, Offset? overshootDir, Duration time}) _samplePosition(
    Duration sampleTime,
  ) {
    while (_samples.length > 2 && _samples[1].time <= sampleTime) {
      _samples.removeAt(0);
    }
    final first = _samples.first;
    if (_samples.length == 1 || first.time >= sampleTime) {
      return (position: first.position, overshootDir: null, time: first.time);
    }
    final next = _samples[1];
    final interval = (next.time - first.time).inMicroseconds;
    if (next.time > sampleTime && interval >= _minDelta.inMicroseconds) {
      final t = (sampleTime - first.time).inMicroseconds / interval;
      return (
        position: Offset.lerp(first.position, next.position, t)!,
        overshootDir: null,
        time: sampleTime,
      );
    }
    if (interval < _minDelta.inMicroseconds ||
        interval > _maxDelta.inMicroseconds) {
      return (position: next.position, overshootDir: null, time: next.time);
    }
    final prediction = math.min(interval ~/ 2, _maxPrediction.inMicroseconds);
    final micros = math.min(
      sampleTime.inMicroseconds,
      next.time.inMicroseconds + prediction,
    );
    final t = (micros - first.time.inMicroseconds) / interval;
    final basis = next.position - first.position;
    return (
      position: Offset.lerp(first.position, next.position, t)!,
      overshootDir: micros > next.time.inMicroseconds && basis != Offset.zero
          ? basis
          : null,
      time: Duration(microseconds: micros),
    );
  }

  Offset? _gateOvershootReversal(Offset candidate) {
    var holdDir = _holdDir;
    if (holdDir == null) {
      final dir = _emittedOvershootDir;
      if (dir == null) return candidate;
      final step = candidate - _lastSampledPosition;
      if (step.dx * dir.dx + step.dy * dir.dy >= 0) return candidate;
      holdDir = dir / dir.distance;
      _holdDir = holdDir;
      _holdAnchorAlong = _alongDir(_samples.last.position, holdDir);
      return null;
    }
    final step = candidate - _lastSampledPosition;
    if (step.dx * holdDir.dx + step.dy * holdDir.dy >= 0) {
      _holdDir = null;
      return candidate;
    }
    final along = _alongDir(_samples.last.position, holdDir);
    if (along >= _holdAnchorAlong) {
      _holdAnchorAlong = along;
      return null;
    }
    if (_holdAnchorAlong - along > _reversalReleasePx) {
      _holdDir = null;
      return candidate;
    }
    return null;
  }

  static double _alongDir(Offset p, Offset dir) =>
      p.dx * dir.dx + p.dy * dir.dy;

  /// 判断尾差是否只是对外推过冲的反向偿还。
  bool isOvershootPayback(Offset tail) {
    final dir = _emittedOvershootDir;
    return dir != null && tail.dx * dir.dx + tail.dy * dir.dy < 0;
  }

  /// 判断现有样本是否仍有尚未输出的插值或外推区间。
  bool get hasPendingMotion {
    final newest = _samples.last;
    if (_lastSampleTime < newest.time) return true;
    if (_samples.length < 2) return false;
    final interval =
        (newest.time - _samples[_samples.length - 2].time).inMicroseconds;
    if (interval < _minDelta.inMicroseconds ||
        interval > _maxDelta.inMicroseconds) {
      return false;
    }
    return _lastSampleTime.inMicroseconds <
        newest.time.inMicroseconds +
            math.min(interval ~/ 2, _maxPrediction.inMicroseconds);
  }
}
