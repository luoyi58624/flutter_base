import 'dart:async' show Timer;

/// 驱动 caret 以固定间隔翻转可见相位，并在交互后从可见相位重新计时。
///
/// 闪烁与帧率及位置动画无关，因此使用 [Timer]；宿主只在真实可编辑焦点
/// 存续期间启动，停止时零资源占用。
final class CaretBlinkDriver {
  /// 创建 caret 闪烁驱动。
  CaretBlinkDriver({required this.onPhase, this.interval = const Duration(milliseconds: 500)});

  /// 相位变化回调；true 表示 caret 应可见。
  final void Function(bool visible) onPhase;

  /// 相邻可见相位之间的翻转间隔。
  final Duration interval;

  Timer? _timer;
  bool _visible = true;

  /// 当前是否处于可见相位。
  bool get visible => _visible;

  /// 当前是否正在计时。
  bool get active => _timer != null;

  /// 立即回到可见相位，并从头开始下一段闪烁周期。
  void restart() {
    _timer?.cancel();
    if (!_visible) {
      _visible = true;
      onPhase(true);
    }
    _timer = Timer.periodic(interval, (_) {
      _visible = !_visible;
      onPhase(_visible);
    });
  }

  /// 停止计时并复位到可见初相，避免下次获焦从隐藏半拍开始。
  void stop() {
    _timer?.cancel();
    _timer = null;
    if (!_visible) {
      _visible = true;
      onPhase(true);
    }
  }

  /// 释放当前计时资源。
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
