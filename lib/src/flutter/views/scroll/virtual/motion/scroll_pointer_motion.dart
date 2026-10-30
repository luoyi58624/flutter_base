part of '../virtual_pipeline.dart';

/// 实际滚轮会话与真实路线共用所有权，曲线采样不依赖正文是否发生位移。
final class _ScrollPointerMotionSession implements ScrollPointerMotionSession {
  _ScrollPointerMotionSession(this.link, this._event, this._onCancelled)
    : route = link.host._ancestorRouteFor(link.axis)!,
      sessionId = ScrollInputTransaction.newSessionId();

  final _ScrollMixinInputLink link;
  final _ScrollInputRoute route;
  final int sessionId;
  final VoidCallback _onCancelled;
  PointerScrollEvent _event;
  ScrollMotionOwner? _owner;
  bool _finished = false;
  @override
  double inputPosition = 0;
  @override
  ScrollMotionOwner get motionOwner => _owner!;
  @override
  bool get isCurrent => !_finished && (_owner?.isCurrent ?? false) && route.isCurrent;

  ScrollInputTransaction _begin(Duration stamp) => ScrollInputTransaction.begin(
    source: ElScrollInputSource.pointerSignal,
    rawEvent: _event,
    timeStamp: stamp,
    sessionId: sessionId,
    onInputCancelled: (_) {
      if (_finished) return;
      _finished = true;
      _onCancelled();
    },
    participants: link,
  );

  void initialize() {
    try {
      final transaction = _begin(_event.timeStamp);
      try {
        _owner = route.sourceOwner;
      } finally {
        transaction.close();
      }
    } catch (_) {
      if (route._sessionId == sessionId) route.finish(cancelled: true);
      rethrow;
    }
  }

  @override
  void updateEvent(PointerScrollEvent event) {
    // 新原始事件仍是独立事务，不能在当前帧业务回调里同步重入并改写目标。
    final transaction = ScrollInputTransaction.begin(source: ElScrollInputSource.pointerSignal, rawEvent: event);
    try {
      _event = event;
    } finally {
      transaction.close();
    }
  }

  @override
  bool startActivity(ScrollActivity activity) {
    if (!isCurrent) {
      activity.dispose();
      return false;
    }
    final transaction = _begin(_event.timeStamp);
    try {
      if (!route.position.startOwnedActivity(motionOwner, activity)) return false;
      // 只有接收滚轮的正文进入滚动状态；祖先保留取消接线，不创建虚假的滚动活动。
      return isCurrent;
    } finally {
      transaction.close();
    }
  }

  @override
  double applyDelta(double delta, Duration timeStamp) {
    if (!isCurrent || delta.abs() <= precisionErrorTolerance) return delta;
    final transaction = _begin(timeStamp);
    try {
      final position = route.position;
      var remaining = delta;
      // 先偿还当前正文的越界量，只扣除实际恢复距离，不瞬移后再处理整笔输入。
      final recovery = position.pixels < position.minScrollExtent && remaining > 0
          ? math.min(remaining, position.minScrollExtent - position.pixels)
          : position.pixels > position.maxScrollExtent && remaining < 0
          ? math.max(remaining, position.maxScrollExtent - position.pixels)
          : 0.0;
      if (recovery != 0) {
        position.setPixelsOwned(motionOwner, position.pixels + recovery);
        remaining -= recovery;
      }
      if (!isCurrent) return delta;
      if (remaining.abs() > precisionErrorTolerance) {
        remaining -= link.interceptScrollDelta(remaining, ElScrollDeltaSource.pointerScroll);
      }
      if (!isCurrent) return delta;
      if (!position.outOfRange) {
        final accepted = remaining.clamp(
          position.minScrollExtent - position.pixels,
          position.maxScrollExtent - position.pixels,
        );
        if (accepted != 0) {
          position.setPixelsOwned(motionOwner, position.pixels + accepted);
          remaining -= accepted;
        }
      }
      if (!isCurrent) return delta;
      if (remaining.abs() > precisionErrorTolerance) {
        remaining -= link.interceptPostScroll(remaining, ElScrollDeltaSource.pointerScroll);
      }
      if (!isCurrent) return delta;
      inputPosition += delta - remaining;
      return remaining;
    } catch (_) {
      finish(cancelled: true);
      rethrow;
    } finally {
      transaction.close();
    }
  }

  @override
  void finish({required bool cancelled}) {
    if (_finished) return;
    _finished = true;
    if (!identical(route.sourceOwner, _owner)) return;
    ScrollInputTransaction? transaction;
    try {
      if (ScrollInputTransaction.current == null) {
        transaction = _begin(SchedulerBinding.instance.currentSystemFrameTimeStamp);
      }
      if (!cancelled) {
        route.endInput();
        if (!(_owner?.isCurrent ?? false)) return;
      }
      if (!cancelled && route.position.outOfRange) {
        // 信号生产者已经结束，仍越界的正文由同组唯一弹簧继续恢复。
        final continuation = link.host._motionCoordinatorFor(link.axis)?._tryBallistic(0);
        if (continuation?.handled ?? false) return;
      }
      route.finish(cancelled: cancelled);
    } catch (_) {
      route.finish(cancelled: true);
      rethrow;
    } finally {
      transaction?.close();
    }
  }
}
