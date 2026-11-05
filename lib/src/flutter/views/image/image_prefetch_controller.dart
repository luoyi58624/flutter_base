import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'image_decode_pipeline.dart';
import 'image_view.dart';

/// 按滚动方向与速度预解 cacheExtent 之外的图片，不改变 ElImageView 参数面。
class ImagePrefetchController {
  /// 创建方向预取控制器。
  ImagePrefetchController({this.workerCount = 1, this.lookAhead = const Duration(seconds: 2)});

  static const bool _configured = bool.fromEnvironment('EL_IMAGE_DIRECTIONAL_PREFETCH', defaultValue: true);

  /// 是否在当前平台启用；仅 Android 系统缩略图能证明预取不争抢原图解码槽。
  static bool get enabled =>
      _configured &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      ImageDecodePipeline.mediaStoreThumbnailEnabled;

  /// 测试钩子：在非 Android 测试进程强制开启调度。
  @visibleForTesting
  static bool debugForceEnabled = false;

  /// 测试钩子：替换实际图片预解，隔离验证方向窗口。
  @visibleForTesting
  static Future<void> Function(String source, Size size, double dpr, BoxFit fit)? debugPreloadOverride;

  /// 并行 worker 数；默认只占一个槽，避免预取反过来堵住可见图片。
  final int workerCount;

  /// 按当前速度向前预解的时间窗。
  final Duration lookAhead;

  int _generation = 0;
  int _direction = 0;
  int _cursor = 0;
  int _target = 0;
  int _activeWorkers = 0;
  int? _lastFirst;
  int? _lastMicros;
  int _teleportCooldownUntilMicros = 0;
  bool _disposed = false;
  List<String> _sources = const [];
  Size _size = Size.zero;
  double _devicePixelRatio = 1;
  BoxFit _fit = BoxFit.cover;
  int _scheduled = 0;
  int _completed = 0;

  /// 根据最新可见/挂载窗口更新方向、速度和预取终点。
  void update({
    required int first,
    required int last,
    required int mountedFirst,
    required int mountedLast,
    required List<String> sources,
    required Size size,
    required double devicePixelRatio,
    BoxFit fit = BoxFit.cover,
  }) {
    if (!(enabled || debugForceEnabled) || _disposed || sources.isEmpty || size.isEmpty || first == last) return;
    final now = DateTime.now().microsecondsSinceEpoch;
    final previousFirst = _lastFirst;
    final previousMicros = _lastMicros;
    final delta = previousFirst == null ? 0 : first - previousFirst;
    _lastFirst = first;
    _lastMicros = now;
    _sources = sources;
    _size = size;
    _devicePixelRatio = devicePixelRatio;
    _fit = fit;
    // 初次布局和仅 cacheExtent 变化都不代表用户滚动。此时预取会跟首屏可见图
    // 争抢系统缩略图槽位，所以只记录基线，等真实 index 位移后再启动。
    if (previousFirst == null || previousMicros == null || delta == 0) return;

    final visibleCount = math.max(1, last - first);
    final directionChanged = _direction != 0 && delta.sign != _direction;
    if (delta.abs() >= visibleCount || directionChanged) {
      // 滚动条跨区瞬移时，中间几百张根本不会进入视口；取消旧方向任务，
      // 快速来回拖还会逐帧反转方向，同样只让目标窗口的 ElImageView 自己抢
      // 可见优先槽，避免松手后后台解码洪峰。
      _generation++;
      _direction = 0;
      _cursor = 0;
      _target = 0;
      _teleportCooldownUntilMicros = now + const Duration(milliseconds: 200).inMicroseconds;
      return;
    }
    if (now < _teleportCooldownUntilMicros) return;

    final nextDirection = delta.sign;
    final dtSeconds = math.max(1, now - previousMicros) / Duration.microsecondsPerSecond;
    final velocity = delta.abs() / dtSeconds;
    final lookAheadCount = math.min(
      400,
      math.max(visibleCount * 4, (velocity * lookAhead.inMicroseconds / Duration.microsecondsPerSecond).ceil()),
    );

    if (nextDirection != _direction) {
      _generation++;
      _direction = nextDirection;
      _cursor = nextDirection > 0 ? mountedLast : mountedFirst - 1;
      _target = _cursor;
    }
    if (_direction > 0) {
      _target = math.max(_target, math.min(sources.length, mountedLast + lookAheadCount));
    } else {
      _target = math.min(_target, math.max(-1, mountedFirst - lookAheadCount - 1));
    }
    _ensureWorkers();
  }

  void _ensureWorkers() {
    while (_activeWorkers < workerCount && _hasWork) {
      _activeWorkers++;
      unawaited(_runWorker(_generation));
    }
  }

  bool get _hasWork => _direction > 0 ? _cursor < _target : _cursor > _target;

  Future<void> _runWorker(int generation) async {
    try {
      while (!_disposed && generation == _generation && _hasWork) {
        final index = _cursor;
        _cursor += _direction;
        if (index < 0 || index >= _sources.length) continue;
        _scheduled++;
        try {
          final debugPreload = debugPreloadOverride;
          if (debugPreload == null) {
            await ElImageView.preload(_sources[index], size: _size, devicePixelRatio: _devicePixelRatio, fit: _fit);
          } else {
            await debugPreload(_sources[index], _size, _devicePixelRatio, _fit);
          }
          _completed++;
        } catch (_) {
          // 单图损坏不阻断方向预取。
        }
      }
    } finally {
      _activeWorkers--;
      if (!_disposed && generation == _generation) _ensureWorkers();
    }
  }

  /// 图片列表或页面状态切换时取消当前方向任务。
  void reset() {
    _generation++;
    _direction = 0;
    _cursor = 0;
    _target = 0;
    _lastFirst = null;
    _lastMicros = null;
    _teleportCooldownUntilMicros = 0;
  }

  /// 释放控制器并阻止新任务入队。
  void dispose() {
    _disposed = true;
    reset();
  }

  /// 已进入预取 worker 的图片数，仅供性能诊断。
  int get debugScheduled => _scheduled;

  /// 已成功预解或命中缓存的图片数，仅供性能诊断。
  int get debugCompleted => _completed;
}
