import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;

/// 可主动通知排队门、同时供 cooperative 阶段轮询的取消令牌。
final class LongLineCooperativeCancellationToken {
  /// 创建一个尚未取消的令牌。
  LongLineCooperativeCancellationToken();

  bool _cancelled = false;
  final Set<void Function()> _listeners = <void Function()>{};

  /// 当前是否已经永久取消。
  bool get isCancelled => _cancelled;

  /// 注册取消监听；令牌已取消时会同步调用一次且不再保留。
  void addListener(void Function() listener) {
    if (_cancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  /// 移除尚未触发的取消监听。
  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// 永久取消并同步唤醒当前全部监听者；重复调用安全。
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final listeners = List<void Function()>.of(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }
}

/// 长行 Web 协作式解析每次让出事件循环前允许执行的抽象工作量。
///
/// 一个 work unit 表示一次 Unicode 原子、UTF-16 code unit、run、tile 或树节点
/// 的常数级处理；调用方必须在执行对应工作前通过 [reserve] 预留预算。
final class LongLineCooperativeScheduler {
  /// 创建一个具有确定性连续工作上限的协作式调度器。
  LongLineCooperativeScheduler({
    this.maxWorkUnitsBeforeYield = defaultMaxWorkUnitsBeforeYield,
    Future<void> Function()? yieldCallback,
    bool Function()? isCancelled,
    this.probe,
  }) : _yieldCallback = yieldCallback ?? _yieldToEventLoop,
       // 对外参数不能暴露私有字段名。
       // ignore: prefer_initializing_formals
       _isCancelled = isCancelled {
    if (maxWorkUnitsBeforeYield < minimumMaxWorkUnitsBeforeYield) {
      throw RangeError.range(maxWorkUnitsBeforeYield, minimumMaxWorkUnitsBeforeYield, null, 'maxWorkUnitsBeforeYield');
    }
  }

  /// 生产环境默认连续工作预算；约等于 8K 次常数级原子操作。
  static const int defaultMaxWorkUnitsBeforeYield = 8 * 1024;

  /// 单个 UAX #9 bracket-stack 常数步骤需要的最小原子预算。
  static const int minimumMaxWorkUnitsBeforeYield = 64;

  /// 每次真正让出事件循环前允许的最大 work units。
  final int maxWorkUnitsBeforeYield;

  /// 可选诊断探针，仅测试与 benchmark 应传入。
  final LongLineCooperativeProbe? probe;

  final Future<void> Function() _yieldCallback;
  final bool Function()? _isCancelled;
  int _reservedSinceYield = 0;
  int _yieldEpoch = 0;

  /// 最近一次真实让步所属代际；嵌套算法用它丢弃让步前的旧批次额度。
  int get reservationEpoch => _yieldEpoch;

  /// 在执行 [workUnits] 个常数级工作前预留预算。
  ///
  /// 返回 null 表示可立即继续；返回 Future 时调用方必须先 await，确保本批工作
  /// 不会突破 [maxWorkUnitsBeforeYield]。单次预留不得大于总预算。
  Future<void>? reserve(int workUnits, {required String phase}) {
    throwIfCancelled();
    if (workUnits <= 0 || workUnits > maxWorkUnitsBeforeYield) {
      throw RangeError.range(workUnits, 1, maxWorkUnitsBeforeYield, 'workUnits');
    }
    if (_reservedSinceYield + workUnits <= maxWorkUnitsBeforeYield) {
      _record(workUnits, phase);
      return null;
    }
    final pending = _beginYield();
    _record(workUnits, phase);
    return pending;
  }

  /// 判断嵌套 await 是否让旧批次额度失效，并把丢弃量写入诊断探针。
  bool discardReservationIfStale(int reservationEpoch, int unconsumedWorkUnits) {
    if (unconsumedWorkUnits < 0) {
      throw RangeError.value(unconsumedWorkUnits, 'unconsumedWorkUnits', '不得小于零');
    }
    if (reservationEpoch == _yieldEpoch) return false;
    if (unconsumedWorkUnits > 0) probe?._recordStaleReservationDiscard(unconsumedWorkUnits);
    return true;
  }

  /// 在不可中断的平台原语前后强制让步，并诚实记录其规模。
  ///
  /// Dart 的连续 typed-data 分配与 String 物化不能在原语内部暂停；该入口保证
  /// 它们独占一个事件循环片段、前后均检查取消，同时把未受 work-unit 预算
  /// 覆盖的规模暴露给 [probe]。
  Future<T> runUninterruptible<T>({
    required int codeUnits,
    int? bytes,
    required String phase,
    required bool materialization,
    required T Function() operation,
  }) async {
    if (codeUnits < 0) throw RangeError.value(codeUnits, 'codeUnits', '不得小于零');
    final resolvedBytes = bytes ?? codeUnits * (materialization ? 2 : 1);
    if (resolvedBytes < 0) throw RangeError.value(resolvedBytes, 'bytes', '不得小于零');
    throwIfCancelled();
    await _forceYield();
    probe?._recordUninterruptible(codeUnits, resolvedBytes, phase, materialization: materialization);
    final result = operation();
    await _forceYield();
    return result;
  }

  /// 当前任务已取消时立即抛出内部取消异常。
  void throwIfCancelled() {
    if (_isCancelled?.call() ?? false) {
      probe?._recordCancellation();
      throw const LongLineCooperativeCancelledException();
    }
  }

  /// 在管线完成时提交最后一个未满预算片段的诊断数据。
  void finish() => probe?._finish(_reservedSinceYield);

  void _record(int workUnits, String phase) {
    _reservedSinceYield += workUnits;
    probe?._recordWork(workUnits, _reservedSinceYield, phase);
  }

  Future<void> _beginYield() {
    probe?._recordYield();
    _reservedSinceYield = 0;
    _yieldEpoch++;
    return _yieldAndCheckCancellation();
  }

  Future<void> _forceYield() async {
    throwIfCancelled();
    await _beginYield();
  }

  Future<void> _yieldAndCheckCancellation() async {
    await _yieldCallback();
    throwIfCancelled();
  }

  static Future<void> _yieldToEventLoop() => Future<void>.delayed(Duration.zero);
}

/// Web cooperative 任务在阶段边界发现失效时使用的轻量取消异常。
final class LongLineCooperativeCancelledException implements Exception {
  /// 创建一个无载荷的协作式取消信号。
  const LongLineCooperativeCancelledException();

  @override
  String toString() => 'LongLineCooperativeCancelledException: 长行协作式任务已取消';
}

/// 协作式长行解析的确定性工作量诊断，仅用于测试与 benchmark。
@visibleForTesting
final class LongLineCooperativeProbe {
  int _yieldCount = 0;
  int _totalWorkUnits = 0;
  int _maximumContinuousWorkUnits = 0;
  int _staleReservationDiscardedWorkUnits = 0;
  int _cancellationCount = 0;
  int _largestUninterruptibleAllocationCodeUnits = 0;
  int _largestUninterruptibleMaterializationCodeUnits = 0;
  int _largestUninterruptibleAllocationBytes = 0;
  int _largestUninterruptibleMaterializationBytes = 0;
  final Map<String, int> _workUnitsByPhase = <String, int>{};
  final Map<String, int> _uninterruptibleCodeUnitsByPhase = <String, int>{};
  final Map<String, int> _uninterruptibleBytesByPhase = <String, int>{};

  /// 实际让出事件循环的次数。
  int get yieldCount => _yieldCount;

  /// 整条管线累计登记的 work units。
  int get totalWorkUnits => _totalWorkUnits;

  /// 两次让步之间观测到的最大可分片循环 work units。
  ///
  /// 连续分配与 String 物化不伪装进此值，分别读取
  /// [largestUninterruptibleAllocationCodeUnits] 与
  /// [largestUninterruptibleMaterializationCodeUnits]。
  int get maximumContinuousWorkUnits => _maximumContinuousWorkUnits;

  /// 嵌套 await 后被主动丢弃、未继续使用的旧批次额度总量。
  int get staleReservationDiscardedWorkUnits => _staleReservationDiscardedWorkUnits;

  /// 调度器实际观察到取消的次数。
  int get cancellationCount => _cancellationCount;

  /// 单次不可中断 typed-data/容器分配的最大逻辑 code-unit 规模。
  int get largestUninterruptibleAllocationCodeUnits => _largestUninterruptibleAllocationCodeUnits;

  /// 单次不可中断 String 物化的最大 UTF-16 code-unit 规模。
  int get largestUninterruptibleMaterializationCodeUnits => _largestUninterruptibleMaterializationCodeUnits;

  /// 单次不可中断 typed-data/容器分配的最大保守字节数。
  int get largestUninterruptibleAllocationBytes => _largestUninterruptibleAllocationBytes;

  /// 单次不可中断 String 物化的最大 UTF-16 字节数。
  int get largestUninterruptibleMaterializationBytes => _largestUninterruptibleMaterializationBytes;

  /// 各处理阶段累计登记的 work units 快照。
  Map<String, int> get workUnitsByPhase => Map<String, int>.unmodifiable(_workUnitsByPhase);

  /// 未受 work-unit 预算覆盖的平台原语规模，按阶段保留最大值。
  Map<String, int> get uninterruptibleCodeUnitsByPhase =>
      Map<String, int>.unmodifiable(_uninterruptibleCodeUnitsByPhase);

  /// 未受 work-unit 预算覆盖的平台原语字节数，按阶段保留最大值。
  Map<String, int> get uninterruptibleBytesByPhase => Map<String, int>.unmodifiable(_uninterruptibleBytesByPhase);

  void _recordYield() => _yieldCount++;

  void _recordStaleReservationDiscard(int workUnits) => _staleReservationDiscardedWorkUnits += workUnits;

  void _recordCancellation() => _cancellationCount++;

  void _recordUninterruptible(int codeUnits, int bytes, String phase, {required bool materialization}) {
    _uninterruptibleCodeUnitsByPhase.update(phase, (value) => math.max(value, codeUnits), ifAbsent: () => codeUnits);
    _uninterruptibleBytesByPhase.update(phase, (value) => math.max(value, bytes), ifAbsent: () => bytes);
    if (materialization) {
      _largestUninterruptibleMaterializationCodeUnits = math.max(
        _largestUninterruptibleMaterializationCodeUnits,
        codeUnits,
      );
      _largestUninterruptibleMaterializationBytes = math.max(_largestUninterruptibleMaterializationBytes, bytes);
    } else {
      _largestUninterruptibleAllocationCodeUnits = math.max(_largestUninterruptibleAllocationCodeUnits, codeUnits);
      _largestUninterruptibleAllocationBytes = math.max(_largestUninterruptibleAllocationBytes, bytes);
    }
  }

  void _recordWork(int workUnits, int continuousWorkUnits, String phase) {
    _totalWorkUnits += workUnits;
    _maximumContinuousWorkUnits = continuousWorkUnits > _maximumContinuousWorkUnits
        ? continuousWorkUnits
        : _maximumContinuousWorkUnits;
    _workUnitsByPhase.update(phase, (value) => value + workUnits, ifAbsent: () => workUnits);
  }

  void _finish(int continuousWorkUnits) {
    if (continuousWorkUnits > _maximumContinuousWorkUnits) {
      _maximumContinuousWorkUnits = continuousWorkUnits;
    }
  }
}
