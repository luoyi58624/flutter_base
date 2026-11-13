part of 'scroll.dart';

/// 按消息 ID 定位，并向页面报告聊天列表是否已接近最新位置。
class ElChatScrollController {
  /// 创建控制器，可在列表挂载前持有。
  ElChatScrollController();

  final _atLatest = ValueNotifier(true);
  _ChatScrollState? _state;
  var _disposed = false;

  /// 是否已经绑定聊天列表。
  bool get isAttached => _state != null;

  /// 是否处于最新端的 48 个逻辑像素内。
  ValueListenable<bool> get atLatest => _atLatest;

  /// 定位已加载的消息，[alignment] 从屏幕顶端 0 到底端 1。
  ///
  /// 返回目标是否已经可见，未挂载、找不到消息或操作被打断时返回 `false`。
  Future<bool> jumpToMessage(Object id, {double alignment = .5}) {
    assert(alignment >= 0 && alignment <= 1);
    return _state?._jumpToMessage(id, 1 - alignment) ?? Future.value(false);
  }

  /// 立即回到最新消息，返回操作是否完成。
  Future<bool> jumpToLatest() => _state?._goToLatest() ?? Future.value(false);

  /// 以动画回到最新消息，返回操作是否完成。
  Future<bool> animateToLatest({
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeOutCubic,
  }) => _state?._goToLatest(duration: duration, curve: curve) ?? Future.value(false);

  /// 释放控制器及其监听，调用方负责释放自己创建的实例。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _state?._cancelCommand();
    _state = null;
    _atLatest.dispose();
  }

  void _attach(_ChatScrollState state) {
    if (_disposed || (_state != null && !identical(_state, state))) {
      throw StateError('聊天控制器必须有效，且只能绑定一个聊天列表。');
    }
    _state = state;
  }

  void _detach(_ChatScrollState state) {
    if (!identical(_state, state)) return;
    _state = null;
    state._cancelCommand();
  }

  void _updateAtLatest(bool value) {
    if (!_disposed) _atLatest.value = value;
  }
}

extension on _ChatScrollState {
  void _cancelCommand() {
    _command++;
    _navigating = false;
    _recycler.cancel();
  }

  bool _isCurrent(int command, ScrollPosition position) =>
      mounted && command == _command && identical(_position, position);

  Future<bool> _goToLatest({Duration duration = Duration.zero, Curve curve = Curves.easeOutCubic}) async {
    final position = _position;
    if (position == null) return false;
    _cancelCommand();
    final command = _command;
    _navigating = true;
    try {
      final target = position.minScrollExtent;
      if (duration == Duration.zero) {
        if ((position.pixels - target).abs() < precisionErrorTolerance) return true;
        position.jumpTo(target);
      } else {
        await position.animateTo(target, duration: duration, curve: curve);
      }
      await SchedulerBinding.instance.endOfFrame;
      return _isCurrent(command, position) && (position.pixels - position.minScrollExtent).abs() < .5;
    } finally {
      _finishCommand(command);
    }
  }

  Future<bool> _jumpToMessage(Object id, double alignment) async {
    final position = _position;
    if (position == null || !_indices.containsKey(id)) return false;
    _cancelCommand();
    final command = _command;
    _navigating = true;
    try {
      if (_layout?._rowFor(id) == null && _recycler.isAttached && widget.sliverBuilder == null) {
        final index = _indices[id]!;
        if (!await _recycler.jumpToIndex(index, alignment: alignment) || !_isCurrent(command, position)) return false;
      }
      return await _revealMessage(id, alignment, position, command);
    } finally {
      _finishCommand(command);
    }
  }

  void _finishCommand(int command) {
    if (command != _command) return;
    _navigating = false;
    if (mounted) {
      _scheduleMetrics();
      SchedulerBinding.instance.ensureVisualUpdate();
    }
  }

  Future<bool> _revealMessage(Object id, double alignment, ScrollPosition position, int command) async {
    var remaining = _indices.length + 1;
    double? lower;
    double? upper;
    while (_isCurrent(command, position) && remaining-- > 0) {
      final index = _indices[id];
      final layout = _layout;
      if (index == null || layout == null) return false;
      if (layout._rowFor(id) case final row?) {
        final viewport = RenderAbstractViewport.maybeOf(row);
        if (viewport == null) return false;
        final target = viewport.getOffsetToReveal(row, alignment).offset;
        if (!target.isFinite) return false;
        position.jumpTo(target.clamp(position.minScrollExtent, position.maxScrollExtent));
        await SchedulerBinding.instance.endOfFrame;
        return _isCurrent(command, position) && _layout?.visibleIds.contains(id) == true;
      }

      // 自定义 Sliver 只需提供常规布局，通过可见消息区间逐步查找尚未构建的目标。
      final range = layout._visibleRange(_indices);
      if (range == null || (index >= range.newest && index <= range.oldest)) return false;
      final pixels = position.pixels;
      final towardHistory = index > range.oldest;
      if (towardHistory) {
        lower = pixels;
      } else {
        upper = pixels;
      }
      final step = math.max(1.0, position.viewportDimension * .8);
      final target = switch ((lower, upper)) {
        (final double low, final double high) => (low + high) / 2,
        _ => pixels + (towardHistory ? step : -step),
      };
      final next = target.clamp(position.minScrollExtent, position.maxScrollExtent);
      if ((pixels - next).abs() < .5) return false;
      position.jumpTo(next);
      await SchedulerBinding.instance.endOfFrame;
    }
    return false;
  }
}
