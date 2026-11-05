import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

import 'long_line_bidi_index.dart';
import 'long_line_cooperative_scheduler.dart';
import 'long_line_visual_index.dart';

/// 在原生独立 isolate 解析完整长行并建立视觉索引。
Future<({LongLineBidiIndex bidiIndex, LongLineVisualIndex visualIndex})> resolveLongLineBidiIndexes({
  required List<String> chunks,
  required int lineLength,
  required LongLineBidiBaseDirection direction,
  required double averageAdvance,
  required LongLineCooperativeCancellationToken cancellationToken,
}) async {
  if (cancellationToken.isCancelled) throw const LongLineCooperativeCancelledException();
  final payload = (chunks: chunks, lineLength: lineLength, direction: direction, averageAdvance: averageAdvance);
  final workingSetBytes = estimateLongLineBidiWorkingSetBytes(lineLength);
  final lease = await _nativeExecutorGate.acquire(workingSetBytes, cancellationToken: cancellationToken);
  final response = ReceivePort('el_ui.longLineBidi.response');
  final errors = ReceivePort('el_ui.longLineBidi.errors');
  final exit = ReceivePort('el_ui.longLineBidi.exit');
  final resultCompleter = Completer<({LongLineBidiIndex bidiIndex, LongLineVisualIndex visualIndex})>();
  final exitCompleter = Completer<void>();
  late final StreamSubscription<Object?> responseSubscription;
  late final StreamSubscription<Object?> errorSubscription;
  late final StreamSubscription<Object?> exitSubscription;
  Isolate? isolate;
  var cancelled = false;
  void cancel() {
    cancelled = true;
    isolate?.kill(priority: Isolate.immediate);
  }

  cancellationToken.addListener(cancel);
  responseSubscription = response.listen((message) {
    if (resultCompleter.isCompleted) return;
    resultCompleter.complete(message as ({LongLineBidiIndex bidiIndex, LongLineVisualIndex visualIndex}));
  });
  errorSubscription = errors.listen((message) {
    if (resultCompleter.isCompleted) return;
    if (message case <Object?>[final Object? error, final Object? stack]) {
      resultCompleter.completeError(RemoteError('$error', '$stack'));
    } else {
      resultCompleter.completeError(StateError('长行 bidi isolate 返回未知错误：$message'));
    }
  });
  exitSubscription = exit.listen((_) {
    if (!exitCompleter.isCompleted) exitCompleter.complete();
    if (resultCompleter.isCompleted) return;
    resultCompleter.completeError(
      cancelled || cancellationToken.isCancelled
          ? const LongLineCooperativeCancelledException()
          : StateError('长行 bidi isolate 未返回结果即退出'),
    );
  });
  try {
    if (cancelled || cancellationToken.isCancelled) {
      throw const LongLineCooperativeCancelledException();
    }
    isolate = await Isolate.spawn(
      _resolveEntry,
      (sendPort: response.sendPort, payload: payload),
      onError: errors.sendPort,
      onExit: exit.sendPort,
      errorsAreFatal: true,
      debugName: 'el_ui.longLineBidi',
    );
    if (cancelled || cancellationToken.isCancelled) {
      isolate.kill(priority: Isolate.immediate);
    }
    final result = await resultCompleter.future;
    if (cancelled || cancellationToken.isCancelled) throw const LongLineCooperativeCancelledException();
    return result;
  } finally {
    cancellationToken.removeListener(cancel);
    final running = isolate;
    if (running != null) {
      running.kill(priority: Isolate.immediate);
      await exitCompleter.future;
    }
    await responseSubscription.cancel();
    await errorSubscription.cancel();
    await exitSubscription.cancel();
    response.close();
    errors.close();
    exit.close();
    lease.release();
  }
}

/// 返回与 Web 门一致的保守峰值工作集估算，供跨平台 diagnostics 使用。
int estimateLongLineBidiWorkingSetBytes(int lineLength) {
  if (lineLength < 0) throw RangeError.value(lineLength, 'lineLength', '不得小于零');
  return 64 * 1024 + lineLength * 192;
}

/// 返回原生可终止 isolate 的真实在途任务与保守工作集诊断。
({int activeTasks, int activeBytes, int queuedTasks, int queuedBytes}) longLineBidiExecutorDiagnostics() =>
    _nativeExecutorGate.diagnostics;

