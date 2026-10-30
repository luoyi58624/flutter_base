import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/widgets.dart';

import '../../scroll_state.dart';

/// position 绑定提供真实代次，旧任务不能跨绑定继续写入。
@internal
abstract interface class ScrollPositionGeneration {
  /// 当前绑定代次。
  int get generation;

  /// 宿主仍在活动树中，允许派发通知和访问祖先。
  bool get contextActive;

  /// 销毁期抑制滚动偏移持久化：position 活动终态可能在已 deactivate 的
  /// element 上触发，祖先查找会断言，此时不应再写 PageStorage。
  void suppressOffsetPersistence();

  /// 是否已进入销毁期抑制。
  bool get offsetPersistenceSuppressed;
}

/// 与真实 position 写入令牌绑定的活动。
@internal
abstract interface class ScrollOwnedActivity {
  /// 此活动唯一可用的写入权。
  ScrollMotionOwner get motionOwner;
}

/// 宿主协调活动的明确分类及布局修正接线。
@internal
abstract interface class ScrollCoordinatedActivity implements ScrollOwnedActivity {
  /// 当前协调活动的实际类别。
  ElScrollActivityType get activityType;

  /// 记录坐标变化，不在布局阶段调用效果更新。
  void didCorrectPixels();
}

/// 设备适配器只把仍持有原活动的句柄视为活跃拖拽或 hold。
@internal
abstract interface class ScrollInputActivityHandle {
  /// 原令牌和原活动是否都还有效。
  bool get isCurrent;
}

/// 一个可取消操作持有的写入令牌，只在显式操作或协作运动启用时分配。
@internal
final class ScrollMotionOwner {
  ScrollMotionOwner._(this.position, this.id, this.bindingGeneration, this._cause, this._onCancelled, this.sessionId);

  /// 唯一的实际写入位置。
  final ScrollEnginePosition position;

  /// 当前 position 的递增 owner 号。
  final int id;

  /// 创建令牌时的绑定代次。
  final int bindingGeneration;

  /// 当前组继承的真实输入会话，绝对命令不继承被取消输入的身份。
  final int? sessionId;

  /// 本操作的运动归因。
  ElScrollUpdateCause get cause => _cause;
  ElScrollUpdateCause _cause;
  VoidCallback? _onCancelled;
  int? _sampleId;
  Duration? _sampleStamp;
  Duration? _lastSampleStamp;
  Duration? _velocityStamp;
  ElScrollUpdateCause? _sampleCause;
  AxisDirection? _sampleDirection;
  double _sampleMin = 0;
  double _sampleMax = 0;
  double _sampleStart = 0;
  double _sampleStartRaw = 0;
  double _sampleCorrection = 0;
  double? _sampleVelocity;

  /// 身份及绑定代次都匹配时才允许推进。
  bool get isCurrent => identical(position._motionOwner, this) && bindingGeneration == position._bindingGeneration;
}

/// 宿主可观测的真实 position，沿用 Flutter 的工厂、活动和通知生命周期。
@internal
class ScrollEnginePosition extends ScrollPositionWithSingleContext {
  /// 创建唯一的实际位置，不额外建立模拟 position。
  ScrollEnginePosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  ElScrollUpdateCause? _commandCause;
  ScrollMotionOwner? _motionOwner;
  ScrollMotionOwner? _executingOwner;
  ScrollMotionOwner? _activityOwner;
  ScrollActivity? _ownedActivity;
  int _nextOwnerId = 0;
  int? _executingCommand;
  double _heldInputVelocity = 0;
  bool get _commandRetired => _executingCommand != null && _executingCommand != _nextOwnerId;
  bool get _writeRetired => _commandRetired || (_executingOwner != null && !_executingOwner!.isCurrent);

  bool get _contextActive =>
      context is! ScrollPositionGeneration || (context as ScrollPositionGeneration).contextActive;

  /// 可选的宿主惯性入口，没有协调能力时保持 null。
  bool Function(double velocity)? ballisticHandler;

  int get _bindingGeneration =>
      context is ScrollPositionGeneration ? (context as ScrollPositionGeneration).generation : 0;

