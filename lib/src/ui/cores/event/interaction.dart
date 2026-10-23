part of 'render.dart';

/// 只保存反馈计时，不保存手势资格、报名、归属或阶段状态。
final class _TapFeedback {
  _TapFeedback(this.onChanged);
  final ValueChanged<bool> onChanged;
  PointerEvent? _down;
  bool _released = false;
  Timer? _enter;
  Timer? _leave;
  bool value = false;
  PointerEvent? get contact => _down;

  void _set(bool next) {
    if (value == next) return;
    value = next;
    onChanged(next);
  }

  void down(PointerEvent source, ElEventConfig config) {
    final down = source.original ?? source;
    final minimum = config.delayTouchUp ?? const Duration(milliseconds: 100);
    final delay = down.kind == PointerDeviceKind.touch
        ? config.delayTouchDown ?? Duration.zero
        : Duration.zero;
    assert(minimum >= Duration.zero && delay >= Duration.zero);
    _enter?.cancel();
    if (!identical(_down, down)) {
      _leave?.cancel();
      _down = down;
      _released = false;
      if (down.kind == PointerDeviceKind.touch && minimum > Duration.zero) {
        _leave = Timer(minimum, () {
          _leave = null;
          if (identical(_down, down) && _released) cancel(down: down);
        });
      }
    }
    if (delay == Duration.zero) {
      _set(true);
    } else {
      _enter = Timer(delay, () {
        if (identical(_down, down) && !_released) _set(true);
      });
    }
  }

  void up(PointerEvent source) {
    final down = source.original ?? source;
    if (!identical(_down, down)) return;
    _released = true;
    _enter?.cancel();
    if (!value ||
        down.kind != PointerDeviceKind.touch ||
        !(_leave?.isActive ?? false)) {
      cancel(down: down);
    }
  }

  void cancel({required PointerEvent? down, bool preserveDuration = false}) {
    final source = down?.original ?? down;
    if (!identical(_down, source)) return;
    _enter?.cancel();
    _enter = null;
    if (!preserveDuration) {
      _leave?.cancel();
      _leave = null;
      _down = null;
    }
    _set(false);
  }
}
