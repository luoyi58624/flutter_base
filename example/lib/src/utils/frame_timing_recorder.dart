import 'dart:async';
import 'dart:developer' show Timeline;
import 'dart:math' as math;
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// 示例帧采样从准备到完成的状态。
enum FrameRecordingPhase {
  /// 尚未开始采样。
  idle,

  /// 等待用户离开设置页并进入目标页面。
  waiting,

  /// 正在显式时间窗口内收集帧。
  recording,

  /// 窗口已结束，等待引擎补发最后一批帧。
  draining,

  /// 采样结束，报告可以复制。
  complete,
}

/// 按显式窗口汇总 Flutter 管线耗时，保留窗口中的全部长帧间隔。
Map<String, Object?> summarizeFrameTimings({
  required Iterable<FrameTiming> timings,
  required int startUs,
  required int endUs,
  required double refreshRate,
  Map<String, Object?> metadata = const {},
}) {
  if (endUs < startUs) throw ArgumentError('采样结束时间不能早于开始时间');
  if (!refreshRate.isFinite || refreshRate <= 0) throw ArgumentError.value(refreshRate, 'refreshRate');
  final byTimestamp = <int, FrameTiming>{};
  for (final timing in timings) {
    final timestamp = timing.timestampInMicroseconds(FramePhase.vsyncStart);
    if (timestamp >= startUs && timestamp < endUs) byTimestamp[timestamp] = timing;
  }
  final timestamps = byTimestamp.keys.toList()..sort();
  final frames = [for (final timestamp in timestamps) byTimestamp[timestamp]!];
  final budgetUs = 1000000 / refreshRate;
  final intervals = [for (var i = 1; i < timestamps.length; i++) timestamps[i] - timestamps[i - 1]];
  return {
    'schema_version': 1,
    'source': 'Flutter.FrameTiming',
    'is_screen_presentation_timing': false,
    'metadata': Map<String, Object?>.of(metadata),
    'window': {
      'start_us': startUs,
      'end_us_exclusive': endUs,
      'duration_ms': (endUs - startUs) / 1000,
      'refresh_rate_hz': refreshRate,
      'budget_ms': budgetUs / 1000,
    },
    'frame_count': frames.length,
    'stationary_frame_count': metadata['window_kind'] == 'stationary' ? frames.length : null,
    'ui': _summarize([for (final frame in frames) frame.buildDuration.inMicroseconds], budgetUs),
    'raster': _summarize([for (final frame in frames) frame.rasterDuration.inMicroseconds], budgetUs),
    'vsync_overhead': _summarize([for (final frame in frames) frame.vsyncOverhead.inMicroseconds], budgetUs),
    'total_span': _summarize([for (final frame in frames) frame.totalSpan.inMicroseconds], budgetUs),
    // 只以显式窗口区分活动和空闲，不能把活动窗口中的严重停顿丢弃。
    'vsync_interval': {
      ..._summarize(intervals, budgetUs),
      'intervals_over_100ms': intervals.where((v) => v > 100000).length,
    },
    'raw_frames': [
      for (final frame in frames)
        {
          'vsync_start_us': frame.timestampInMicroseconds(FramePhase.vsyncStart),
          'ui_us': frame.buildDuration.inMicroseconds,
          'raster_us': frame.rasterDuration.inMicroseconds,
          'vsync_overhead_us': frame.vsyncOverhead.inMicroseconds,
          'total_span_us': frame.totalSpan.inMicroseconds,
        },
    ],
  };
}

Map<String, Object?> _summarize(List<int> values, double budgetUs) {
  values.sort();
  double percentile(double quantile) => values.isEmpty ? 0 : values[(values.length * quantile).ceil() - 1] / 1000;
  Map<String, Object> exceeded(double factor) {
    final count = values.where((value) => value > budgetUs * factor).length;
    return {'count': count, 'ratio': values.isEmpty ? 0.0 : count / values.length};
  }

  return {
    'sample_count': values.length,
    'p50_ms': percentile(.5),
    'p90_ms': percentile(.9),
    'p99_ms': percentile(.99),
    'max_ms': values.isEmpty ? 0.0 : values.last / 1000,
    'above_B': exceeded(1),
    'above_1_5B': exceeded(1.5),
    'above_2B': exceeded(2),
  };
}

