part of '../virtual_pipeline.dart';

/// 实际输入与整组运动生命周期的不可变详情，两类终态通过各自钩子区分。
@immutable
final class ElScrollSessionDetails {
  /// 记录原会话身份和本次回调时的已提交观察。
  const ElScrollSessionDetails({
    required this.scrollView,
    required this.sourceScrollView,
    required this.axis,
    required this.bindingGeneration,
    required this.motionId,
    required this.sessionId,
    required this.source,
    required this.timeStamp,
    required this.rawEvent,
    required this.releaseVelocity,
    required this.snapshot,
  });

  /// 当前参与接力的实时宿主。
  final ElScrollViewState scrollView;

  /// 原始输入命中的实时源宿主。
  final ElScrollViewState sourceScrollView;

  /// 本组对应的轴。
  final Axis axis;

  /// 本组开始时此宿主的绑定代次，取消后的新绑定不会覆盖它。
  final int bindingGeneration;

  /// 全部参与宿主共享的运动组身份。
  final int motionId;

  /// 原设备会话身份，非设备启动的运动可能为空。
  final int? sessionId;

  /// 原始输入来源，续接惯性不会把它改成另一次设备输入。
  final ElScrollInputSource source;

  /// 本次事件或帧的真实系统时钟采样。
  final Duration timeStamp;

  /// 最近的原始输入事件，仅供诊断；运动终态可能晚于该事件。
  final PointerEvent? rawEvent;

  /// 原始释放速度，正值朝内容终点；没有释放跟踪器时为空。
  final double? releaseVelocity;

  /// 回调前共享的不可变观察，不把实时 position 作为历史状态。
  final ElScrollSnapshot snapshot;
}

enum _ScrollSessionPhase { inputStart, inputEnd, inputCancel, motionSettled, motionCancelled }

/// 每组只在开始和终态访问订阅者，不在运动 tick 扫描所有 Mixin。
final class _ScrollSession {
  _ScrollSession(this.route, ScrollInputTransaction? transaction)
    : motionId = ++_nextMotionId,
      sessionId = transaction?.sessionId,
      source = transaction?.source ?? ElScrollInputSource.unknown,
      timeStamp = transaction?.timeStamp ?? SchedulerBinding.instance.currentSystemFrameTimeStamp,
      rawEvent = transaction?.rawEvent;

  static int _nextMotionId = 0;
  final _ScrollInputRoute route;
  final int motionId;
  final int? sessionId;
  final ElScrollInputSource source;
  Duration timeStamp;
  PointerEvent? rawEvent;
  double? releaseVelocity;
  final List<_ScrollSessionClient> clients = [];
  bool _inputEnded = false;
  bool _finished = false;
  bool? _pendingFinish;
  int _dispatchDepth = 0;
  bool _settling = false;
  void Function(bool cancelled)? _beforeTerminal;

  void observeSample(ScrollInputTransaction transaction) {
    timeStamp = transaction.timeStamp;
    if (transaction.rawEvent != null) rawEvent = transaction.rawEvent;
  }

  void begin() {
    for (final host in [route.source, ...route.ancestors]) {
      final entries = host._mixinClients?.entries.toList(growable: false);
      if (entries == null) continue;
      for (final entry in entries) {
        if (!route.isCurrent) return;
        final client = entry.key;
        if (client is! ElScrollMixin ||
            !entry.value.wantsScrollSessions ||
            entry.value.axis != route.axis ||
            !client.mountedForScrollCallbacks) {
          continue;
        }
        final subscription = _ScrollSessionClient(this, client, host);
        clients.add(subscription);
        client._sessionSubscription = subscription;
      }
    }
    if (sessionId != null) _dispatch(_ScrollSessionPhase.inputStart);
  }

  void endInput() {
    if (_inputEnded || _finished) return;
    _inputEnded = true;
    if (sessionId != null) _dispatch(_ScrollSessionPhase.inputEnd);
  }

  ElScrollSessionDetails detailsFor(ElScrollViewState host, int generation) => ElScrollSessionDetails(
    scrollView: host,
    sourceScrollView: route.source,
    axis: route.axis,
    bindingGeneration: generation,
    motionId: motionId,
    sessionId: sessionId,
    source: source,
    timeStamp: timeStamp,
    rawEvent: rawEvent,
    releaseVelocity: releaseVelocity,
    snapshot: host.positionFor(route.axis) == null ? ElScrollSnapshot.detached : host._readMixinSnapshotFor(route.axis),
  );

  void _dispatch(_ScrollSessionPhase phase) {
    _withinLifecycleTransaction(() => _dispatchPhase(phase));
  }

  void _withinLifecycleTransaction(VoidCallback body, {ElScrollViewState? host}) {
    if (ScrollInputTransaction.current != null) {
      body();
      return;
    }
    final transaction = ScrollInputTransaction.begin(
      source: source,
      sessionId: sessionId,
      rawEvent: rawEvent,
      timeStamp: timeStamp,
    );
    try {
      transaction.establishOrigin(route.source);
      if (host != null) {
        host._inputRouter?._joinTransaction(transaction);
      } else {
        for (final client in clients) {
          client.host._inputRouter?._joinTransaction(transaction);
        }
      }
      body();
    } finally {
      transaction.close();
    }
  }