  /// 先失效旧操作，再取得当前绑定的写入权；取消回调只做内部终态结算。
  ScrollMotionOwner claimMotion({
    required ElScrollUpdateCause cause,
    required VoidCallback onCancelled,
    int? sessionId,
  }) {
    final id = ++_nextOwnerId;
    _revokeMotion();
    final owner = ScrollMotionOwner._(this, id, _bindingGeneration, cause, onCancelled, sessionId);
    if (id == _nextOwnerId) {
      _motionOwner = owner;
      onActivityChanged?.call();
    }
    return owner;
  }

  /// 同一运动组从直接输入转入惯性时保留令牌，只更新真实阶段的归因。
  void setMotionCause(ScrollMotionOwner owner, ElScrollUpdateCause cause) {
    if (!owner.isCurrent || owner._cause == cause) return;
    owner._cause = cause;
    owner._sampleId = null;
    owner._lastSampleStamp = null;
    owner._velocityStamp = null;
    owner._sampleVelocity = null;
  }

  void _revokeMotion() {
    final previous = _motionOwner;
    if (previous == null) return;
    endMotionSample(previous);
    if (!identical(_motionOwner, previous)) return;
    _motionOwner = null;
    final notify = previous._onCancelled;
    previous._onCancelled = null;
    notify?.call();
    onActivityChanged?.call();
  }

  bool _activityOwnedBy(ScrollMotionOwner owner) =>
      (activity is ScrollOwnedActivity && identical((activity as ScrollOwnedActivity).motionOwner, owner)) ||
      (identical(_activityOwner, owner) && identical(_ownedActivity, activity));

  R _withinOwner<R>(ScrollMotionOwner owner, R Function() action) {
    final previous = _executingOwner;
    final previousCommand = _executingCommand;
    _executingOwner = owner;
    _executingCommand = null;
    try {
      return action();
    } finally {
      _executingOwner = previous;
      _executingCommand = previousCommand;
    }
  }

  /// 已解析输入链的设备适配器显式取得官方 Drag，raw drag 仍会接管旧输入。
  Drag dragOwned(ScrollMotionOwner owner, DragStartDetails details, VoidCallback onCancelled) {
    if (!owner.isCurrent) return const _RetiredDrag();
    return _withinOwner(owner, () {
      // 手势阈值已在源输入识别完成，正文分账后的余量不能再被官方起动阈值吞掉。
      final carriedVelocity = physics.carriedMomentum(_heldInputVelocity);
      _heldInputVelocity = 0;
      final drag = ScrollDragController(
        delegate: this,
        details: details,
        onDragCanceled: onCancelled,
        carriedVelocity: carriedVelocity,
      );
      beginActivity(_OwnedDragActivity(this, owner, drag));
      return _GuardedDrag(this, owner, drag);
    });
  }

  /// 由原生 Drag 结算平台动量，实际惯性仍交给当前组的唯一协调器。
  bool endInputDragOwned(ScrollMotionOwner owner, DragEndDetails details, DragStartDetails start) {
    if (!owner.isCurrent) return false;
    try {
      if (activity is! _OwnedDragActivity) dragOwned(owner, start, () {});
      if (!owner.isCurrent) return false;
      final current = activity;
      if (current is! _OwnedDragActivity || !identical(current.motionOwner, owner)) return false;
      _withinOwner(owner, () => current.drag.end(details));
      return owner.isCurrent && observedActivity == ElScrollActivityType.ballistic;
    } catch (_) {
      cancelMotion(owner);
      rethrow;
    }
  }

  /// 在同一输入 owner 内建立 hold，旧 hold 的迟到取消不能覆盖新活动。
  ScrollHoldController holdOwned(ScrollMotionOwner owner, VoidCallback onCancelled) {
    if (!owner.isCurrent) return const _RetiredHold();
    return _withinOwner(owner, () => _GuardedHold(this, owner, super.hold(onCancelled)));
  }

