part of '../dispatcher.dart';

/// 处理已经识别成功的拖拽输出，采样与代理分账不会反向改变手势归属。
final class _DragOutput {
  _DragOutput(
    this.host,
    ElTransformGestureDetails start, {
    bool resample = true,
  }) : axis = start.dragAxis,
       position = start.globalPosition,
       last = start,
       generation = host._transformGeneration {
    for (final member in host._chain().skip(1)) {
      final proxy = member.event?.dragProxy;
      if (proxy != null && (proxy.axis == null || proxy.axis == axis)) {
        proxies.add(member);
      } else if (member._hasDrag) {
        break;
      }
    }
    if (!resample) return;
    final platform = DragResamplingPolicy.hostPlatform;
    if (platform != null &&
        DragResamplingPolicy.allowsGlobalGate() &&
        host.config.dragResampling.contains(platform) &&
        dragResamplingAllowsKind(
          platform: platform,
          kind: start.originalEvent.kind,
        )) {
      sampler = createDragResampler(
        DragResamplingContext(
          refreshRate: host._displayRefreshRate(),
          seedTime: start.timeStamp,
          seedPosition: position,
          onSample: (sampler, next, delta) {
            if (_valid) {
              _deliver(next, delta, sampleTime: sampler.lastSampleTime);
            }
          },
        ),
      );
    }
  }

  final ElEventDispatcher host;
  final int generation;
  final Axis? axis;
  final List<ElEventDispatcher> proxies = [];
  DragResampler? sampler;
  Offset position;
  Offset offset = Offset.zero;
  ElTransformGestureDetails last;
  bool disposed = false;
  bool get _valid =>
      !disposed && !host._disposed && generation == host._transformGeneration;

  void update(ElTransformGestureDetails details) {
    if (!_valid) return;
    last = details;
    final current = sampler;
    if (current == null) {
      _deliver(details.globalPosition, details.delta);
    } else {
      current.push(details.timeStamp, details.globalPosition);
    }
  }

  void _deliver(Offset next, Offset delta, {Duration? sampleTime}) {
    if (!_valid) return;
    position = next;
    offset += delta;
    final callback = ElEventCallback(
      phase: ElEventPhase.dragUpdate,
      globalPosition: next,
      localPosition: host._local(next),
      delta: delta,
      localDelta: host._localDelta(next, delta),
      dragOffset: offset,
      dragAxis: axis,
      dragDirection: last.dragDirection,
      buttons: last.buttons,
      originalEvent: last.originalEvent,
      sampleTimeStamp: sampleTime,
    );
    callback.dragPipelineActive = proxies.isNotEmpty;
    callback.hasAncestorDragConsumer = host._transform?.parent != null;
    for (final member in proxies.reversed) {
      if (!_valid) return;
      _proxy(member, member.event?.dragProxy?.onDragPreUpdate, callback);
    }
    if (!_valid) return;
    _at(host, callback);
    callback.updateEagerGestureHandler(
      (callback, cancelTap, allowScale) => host._claim(
        host._snapshot(last).input.route,
        callback,
        cancelTap,
        allowScale,
      ),
    );
    host._invoke(host._handler(ElEventPhase.dragUpdate, axis), callback);
    if (callback.propagationStopped) last.stopPropagation();
    if (!_valid) return;
    for (final member in proxies) {
      if (!_valid || callback.remainingDelta == Offset.zero) break;
      _proxy(member, member.event?.dragProxy?.onDragOverflow, callback);
    }
  }

  void _at(ElEventDispatcher member, ElEventCallback callback) {
    callback.localPosition = member._local(callback.globalPosition);
    callback.localDelta = member._localDelta(
      callback.globalPosition,
      callback.delta,
    );
    callback.updateLocalDeltaResolver(
      (delta) => member._localDelta(callback.globalPosition, delta),
    );
  }

  void _proxy(
    ElEventDispatcher member,
    ElEventHandler? handler,
    ElEventCallback callback,
  ) {
    if (member._disposed || member.disabled || handler == null) return;
    _at(member, callback);
    callback.updateEagerGestureHandler(null);
    member._invoke(handler, callback);
    callback.resetPropagation();
  }

  void finish(ElTransformGestureDetails details, {required bool canceled}) {
    if (disposed) return;
    if (!canceled && sampler != null && last.globalPosition != position) {
      _deliver(last.globalPosition, last.globalPosition - position);
    }
    dispose();
  }

  void dispose() {
    if (disposed) return;
    disposed = true;
    sampler?.dispose();
    sampler = null;
  }
}
