import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/scheduler.dart';

/// 过渡与关键帧共用的帧时钟，只在首次播放时创建 Ticker。
@internal
final class ElAnimationClock {
  /// 创建时钟，回调接收两次 tick 之间的增量。
  ElAnimationClock(this.onTick);

  /// 每帧增量回调。
  final void Function(Duration delta) onTick;
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  /// 开始或继续播放，重新启动时清除上一轮的时间基准。
  void start() {
    final ticker = _ticker ??= Ticker(_tick);
    if (ticker.isActive) return;
    _lastElapsed = Duration.zero;
    ticker.start();
  }

  void _tick(Duration elapsed) {
    final delta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    onTick(delta);
  }

  /// 停止计时，保留可复用的 Ticker。
  void stop() => _ticker?.stop();

  /// 释放 Ticker。
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
  }
}