  /// 安装当前令牌持有的活动，不创建第二个 position。
  bool startOwnedActivity(ScrollMotionOwner owner, ScrollActivity next) {
    if (!owner.isCurrent) {
      next.dispose();
      return false;
    }
    return _withinOwner(owner, () {
      beginActivity(next);
      return owner.isCurrent;
    });
  }

  /// 当前令牌才可推进内容，返回真实 position 拒绝的像素量。
  double setPixelsOwned(ScrollMotionOwner owner, double value) {
    if (!owner.isCurrent) return 0;
    final previous = _executingOwner;
    final previousCommand = _executingCommand;
    _executingOwner = owner;
    _executingCommand = null;
    try {
      return super.setPixels(value);
    } finally {
      _executingOwner = previous;
      _executingCommand = previousCommand;
    }
  }

  double _contentCoordinate(double value) =>
      (axisDirectionIsReversed(axisDirection) ? maxScrollExtent - value : value - minScrollExtent).clamp(
        0.0,
        maxScrollExtent - minScrollExtent,
      );

  /// 真实输入事务开始时记录正文基准，不用输入或 simulation 的总速度代替正文。
  void beginMotionSample(ScrollMotionOwner owner, int sampleId, Duration stamp) {
    if (!owner.isCurrent || !hasPixels || !hasContentDimensions || owner._sampleId == sampleId) return;
    owner._sampleId = sampleId;
    owner._sampleStamp = stamp;
    owner._sampleCause = owner.cause;
    owner._sampleDirection = axisDirection;
    owner._sampleMin = minScrollExtent;
    owner._sampleMax = maxScrollExtent;
    owner._sampleStart = _contentCoordinate(pixels);
    owner._sampleStartRaw = pixels;
    owner._sampleCorrection = 0;
  }

  /// 样本结束或 raw 命令接管前结算实际正文位移，观察只派发一次最终样本。
  void endMotionSample(ScrollMotionOwner owner) {
    if (!owner.isCurrent || owner._sampleId == null) return;
    owner._sampleId = null;
    final stamp = owner._sampleStamp!;
    final previous = owner._lastSampleStamp;
    final elapsed = previous == null ? 0 : (stamp - previous).inMicroseconds;
    final comparable =
        owner._sampleDirection == axisDirection &&
        owner._sampleMin == minScrollExtent &&
        (!axisDirectionIsReversed(axisDirection) || owner._sampleMax == maxScrollExtent);
    final delta = _contentCoordinate(pixels) - owner._sampleStart - owner._sampleCorrection;
    final velocity = comparable && elapsed > 0 ? delta * Duration.microsecondsPerSecond / elapsed : null;
    final oldVelocity = owner._sampleVelocity;
    owner._sampleVelocity = velocity != null && velocity.isFinite ? velocity : null;
    owner._velocityStamp = stamp;
    owner._lastSampleStamp = stamp;
    if (pixels != owner._sampleStartRaw || oldVelocity != owner._sampleVelocity || !comparable) {
      onMotionSample?.call(owner._sampleCause!, comparable ? delta : null);
    }
  }

  /// 同一时刻已完成的正文速度；新样本未完成或历史速度过期时为 null。
  double? motionVelocityAt(Duration stamp) {
    final owner = _motionOwner;
    return owner != null && owner.isCurrent && owner._sampleId == null && owner._velocityStamp == stamp
        ? owner._sampleVelocity
        : null;
  }

  /// 实际 position 通知尚在一笔受控样本内时，由样本终点合并观察。
  bool get hasActiveMotionSample => _motionOwner?.isCurrent == true && _motionOwner!._sampleId != null;

  /// 已被新命令接管的旧通知不能再次派发宿主快照。
  bool get isRetiredWrite => _writeRetired;

  /// 只停止此令牌仍持有的活动，旧令牌不会停止后来接管的动画。
  bool cancelMotion(ScrollMotionOwner owner) {
    if (!owner.isCurrent) return false;
    final shouldStop = _activityOwnedBy(owner);
    final previousActivity = activity;
    _revokeMotion();
    if (shouldStop && _motionOwner == null && identical(activity, previousActivity)) _stopOwnedActivity();
    return true;
  }