/// 有限时长的帧耗时记录器，窗口内不刷新界面，结束后统一汇总。
class FrameTimingRecorder extends ChangeNotifier {
  /// 创建记录器；可替换时钟和排空等待以验证窗口边界与订阅生命周期。
  FrameTimingRecorder({
    SchedulerBinding? binding,
    int Function()? nowUs,
    this.drainDuration = const Duration(milliseconds: 1100),
  }) : _binding = binding ?? SchedulerBinding.instance,
       _nowUs = nowUs ?? (() => Timeline.now);

  final SchedulerBinding _binding;
  final int Function() _nowUs;

  /// 等待引擎批量投递尾部帧的时长，报告按时间戳过滤而非按送达时间过滤。
  final Duration drainDuration;
  final _frames = <FrameTiming>[];
  Timer? _timer;
  bool _subscribed = false;
  bool _disposed = false;
  int? _startUs;
  int? _endUs;
  double _refreshRate = 60;
  Map<String, Object?> _metadata = {};
  FrameRecordingPhase _phase = .idle;
  Map<String, Object?>? _report;

  /// 当前准备、采样和排空状态。
  FrameRecordingPhase get phase => _phase;

  /// 是否已有尚未结束的任务。
  bool get isActive => _phase == .waiting || _phase == .recording || _phase == .draining;

  /// 是否仍订阅引擎帧回调。
  bool get isSubscribed => _subscribed;

  /// 完成后的报告；新任务开始时清除。
  Map<String, Object?>? get report => _report;

  /// 安排一个采样窗口，延迟期间可离开设置页，零延迟适合离线测试。
  void start({
    required double refreshRate,
    required Map<String, Object?> metadata,
    Duration delay = const Duration(seconds: 3),
    Duration duration = const Duration(seconds: 10),
  }) {
    if (_disposed) throw StateError('记录器已释放');
    if (isActive) throw StateError('已有采样任务正在执行');
    if (duration <= Duration.zero || delay < Duration.zero) throw ArgumentError('采样时长必须为正，准备时间不能为负');
    if (!refreshRate.isFinite || refreshRate <= 0) throw ArgumentError.value(refreshRate, 'refreshRate');
    _report = null;
    _frames.clear();
    _startUs = null;
    _endUs = null;
    _refreshRate = refreshRate;
    _metadata = Map<String, Object?>.of(metadata);
    _phase = .waiting;
    // 开始按钮导致的界面帧发生在准备期；采样开始不额外通知 UI，避免静止测量自激。
    notifyListeners();
    if (delay == Duration.zero) {
      _begin(duration);
    } else {
      _timer = Timer(delay, () => _begin(duration));
    }
  }

  void _begin(Duration duration) {
    _startUs = _nowUs();
    _endUs = _startUs! + duration.inMicroseconds;
    _phase = .recording;
    _binding.addTimingsCallback(_onTimings);
    _subscribed = true;
    _timer = Timer(duration, _drain);
  }

  void _onTimings(List<FrameTiming> timings) {
    final start = _startUs;
    final end = _endUs;
    if (_disposed || start == null || end == null) return;
    for (final timing in timings) {
      final timestamp = timing.timestampInMicroseconds(FramePhase.vsyncStart);
      if (timestamp >= start && timestamp < end) _frames.add(timing);
    }
  }

  /// 取消尚未开始的任务，或结束当前窗口并等待最后一批帧。
  void stop() {
    if (_phase == .waiting) {
      _timer?.cancel();
      _phase = .idle;
      notifyListeners();
    } else if (_phase == .recording) {
      _endUs = math.max(_startUs!, math.min(_endUs!, _nowUs()));
      _drain();
    }
  }

  void _drain() {
    _timer?.cancel();
    _phase = .draining;
    // 窗口已封口，这次状态通知产生的帧不会计入测量。
    notifyListeners();
    _timer = Timer(drainDuration, _complete);
  }

  void _detach() {
    if (!_subscribed) return;
    _binding.removeTimingsCallback(_onTimings);
    _subscribed = false;
  }

  void _complete() {
    _detach();
    _report = summarizeFrameTimings(
      timings: _frames,
      startUs: _startUs!,
      endUs: _endUs!,
      refreshRate: _refreshRate,
      metadata: {..._metadata, 'drain_wait_ms': drainDuration.inMilliseconds},
    );
    _frames.clear();
    _phase = .complete;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _detach();
    _frames.clear();
    super.dispose();
  }
}
