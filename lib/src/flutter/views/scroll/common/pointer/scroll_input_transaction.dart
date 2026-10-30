import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';

import '../../scroll_state.dart';
import '../viewport/scroll_engine_position.dart';

/// 可选输入事务中的已登记参与者，不向业务公开。
@internal
abstract interface class ScrollInputTransactionMember {
  /// 整次输入退出后释放快照，并安排登记配置提交。
  void finishInputTransaction();
}

/// 输入入口在预算处理前固定已提交参与配置。
@internal
abstract interface class ScrollInputTransactionSource {
  /// 加入新设备事务，嵌套旧协议也可继续传递当前事务。
  void joinInputTransaction(ScrollInputTransaction transaction);
}

/// 真实输入入口按需查询可消费自由度，并把释放交给唯一运动生产者。
@internal
abstract interface class ScrollMotionInput {
  /// 正文无范围时是否仍有已声明的输入行程。
  bool get hasMotionInputRange;

  /// 真实祖先已由统一路线处理，设备分发不得再次让渡整笔输入。
  bool get handlesAncestorInput;

  /// 取消当前输入所属的写入组，只影响仍持有令牌的活动。
  void cancelCoordinatedInput();

  /// 接收已经过过滤和连甩增强的物理轴速度，成功后不再启动原生 fling。
  ({bool handled, bool launched}) startReleasedMotion(DragEndDetails details);
}

/// 设备输入入口建立的同步事务，覆盖 pre、正文、post 和异常退出。
@internal
final class ScrollInputTransaction {
  ScrollInputTransaction._({
    required this.source,
    required this.rawEvent,
    required this.timeStamp,
    this.sessionId,
    this.onInputCancelled,
  }) : id = ++_nextId;

  static int _nextId = 0;
  static int _nextSessionId = 0;
  static ScrollInputTransaction? _current;

  /// 当前同步输入事务；默认未启用输入协作时保持 null。
  static ScrollInputTransaction? get current => _current;

  Object? _origin;

  /// 命中并拥有原始输入的宿主，祖先加入事务不会替换它。
  Object? get origin => _origin;

  /// 由实际输入入口确认源宿主，禁止一笔事务出现两个源。
  void establishOrigin(Object origin) {
    if (_origin != null && !identical(_origin, origin)) throw FlutterError('同一滚动输入只能拥有一个源宿主。');
    _origin = origin;
  }

  /// 为一个实际设备手势分配稳定会话号。
  static int newSessionId() => ++_nextSessionId;

  /// 独立设备输入不能在另一次输入的业务回调中同步重入。
  static ScrollInputTransaction begin({
    required ElScrollInputSource source,
    PointerEvent? rawEvent,
    Duration? timeStamp,
    int? sessionId,
    void Function(int? sessionId)? onInputCancelled,
    ScrollInputTransactionSource? participants,
  }) {
    if (_current != null) throw FlutterError('滚动输入事务不得同步重入。');
    final transaction = _current = ScrollInputTransaction._(
      source: source,
      rawEvent: rawEvent,
      timeStamp: timeStamp ?? rawEvent?.timeStamp ?? SchedulerBinding.instance.currentSystemFrameTimeStamp,
      sessionId: sessionId,
      onInputCancelled: onInputCancelled,
    );
    try {
      participants?.joinInputTransaction(transaction);
      return transaction;
    } catch (_) {
      transaction.close();
      rethrow;
    }
  }

  /// 当前事务号，嵌套协商和本地阶段共用。
  final int id;

  /// 原始输入适配后可确认的设备来源。
  final ElScrollInputSource source;

  /// 原始设备事件只供诊断，重采样可能继续引用上一条原始事件。
  final PointerEvent? rawEvent;

  /// 真正的事件或重采样时刻，与系统帧时间同域。
  final Duration timeStamp;

  /// 本次直接手势的会话号；独立信号或旧采样入口可能没有会话。
  final int? sessionId;

  /// 写入组被新命令接管时退役原设备序列，即使正文尚未创建 Drag。
  final void Function(int? sessionId)? onInputCancelled;

  final List<ScrollInputTransactionMember> _members = [];
  Map<Object, Object>? _writers;

  /// 登记本样本已取得的真实 position 写入令牌，普通输入不分配此表。
  void bindWriter(Object position, Object authority) {
    final writers = _writers ??= Map.identity();
    final previous = writers[position];
    if (previous != null && !identical(previous, authority)) throw FlutterError('同一输入样本不能为 position 登记两个 writer。');
    writers[position] = authority;
    if (position is ScrollEnginePosition && authority is ScrollMotionOwner) {
      position.beginMotionSample(authority, id, timeStamp);
    }
  }

  /// 真实设备适配器显式使用该令牌，业务 raw 命令不会自动继承它。
  Object? writerFor(Object position) => _writers?[position];

  /// 当前宿主首次参与时登记；由宿主保证同一事务不重复加入。
  void join(ScrollInputTransactionMember member) => _members.add(member);

  /// 所有收尾退出后才清理事务，输入结束回调同样不得同步重入独立输入。
  void close() {
    assert(identical(_current, this));
    Object? firstError;
    StackTrace? firstStack;
    try {
      for (final entry in _writers?.entries ?? const <MapEntry<Object, Object>>[]) {
        try {
          if (entry.key is ScrollEnginePosition && entry.value is ScrollMotionOwner) {
            (entry.key as ScrollEnginePosition).endMotionSample(entry.value as ScrollMotionOwner);
          }
        } catch (error, stack) {
          firstError ??= error;
          firstStack ??= stack;
        }
      }
      for (final member in _members) {
        try {
          member.finishInputTransaction();
        } catch (error, stack) {
          firstError ??= error;
          firstStack ??= stack;
        }
      }
    } finally {
      _current = null;
      _members.clear();
      _writers?.clear();
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
  }

  /// 内容拖拽按实际指针种类分类，不把未知设备冒充触屏。
  static ElScrollInputSource dragSource(PointerEvent? event) => switch (event?.kind) {
    PointerDeviceKind.touch => ElScrollInputSource.touch,
    PointerDeviceKind.stylus || PointerDeviceKind.invertedStylus => ElScrollInputSource.stylus,
    PointerDeviceKind.mouse => ElScrollInputSource.mouseDrag,
    PointerDeviceKind.trackpad => ElScrollInputSource.trackpad,
    _ => ElScrollInputSource.unknown,
  };
}
