import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show TickerModeData;

/// 过渡与关键帧共用的帧时钟，只在首次播放时创建 Ticker。
@internal
final class ElAnimationClock {
  /// 创建时钟，回调接收两次 tick 之间的增量。
  ElAnimationClock(this.onTick, {TickerModeData tickerMode = TickerModeData.fallback}) : _tickerMode = tickerMode;

  /// 每帧增量回调。
  final void Function(Duration delta) onTick;
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  TickerModeData _tickerMode;

  /// 同步宿主的停表和强制帧策略，不改变动画自身的运行时间线。
  set tickerMode(TickerModeData value) {
    _tickerMode = value;
    final ticker = _ticker;
    if (ticker == null) return;
    ticker.forceFrames = value.forceFrames;
    ticker.muted = !value.enabled;
  }

  /// 开始或继续播放，重新启动时清除上一轮的时间基准。
  void start() {
    final ticker = _ticker ??= (Ticker(_tick)
      ..forceFrames = _tickerMode.forceFrames
      ..muted = !_tickerMode.enabled);
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