  /// 正常完成时释放令牌，不再发送取消终态。
  void completeMotion(ScrollMotionOwner owner) {
    if (!owner.isCurrent) return;
    owner._onCancelled = null;
    cancelMotion(owner);
  }

  /// 换绑定前停止旧 owned activity，禁止它被 Flutter absorb 转移到新 position。
  void retireMotion() {
    final owner = _motionOwner;
    final shouldStop = owner != null && _activityOwnedBy(owner);
    final previousActivity = activity;
    _revokeMotion();
    if (shouldStop && _motionOwner == null && identical(activity, previousActivity)) _stopOwnedActivity();
  }

  void _stopOwnedActivity() {
    final previous = _executingOwner;
    final previousCommand = _executingCommand;
    _executingOwner = null;
    _executingCommand = null;
    try {
      super.goIdle();
    } finally {
      _executingOwner = previous;
      _executingCommand = previousCommand;
    }
  }

  /// 在已取得的写入权内进行绝对定位，业务再次调用 raw API 仍会取得新权属。
  bool jumpToOwned(ScrollMotionOwner owner, double value, {ElScrollUpdateCause? cause}) {
    if (!owner.isCurrent) return false;
    final previousOwner = _executingOwner;
    final previousCause = _commandCause;
    final previousCommand = _executingCommand;
    _executingOwner = owner;
    _executingCommand = null;
    _commandCause = cause ?? owner.cause;
    try {
      super.jumpTo(value);
      return owner.isCurrent;
    } finally {
      _executingOwner = previousOwner;
      _commandCause = previousCause;
      _executingCommand = previousCommand;
    }
  }

  /// 在已取得的写入权内启动官方 driven activity，逐帧写入前验证令牌。
  Future<void> animateToOwned(ScrollMotionOwner owner, double to, {required Duration duration, required Curve curve}) {
    if (!owner.isCurrent) return Future<void>.value();
    if ((to - pixels).abs() <= physics.toleranceFor(this).distance) {
      jumpToOwned(owner, to);
      return Future<void>.value();
    }
    final next = _OwnedDrivenActivity(this, owner, to: to, duration: duration, curve: curve);
    final previous = _executingOwner;
    final previousCommand = _executingCommand;
    _executingOwner = owner;
    _executingCommand = null;
    try {
      beginActivity(next);
      return next.done;
    } finally {
      _executingOwner = previous;
      _executingCommand = previousCommand;
    }
  }

  /// 布局修正在原操作内记账，不能因为内部 jump 误判外部接管。
  void correctLayoutPixels(double value) {
    final owner = _motionOwner;
    if (owner != null && owner.isCurrent) {
      final currentActivity = activity;
      if (currentActivity is ScrollCoordinatedActivity || currentActivity is DragScrollActivity) {
        final previous = _commandCause;
        _commandCause = ElScrollUpdateCause.layoutCorrection;
        try {
          if (owner._sampleId != null) {
            owner._sampleCorrection += _contentCoordinate(value) - _contentCoordinate(pixels);
          }
          super.forcePixels(value);
          if (owner.isCurrent && identical(activity, currentActivity) && currentActivity is ScrollCoordinatedActivity) {
            (currentActivity as ScrollCoordinatedActivity).didCorrectPixels();
          }
        } finally {
          _commandCause = previous;
        }
      } else {
        jumpToOwned(owner, value, cause: ElScrollUpdateCause.layoutCorrection);
      }
    } else {
      jumpTo(value);
    }
  }

  /// 宿主按需监听活动切换；未订阅时为 null，不分配额外 notifier。
  VoidCallback? onActivityChanged;

  /// 可选的正文样本观察入口，没有滚动订阅者时保持 null。
  void Function(ElScrollUpdateCause cause, double? motionDelta)? onMotionSample;

  /// 只读取现役令牌上的会话，不能从外层尚未退出的旧输入事务推断。
  int? get observedSessionId => _motionOwner?.isCurrent == true ? _motionOwner!.sessionId : null;