final _LongLineBidiNativeExecutorGate _nativeExecutorGate = _LongLineBidiNativeExecutorGate();

final class _LongLineBidiNativeExecutorGate {
  static const int maxActiveTasks = 2;

  final Queue<_NativeGateRequest> _queue = Queue<_NativeGateRequest>();
  int _activeTasks = 0;
  int _activeBytes = 0;

  ({int activeTasks, int activeBytes, int queuedTasks, int queuedBytes}) get diagnostics => (
    activeTasks: _activeTasks,
    activeBytes: _activeBytes,
    queuedTasks: _queue.length,
    queuedBytes: _queue.fold<int>(0, (sum, request) => sum + request.estimatedBytes),
  );

  Future<_NativeGateLease> acquire(
    int estimatedBytes, {
    required LongLineCooperativeCancellationToken cancellationToken,
  }) {
    if (estimatedBytes <= 0) throw RangeError.value(estimatedBytes, 'estimatedBytes', '必须大于零');
    if (cancellationToken.isCancelled) {
      return Future<_NativeGateLease>.error(const LongLineCooperativeCancelledException());
    }
    final request = _NativeGateRequest(
      gate: this,
      estimatedBytes: estimatedBytes,
      cancellationToken: cancellationToken,
    );
    _queue.addLast(request);
    request.attachCancellation();
    _drain();
    return request.completer.future;
  }

  void _cancelQueued(_NativeGateRequest request) {
    if (!_queue.remove(request)) return;
    request.detachCancellation();
    request.completer.completeError(const LongLineCooperativeCancelledException());
    _drain();
  }

  void _drain() {
    while (_activeTasks < maxActiveTasks && _queue.isNotEmpty) {
      final request = _queue.removeFirst();
      request.detachCancellation();
      if (request.cancellationToken.isCancelled) {
        request.completer.completeError(const LongLineCooperativeCancelledException());
        continue;
      }
      _activeTasks++;
      _activeBytes += request.estimatedBytes;
      request.completer.complete(
        _NativeGateLease(() {
          _activeTasks--;
          _activeBytes -= request.estimatedBytes;
          _drain();
        }),
      );
    }
  }
}

final class _NativeGateRequest {
  _NativeGateRequest({required this.gate, required this.estimatedBytes, required this.cancellationToken});

  final _LongLineBidiNativeExecutorGate gate;
  final int estimatedBytes;
  final LongLineCooperativeCancellationToken cancellationToken;
  final Completer<_NativeGateLease> completer = Completer<_NativeGateLease>();
  late final void Function() _cancelListener = _handleCancellation;

  void attachCancellation() => cancellationToken.addListener(_cancelListener);

  void detachCancellation() => cancellationToken.removeListener(_cancelListener);

  void _handleCancellation() => gate._cancelQueued(this);
}

final class _NativeGateLease {
  _NativeGateLease(this._onRelease);

  final void Function() _onRelease;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _onRelease();
  }
}

Future<void> _resolveEntry(
  ({
    SendPort sendPort,
    ({List<String> chunks, int lineLength, LongLineBidiBaseDirection direction, double averageAdvance}) payload,
  })
  message,
) async {
  final result = _resolvePayload(message.payload);
  message.sendPort.send(result);
  // 结果送达后继续持有事件端口，直到父 isolate kill 并观察到 onExit；这样
  // diagnostics 与 scope executor 槽绝不会早于真实 isolate 退出而释放。
  final hold = ReceivePort('el_ui.longLineBidi.hold');
  await hold.first;
}

({LongLineBidiIndex bidiIndex, LongLineVisualIndex visualIndex}) _resolvePayload(
  ({List<String> chunks, int lineLength, LongLineBidiBaseDirection direction, double averageAdvance}) payload,
) {
  final text = payload.lineLength == 0 ? '' : (StringBuffer()..writeAll(payload.chunks)).toString();
  if (text.length != payload.lineLength) throw StateError('后台水合结果长度与声明的 lineLength 不一致');
  final bidiIndex = LongLineBidiIndex.resolve(text, baseDirection: payload.direction);
  return (
    bidiIndex: bidiIndex,
    visualIndex: LongLineVisualIndex(text: text, bidiIndex: bidiIndex, averageAdvance: payload.averageAdvance),
  );
}
