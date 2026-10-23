import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/scheduler.dart';

/// 帧驱动拖拽重采样核心（vsync 插值 + 有界外推）。
@internal
final class DragResampler {
  DragResampler({
    required this._onSample,
    required this.samplingOffset,
    required this.adaptive,
    required Duration seedTime,
    required Offset seedPosition,
  }) : _lastSampledPosition = seedPosition {
    _samples.add((time: seedTime, position: seedPosition));
  }

  static const Duration kResampleMaxPrediction = Duration(milliseconds: 8);
  static const Duration kResampleMinDelta = Duration(milliseconds: 2);
  static const Duration kResampleMaxDelta = Duration(milliseconds: 20);
  static const double kReversalReleasePx = 2.0;
  static const int kIdleGraceFrames = 4;

  final void Function(DragResampler sampler, Offset position, Offset delta)
  _onSample;
  final Duration samplingOffset;
  final bool adaptive;

  int _intervalEmaMicros = 0;
  final List<({Duration time, Offset position})> _samples = [];
  Offset _lastSampledPosition;
  int? _frameCallbackId;
  Duration? _lastSampleTime;
  int _idleGraceLeft = kIdleGraceFrames;
  bool _disposed = false;
  Offset? _emittedOvershootDir;
  Offset? _holdDir;
  double _holdAnchorAlong = 0;

  Offset get lastSampledPosition => _lastSampledPosition;

  Duration? get lastSampleTime => _lastSampleTime;

  void push(Duration timeStamp, Offset position) {
    if (_disposed) return;
    final intervalMicros = (timeStamp - _samples.last.time).inMicroseconds;
    _samples.add((time: timeStamp, position: position));
    if (intervalMicros >= kResampleMinDelta.inMicroseconds &&
        intervalMicros <= kResampleMaxDelta.inMicroseconds) {
      _intervalEmaMicros = _intervalEmaMicros == 0
          ? intervalMicros
          : (_intervalEmaMicros * 3 + intervalMicros) ~/ 4;
    }
    _idleGraceLeft = kIdleGraceFrames;
    _ensureScheduled();
  }

  int _effectiveOffsetMicros() {
    final base = samplingOffset.inMicroseconds;
    if (!adaptive || _intervalEmaMicros == 0) return base;
    const jitterMarginMicros = 2000;
    final trailing =
        _intervalEmaMicros + (_intervalEmaMicros >> 2) + jitterMarginMicros;
    final floor = -base;
    final ceiling = math.max(kResampleMaxDelta.inMicroseconds, floor);
    final clamped = math.min(math.max(trailing, floor), ceiling);
    return -clamped;
  }

  void _ensureScheduled() {
    if (_frameCallbackId != null || _disposed) return;
    _frameCallbackId = SchedulerBinding.instance.scheduleFrameCallback(
      _onFrame,
    );
  }

  void _onFrame(Duration _) {
    _frameCallbackId = null;
    if (_disposed) return;
    var sampleTime =
        SchedulerBinding.instance.currentSystemFrameTimeStamp +
        Duration(microseconds: _effectiveOffsetMicros());
    final previous = _lastSampleTime;
    if (previous != null && sampleTime < previous) sampleTime = previous;
    _lastSampleTime = sampleTime;
    final sampled = _samplePosition(sampleTime);
    final position = _gateOvershootReversal(sampled.position);
    if (position != null && position != _lastSampledPosition) {
      final delta = position - _lastSampledPosition;
      _lastSampledPosition = position;
      _emittedOvershootDir = sampled.overshootDir;
      _onSample(this, position, delta);
      if (_disposed) return;
    }
    if (_hasPendingMotion(sampleTime)) {
      _idleGraceLeft = kIdleGraceFrames;
      _ensureScheduled();
    } else if (_idleGraceLeft > 0) {
      _idleGraceLeft--;
      _ensureScheduled();
    }
  }

  ({Offset position, Offset? overshootDir}) _samplePosition(
    Duration sampleTime,
  ) {
    while (_samples.length > 2 && _samples[1].time <= sampleTime) {
      _samples.removeAt(0);
    }
    final first = _samples.first;
    if (_samples.length == 1 || first.time >= sampleTime) {
      return (position: first.position, overshootDir: null);
    }
    final next = _samples[1];
    final intervalMicros = (next.time - first.time).inMicroseconds;
    if (next.time > sampleTime) {
      if (intervalMicros < kResampleMinDelta.inMicroseconds) {
        return (position: next.position, overshootDir: null);
      }
      final t = (sampleTime - first.time).inMicroseconds / intervalMicros;
      return (
        position: Offset.lerp(first.position, next.position, t)!,
        overshootDir: null,
      );
    }
    if (intervalMicros < kResampleMinDelta.inMicroseconds ||
        intervalMicros > kResampleMaxDelta.inMicroseconds) {
      return (position: next.position, overshootDir: null);
    }
    final predictionMicros = math.min(
      intervalMicros ~/ 2,
      kResampleMaxPrediction.inMicroseconds,
    );
    final clampedMicros = math.min(
      sampleTime.inMicroseconds,
      next.time.inMicroseconds + predictionMicros,
    );
    final t = (clampedMicros - first.time.inMicroseconds) / intervalMicros;
    final basis = next.position - first.position;
    final overshot =
        clampedMicros > next.time.inMicroseconds && basis != Offset.zero;
    return (
      position: Offset.lerp(first.position, next.position, t)!,
      overshootDir: overshot ? basis : null,
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
    if (_holdAnchorAlong - along > kReversalReleasePx) {
      _holdDir = null;
      return candidate;
    }
    return null;
  }

  static double _alongDir(Offset p, Offset dir) =>
      p.dx * dir.dx + p.dy * dir.dy;

  bool isOvershootPayback(Offset tail) {
    final dir = _emittedOvershootDir;
    if (dir == null) return false;
    return tail.dx * dir.dx + tail.dy * dir.dy < 0;
  }

  bool _hasPendingMotion(Duration sampleTime) {
    final newest = _samples.last;
    if (sampleTime < newest.time) return true;
    if (_samples.length < 2) return false;
    final older = _samples[_samples.length - 2];
    final intervalMicros = (newest.time - older.time).inMicroseconds;
    if (intervalMicros < kResampleMinDelta.inMicroseconds ||
        intervalMicros > kResampleMaxDelta.inMicroseconds) {
      return false;
    }
    final predictionMicros = math.min(
      intervalMicros ~/ 2,
      kResampleMaxPrediction.inMicroseconds,
    );
    return sampleTime.inMicroseconds <
        newest.time.inMicroseconds + predictionMicros;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final id = _frameCallbackId;
    _frameCallbackId = null;
    if (id != null) SchedulerBinding.instance.cancelFrameCallbackWithId(id);
    _samples.clear();
  }
}