  /// 读取本 position 实际持有的活动，未知自定义活动保留 unknown。
  ElScrollActivityType get observedActivity => switch (activity) {
    final ScrollCoordinatedActivity coordinated => coordinated.activityType,
    IdleScrollActivity() => ElScrollActivityType.idle,
    HoldScrollActivity() => ElScrollActivityType.hold,
    DragScrollActivity() => ElScrollActivityType.touchDrag,
    BallisticScrollActivity() => ElScrollActivityType.ballistic,
    DrivenScrollActivity() => ElScrollActivityType.programmatic,
    _ => ElScrollActivityType.unknown,
  };

  /// 同步命令优先，异步阶段从本 position 的真实活动读取来源。
  ElScrollUpdateCause get observedCause =>
      _commandCause ??
      (_motionOwner?.isCurrent == true ? _motionOwner!.cause : null) ??
      _drivenCause ??
      switch (activity) {
        DragScrollActivity() => ElScrollUpdateCause.userInput,
        BallisticScrollActivity() => ElScrollUpdateCause.ballistic,
        DrivenScrollActivity() => ElScrollUpdateCause.externalCommand,
        _ => ElScrollUpdateCause.unknown,
      };

  ElScrollUpdateCause? _drivenCause;

  @override
  void beginActivity(ScrollActivity? newActivity) {
    if (newActivity == null) return;
    final executing = _executingOwner;
    if (_commandRetired || (executing != null && !executing.isCurrent)) {
      newActivity.dispose();
      return;
    }
    if (executing == null) {
      final epoch = _nextOwnerId;
      _revokeMotion();
      if (epoch != _nextOwnerId) {
        newActivity.dispose();
        return;
      }
    }
    _activityOwner = executing;
    _ownedActivity = executing == null ? null : newActivity;
    _drivenCause = newActivity is DrivenScrollActivity ? _commandCause : null;
    if (onActivityChanged == null) {
      super.beginActivity(newActivity);
      return;
    }
    final before = observedActivity;
    super.beginActivity(newActivity);
    if (before != observedActivity) onActivityChanged?.call();
  }

  @override
  double setPixels(double newPixels) {
    if (_writeRetired) return 0;
    return super.setPixels(newPixels);
  }

  @override
  void forcePixels(double value) {
    if (!_writeRetired) super.forcePixels(value);
  }

  @override
  void didStartScroll() {
    if (!_writeRetired && _contextActive) super.didStartScroll();
  }

  @override
  void didUpdateScrollPositionBy(double delta) {
    if (!_writeRetired && _contextActive) super.didUpdateScrollPositionBy(delta);
  }

  @override
  void didEndScroll() {
    if (!_writeRetired && _contextActive) super.didEndScroll();
  }

  @override
  void didOverscrollBy(double value) {
    if (!_writeRetired && _contextActive) super.didOverscrollBy(value);
  }

  @override
  void didUpdateScrollDirection(ScrollDirection direction) {
    if (!_writeRetired && _contextActive) super.didUpdateScrollDirection(direction);
  }

  @override
  void saveScrollOffset() {
    // 基类会在活动终态直写偏移；销毁期抑制时同样要拦住。
    final ctx = context;
    if (ctx is ScrollPositionGeneration && (ctx as ScrollPositionGeneration).offsetPersistenceSuppressed) return;
    super.saveScrollOffset();
  }

  @override
  void jumpTo(double value) => _jumpTo(value, ElScrollUpdateCause.externalCommand);

  /// 滚动条等绝对用户操作保持原跳转语义，只补充真实运动来源。
  void jumpToFromInput(double value) => _jumpTo(value, ElScrollUpdateCause.userInput);

  void _jumpTo(double value, ElScrollUpdateCause cause) {
    final previous = _commandCause;
    final previousOwner = _executingOwner;
    final previousCommand = _executingCommand;
    _executingCommand = ++_nextOwnerId;
    _executingOwner = null;
    _commandCause = cause;
    try {
      _revokeMotion();
      if (_commandRetired) return;
      super.jumpTo(value);
    } finally {
      _commandCause = previous;
      _executingOwner = previousOwner;
      _executingCommand = previousCommand;
    }
  }

