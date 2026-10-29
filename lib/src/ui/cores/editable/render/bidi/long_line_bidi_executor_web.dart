import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'long_line_bidi_index.dart';
import 'long_line_cooperative_scheduler.dart';
import 'long_line_visual_index.dart';
import 'long_line_web_event_loop.dart';

/// 在 Web 主 isolate 内按硬预算协作式解析完整长行并建立视觉索引。
Future<({LongLineBidiIndex bidiIndex, LongLineVisualIndex visualIndex})> resolveLongLineBidiIndexes({
  required List<String> chunks,
  required int lineLength,
  required LongLineBidiBaseDirection direction,
  required double averageAdvance,
  required LongLineCooperativeCancellationToken cancellationToken,
}) async {
  final workingSetBytes = estimateLongLineBidiWorkingSetBytes(lineLength);
  final lease = await _webWorkingSetGate.acquire(workingSetBytes, cancellationToken: cancellationToken);
  final scheduler = LongLineCooperativeScheduler(
    yieldCallback: yieldLongLineWebEventLoop,
    isCancelled: () => cancellationToken.isCancelled,
  );
  try {
    final buffer = StringBuffer();
    var hydratedLength = 0;
    for (final chunk in chunks) {
      final pending = scheduler.reserve(1, phase: 'web.hydrate-chunks');
      if (pending != null) await pending;
      buffer.write(chunk);
      hydratedLength += chunk.length;
    }
    if (hydratedLength != lineLength) throw StateError('后台水合结果长度与声明的 lineLength 不一致');
    final text = lineLength == 0
        ? ''
        : await scheduler.runUninterruptible<String>(
            codeUnits: lineLength,
            bytes: lineLength * 2,
            phase: 'web.materialize-text',
            materialization: true,
            operation: buffer.toString,
          );
    final bidiIndex = await LongLineBidiIndex.resolveCooperatively(
      text,
      baseDirection: direction,
      scheduler: scheduler,
    );
    final visualIndex = await LongLineVisualIndex.createCooperatively(
      text: text,
      bidiIndex: bidiIndex,
      averageAdvance: averageAdvance,
      scheduler: scheduler,
    );
    scheduler.throwIfCancelled();
    return (bidiIndex: bidiIndex, visualIndex: visualIndex);
  } finally {
    scheduler.finish();
    lease.release();
  }
}

/// Web cooperative 解析使用的保守峰值工作集估算。
int estimateLongLineBidiWorkingSetBytes(int lineLength) {
  if (lineLength < 0) throw RangeError.value(lineLength, 'lineLength', '不得小于零');
  // 同时覆盖 UAX typed arrays、result maps、paint runs、tile objects、宽度树、
  // UTF-16 正文与 chunk/list headers；病态逐 code-unit 交替时按 192B/项保守计费。
  return 64 * 1024 + lineLength * 192;
}

/// 返回 Web 全局长行解析门当前的工作集诊断。
({int activeTasks, int activeBytes, int queuedTasks, int queuedBytes}) longLineBidiExecutorDiagnostics() =>
    _webWorkingSetGate.diagnostics;

/// Web 长行解析允许同时在途的保守工作集软上限。
///
/// 单个估算超过本值的任务仍会独占执行，避免合法巨行永久排队；本值只限制
/// 多任务并发叠加，不承诺浏览器进程的绝对内存硬上限。
const int longLineBidiWebWorkingSetBudgetBytes = 512 * 1024 * 1024;

/// 达到该估算值的单个任务必须独占 Web cooperative 解析门。
const int longLineBidiWebExclusiveTaskBytes = 128 * 1024 * 1024;

/// 用受控 action 白盒验证 Web 工作集门的排队、取消与释放。
@visibleForTesting
Future<T> runWithLongLineBidiWebGateForTesting<T>({
  required int estimatedBytes,
  required LongLineCooperativeCancellationToken cancellationToken,
  required Future<T> Function() action,
}) async {
  final lease = await _webWorkingSetGate.acquire(estimatedBytes, cancellationToken: cancellationToken);
  try {
    return await action();
  } finally {
    lease.release();
  }
}

final _LongLineBidiWebWorkingSetGate _webWorkingSetGate = _LongLineBidiWebWorkingSetGate();

final class _LongLineBidiWebWorkingSetGate {
  final Queue<_WebGateRequest> _queue = Queue<_WebGateRequest>();
  int _activeTasks = 0;
  int _activeBytes = 0;
  bool _exclusiveActive = false;

  ({int activeTasks, int activeBytes, int queuedTasks, int queuedBytes}) get diagnostics => (
    activeTasks: _activeTasks,
    activeBytes: _activeBytes,
    queuedTasks: _queue.length,
    queuedBytes: _queue.fold<int>(0, (sum, request) => sum + request.estimatedBytes),
  );

  Future<_WebGateLease> acquire(int estimatedBytes, {required LongLineCooperativeCancellationToken cancellationToken}) {
    if (estimatedBytes <= 0) throw RangeError.value(estimatedBytes, 'estimatedBytes', '必须大于零');
    if (cancellationToken.isCancelled) {
      return Future<_WebGateLease>.error(const LongLineCooperativeCancelledException());
    }
    final request = _WebGateRequest(gate: this, estimatedBytes: estimatedBytes, cancellationToken: cancellationToken);
    _queue.addLast(request);
    request.attachCancellation();
    _drain();
    return request.completer.future;
  }

  void _cancelQueued(_WebGateRequest request) {
    if (!_queue.remove(request)) return;
    request.detachCancellation();
    request.completer.completeError(const LongLineCooperativeCancelledException());
    _drain();
  }

  void _drain() {
    while (_queue.isNotEmpty) {
      final request = _queue.first;
      if (request.cancellationToken.isCancelled) {
        _queue.removeFirst();
        request.detachCancellation();
        request.completer.completeError(const LongLineCooperativeCancelledException());
        continue;
      }
      final exclusive = request.estimatedBytes >= longLineBidiWebExclusiveTaskBytes;
      if (_activeTasks > 0 && (exclusive || _exclusiveActive)) return;
      if (_activeTasks > 0 && _activeBytes + request.estimatedBytes > longLineBidiWebWorkingSetBudgetBytes) return;
      _queue.removeFirst();
      request.detachCancellation();
      _activeTasks++;
      _activeBytes += request.estimatedBytes;
      _exclusiveActive = exclusive;
      request.completer.complete(
        _WebGateLease(() {
          _activeTasks--;
          _activeBytes -= request.estimatedBytes;
          if (exclusive) _exclusiveActive = false;
          _drain();
        }),
      );
    }
  }
}

final class _WebGateRequest {
  _WebGateRequest({required this.gate, required this.estimatedBytes, required this.cancellationToken});

  final _LongLineBidiWebWorkingSetGate gate;
  final int estimatedBytes;
  final LongLineCooperativeCancellationToken cancellationToken;
  final Completer<_WebGateLease> completer = Completer<_WebGateLease>();
  late final void Function() _cancelListener = _handleCancellation;

  void attachCancellation() => cancellationToken.addListener(_cancelListener);

  void detachCancellation() => cancellationToken.removeListener(_cancelListener);

  void _handleCancellation() => gate._cancelQueued(this);
}

final class _WebGateLease {
  _WebGateLease(this._onRelease);

  final void Function() _onRelease;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _onRelease();
  }
}