  void _dispatchPhase(_ScrollSessionPhase phase) {
    final details = <ElScrollViewState, ElScrollSessionDetails>{};
    // 同一批次先固定详情和终态，前一个回调的新命令不能重写后一个的历史。
    final notifications = <(_ScrollSessionClient, ElScrollSessionDetails)>[];
    for (final client in clients) {
      if (client.prepare(phase)) {
        notifications.add((
          client,
          details.putIfAbsent(client.host, () => detailsFor(client.host, client.bindingGeneration)),
        ));
      }
    }
    _dispatchDepth++;
    try {
      for (final entry in notifications) {
        if (phase == _ScrollSessionPhase.inputStart && !route.isCurrent) break;
        entry.$1.deliver(phase, entry.$2);
      }
    } finally {
      _dispatchDepth--;
      if (_dispatchDepth == 0 && _pendingFinish != null) {
        final cancelled = _pendingFinish!;
        _pendingFinish = null;
        _finishNow(cancelled);
      }
    }
  }

  void finish({required bool cancelled, void Function(bool cancelled)? beforeTerminal}) {
    if (_finished) return;
    _finished = true;
    _beforeTerminal = beforeTerminal;
    if (_dispatchDepth != 0) {
      _pendingFinish = cancelled;
    } else {
      _finishNow(cancelled);
    }
  }

  void _finishNow(bool cancelled) {
    timeStamp = ScrollInputTransaction.current?.timeStamp ?? SchedulerBinding.instance.currentSystemFrameTimeStamp;
    _settling = !cancelled;
    if (!_inputEnded && sessionId != null) {
      _inputEnded = true;
      _dispatch(cancelled ? _ScrollSessionPhase.inputCancel : _ScrollSessionPhase.inputEnd);
    }
    if (cancelled) {
      _terminate(true);
      return;
    }
    if (!_settling) return;
    final futures = <Future<void>>[];
    for (final subscription in clients.toList(growable: false)) {
      if (!_settling) return;
      final client = subscription.client;
      if (subscription._motionTerminal ||
          !client.mountedForScrollCallbacks ||
          !identical(client.scrollView, subscription.host)) {
        continue;
      }
      try {
        final future = client.onScrollSettle(detailsFor(subscription.host, subscription.bindingGeneration));
        if (future != null) futures.add(future.then<void>((_) {}, onError: _settleError));
      } catch (error, stack) {
        _settleError(error, stack);
      }
    }
    if (!_settling) return;
    if (futures.isEmpty) {
      _terminate(false);
    } else {
      Future.wait(futures).then((_) async {
        if (!_settling) return;
        await SchedulerBinding.instance.endOfFrame;
        if (_settling) _terminate(false);
      });
    }
  }

  void _settleError(Object error, StackTrace stack) {
    if (error is! TickerCanceled) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'el_ui scroll settle'));
    }
    cancelSettling();
  }

  void cancelSettling() {
    if (!_settling) {
      if (_pendingFinish == false) _pendingFinish = true;
      return;
    }
    _settling = false;
    if (_dispatchDepth != 0) {
      _pendingFinish = true;
    } else {
      _finishNow(true);
    }
  }

  void _terminate(bool cancelled) {
    _settling = false;
    final beforeTerminal = _beforeTerminal;
    _beforeTerminal = null;
    beforeTerminal?.call(cancelled);
    timeStamp = ScrollInputTransaction.current?.timeStamp ?? SchedulerBinding.instance.currentSystemFrameTimeStamp;
    _dispatch(cancelled ? _ScrollSessionPhase.motionCancelled : _ScrollSessionPhase.motionSettled);
    clients.clear();
    route._onLifecycleTerminated();
  }
}

/// State 的会话订阅可先于整组解绑，迟到终态不触碰新绑定。
final class _ScrollSessionClient {
  _ScrollSessionClient(this.session, this.client, this.host)
    : bindingGeneration = host._bindingGenerationFor(session.route.axis);
  final _ScrollSession session;
  final ElScrollMixin<StatefulWidget> client;
  final ElScrollViewState host;
  final int bindingGeneration;
  bool _started = false;
  bool _inputTerminal = false;
  bool _motionTerminal = false;
  bool _startDelivered = false;

  bool prepare(_ScrollSessionPhase phase) {
    if (_motionTerminal) return false;
    switch (phase) {
      case _ScrollSessionPhase.inputStart:
        if (_started) return false;
        _started = true;
      case _ScrollSessionPhase.inputEnd || _ScrollSessionPhase.inputCancel:
        if (!_startDelivered || _inputTerminal) return false;
        _inputTerminal = true;
      case _ScrollSessionPhase.motionSettled || _ScrollSessionPhase.motionCancelled:
        _motionTerminal = true;
        if (identical(client._sessionSubscription, this)) client._sessionSubscription = null;
        if (session.sessionId != null && !_startDelivered) return false;
    }
    return true;
  }

  void deliver(_ScrollSessionPhase phase, ElScrollSessionDetails details) {
    if (!client.mountedForScrollCallbacks || !identical(client.scrollView, host)) return;
    if (phase == _ScrollSessionPhase.inputStart) _startDelivered = true;
    try {
      client._handleSessionPhase(phase, details);
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'el_ui scroll session'));
    }
  }

  void cancel() {
    if (_motionTerminal) return;
    session._withinLifecycleTransaction(() {
      final details = session.detailsFor(host, bindingGeneration);
      if (prepare(_ScrollSessionPhase.inputCancel)) deliver(_ScrollSessionPhase.inputCancel, details);
      if (prepare(_ScrollSessionPhase.motionCancelled)) deliver(_ScrollSessionPhase.motionCancelled, details);
    }, host: host);
  }
}