  @override
  Future<void> animateTo(double to, {required Duration duration, required Curve curve}) =>
      _animateTo(to, duration, curve, ElScrollUpdateCause.externalCommand);

  /// 保留滚动条按钮等用户动画来源，继续使用原生动画和结束后的物理回位。
  Future<void> animateToFromInput(double to, {required Duration duration, required Curve curve}) =>
      _animateTo(to, duration, curve, ElScrollUpdateCause.userInput);

  Future<void> _animateTo(double to, Duration duration, Curve curve, ElScrollUpdateCause cause) {
    final previous = _commandCause;
    final previousOwner = _executingOwner;
    final previousCommand = _executingCommand;
    _executingCommand = ++_nextOwnerId;
    _executingOwner = null;
    _commandCause = cause;
    try {
      _revokeMotion();
      if (_commandRetired) return Future<void>.value();
      return super.animateTo(to, duration: duration, curve: curve);
    } finally {
      _commandCause = previous;
      _executingOwner = previousOwner;
      _executingCommand = previousCommand;
    }
  }

  @override
  void pointerScroll(double delta) {
    final previous = _commandCause;
    final previousOwner = _executingOwner;
    final previousCommand = _executingCommand;
    _executingCommand = ++_nextOwnerId;
    _executingOwner = null;
    _commandCause = ElScrollUpdateCause.userInput;
    try {
      _revokeMotion();
      if (_commandRetired) return;
      super.pointerScroll(delta);
    } finally {
      _commandCause = previous;
      _executingOwner = previousOwner;
      _executingCommand = previousCommand;
    }
  }

  @override
  ScrollHoldController hold(VoidCallback holdCancelCallback) {
    // 必须先记住被接住的真实活动速度，取消旧组会立即处置它的 ticker。
    _heldInputVelocity = activity?.velocity ?? 0;
    final previous = _executingOwner;
    final previousCause = _commandCause;
    final previousCommand = _executingCommand;
    _executingCommand = ++_nextOwnerId;
    _executingOwner = null;
    _commandCause = ElScrollUpdateCause.userInput;
    try {
      _revokeMotion();
      if (_commandRetired) return const _RetiredHold();
      final hold = super.hold(holdCancelCallback);
      return _commandRetired ? const _RetiredHold() : hold;
    } finally {
      _executingOwner = previous;
      _commandCause = previousCause;
      _executingCommand = previousCommand;
    }
  }

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    final previous = _executingOwner;
    final previousCause = _commandCause;
    final previousCommand = _executingCommand;
    _executingCommand = ++_nextOwnerId;
    _executingOwner = null;
    _commandCause = ElScrollUpdateCause.userInput;
    try {
      _revokeMotion();
      if (_commandRetired) return const _RetiredDrag();
      final drag = super.drag(details, dragCancelCallback);
      return _commandRetired ? const _RetiredDrag() : drag;
    } finally {
      _executingOwner = previous;
      _commandCause = previousCause;
      _executingCommand = previousCommand;
    }
  }

  ScrollMotionOwner? get _continuingOwner {
    final executing = _executingOwner;
    if (executing != null) return executing;
    final owner = _motionOwner;
    return owner != null && _activityOwnedBy(owner) ? owner : null;
  }

  @override
  void goIdle() {
    if (_commandRetired) return;
    final owner = _continuingOwner;
    if (owner == null) {
      super.goIdle();
      return;
    }
    if (!owner.isCurrent) return;
    final previous = _executingOwner;
    _executingOwner = owner;
    try {
      super.goIdle();
    } finally {
      _executingOwner = previous;
    }
  }

  @override
  void goBallistic(double velocity) {
    if (_commandRetired) return;
    final owner = _continuingOwner;
    if ((owner == null || (owner.isCurrent && activity is _OwnedDragActivity)) &&
        _commandCause == null &&
        activity is! DrivenScrollActivity &&
        (ballisticHandler?.call(velocity) ?? false)) {
      return;
    }
    if (owner == null) {
      super.goBallistic(velocity);
      return;
    }
    if (!owner.isCurrent) return;
    final previous = _executingOwner;
    _executingOwner = owner;
    try {
      final simulation = physics.createBallisticSimulation(this, velocity);
      if (simulation == null) {
        super.goIdle();
      } else {
        beginActivity(_OwnedBallisticActivity(this, owner, simulation));
      }
    } finally {
      _executingOwner = previous;
    }
  }

  @override
  void dispose() {
    onActivityChanged = null;
    onMotionSample = null;
    ballisticHandler = null;
    _revokeMotion();
    super.dispose();
  }
}

