part of 'index.dart';

class _RecyclerPointerScroll {
  ScrollPosition? _position;
  SmoothPointerScrollController? _smooth;
  final _retired = <SmoothPointerScrollController>{};
  int _binding = 0;
  bool _active = true;
  bool _disposed = false;

  void bind(ScrollPosition position, ElSmoothScroll? algorithm) {
    if (identical(_position, position)) {
      _smooth?.algorithm = algorithm;
      return;
    }
    final previous = _smooth;
    _binding++;
    _position = position;
    _smooth = SmoothPointerScrollController(
      position: () => position,
      targetOffsetForDelta: (delta, {from}) =>
          ((from ?? position.pixels) + delta).clamp(position.minScrollExtent, position.maxScrollExtent),
      algorithm: algorithm,
      debugLabel: 'RecyclerView pointer scroll',
    );
    if (previous == null) return;
    _retired.add(previous);
    // 位置可能因物理/控制器变化在 build 中换绑，终态通知留到安全阶段派发。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_retired.remove(previous)) previous.dispose();
    });
  }

  void handle(PointerSignalEvent event, AxisDirection direction, Set<LogicalKeyboardKey> modifiers) {
    if (event is PointerScrollInertiaCancelEvent) {
      reset();
      return;
    }
    final smooth = _smooth;
    final position = _position;
    if (!_active || _disposed || event is! PointerScrollEvent || smooth == null || smooth.algorithm == null) return;
    if (position == null || !position.hasPixels || !position.hasContentDimensions) return;
    if (!position.physics.shouldAcceptUserOffset(position)) return;
    final flip =
        event.kind == PointerDeviceKind.mouse && HardwareKeyboard.instance.logicalKeysPressed.any(modifiers.contains);
    final axis = flip ? flipAxis(axisDirectionToAxis(direction)) : axisDirectionToAxis(direction);
    var delta = axis == Axis.horizontal ? event.scrollDelta.dx : event.scrollDelta.dy;
    if (axisDirectionIsReversed(direction)) delta = -delta;
    if (delta == 0 || !smooth.canConsumeDelta(delta)) return;
    final binding = _binding;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (!_active || _disposed || binding != _binding || !identical(_smooth, smooth)) return;
      if (!smooth.canConsumeDelta(delta)) return;
      smooth.applyPointerScroll(event, delta);
      event.respond(allowPlatformDefault: false);
    });
  }

  void reset() {
    _binding++;
    _smooth?.reset();
    for (final previous in _retired) {
      previous.reset();
    }
  }

  void suspend() {
    _active = false;
    reset();
  }

  void resume() => _active = true;

  void dispose() {
    _disposed = true;
    _active = false;
    _binding++;
    _smooth?.dispose();
    for (final previous in _retired) {
      previous.dispose();
    }
    _retired.clear();
    _smooth = null;
    _position = null;
  }
}