final class _OwnedDragActivity extends DragScrollActivity implements ScrollOwnedActivity {
  _OwnedDragActivity(ScrollEnginePosition position, this.motionOwner, this.drag) : super(position, drag);
  @override
  final ScrollMotionOwner motionOwner;
  final ScrollDragController drag;
  @override
  void dispose() {
    super.dispose();
    drag.dispose();
  }
}

final class _RetiredDrag implements Drag, ScrollInputActivityHandle {
  const _RetiredDrag();
  @override
  bool get isCurrent => false;
  @override
  void update(DragUpdateDetails details) {}
  @override
  void end(DragEndDetails details) {}
  @override
  void cancel() {}
}

final class _RetiredHold implements ScrollHoldController, ScrollInputActivityHandle {
  const _RetiredHold();
  @override
  bool get isCurrent => false;
  @override
  void cancel() {}
}

final class _GuardedDrag implements Drag, ScrollInputActivityHandle {
  _GuardedDrag(this.position, this.owner, this.inner);
  final ScrollEnginePosition position;
  final ScrollMotionOwner owner;
  final Drag inner;
  @override
  bool get isCurrent =>
      owner.isCurrent &&
      position._activityOwnedBy(owner) &&
      position._ownedActivity is _OwnedDragActivity &&
      identical((position._ownedActivity! as _OwnedDragActivity).drag, inner);
  @override
  void update(DragUpdateDetails details) {
    if (isCurrent) position._withinOwner(owner, () => inner.update(details));
  }

  @override
  void end(DragEndDetails details) {
    if (isCurrent) position._withinOwner(owner, () => inner.end(details));
  }

  @override
  void cancel() {
    if (isCurrent) position._withinOwner(owner, inner.cancel);
  }
}

final class _GuardedHold implements ScrollHoldController, ScrollInputActivityHandle {
  _GuardedHold(this.position, this.owner, this.inner);
  final ScrollEnginePosition position;
  final ScrollMotionOwner owner;
  final ScrollHoldController inner;
  @override
  bool get isCurrent =>
      owner.isCurrent && position._activityOwnedBy(owner) && identical(position._ownedActivity, inner);
  @override
  void cancel() {
    if (isCurrent) position._withinOwner(owner, inner.cancel);
  }
}

final class _OwnedDrivenActivity extends DrivenScrollActivity implements ScrollOwnedActivity {
  _OwnedDrivenActivity(
    ScrollEnginePosition super.delegate,
    this.motionOwner, {
    required super.to,
    required super.duration,
    required super.curve,
  }) : super(from: delegate.pixels, vsync: delegate.context.vsync);

  @override
  final ScrollMotionOwner motionOwner;

  @override
  bool applyMoveTo(double value) {
    if (!motionOwner.isCurrent) return true;
    final applied = super.applyMoveTo(value);
    // 位置通知中允许新命令接管；旧 tick 的 goIdle 也不得覆盖新 activity。
    return !motionOwner.isCurrent || applied;
  }
}

final class _OwnedBallisticActivity extends BallisticScrollActivity implements ScrollOwnedActivity {
  _OwnedBallisticActivity(ScrollEnginePosition position, this.motionOwner, Simulation simulation)
    : super(position, simulation, position.context.vsync, position.shouldIgnorePointer);

  @override
  final ScrollMotionOwner motionOwner;

  @override
  bool applyMoveTo(double value) {
    if (!motionOwner.isCurrent) return true;
    final applied = super.applyMoveTo(value);
    return !motionOwner.isCurrent || applied;
  }
}
