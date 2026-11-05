import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show VoidCallback, internal;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show Axis, AxisDirection, Matrix4;
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter/services.dart' show LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter/widgets.dart' show FocusNode;

part 'transform.dart';

/// 按落点换算增量，供原始输入、手势与余量共用相同的坐标投影。
@internal
Offset transformGestureDelta(Matrix4? transform, Offset position, Offset delta) =>
    PointerEvent.transformDeltaViaPositions(
      transform: transform,
      untransformedDelta: delta,
      untransformedEndPosition: position,
    );

/// 同阶段成员共享的传播与默认动作控制，不依赖宿主或业务事件类型。
class GestureControl {
  /// 创建独立控制状态，或与现有派发共享控制。
  GestureControl({GestureControl? source}) : _controlSource = source;

  GestureControl? _controlSource;
  bool _propagationStopped = false;
  bool _defaultPrevented = false;

  GestureControl get _control => _controlSource?._control ?? this;

  /// 当前阶段是否已停止向后续成员传播。
  bool get propagationStopped => _control._propagationStopped;

  /// 当前阶段尚未执行的默认动作是否已取消。
  bool get defaultPrevented => _control._defaultPrevented;

  /// 停止当前阶段传播，具体家族边界由识别器处理。
  void stopPropagation() => _control._propagationStopped = true;

  /// 阻止当前阶段的后续默认动作，不改变官方竞技场已定归属。
  void preventDefault() => _control._defaultPrevented = true;

  /// 位移分配的独立阶段可复位传播标记，保留已经取消的默认动作。
  void resetPropagation() => _control._propagationStopped = false;
}

/// 包内共享控制接线，不经公共入口暴露给业务回调。
extension GestureControlAccess on GestureControl {
  /// 在派发前接入同阶段控制，保持默认动作与传播标记共享。
  void shareControl(GestureControl source) => _controlSource = source;
}

/// 一次原始输入的共享数据与控制，滚轮和触控板使用各自的真实位移。
final class PointerGestureDetails extends GestureControl {
  /// 从官方事件建立派发数据，特殊终态可沿用上一输入的位置。
  PointerGestureDetails(this.originalEvent, {Offset? position})
    : globalPosition =
          position ??
          switch (originalEvent) {
            PointerPanZoomUpdateEvent(:final position, :final pan) => position + pan,
            _ => originalEvent.position,
          },
      delta = switch (originalEvent) {
        PointerScrollEvent(:final scrollDelta) => scrollDelta,
        PointerPanZoomUpdateEvent(:final panDelta) => panDelta,
        _ => originalEvent.delta,
      };

  /// 当前物理输入，保留时间戳、设备和平台元数据。
  final PointerEvent originalEvent;

  /// 原始输入的全局位置。
  final Offset globalPosition;

  /// 滚轮、平移缩放或普通指针本次产生的全局位移。
  final Offset delta;

  bool _completed = false;
}

/// 事件阶段。
enum ElEventPhase {
  /// 指针进入。
  pointerEnter,

  /// 指针悬停。
  pointerHover,

  /// 指针离开。
  pointerExit,

  /// 指针按下。
  pointerDown,

  /// 指针移动。
  pointerMove,

  /// 指针抬起。
  pointerUp,

  /// 指针取消。
  pointerCancel,

  /// 触控板平移缩放开始。
  pointerPanZoomStart,

  /// 触控板平移缩放更新。
  pointerPanZoomUpdate,

  /// 触控板平移缩放结束。
  pointerPanZoomEnd,

  /// 鼠标滚轮或其他指针信号。
  pointerSignal,

  /// 主指针或键盘激活键按下。
  tapDown(.press, .candidate),

  /// 主指针或键盘激活键释放。
  tapUp(.press, .release),

  /// 点击。
  tap,

  /// 双击。
  doubleTap,

  /// 双击按下。
  doubleTapDown,

  /// 三击。
  tripleTap,

  /// 三击按下。
  tripleTapDown,

  /// 第二按钮按下，通常对应鼠标右键。
  secondaryTapDown(.press, .candidate),

  /// 第二按钮抬起。
  secondaryTapUp(.press, .release),

  /// 第二按钮点击。
  secondaryTap,

  /// 第三按钮按下，通常对应鼠标中键。
  tertiaryTapDown(.press, .candidate),

  /// 第三按钮抬起。
  tertiaryTapUp(.press, .release),

  /// 第三按钮点击。
  tertiaryTap,

  /// 前进按钮按下。
  forwardTapDown(.press, .candidate),

  /// 前进按钮抬起。
  forwardTapUp(.press, .release),

  /// 前进按钮点击。
  forwardTap,

  /// 后退按钮按下。
  backTapDown(.press, .candidate),

  /// 后退按钮抬起。
  backTapUp(.press, .release),

  /// 后退按钮点击。
  backTap,

  /// 长按。
  longPress,

  /// Tap 候选被取消。
  tapCancel(.press, .terminal),

  /// 拖拽候选按下。
  dragDown(.drag, .candidate),

  /// 拖拽开始。
  dragStart(.drag),

  /// 拖拽更新。
  dragUpdate(.drag, .update),

  /// 拖拽结束。
  dragEnd(.drag, .terminal),

  /// 拖拽取消。
  dragCancel(.drag, .terminal),

  /// 缩放开始。
  scaleStart(.scale, .candidate),

  /// 缩放更新。
  scaleUpdate(.scale, .update),

  /// 缩放结束。
  scaleEnd(.scale, .terminal),

  /// 缩放取消。
  scaleCancel(.scale, .terminal),

  /// 旋转更新。
  rotationUpdate(.scale, .update),

  /// 键盘按下。
  keyDown,

  /// 键盘重复按下。
  keyRepeat,

  /// 键盘抬起。
  keyUp,

  /// 获得焦点。
  focus,

  /// 失去焦点。
  blur;

  /// 拖拽的开始、更新和终止阶段，不包含候选按下。
  static const dragPhases = <ElEventPhase>[dragStart, dragUpdate, dragEnd, dragCancel];

  /// 缩放的开始、更新和终止阶段，不包含旋转更新。
  static const zoomPhases = <ElEventPhase>[scaleStart, scaleUpdate, scaleEnd, scaleCancel];

  /// 缩放与旋转共享的变换阶段。
  static const scalePhases = <ElEventPhase>[...zoomPhases, rotationUpdate];

  const ElEventPhase([this._family = .press, this._stage = .other]);

  final _GestureFamily _family;
  final _GestureStage _stage;

  bool get _terminal => _stage == .terminal || _stage == .release;
  bool get _candidate => _stage == .candidate;
  bool get _establishesBoundary => _stage != .terminal && _stage != .update;
}

/// 按压候选终止的原因，仅描述识别器自身的生命周期。
enum PressCancelReason {
  /// 移动容差、按钮变化或追加指针使候选失效。
  rejected,

  /// 外部资格暂时不满足，重新满足后可恢复按下候选。
  ineligible,

  /// 长按成立，结束普通点击候选。
  longPressAccepted,

  /// 官方竞技场将指针判给其他识别器。
  arenaRejected,

  /// 平台取消指针。
  pointerCanceled,

  /// 宿主主动取消或识别器销毁。
  canceled,
}

/// 按压识别回调，所有阶段都可以通过详情停止冒泡。
typedef PressGestureCallback = void Function(PressGestureDetails details);

/// 拖拽与变换回调，所有阶段都可以通过详情停止冒泡。
typedef TransformGestureCallback = void Function(TransformGestureDetails details);

typedef _GestureCallback = void Function(GestureDetails details);

/// 统一输入数据；原始事件类型由宿主或识别器的类型参数约束。
abstract class _InputData<E> extends GestureControl {
  /// 创建输入快照，本地位置默认与全局位置相同。
  _InputData({
    required this.phase,
    required this.originalEvent,
    required this.globalPosition,
    Offset? localPosition,
    this.sampleTimeStamp,
    GestureControl? control,
  }) : _localPosition = localPosition ?? globalPosition,
       super(source: control);

  /// 当前事件阶段。
  final ElEventPhase phase;

  /// 触发通知的原始事件，手势详情限定为 PointerEvent。
  final E originalEvent;

  /// 当前事件对应的指针事件；键盘/焦点事件为 null。
  PointerEvent? get pointerEvent => originalEvent is PointerEvent ? originalEvent as PointerEvent : null;

  /// 全局位置。
  final Offset globalPosition;

  /// 合成采样的实际时刻，为空时沿用原始输入时间。
  final Duration? sampleTimeStamp;

  Offset _localPosition;

  /// 当前目标的本地位置，冒泡时按目标坐标重定向。
  Offset get localPosition => _localPosition;

  PointerEvent? get _pointerEvent => originalEvent is PointerEvent ? originalEvent as PointerEvent : null;

  /// 当前通知的指针编号，非指针事件为零。
  int get pointer => _pointerEvent?.pointer ?? 0;

  /// 原始输入时间，不以输出采样时刻或回调处理时间代替。
  Duration get timeStamp => _pointerEvent?.timeStamp ?? Duration.zero;

  /// 当前输入按钮位，非指针事件为零。
  int get buttons => _pointerEvent?.buttons ?? 0;

  /// 全局横坐标。
  double get globalX => globalPosition.dx;

  /// 全局纵坐标。
  double get globalY => globalPosition.dy;

  /// 本地横坐标。
  double get localX => localPosition.dx;

  /// 本地纵坐标。
  double get localY => localPosition.dy;

  Object? _dispatchIdentity;
  Object? _sequenceIdentity;
  bool _isPrimaryTarget = true;
  bool Function()? _isActive;

  /// 本次派发是否仍有效，取消或回调重入后立即失效。
  bool get isActive => _isActive?.call() ?? true;

  /// 是否为当前阶段首个实际接收回调的成员。
  bool get isPrimaryTarget => _isPrimaryTarget;

  /// 同阶段共享的派发身份，用于共享默认动作与消费结果。
  Object get dispatchIdentity => _dispatchIdentity ?? this;

  /// 冻结路线的身份，延迟通知仍沿用原身份。
  Object get sequenceIdentity => _sequenceIdentity ?? dispatchIdentity;

  /// 适配层重定向当前目标的本地位置。
  void updateLocalPosition(Offset value) => _localPosition = value;

  void _updateTransform(Matrix4? transform) {
    _localPosition = PointerEvent.transformPosition(transform, globalPosition);
  }
}

/// 手势输入保留 PointerEvent 窄类型，不要求业务回调使用相同原始事件类型。
abstract class GestureDetails extends _InputData<PointerEvent> {
  /// 创建手势输入快照，本地位置默认与全局位置相同。
  GestureDetails({
    required super.phase,
    required super.originalEvent,
    required super.globalPosition,
    super.localPosition,
    super.sampleTimeStamp,
    super.control,
  });
}

/// 共享位移、速度与余量算法，按压详情不持有这些变换字段。
abstract class _MotionData<E> extends _InputData<E> {
  /// 创建变换快照，余量默认等于本次位移。
  _MotionData({
    required super.phase,
    required super.originalEvent,
    required super.globalPosition,
    super.localPosition,
    this.delta = Offset.zero,
    Offset localDelta = Offset.zero,
    Offset? remainingDelta,
    Offset? remainingLocalDelta,
    this.dragOffset = Offset.zero,
    this.dragDirection,
    this.dragAxis,
    this.velocity = Velocity.zero,
    this.primaryVelocity,
    int pointerCount = 0,
    this.scale = 1,
    this.rotation = 0,
    this.logScaleVelocity = 0,
    super.sampleTimeStamp,
    super.control,
  }) : _localDelta = localDelta,
       _remainingDelta = remainingDelta ?? delta,
       _remainingLocalDelta = remainingLocalDelta ?? localDelta,
       // 保留公开参数名，存储仍为只读 getter 的私有字段。
       // ignore: prefer_initializing_formals
       _pointerCount = pointerCount;

  /// 本次全局移动增量。
  final Offset delta;

  Offset _localDelta;
  Offset _remainingDelta;
  Offset _remainingLocalDelta;
  int _pointerCount;
  Offset Function(Offset)? _localDeltaResolver;
  Matrix4? _localTransform;

  /// 当前目标的本地移动增量。
  Offset get localDelta => _localDelta;

  /// 尚未消费的全局位移；预处理、主消费者、溢出处理共用同一台账。
  Offset get remainingDelta => _remainingDelta;

  /// 当前目标坐标系中尚未消费的本地位移。
  Offset get remainingLocalDelta => _remainingLocalDelta;

  /// 正式起拖后的累计位移，不包含激活前的 slop 段。
  final Offset dragOffset;

  /// 起手方向。
  final AxisDirection? dragDirection;

  /// 胜出轴向，自由拖拽为空。
  final Axis? dragAxis;

  /// 释放时的二维速度。
  final Velocity velocity;

  /// 显式主轴速度，可为空；具体识别详情可按目标本地速度重载。
  final double? primaryVelocity;

  /// 当前目标参与本阶段的指针数量，终止通知使用结算后的余数。
  int get pointerCount => _pointerCount;

  /// 本轮累计缩放比例。
  final double scale;

  /// 本轮累计旋转弧度。
  final double rotation;

  /// 对数缩放速度，单位为每秒，仅缩放结束时有意义。
  final double logScaleVelocity;

  /// 适配层写入目标本地数据；各字段独立更新，不隐式重新消费余量。
  void updateLocalMotion({Offset? localDelta, Offset? remainingDelta, Offset? remainingLocalDelta, int? pointerCount}) {
    if (localDelta != null) _localDelta = localDelta;
    if (remainingDelta != null) _remainingDelta = remainingDelta;
    if (remainingLocalDelta != null) _remainingLocalDelta = remainingLocalDelta;
    if (pointerCount != null) _pointerCount = pointerCount;
  }

  /// 重定向余量换算器，未消费时直接复用当前本地位移避免重复反解。
  void updateLocalDeltaResolver(Offset Function(Offset)? resolver) {
    _localDeltaResolver = resolver;
    _remainingLocalDelta = _remainingDelta == delta ? _localDelta : _resolveLocalDelta(_remainingDelta);
  }

  /// 同向消费并钳制到剩余量，不接受反向消费或超额反转。
  void consumeDelta(Offset requested) {
    final consumed = Offset(
      _consumable(_remainingDelta.dx, requested.dx),
      _consumable(_remainingDelta.dy, requested.dy),
    );
    if (consumed == Offset.zero) return;
    _remainingDelta -= consumed;
    _remainingLocalDelta = _resolveLocalDelta(_remainingDelta);
  }

  /// 消费指定轴上的位移。
  void consumePrimaryDelta(Axis axis, double requested) =>
      consumeDelta(axis == Axis.vertical ? Offset(0, requested) : Offset(requested, 0));

  /// 消费全部剩余位移。
  void consumeAllDelta() {
    _remainingDelta = Offset.zero;
    _remainingLocalDelta = Offset.zero;
  }

  /// 读取指定轴上尚未消费的位移。
  double remainingPrimaryDelta(Axis axis) => axis == Axis.vertical ? _remainingDelta.dy : _remainingDelta.dx;

  Offset _resolveLocalDelta(Offset value) => _localDeltaResolver?.call(value) ?? _transformDelta(value);

  Offset _transformDelta(Offset value) => transformGestureDelta(_localTransform, globalPosition, value);

  static double _consumable(double remaining, double requested) =>
      remaining == 0 || requested == 0 || remaining.sign != requested.sign
      ? 0
      : requested.abs() >= remaining.abs()
      ? remaining
      : requested;

  @override
  void _updateTransform(Matrix4? transform) {
    super._updateTransform(transform);
    _localTransform = transform;
    _localDelta = _transformDelta(delta);
    _remainingLocalDelta = _remainingDelta == delta ? _localDelta : _resolveLocalDelta(_remainingDelta);
  }
}

/// 焦点变化来源。
enum ElFocusReason {
  /// 用户代码直接调用 [FocusNode.requestFocus] / [FocusNode.unfocus]。
  programmatic,

  /// 指针按下触发聚焦。
  pointer,

  /// 键盘遍历触发聚焦。
  keyboard,

  /// 生命周期触发，例如自动聚焦、卸载或禁用。
  lifecycle,
}

/// `onTapCancel` 与合成 `onPointerCancel` 的语义原因。
///
/// 取消原因描述当前交互为何结束，让组件无需检查
/// [ElEventDetails.originalEvent] 的 Flutter 原始类型。
enum ElEventCancelReason {
  /// Tap 候选因越界、超距离、按键变化、追加指针或宿主漂移被拒绝，pointer
  /// 仍可继续投递。
  tapRejected,

  /// 当前节点的 Drag、Scale 或 eager 已接受，只取消本节点 Tap 激活资格。
  selfGestureAccepted,

  /// 其他节点或复合手势 driver 已接受，当前节点只取消 Tap/主手势资格。
  ///
  /// DragProxy 等旁路生命周期仍可继续投递，本值不表示整个 pointer 链已终止。
  otherGestureAccepted,

  /// 平台发出 PointerCancel，当前 pointer 序列已物理终止。
  pointerCanceled,

  /// 配置替换、宿主卸载或主动 cancelAll 等外部生命周期取消。
  external,
}

/// 业务事件详情；同阶段沿链复用，宿主逐级重写本地坐标与指针数量。
class ElEventDetails extends _MotionData<Object?> {
  /// 创建事件详情，保留非指针原始事件、显式主轴速度及独立初始余量。
  ElEventDetails({
    required super.phase,
    required super.globalPosition,
    required Offset localPosition,
    super.delta,
    super.localDelta,
    super.remainingDelta,
    super.remainingLocalDelta,
    super.dragOffset,
    super.dragDirection,
    super.dragAxis,
    super.velocity,
    super.primaryVelocity,
    this.buttons = 0,
    this.tapCount = 0,
    super.pointerCount,
    super.scale,
    super.rotation,
    super.logScaleVelocity,
    this.logicalKey,
    this.physicalKey,
    this.character,
    this.focusReason,
    ElEventCancelReason? cancelReason,
    super.originalEvent,
    super.sampleTimeStamp,
  }) : assert(
         phase == ElEventPhase.tapCancel || phase == ElEventPhase.pointerCancel || cancelReason == null,
         'cancelReason 只能用于 ElEventPhase.tapCancel 或 ElEventPhase.pointerCancel。',
       ),
       cancelReason = switch (phase) {
         ElEventPhase.tapCancel => cancelReason ?? ElEventCancelReason.external,
         ElEventPhase.pointerCancel => cancelReason ?? ElEventCancelReason.pointerCanceled,
         _ => null,
       },
       super(localPosition: localPosition);

  /// 当前指针按键位。
  @override
  final int buttons;

  /// 当前连续点击次数。
  final int tapCount;

  /// 键盘事件的逻辑按键。
  final LogicalKeyboardKey? logicalKey;

  /// 键盘事件的物理按键。
  final PhysicalKeyboardKey? physicalKey;

  /// 键盘事件产生的字符。
  final String? character;

  /// 焦点变化来源，仅 focus 与 blur 有值。
  final ElFocusReason? focusReason;

  /// 业务取消原因，仅 tapCancel 与 pointerCancel 有值。
  final ElEventCancelReason? cancelReason;

  /// 冒泡时由适配层更新当前目标的本地位置。
  set localPosition(Offset value) => updateLocalPosition(value);

  /// 冒泡时由适配层更新当前目标的本地增量。
  set localDelta(Offset value) => updateLocalMotion(localDelta: value);

  /// 保留业务管线直接写入全局余量的接口。
  set remainingDelta(Offset value) => updateLocalMotion(remainingDelta: value);

  /// 保留业务管线直接写入本地余量的接口。
  set remainingLocalDelta(Offset value) => updateLocalMotion(remainingLocalDelta: value);

  /// 终止通知按当前目标重写结算后的指针数量。
  set pointerCount(int value) => updateLocalMotion(pointerCount: value);

  void Function(ElEventDetails callback, bool cancelSelfTap, bool allowScaleUpgrade)? _eagerGestureHandler;
  VoidCallback? _preserveFocusHandler;
  bool _callbackInvoked = false;
  bool _keyboardTapMatched = false;

  /// 是否处于预处理、主消费者、溢出处理共用余量的拖拽管线。
  bool dragPipelineActive = false;

  /// 是否将本次方向的滚动边界弹性位移留给祖先。
  bool dragBoundaryHandoff = false;

  /// 是否仍有未失权、位于传播边界内且订阅同轴拖拽的祖先消费者。
  bool hasAncestorDragConsumer = false;

  /// 本阶段是否已执行过至少一个业务处理器。
  bool get callbackInvoked => _callbackInvoked;

  /// 请求独占当前指针；多指 Scale 整组认领，不改变真实悬停或全局输入锁。
  ///
  /// 失权成员先收到 PointerCancel，再按已公开阶段收到 Tap/Drag/Scale Cancel；
  /// 已有官方归属时同步清理；Down 的未决请求等官方裁决后提交，不隐式停止传播。
  /// [cancelSelfTap] 仅取消自己的最终点击，保留释放和拖拽；[allowScaleUpgrade]
  /// 允许同链多指缩放后来接管，默认关闭且不能恢复官方已判负的识别器。
  void eagerGesture({bool cancelSelfTap = false, bool allowScaleUpgrade = false}) {
    _eagerGestureHandler?.call(this, cancelSelfTap, allowScaleUpgrade);
  }

  /// 仅在 PointerDown 保留现有焦点，不阻断传播或其他默认动作。
  void preserveFocus() => _preserveFocusHandler?.call();

  /// 按当前阶段截断祖先交互，不认领指针或阻断 Flutter 的物理投递。
  ///
  /// PointerDown 阻断整条指针链；TapDown、TapUp 分别截断后续点击家族，Tap 只截当前点击；
  /// DragDown/Start、ScaleStart、PanZoomStart 分别建立自己的路线边界。
  /// 高频 Move/DragUpdate 不做通用冒泡；需要持续独占时在胜出起点调用 eagerGesture。
  @override
  void stopPropagation() => super.stopPropagation();

  /// 取消本阶段尚未执行的默认动作，同阶段祖先共享标记，下一阶段重新开始。
  ///
  /// 不追溯撤销已执行的子动作，也不停止传播、独占手势或消费位移。
  /// 长按可阻止自动认领与点击取消；滚轮可阻止平台及组件默认滚动；
  /// 滚动 Drag/PanZoom 起点与更新可锁存拒绝后续默认滚动，End 仅拒绝惯性且终态始终清理。
  /// 键盘报告 handled 并跳过内建焦点遍历；组件 Tap 可拒绝按下动作、导航或关闭。
  /// PointerDown 不因此阻止指针聚焦、后续手势或已经执行的滚动 hold。
  @override
  void preventDefault() => super.preventDefault();
}

/// 包内业务回调接线，不经公共入口暴露给事件订阅方。
extension EventDetailsAccess on ElEventDetails {
  /// 当前键盘阶段是否配对主焦点节点的按下，供按钮判定 Space 释放激活。
  bool get keyboardTapMatched => _keyboardTapMatched;

  /// 由分发器按当前接收节点更新键盘配对事实，不进入公共事件参数。
  void updateKeyboardTapMatched(bool value) => _keyboardTapMatched = value;

  /// 标记本阶段已执行业务处理器。
  void markCallbackInvoked() => _callbackInvoked = true;

  /// 更新当前目标的独占请求处理器，代理阶段可暂时清空。
  void updateEagerGestureHandler(
    void Function(ElEventDetails callback, bool cancelSelfTap, bool allowScaleUpgrade)? handler,
  ) => _eagerGestureHandler = handler;

  /// 更新 PointerDown 的焦点保持处理器。
  void updatePreserveFocusHandler(VoidCallback? handler) => _preserveFocusHandler = handler;
}

/// 按压详情只保留按压元数据，不携带位移、速度或缩放台账。
final class PressGestureDetails extends GestureDetails {
  /// 创建按压详情。
  PressGestureDetails({
    required super.phase,
    required super.originalEvent,
    required super.globalPosition,
    required this.buttons,
    PointerEvent? downEvent,
    this.tapCount = 0,
    this.cancelReason,
    super.sampleTimeStamp,
  }) : downEvent = downEvent ?? originalEvent;

  /// 本轮物理按下事件，移回后的通知仍保留原事件。
  final PointerEvent downEvent;

  /// 按下时的按钮，释放时仍保留原按钮信息。
  @override
  final int buttons;

  /// 当前有效连续点击次数，候选阶段可为零。
  final int tapCount;

  /// 按压取消的原因，暂时资格失效与永久拒绝保持不同语义。
  final PressCancelReason? cancelReason;
}

/// 拖拽、缩放与旋转详情，共用变换数据但按目标坐标推导主轴速度。
final class TransformGestureDetails extends _MotionData<PointerEvent> implements GestureDetails {
  /// 创建变换详情。
  TransformGestureDetails({
    required super.phase,
    required super.originalEvent,
    required super.globalPosition,
    super.delta,
    super.dragOffset,
    super.dragAxis,
    super.dragDirection,
    super.velocity,
    super.pointerCount,
    super.scale,
    super.rotation,
    super.logScaleVelocity,
    this.started = false,
    this.pointerIds = const [],
    super.sampleTimeStamp,
  }) : _localVelocity = velocity.pixelsPerSecond,
       super(localDelta: delta);

  /// 当前家族是否已进入 Start，候选取消时为 false。
  final bool started;

  /// 是否为正式接受前向后代发出的起拖拦截提案。
  bool isProposal = false;

  /// 当前变换中已接受的真实指针标识。
  final List<int> pointerIds;

  Offset _localVelocity;

  /// 当前目标本地主轴上的释放速度，自由拖拽为空。
  @override
  double? get primaryVelocity => switch (dragAxis) {
    Axis.horizontal => _localVelocity.dx,
    Axis.vertical => _localVelocity.dy,
    null => null,
  };

  @override
  void _updateTransform(Matrix4? transform) {
    super._updateTransform(transform);
    _localVelocity = _transformDelta(velocity.pixelsPerSecond);
  }
}

/// 将同一 El 路线的订阅者与参加官方竞技场的所有者分开。
abstract class _GestureRecognizer extends OneSequenceGestureRecognizer {
  _GestureRecognizer({super.debugOwner, super.supportedDevices, super.allowedButtonsFilter});

  final Map<int, _GestureRoute> _routes = <int, _GestureRoute>{};
  final Map<int, _GestureInput> _inputs = {};
  bool _disposed = false;
  bool _canceling = false;

  GestureTeam? get _cooperation => team is GestureTeam ? team as GestureTeam : null;

  @override
  set team(GestureArenaTeam? value) {
    assert(_inputs.isEmpty, '不能在活动输入中更换手势团队');
    super.team = value;
    _cooperation?._members.add(this);
  }

  bool _participates(int pointer) => _cooperation?._participates(pointer) ?? true;

  bool _registeredFor(_GestureRoute route, int pointer) =>
      (_cooperation?._primaryAllowed(pointer) ?? true) &&
      (_cooperation?.onPointerEvent == null || route.subscription(this).downs.containsKey(pointer));

  /// 官方竞技场确认本路线获胜时通知成员，不代表拖拽或长按已经达到阈值。
  void Function(int pointer)? onAccepted;

  _GestureRecognizer? get _bubbleParent;

  _GestureCallback? _handlerFor(ElEventPhase phase);

  void _requestAccept(_GestureRoute route, int pointer);

  void _cancelRoutePointer(_GestureRoute route, int pointer, PointerEvent? event);

  void _stopOtherRoutes(_GestureRoute route, GestureDetails details) {}

  void _handleRoutedEvent(PointerEvent event, {bool staged = false, _GestureInput? input}) {
    final source = input?.source?.team ?? _cooperation;
    if (staged || source?._routeOwnMove(event, routedInput: input) != true) handleEvent(event);
  }

  /// 请求接受指定指针的官方竞技场归属；不会覆盖已经确认的其他赢家。
  void acceptPointer(int pointer) {
    if (_disposed || _canceling) return;
    final route = _routes[pointer];
    if (route != null && route.active && !route.owner._disposed) {
      route.owner._requestAccept(route, pointer);
    }
  }

  void _notifyAccepted(_GestureRoute route, int pointer) {
    for (final member in route.members.toList()) {
      if (!route.active || member._disposed) continue;
      final callback = member.onAccepted;
      if (callback != null) {
        member.invokeCallback<void>('accepted', () => callback(pointer));
      }
    }
  }

  /// 取消指定指针；宿主判断越界时可传入当前输入，不需要向识别器提供元素尺寸。
  void cancelPointer(int pointer, {PointerEvent? event}) {
    assert(event == null || event.pointer == pointer);
    if (_disposed || _canceling) return;
    final route = _routes[pointer];
    if (route != null && route.active && !route.owner._disposed) {
      route.owner._cancelRoutePointer(route, pointer, event);
    }
  }

  /// 取消自身拥有的全部活动手势和待发通知，取消后仍可识别新序列。
  void cancel();

  /// 当前成员仍跟踪输入或承担释放义务，不包含终态后的反馈保留。
  bool get hasActiveInput => _routes.isNotEmpty;

  // 指针路由与官方席位归输入记录所有，成员销毁时可以连同未决席位一起转交。
  void _trackPointer(int pointer, Matrix4? transform, {bool compete = true, _PointerObservation? source}) {
    source ??= _cooperation?._observations[pointer];
    final input = _GestureInput(this, pointer, transform, source)..settled = !compete;
    _inputs[pointer] = input;
    source?.inputs.add(input);
    GestureBinding.instance.pointerRouter.addRoute(pointer, input.route, transform);
    if (compete) {
      final entry =
          source?.arena._add(pointer, input) ??
          team?.add(pointer, input) ??
          GestureBinding.instance.gestureArena.add(pointer, input);
      if (!input.settled) input.entry = entry;
    }
  }

  @override
  void startTrackingPointer(int pointer, [Matrix4? transform]) => _trackPointer(pointer, transform);

  @override
  void resolvePointer(int pointer, GestureDisposition disposition) {
    super.resolvePointer(pointer, disposition);
    final input = _inputs[pointer];
    final entry = input?.entry;
    if (input == null || entry == null) return;
    input.entry = null;
    entry.resolve(disposition);
    input.releaseIfFinished();
  }

  @override
  void resolve(GestureDisposition disposition) {
    super.resolve(disposition);
    for (final pointer in _inputs.keys.toList()) {
      resolvePointer(pointer, disposition);
    }
  }

  void _transferTrackingTo(_GestureRecognizer target, int pointer) {
    final input = _inputs.remove(pointer);
    if (input == null) return;
    input.owner = target;
    target._inputs[pointer] = input;
  }

  @override
  void stopTrackingPointer(int pointer) {
    final input = _inputs[pointer];
    if (input == null || !input.tracking) return;
    input.tracking = false;
    GestureBinding.instance.pointerRouter.removeRoute(pointer, input.route);
    input.releaseIfFinished();
    if (_inputs.values.every((value) => !value.tracking)) didStopTrackingLastPointer(pointer);
  }

  bool _isDelegated(int pointer) {
    final route = _routes[pointer];
    return route != null && route.active && !identical(route.owner, this);
  }

  /// 祖先只登记自己的坐标，实际指针由最内层所有者跟踪与参赛。
  bool _delegatePointer(PointerEvent event) {
    final route = _routes[event.pointer];
    if (route == null || !route.active || identical(route.owner, this)) {
      return false;
    }
    route.subscription(this).downs[event.pointer] = event;
    return true;
  }

  _GestureRoute _beginRoute(PointerEvent event, {_GestureRoute? route}) {
    assert(!_disposed);
    final result = route ?? _newRoute(event.pointer);
    assert(result.active && identical(result.owner, this));
    result.pointers.add(event.pointer);
    result.subscription(this).downs[event.pointer] = event;
    for (final member in result.members) {
      if (member._disposed) continue;
      final previous = member._routes[event.pointer];
      // 同一指针可能命中多个透明分支；已参赛或已委托的路线不能被后来者偷换。
      if (previous != null && previous.active && !identical(previous, result)) {
        continue;
      }
      member._routes[event.pointer] = result;
      _GestureInputRegistry.recognizers.add(member);
    }
    _GestureInputRegistry.sync();
    return result;
  }

  _GestureRoute _newRoute(int pointer) {
    final members = _snapshotChain();
    final conflict = members.indexWhere((member) {
      final previous = member._routes[pointer];
      return previous != null && previous.active;
    });
    if (conflict == 0) {
      throw StateError('同一识别器不能为同一指针重复创建路线。');
    }
    // 透明重叠分支可以分别参赛，共享祖先只订阅首次命中的那条路线。
    if (conflict > 0) members.removeRange(conflict, members.length);
    return _GestureRoute(this, members);
  }

  List<_GestureRecognizer> _snapshotChain() {
    final result = <_GestureRecognizer>[];
    final seen = <_GestureRecognizer>{};
    _GestureRecognizer? current = this;
    while (current != null) {
      if (!seen.add(current)) {
        throw StateError('手势 parent 链不能包含循环引用。');
      }
      if (!current._disposed) result.add(current);
      current = current._bubbleParent;
    }
    return result;
  }

  bool _hasHandlerInChain(ElEventPhase phase) => _snapshotChain().any((member) => member._handlerFor(phase) != null);

  bool _routeHasHandler(_GestureRoute route, ElEventPhase phase) {
    if (!route.active) return false;
    final end = route.cutoffs[phase._family] ?? route.members.length - 1;
    for (var index = 0; index <= end; index++) {
      final member = route.members[index];
      if (!member._disposed &&
          !route.subscription(member).phase(phase._family).excluded &&
          member._handlerFor(phase) != null) {
        return true;
      }
    }
    return false;
  }

  void _endRoute(_GestureRoute route) {
    if (!route.active) return;
    // Cancel 回调可重入销毁所有者，坐标快照须等已公开的终态全部投递后再释放。
    if (route.terminalDispatchDepth > 0) {
      route.closeRequested = true;
      _releaseRoutePointers(route);
      return;
    }
    route.active = false;
    _releaseRoutePointers(route);
    route._subscriptions.clear();
  }

  /// 物理序列结束即解除报名委托，延迟业务通知仍可保留冻结路线。
  void _releaseRoutePointers(_GestureRoute route) {
    for (final member in route.members) {
      for (final pointer in route.pointers) {
        if (identical(member._routes[pointer], route)) {
          member._routes.remove(pointer);
        }
      }
    }
    _GestureInputRegistry.sync();
  }

  void _dispatchGesture(
    _GestureRoute route,
    GestureDetails callback, {
    int? routingPointer,
    Object? sequenceIdentity,
    int firstMember = 0,
    int? lastMember,
    bool skipCancelingMembers = false,
    bool isolatedMember = false,
    GestureDetails? Function(_GestureRecognizer member)? prepare,
  }) {
    final pointer = routingPointer ?? callback.pointer;

    final terminal = callback.phase._terminal;
    if (!route.active || route.owner._disposed && !terminal) return;
    if (terminal) route.terminalDispatchDepth++;
    try {
      final family = callback.phase._family;
      final revision = (route.revisions[family] ?? 0) + (isolatedMember ? 0 : 1);
      route.revisions[family] = revision;
      final candidate = callback.phase._candidate;
      final admitsDragMembers =
          callback.phase == ElEventPhase.dragStart &&
          route.owner is TransformRecognizer &&
          (route.owner as TransformRecognizer)._session?.cooperation != null;
      if (candidate && !isolatedMember) route.observedEnds[family] = -1;
      var end = lastMember ?? route.cutoffs[family] ?? route.members.length - 1;
      if (!candidate && !admitsDragMembers && lastMember == null) {
        end = math.min(end, route.observedEnds[family] ?? end);
      }
      var firstTarget = true;
      for (var index = firstMember; index <= end; index++) {
        // 同家族重入可能已取消当前阶段，不能再把旧 Down/Start 送给后续祖先。
        if (!route.active || !terminal && (route.owner._disposed || route.revisions[family] != revision)) {
          break;
        }
        final member = route.members[index];
        final subscription = route.subscription(member);
        final state = subscription.phase(family);

        if (member._disposed ||
            callback.phase == ElEventPhase.dragUpdate &&
                member is TransformRecognizer &&
                !member.receivesDragUpdates(pointer) ||
            skipCancelingMembers && state.canceling ||
            (callback.phase == ElEventPhase.tapCancel
                ? !subscription.downs.containsKey(pointer)
                : !member._registeredFor(route, pointer)) ||
            candidate &&
                !member._participates(pointer) &&
                !(family == _GestureFamily.scale && member._cooperation?.canClaimPointers([pointer]) == true) ||
            state.excluded) {
          continue;
        }
        if (candidate || admitsDragMembers) {
          route.observedEnds[family] = math.max(route.observedEnds[family] ?? -1, index);
        }
        final handler = member._handlerFor(callback.phase);
        if (handler == null) continue;
        if (callback.phase._stage == .update) {
          final version = state.revision;
          if (member._cooperation?._deferUpdate(callback.originalEvent, () {
                if (!route.active ||
                    member._disposed ||
                    callback.propagationStopped ||
                    state.revision != version ||
                    state.excluded) {
                  return;
                }
                _dispatchGesture(
                  route,
                  callback,
                  routingPointer: pointer,
                  sequenceIdentity: sequenceIdentity,
                  firstMember: index,
                  lastMember: index,
                  isolatedMember: true,
                  prepare: prepare,
                );
              }) ==
              true) {
            continue;
          }
        }
        final details = prepare == null ? callback : prepare(member);
        if (details == null) continue;
        if (callback.phase == ElEventPhase.dragStart && !route.dragStartRecipients.add(member)) continue;
        if (!identical(details, callback)) details._controlSource = callback;
        details._sequenceIdentity = sequenceIdentity ?? route;
        details._isPrimaryTarget = firstTarget;
        final memberRevision = state.revision;
        details._isActive = () =>
            route.active &&
            !member._disposed &&
            !state.excluded &&
            route.revisions[family] == revision &&
            state.revision == memberRevision;
        firstTarget = false;
        member.invokeCallback<void>(callback.phase.name, () {
          final down = subscription.downs[pointer];
          details._updateTransform(down?.transform);
          final cooperation = member._cooperation;
          if (cooperation == null) {
            handler(details);
          } else {
            cooperation._during(details.originalEvent, () => handler(details));
          }
        });
        // 终态是已公开生命周期的清理义务，不能由子回调吞掉祖先的唯一结算。
        if (details.propagationStopped) {
          member._stopOtherRoutes(route, details);
          // Up 之后的业务点击仍遵守最早截断点，已经公开的释放通知继续结清。
          if (terminal) {
            if (callback.phase._establishesBoundary) {
              route.cutoffs[family] = math.min(route.cutoffs[family] ?? index, index);
            }
            if (family == _GestureFamily.press &&
                callback.phase != ElEventPhase.tapCancel &&
                member is PressRecognizer &&
                !member.bubbleReleaseAfterStop) {
              break;
            }
            continue;
          }
          if (callback.phase._establishesBoundary) {
            route.cutoffs[family] = index;
            final cancellation = _boundaryCancellation(callback);
            if (cancellation != null && route.active && route.revisions[family] == revision) {
              final observed = route.observedEnds[family] ?? index;
              route.observedEnds[family] = index;
              if (observed > index) {
                _dispatchGesture(
                  route,
                  cancellation,
                  routingPointer: pointer,
                  sequenceIdentity: sequenceIdentity,
                  firstMember: index + 1,
                  lastMember: observed,
                );
              }
            }
          }
          break;
        }
      }
    } finally {
      if (terminal) {
        route.terminalDispatchDepth--;
        if (route.closeRequested && route.terminalDispatchDepth == 0) {
          _endRoute(route);
        }
      }
    }
  }

  static GestureDetails? _boundaryCancellation(GestureDetails details) {
    if (details is TransformGestureDetails && details.phase == ElEventPhase.dragStart) {
      return TransformGestureDetails(
        phase: ElEventPhase.dragCancel,
        globalPosition: details.globalPosition,
        dragOffset: details.dragOffset,
        dragAxis: details.dragAxis,
        dragDirection: details.dragDirection,
        pointerCount: details.pointerCount,
        originalEvent: details.originalEvent,
      );
    }
    if (details is PressGestureDetails &&
        (details.phase == ElEventPhase.doubleTapDown ||
            details.phase == ElEventPhase.tripleTapDown ||
            details.phase == ElEventPhase.longPress)) {
      return PressGestureDetails(
        phase: ElEventPhase.tapCancel,
        globalPosition: details.globalPosition,
        downEvent: details.downEvent,
        originalEvent: details.originalEvent,
        buttons: details.buttons,
        cancelReason: PressCancelReason.canceled,
      );
    }
    return null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cooperation?._members.remove(this);
    for (final route in _routes.values.toSet()) {
      if (identical(route.owner, this)) _endRoute(route);
    }
    _routes.clear();
    _GestureInputRegistry.sync();
    for (final pointer in _inputs.keys.toList()) {
      stopTrackingPointer(pointer);
    }
    super.dispose();
  }
}

final class _GestureInput extends GestureArenaMember {
  _GestureInput(this.owner, this.pointer, this.transform, this.source);
  _GestureRecognizer owner;
  final int pointer;
  final Matrix4? transform;
  final _PointerObservation? source;
  GestureArenaEntry? entry;
  bool tracking = true;
  bool settled = false;
  late final PointerRoute route = _handleEvent;

  void _handleEvent(PointerEvent event) {
    if (tracking && !owner._disposed && identical(owner._inputs[pointer], this)) {
      owner._handleRoutedEvent(event, input: this);
    }
  }

  void releaseIfFinished() {
    if (!tracking && settled && identical(owner._inputs[pointer], this)) {
      owner._inputs.remove(pointer);
      source?.inputs.remove(this);
    }
  }

  void _complete(bool accepted) {
    entry = null;
    settled = true;
    final target = owner;
    if (!target._disposed && identical(target._inputs[pointer], this)) {
      if (accepted) {
        target.acceptGesture(pointer);
      } else {
        target.rejectGesture(pointer);
      }
    }
    releaseIfFinished();
  }

  @override
  void acceptGesture(int pointer) => _complete(true);

  @override
  void rejectGesture(int pointer) => _complete(false);
}

enum _GestureFamily { press, drag, scale }

enum _GestureStage { other, candidate, update, terminal, release }

class _GestureRoute {
  _GestureRoute(this.owner, this.members);

  _GestureRecognizer owner;
  final List<_GestureRecognizer> members;
  // 实际登记前已加入首指针，生命周期内只追加，不另存一份初始编号。
  final Set<int> pointers = <int>{};
  final Set<_GestureRecognizer> dragStartRecipients = {};
  final Map<_GestureRecognizer, _GestureSubscription> _subscriptions = {};
  final Map<_GestureFamily, int> cutoffs = <_GestureFamily, int>{};
  final Map<_GestureFamily, int> revisions = <_GestureFamily, int>{};
  final Map<_GestureFamily, int> observedEnds = <_GestureFamily, int>{};
  int terminalDispatchDepth = 0;
  bool closeRequested = false;
  bool active = true;

  _GestureSubscription subscription(_GestureRecognizer member) =>
      _subscriptions.putIfAbsent(member, _GestureSubscription.new);

  void invalidate(_GestureRecognizer member, _GestureFamily family) => subscription(member).phase(family).revision++;
}

// 每个成员独立保存坐标和家族资格；临时长按路线只共享坐标，不共享取消状态。
class _GestureSubscription extends _GestureMemberPhase {
  Map<int, PointerEvent> downs = {};
  _GestureMemberPhase? _scale;

  // 路线只包含同类识别器，Press 和 Drag 各自使用主状态，Scale 另存一份。
  _GestureMemberPhase phase(_GestureFamily family) => family == .scale ? (_scale ??= _GestureMemberPhase()) : this;
}

class _GestureMemberPhase {
  int revision = 0;
  bool excluded = false;
  bool canceling = false;
}

/// 通过官方竞技场协调同次输入的识别器，不保存重复的手势阶段状态。
///
/// parent 连接元素关系，是否共享官方席位由成员自身的识别意图决定。
final class GestureTeam extends GestureArenaTeam implements GestureArenaMember {
  /// 创建协作团队，识别器通过官方 team 属性加入。
  GestureTeam({this.parent}) {
    captain = this;
  }

  /// 元素对应的祖先团队，已开始输入沿用原有官方席位。
  GestureTeam? parent;

  /// 原始输入观察者；通过 [currentPointerDetails] 共享控制，返回 false 截断传播，不因此参赛。
  /// 与识别器共用团队时，从 Down 开始调用 [observePointer]，按实际输入登记接收资格。
  bool Function(PointerEvent event, PressCancelReason? reason)? onPointerEvent;

  /// 设备直接移除时通知实际指针编号，不要求此前收到 Up 或 Cancel。
  void Function(PointerRemovedEvent event)? onPointerRemoved;

  /// 原始触控板消费者可预先保留席位，后续接受仍须服从官方结果。
  bool acceptsPanZoom = false;

  /// 根据点击意图、拖拽轴与阈值筛选自动挂接的父级，手工冒泡链默认不筛选。
  bool matchParentGestures = false;

  /// 宿主只在声明拖拽或缩放时创建变换识别器；缺少变换成员按不订阅拖拽筛选父级。
  bool transformOnDemand = false;

  /// 将移动观察延后到本团队的原生路由位置，允许内层起拖先决定祖先资格。
  bool deferPointerMoves = false;

  /// 等本次原生路由全部完成后再提交点击，让祖先释放阶段的拖拽救援先结算。
  bool deferPointerReleases = false;

  final Map<int, _CooperativePointer> _pointers = {};
  final Set<_GestureRecognizer> _members = {};
  final Map<int, _PointerObservation> _observations = {};
  static final _dispatches = Expando<_PointerDispatch>('El raw input');
  static final _rawDetails = Expando<PointerGestureDetails>('El pointer control');
  PointerEvent? _currentEvent;
  _PointerObservation? _currentObservation;
  PointerGestureDetails? _currentPointerDetails;
  bool _disposed = false;

  /// 原始输入回调是否正在投递，供声明更新及时结清旧订阅。
  bool get isDispatching => _currentPointerDetails != null;

  /// 当前是否正在投递物理终态。
  bool get isDispatchingTerminal => _terminal(_currentPointerDetails?.originalEvent);

  /// 当前回调对应的共享输入状态，回调之外为空。
  PointerGestureDetails? get currentPointerDetails => _currentPointerDetails;

  /// 当前元素尚未结束且未被排他的原始指针数。
  int get pointerCount => _observations.values.where((input) => input.active && !_terminal(input.event)).length;

  /// 普通活动指针数量，不把触控板变换序列当作接触指针。
  int get ordinaryPointerCount => _observations.values
      .where((input) => input.active && input.down is PointerDownEvent && !_terminal(input.event))
      .length;

  /// 当前识别状态是否仍活跃，原始输入的延后清理不影响此查询。
  bool get hasActiveInput => _members.any((member) => member.hasActiveInput);

  /// 结清本团队拥有且没有存活祖先承接的输入；承接资格按按下时冻结的路线判断。
  void terminateOwnedInputs({required bool Function(GestureTeam? team) survives}) {
    final owned = _members.expand((member) => member._routes.values).where((route) {
      return identical(route.owner._cooperation, this) && route.active;
    }).toSet();
    final ending = owned.where((route) {
      return !route.members.skip(1).any((member) {
        final index = route.members.indexOf(member);
        return !member._disposed &&
            member._registeredFor(route, route.pointers.last) &&
            survives(member._cooperation) &&
            ElEventPhase.values.any(
              (phase) =>
                  member._handlerFor(phase) != null &&
                  index <= (route.cutoffs[phase._family] ?? route.members.length - 1) &&
                  !route.subscription(member).phase(phase._family).excluded,
            );
      });
    }).toList();
    for (final input in _observations.values.toList()) {
      final dispatch = input.dispatch;
      if (!identical(dispatch.members.firstOrNull?.team, this)) continue;
      if (dispatch.members
          .skip(1)
          .any((other) => other.isCurrent && other.active && !other.team._disposed && survives(other.team))) {
        continue;
      }
      for (final other in dispatch.members.toList()) {
        if (!other.isCurrent || !other.active) continue;
        other.active = false;
        if (other.notified) other.team._deliver(_cancelEvent(other), PressCancelReason.canceled);
        other.entry?.resolve(GestureDisposition.rejected);
        other.team._releaseObservation(input.down.pointer, other);
      }
    }
    for (final route in ending) {
      for (final pointer in route.pointers.toList()) {
        if (route.active) route.owner.cancelPointer(pointer);
      }
    }
  }

  /// 测试隔离时结清共享输入，避免上一例的独占与设备路由残留。
  static void debugReset() {
    for (final team in _GestureInputRegistry.teams.toList()) {
      team.cancel();
      for (final entry in team._observations.entries.toList()) {
        team._releaseObservation(entry.key, entry.value);
      }
    }
    for (final member in _GestureInputRegistry.recognizers.toList()) {
      member.cancel();
    }
    _GestureInputRegistry.sync();
  }

  /// 当前指针的物理开始事件，可用于约束延后调用的独占请求。
  PointerEvent? downEventFor(int pointer) => _observationFor(pointer)?.down;

  _PointerObservation? _observationFor(int pointer) =>
      _observations[pointer] ??
      _members
          .map((member) {
            final own = member._inputs[pointer]?.source;
            if (own != null) return own;
            final route = member._routes[pointer];
            return route?.subscription(member).downs.containsKey(pointer) == true
                ? route!.owner._inputs[pointer]?.source
                : null;
          })
          .whereType<_PointerObservation>()
          .firstOrNull;

  /// 全部指针已取得官方归属且仍有资格时才允许多指接管，不改变任何成员。
  bool canClaimPointers(Iterable<int> pointers) {
    final ids = pointers.toSet();
    return !_disposed &&
        ids.isNotEmpty &&
        ids.every((pointer) {
          final input = _observationFor(pointer);
          return input != null &&
              (input.active || input.scaleAllowed) &&
              !input.dispatch.members.any(
                (other) => !identical(other.team, this) && other.isCurrent && other.request?.allowScale == false,
              ) &&
              input.dispatch.arenas.any((arena) => arena._pointers[pointer]?.result == GestureDisposition.accepted);
        });
  }

  /// 先验证全部输入、再同步提交所有成员资格，最后统一通知取消。
  bool claimPointers(Iterable<int> pointers, {bool cancelTap = false, bool allowScaleUpgrade = false}) {
    final ids = pointers.toSet();
    if (!canClaimPointers(ids)) return false;
    final notifications = <void Function()>[];
    for (final pointer in ids) {
      final input = _observationFor(pointer)!;
      _commitRequest(pointer, input, (cancelTap: cancelTap, allowScale: allowScaleUpgrade), notifications);
    }
    for (final notify in notifications) {
      notify();
    }
    return true;
  }

  bool _sharesArenaWith(GestureTeam other) {
    if (!matchParentGestures || !other.matchParentGestures) return true;
    final press = _members.whereType<PressRecognizer>().firstOrNull;
    final otherPress = other._members.whereType<PressRecognizer>().firstOrNull;
    if (press != null && otherPress != null && press.competeForTap != otherPress.competeForTap) {
      return false;
    }
    final transform = _members.whereType<TransformRecognizer>().firstOrNull;
    final otherTransform = other._members.whereType<TransformRecognizer>().firstOrNull;
    if (transform != null && otherTransform != null) return transform._compatibleWith(otherTransform);
    // 手工组装的团队缺少变换成员时不按拖拽筛选；按需创建的团队缺少成员等同于不订阅拖拽。
    if (transform == null && !transformOnDemand || otherTransform == null && !other.transformOnDemand) return true;
    return !(transform?._hasOwnDrag ?? false) && !(otherTransform?._hasOwnDrag ?? false);
  }

  GestureTeam get _arenaRoot {
    final seen = <GestureTeam>{};
    var result = this;
    while (result.parent != null) {
      if (!seen.add(result)) throw StateError('手势团队 parent 链不能循环。');
      if (!_sharesArenaWith(result.parent!)) break;
      result = result.parent!;
    }
    return result;
  }

  @override
  GestureArenaEntry add(int pointer, GestureArenaMember member) {
    final root = _arenaRoot;
    return root._add(pointer, member);
  }

  GestureArenaEntry _add(int pointer, GestureArenaMember member) {
    final source = switch (member) {
      _GestureRecognizer() => member._cooperation?._observations[pointer]?.dispatch,
      _GestureInput() => member.source?.dispatch,
      _PointerObservation() => member.team._observations[pointer]?.dispatch,
      _ => null,
    };
    final previous = _pointers[pointer];
    if (previous != null && source != null && !identical(source, previous.dispatch)) {
      _pointers.remove(pointer);
    }
    final state = _pointers.putIfAbsent(pointer, () {
      final state = _CooperativePointer()..dispatch = source;
      state.captainEntry = super.add(pointer, this);
      return state;
    });
    final delegate = _CooperativeMember(state, member, pointer);
    state.members.add(delegate);
    return delegate;
  }

  void _finishNative(int pointer, GestureDisposition result) {
    final state = _pointers[pointer];
    if (state == null) return;
    state.result = result;
    final dispatch = state.dispatch;
    if (dispatch == null) {
      _pointers.remove(pointer);
      for (final member in state.members.toList()) {
        member.finish(pointer, result);
      }
    } else {
      dispatch.settle(pointer);
    }
    _settleRequests(pointer, dispatch);
  }

  /// 接收官方竞技场胜出裁决，并结算协作成员。
  @override
  void acceptGesture(int pointer) => _finishNative(pointer, GestureDisposition.accepted);

  /// 接收官方竞技场落败裁决，并结算协作成员。
  @override
  void rejectGesture(int pointer) => _finishNative(pointer, GestureDisposition.rejected);

  /// 记录真实命中输入并投递原始回调，返回当前元素是否可以接收该输入。
  bool observePointer(PointerEvent event) {
    final start = event is PointerDownEvent || event is PointerPanZoomStartEvent;
    if (_disposed) return false;
    if (event is PointerHoverEvent || event is PointerSignalEvent) {
      return _deliver(event, null);
    }
    if (start) {
      final key = event.original ?? event;
      final previous = _observations[event.pointer];
      if (previous != null && identical(previous.down.original ?? previous.down, key) && !_terminal(previous.event)) {
        return false;
      }
      var dispatch = _dispatches[key];
      if (dispatch == null || dispatch.members.firstOrNull?.isCurrent != true) {
        dispatch = _PointerDispatch();
        _dispatches[key] = dispatch;
      }
      if (dispatch.stopped) return false;
      final input = _PointerObservation(this, dispatch, event, _arenaRoot);
      _observations[event.pointer] = input;
      _GestureInputRegistry.teams.add(this);
      _GestureInputRegistry.sync();
      dispatch.members.add(input);
      dispatch.arenas.add(input.arena);
      if (event is PointerPanZoomStartEvent && acceptsPanZoom) {
        input.entry = add(event.pointer, input);
      }
      if (!_hasPendingOther(input)) {
        input.notified = true;
        if (!_deliver(event, null)) dispatch.stopped = true;
      }
      return input.active;
    }
    final input = _observations[event.pointer];
    if (input == null) return false;
    input.event = event;
    if (deferPointerMoves && event is PointerMoveEvent) {
      input.pendingMove = event.original ?? event;
      input.routedMove = null;
      input.afterMove.clear();
      return input.active;
    }
    if (_terminal(event)) {
      scheduleMicrotask(() => _releaseObservation(event.pointer, input));
    }
    if (!input.active) return false;
    final proceed = _deliver(event, event is PointerCancelEvent ? PressCancelReason.pointerCanceled : null);
    return input.active && proceed;
  }

  bool _routeOwnMove(PointerEvent event, {_GestureInput? routedInput}) {
    if (!deferPointerMoves || event is! PointerMoveEvent) return false;
    final input = routedInput?.source ?? _observations[event.pointer];
    final key = event.original ?? event;
    final registered = _observations[event.pointer];
    if (input == null || registered != null && !identical(registered, input)) return true;
    if (registered == null) input.event = event;
    if (!identical(input.event.original ?? input.event, key) || identical(input.routedMove, key)) {
      return true;
    }
    input.routedMove = key;
    // 只推进当前原生席位已有的成员，不提前外层席位或回调中新挂载的识别器。
    final entries = input.inputs.toList();
    _flushMove(event);
    for (final entry in entries) {
      if (!identical(_observations[event.pointer], registered) ||
          !identical(input.event.original ?? input.event, key)) {
        break;
      }
      final member = entry.owner;
      final observation = member._cooperation?._observations[event.pointer] ?? input;
      if (identical(observation.dispatch, input.dispatch) &&
          (observation.active ||
              member is TransformRecognizer &&
                  (observation.scaleAllowed || member._hasActiveReceiver(event.pointer))) &&
          entry.tracking &&
          !member._disposed &&
          identical(member._inputs[event.pointer], entry)) {
        member._handleRoutedEvent(key.transformed(entry.transform), staged: true);
      }
    }
    return true;
  }

  void _flushMove(PointerEvent event) {
    final input = _observations[event.pointer];
    final key = event.original ?? event;
    if (input == null || !identical(input.pendingMove, key)) return;
    input.pendingMove = null;
    if (input.active && !_hasPendingOther(input)) _deliver(input.event, null);
    final pending = input.afterMove.toList();
    input.afterMove.clear();
    for (final callback in pending) {
      if (identical(_observations[event.pointer], input) && identical(input.event.original ?? input.event, key)) {
        callback();
      }
    }
  }

  bool _deferUpdate(PointerEvent event, void Function() callback) {
    if (!deferPointerMoves || event is! PointerMoveEvent) return false;
    final input = _observationFor(event.pointer);
    final key = event.original ?? event;
    if (input == null || !identical(input.event.original ?? input.event, key)) return true;
    if (identical(input.pendingMove, key)) {
      input.afterMove.add(callback);
      return true;
    }
    return false;
  }

  bool _deferRelease(PointerUpEvent event, Object key, void Function() callback) {
    if (!deferPointerReleases) return false;
    final input = _observationFor(event.pointer);
    if (input == null || identical(input.routedRelease, event.original ?? event)) return false;
    input.afterRelease[key] = callback;
    return true;
  }

  bool _deliver(PointerEvent event, PressCancelReason? reason) {
    final key = event.original ?? event;
    var details = _rawDetails[key];
    if (details == null || details._completed) {
      final created = PointerGestureDetails(event);
      _rawDetails[key] = details = created;
      scheduleMicrotask(() => created._completed = true);
    }
    if (details.propagationStopped) return false;
    _during(event, () {
      if (onPointerEvent?.call(event, reason) == false) details!.stopPropagation();
    }, pointerDetails: details);
    return !details.propagationStopped;
  }

  void _during(PointerEvent event, void Function() callback, {PointerGestureDetails? pointerDetails}) {
    final previousEvent = _currentEvent;
    final previousInput = _currentObservation;
    final previousDetails = _currentPointerDetails;
    _currentEvent = event;
    _currentObservation = _observations[event.pointer];
    _currentPointerDetails = pointerDetails ?? previousDetails;
    try {
      callback();
    } finally {
      _currentEvent = previousEvent;
      _currentObservation = previousInput;
      _currentPointerDetails = previousDetails;
    }
  }

  bool _hasPendingOther(_PointerObservation input) =>
      input.dispatch.members.any((other) => !identical(other.team, this) && other.isCurrent && other.request != null);

  bool _participates(int pointer) {
    if (onPointerEvent == null) return true;
    final input = _observationFor(pointer);
    return input != null && _primaryAllowed(pointer) && !_hasPendingOther(input);
  }

  bool _primaryAllowed(int pointer) {
    final dispatch = _observations[pointer]?.dispatch;
    final cutoff = dispatch?.primaryCutoff;
    if (dispatch == null || cutoff == null || dispatch.primaryExempt.contains(this)) return true;
    final boundary = dispatch.indexOfTeam(cutoff);
    return boundary < 0 || dispatch.indexOfTeam(this) < boundary;
  }

  /// 请求当前元素独占输入，成员失权直接通过识别器取消，不复制其阶段状态。
  ///
  /// 延后调用时传入 [downEvent]，避免指针编号复用后请求作用于下一次输入。
  void claimPointer(int pointer, {PointerEvent? downEvent, bool cancelTap = false, bool allowScaleUpgrade = false}) {
    final input = _observationFor(pointer);
    if (input == null ||
        downEvent != null && !identical(input.down, downEvent) ||
        !input.active ||
        _disposed ||
        input.arena._pointers[pointer]?.result == GestureDisposition.rejected &&
            !input.dispatch.arenas.any((arena) => arena._pointers[pointer]?.result == GestureDisposition.accepted) ||
        _currentObservation != null &&
            _currentObservation!.down.pointer == pointer &&
            !identical(_currentObservation, input)) {
      return;
    }
    final accepted = input.dispatch.arenas.any(
      (arena) => arena._pointers[pointer]?.result == GestureDisposition.accepted,
    );
    if (accepted && !identical(input.team, this)) {
      if (!canClaimPointers([pointer])) return;
      final notifications = <void Function()>[];
      _commitRequest(pointer, input, (cancelTap: cancelTap, allowScale: allowScaleUpgrade), notifications);
      for (final notify in notifications) {
        notify();
      }
      return;
    }
    final canEnroll =
        (_currentEvent is PointerDownEvent || _currentEvent is PointerPanZoomStartEvent) &&
        input.arena._pointers[pointer]?.result == null;
    if (!accepted && input.arena._pointers[pointer] == null && !canEnroll) {
      return;
    }
    input.request = (cancelTap: cancelTap || (input.request?.cancelTap ?? false), allowScale: allowScaleUpgrade);
    if (!accepted && input.entry == null && canEnroll) {
      input.entry = add(pointer, input);
    }
    for (final member in _members.toList()) {
      member.acceptPointer(pointer);
    }
    input.entry?.resolve(GestureDisposition.accepted);
    _settleRequests(pointer, input.dispatch);
  }

  void _settleRequests(int pointer, _PointerDispatch? dispatch) {
    if (dispatch == null ||
        !dispatch.arenas.any((arena) => arena._pointers[pointer]?.result == GestureDisposition.accepted)) {
      return;
    }
    final notifications = <void Function()>[];
    for (final input in dispatch.members.toList()) {
      if (!input.isCurrent || !input.active) continue;
      final request = input.request;
      if (request == null) continue;
      input.team._commitRequest(pointer, input, request, notifications);
    }
    for (final notify in notifications) {
      notify();
    }
  }

  void _commitRequest(
    int pointer,
    _PointerObservation input,
    ({bool cancelTap, bool allowScale}) request,
    List<void Function()> notifications,
  ) {
    input.request = null;
    if (identical(input.team, this) && input.scaleAllowed) {
      input.active = true;
      input.scaleAllowed = false;
    }
    for (final other in input.dispatch.members.toList()) {
      if (!other.isCurrent || !other.active) continue;
      final target = other.team;
      if (identical(target, this)) {
        if (request.cancelTap) {
          notifications.add(() {
            for (final press in target._members.whereType<PressRecognizer>().toList()) {
              press.rejectTap(pointer, reason: PressCancelReason.longPressAccepted);
            }
          });
        }
      } else {
        other.active = false;
        other.scaleAllowed = request.allowScale;
        notifications.add(() {
          if (other.notified) {
            target._deliver(_cancelEvent(other, rejected: true), PressCancelReason.arenaRejected);
          }
          final members = <_GestureRecognizer>{...target._members, ...other.inputs.map((entry) => entry.owner)};
          for (final member in members) {
            if (identical(member._cooperation, this)) continue;
            if (member is PressRecognizer) member._cancelMember(pointer, PressCancelReason.arenaRejected);
            if (member is TransformRecognizer) member.cancelMember(pointer, cancelScale: !request.allowScale);
          }
        });
      }
    }
  }

  void _cancelDragForScale(Iterable<int> pointers, {PointerEvent? event}) {
    final transforms = <TransformRecognizer>{};
    for (final pointer in pointers) {
      for (final team in _observationFor(pointer)?.dispatch.members.map((input) => input.team) ?? [this]) {
        transforms.addAll(team._members.whereType<TransformRecognizer>());
      }
    }
    for (final member in transforms) {
      if (member.cancelDragOnScale) {
        member.cancelMember(null, cancelScale: false, event: event);
      }
    }
  }

  /// 结清当前团队成员的按压订阅，并明确取消原因。
  void cancelPress(int pointer, {PressCancelReason reason = PressCancelReason.canceled}) {
    for (final member in _members.whereType<PressRecognizer>().toList()) {
      member._cancelMember(pointer, reason);
    }
  }

  /// 取消同一输入路线中更内层的点击资格，保留其物理释放通知。
  void rejectDescendantPress(int pointer) {
    final dispatch = _observationFor(pointer)?.dispatch;
    if (dispatch == null) return;
    final end = dispatch.indexOfTeam(this);
    for (final input in dispatch.members.take(end < 0 ? 0 : end)) {
      for (final press in input.team._members.whereType<PressRecognizer>()) {
        press.rejectTap(pointer, reason: PressCancelReason.arenaRejected);
      }
    }
  }

  /// 结清当前元素的输入观察与识别订阅，可按物理开始事件筛选。
  void cancel({bool Function(PointerEvent down)? where}) {
    for (final input in _observations.values.toList()) {
      if (where != null && !where(input.down)) continue;
      if (!input.active) {
        _revokeScaleGrants(input);
        continue;
      }
      input.active = false;
      _revokeScaleGrants(input);
      if (!_terminal(input.event) && input.notified) {
        _deliver(_cancelEvent(input), PressCancelReason.canceled);
      }
      input.entry?.resolve(GestureDisposition.rejected);
      if (where != null) {
        for (final member in _members.toList()) {
          if (member is PressRecognizer) member.cancelMember(input.down.pointer);
          if (member is TransformRecognizer) member.cancelMember(input.down.pointer);
        }
      }
    }
    if (where != null) return;
    for (final member in _members.toList()) {
      if (member is PressRecognizer) member.cancelMember();
      if (member is TransformRecognizer) member.cancelMember(null);
    }
  }

  void _revokeScaleGrants(_PointerObservation input) {
    final pointer = input.down.pointer;
    final dispatch = input.dispatch;
    if (dispatch.members.any((other) => other.isCurrent && other.active)) return;
    for (final other in dispatch.members.toList()) {
      if (!other.isCurrent || !other.scaleAllowed) continue;
      other.scaleAllowed = false;
      for (final member in other.team._members.whereType<TransformRecognizer>().toList()) {
        member.cancelPointer(pointer);
      }
    }
  }

  /// 销毁团队自己的观察记录，官方席位仍按既有规则结算。
  void dispose() {
    if (_disposed) return;
    cancel();
    _disposed = true;
    for (final entry in _observations.entries.toList()) {
      _releaseObservation(entry.key, entry.value);
    }
    onPointerEvent = null;
    onPointerRemoved = null;
    parent = null;
  }

  void _releaseObservation(int pointer, _PointerObservation input) {
    if (!identical(_observations[pointer], input)) return;
    _observations.remove(pointer);
    final dispatch = input.dispatch;
    if (dispatch.members.every((member) => !member.isCurrent)) {
      for (final arena in dispatch.arenas) {
        if (identical(arena._pointers[pointer]?.dispatch, dispatch)) {
          arena._pointers.remove(pointer);
        }
      }
    }
    _GestureInputRegistry.sync();
  }

  static bool _terminal(PointerEvent? event) =>
      event is PointerUpEvent || event is PointerCancelEvent || event is PointerPanZoomEndEvent;
  static final _removals = Expando<PointerRemovedEvent>();

  /// 判断合成终态是否由设备移除触发，供宿主保留自己的静默收尾约定。
  static bool isDeviceRemoval(PointerEvent event) => _removals[event.original ?? event] != null;

  static PointerEvent _cancelEvent(_PointerObservation input, {bool rejected = false, PointerRemovedEvent? original}) {
    final event = input.event;
    if (input.down is PointerPanZoomStartEvent && !rejected) {
      final canceled = PointerPanZoomEndEvent(
        pointer: input.down.pointer,
        device: input.down.device,
        position: event is PointerPanZoomUpdateEvent ? event.position + event.pan : event.position,
        timeStamp: event.timeStamp,
        viewId: input.down.viewId,
      );
      if (original != null) _removals[canceled] = original;
      return canceled;
    }
    final canceled = PointerCancelEvent(
      pointer: input.down.pointer,
      device: input.down.device,
      position: event.position,
      timeStamp: event.timeStamp,
      kind: input.down.kind == PointerDeviceKind.trackpad ? PointerDeviceKind.unknown : input.down.kind,
      viewId: input.down.viewId,
    );
    if (original != null) _removals[canceled] = original;
    return canceled;
  }
}

// Removed 没有命中路径；只在存在活动输入时统一监听，避免各宿主再建指针表。
abstract final class _GestureInputRegistry {
  static final recognizers = <_GestureRecognizer>{};
  static final teams = <GestureTeam>{};
  static bool _listening = false;

  static void sync() {
    recognizers.removeWhere((member) => member._routes.isEmpty);
    teams.removeWhere((team) => team._observations.isEmpty);
    final needed = recognizers.isNotEmpty || teams.isNotEmpty;
    if (needed == _listening) return;
    _listening = needed;
    final router = GestureBinding.instance.pointerRouter;
    if (needed) {
      router.addGlobalRoute(_handleRemoved);
    } else {
      router.removeGlobalRoute(_handleRemoved);
    }
  }

  static void _handleRemoved(PointerEvent event) {
    if (event is PointerUpEvent) {
      final ending = teams.map((team) => team._observations[event.pointer]).whereType<_PointerObservation>().toList();
      for (final input in ending) {
        input.routedRelease = event.original ?? event;
      }
      for (final input in ending) {
        final callbacks = input.afterRelease.values.toList();
        input.afterRelease.clear();
        for (final callback in callbacks) {
          callback();
        }
      }
      return;
    }
    if (event is PointerMoveEvent) {
      for (final team in teams.toList()) {
        if (team.deferPointerMoves) team._flushMove(event);
      }
      return;
    }

    if (event is PointerDownEvent || event is PointerPanZoomStartEvent) {
      final key = event.original ?? event;
      final dispatch = GestureTeam._dispatches[key];
      if (dispatch != null) {
        dispatch.registrationClosed = true;
        dispatch.settle(event.pointer);
      }
      return;
    }
    if (event is! PointerRemovedEvent) return;
    final routes = recognizers.expand((member) => member._routes.values).toSet();
    final contacts = <(int, int, PointerDeviceKind)>{};
    for (final route in routes) {
      for (final subscription in route._subscriptions.values) {
        for (final down in subscription.downs.values) {
          if (route.owner._routes.containsKey(down.pointer)) contacts.add((down.pointer, down.device, down.kind));
        }
      }
    }
    for (final team in teams) {
      for (final input in team._observations.values) {
        if (input.active && !GestureTeam._terminal(input.event)) {
          contacts.add((input.down.pointer, input.down.device, input.down.kind));
        }
      }
    }
    final deviceContacts = contacts.where((contact) => contact.$2 == event.device && contact.$3 == event.kind).toList();
    // 设备级 Removed 的 pointer 可为零，但绝不能借“只剩一指”跨 device 猜测。
    bool matches(PointerEvent down) => event.pointer != 0
        ? down.pointer == event.pointer
        : deviceContacts.length == 1 && deviceContacts.single.$1 == down.pointer;
    final affected = <(GestureTeam, int, _PointerObservation)>[];
    for (final team in teams.toList()) {
      for (final entry in team._observations.entries.toList()) {
        final input = entry.value;
        if (GestureTeam._terminal(input.event) || !matches(input.down)) continue;
        if (!input.active) {
          team._releaseObservation(entry.key, input);
          continue;
        }
        affected.add((team, entry.key, input));
        input.active = false;
        team.onPointerRemoved?.call(
          PointerRemovedEvent(
            timeStamp: event.timeStamp,
            pointer: input.down.pointer,
            device: input.down.device,
            kind: input.down.kind,
            position: input.event.position,
            viewId: event.viewId,
            original: event,
          ),
        );
        if (input.notified) {
          team._deliver(GestureTeam._cancelEvent(input, original: event), PressCancelReason.pointerCanceled);
        }
      }
    }
    for (final route in routes) {
      if (!route.active) continue;
      final downs = route._subscriptions.values
          .expand((subscription) => subscription.downs.values)
          .where(matches)
          .toList();
      for (final pointer in downs.map((down) => down.pointer).toSet()) {
        if (!route.active) continue;
        final down = downs.firstWhere((down) => down.pointer == pointer);
        final canceled = PointerCancelEvent(
          pointer: pointer,
          device: down.device,
          kind: down.kind == PointerDeviceKind.trackpad ? PointerDeviceKind.unknown : down.kind,
          position: route.owner._inputs[pointer]?.source?.event.position ?? event.position,
          timeStamp: event.timeStamp,
        );
        GestureTeam._removals[canceled] = event;
        route.owner.cancelPointer(pointer, event: canceled);
      }
    }
    for (final (team, pointer, input) in affected) {
      input.entry?.resolve(GestureDisposition.rejected);
      team._releaseObservation(pointer, input);
    }
    sync();
  }
}

/// 只冻结原始输入的实际投递成员，官方结果保存在对应的竞技场团队状态中。
final class _PointerDispatch {
  final members = <_PointerObservation>[];
  final arenas = <GestureTeam>{};
  bool stopped = false;
  bool registrationClosed = false;
  GestureTeam? primaryCutoff;
  final primaryExempt = <GestureTeam>{};

  int indexOfTeam(GestureTeam team) => members.indexWhere((input) => identical(input.team, team));

  // 各席位保持原生报名位置；自家席位先判负不能抢在自家赢家前取消协作成员。
  void settle(int pointer) {
    if (!registrationClosed) return;
    final states = arenas.map((arena) => arena._pointers[pointer]).whereType<_CooperativePointer>().toList();
    final accepted = states.any((state) => state.result == GestureDisposition.accepted);
    if (!accepted && states.any((state) => state.result == null)) return;
    final result = accepted ? GestureDisposition.accepted : GestureDisposition.rejected;
    for (final state in states) {
      for (final member in state.members.toList()) {
        member.finish(pointer, result);
      }
    }
  }
}

final class _PointerObservation extends GestureArenaMember {
  _PointerObservation(this.team, this.dispatch, this.down, this.arena) : event = down;
  final GestureTeam team;
  final _PointerDispatch dispatch;
  final PointerEvent down;
  final GestureTeam arena;
  PointerEvent event;
  PointerEvent? pendingMove, routedMove;
  final List<void Function()> afterMove = [];
  PointerEvent? routedRelease;
  final Map<Object, void Function()> afterRelease = {};
  final List<_GestureInput> inputs = [];
  bool active = true;
  bool scaleAllowed = false;
  bool notified = false;
  GestureArenaEntry? entry;
  ({bool cancelTap, bool allowScale})? request;

  bool get isCurrent => identical(team._observations[down.pointer], this);

  @override
  void acceptGesture(int pointer) => team._settleRequests(pointer, team._observations[pointer]?.dispatch);

  @override
  void rejectGesture(int pointer) {
    team._observations[pointer]?.entry = null;
  }
}

final class _CooperativePointer {
  late final GestureArenaEntry captainEntry;
  final List<_CooperativeMember> members = [];
  GestureDisposition? result;
  _PointerDispatch? dispatch;
}

// 每个团队只占原生队长席位，成员请求与通知都在同一个本地记录结算。
final class _CooperativeMember implements GestureArenaEntry {
  _CooperativeMember(this.state, this.member, this.pointer);
  final _CooperativePointer state;
  final GestureArenaMember member;
  final int pointer;
  bool resolved = false;
  bool withdrawn = false;
  bool notified = false;

  void finish(int pointer, GestureDisposition disposition) {
    if (notified) return;
    notified = true;
    if (!withdrawn && disposition == GestureDisposition.accepted) {
      member.acceptGesture(pointer);
    } else {
      member.rejectGesture(pointer);
    }
  }

  @override
  void resolve(GestureDisposition disposition) {
    if (resolved || state.result != null) return;
    resolved = true;
    if (disposition == GestureDisposition.accepted) {
      state.captainEntry.resolve(disposition);
      return;
    }
    withdrawn = true;
    finish(pointer, disposition);
    if (state.result == null && state.members.every((member) => member.withdrawn)) {
      state.captainEntry.resolve(GestureDisposition.rejected);
    }
  }
}

/// 在官方竞技场中识别点击、连击、侧键与长按，并沿 [parent] 冒泡。
///
/// 仅使用指针输入与识别参数；宿主可提供范围函数并订阅通用反馈状态。
class PressRecognizer extends _GestureRecognizer {
  /// 连续点击的默认位置容差，也可供元素适配采用相同的点击距离规则。
  static const double defaultConsecutiveTapDistance = 10;

  /// 按压回调表支持的阶段，供识别器与宿主共用同一范围。
  @internal
  static final callbackPhases = List<ElEventPhase>.unmodifiable(
    ElEventPhase.values.getRange(ElEventPhase.tapDown.index, ElEventPhase.tapCancel.index + 1),
  );
  static final _primaryPhases = <ElEventPhase>[
    ...ElEventPhase.values.getRange(ElEventPhase.tapDown.index, ElEventPhase.secondaryTapDown.index),
    ElEventPhase.longPress,
    ElEventPhase.tapCancel,
  ];

  /// 创建独立按压识别器，识别参数在每次按下时冻结。
  PressRecognizer({super.debugOwner, super.supportedDevices, super.allowedButtonsFilter});

  /// 同类手势冒泡父级，不重复参加同一指针的竞技场。
  PressRecognizer? parent;

  /// 是否竞争主键点击；关闭时只观察按压，长按仍可独立报名。
  bool competeForTap = true;

  /// 是否独立跟踪追加主触点，允许复合手势决定何时取消点击；侧键始终独立。
  bool allowMultiplePointers = false;

  /// 第二击与前一击的最长间隔，空值恢复官方默认时限。
  Duration? doubleTapInterval = kDoubleTapTimeout;

  /// 第三击与前一击的最长间隔。
  Duration? tripleTapInterval = kDoubleTapTimeout;

  /// 长按成立前的等待时间。
  Duration? longPressDelay = kLongPressTimeout;

  /// 点击移动容差；为空时使用官方设备容差，可设为无穷大交由宿主决定取消。
  double? tapSlopTolerance;

  /// 侧键点击移动容差；为空时沿用主键容差，与宿主的主键边界策略独立。
  double? secondaryTapSlopTolerance;

  /// 提交点击或长按前的成员资格判断，尺寸等外部条件由调用方计算。
  bool Function(ElEventPhase phase, PointerEvent event)? isEligible;

  /// 长按成立后是否自动取消自身点击，关闭后可由调用方通过 rejectTap 决定。
  bool cancelTapOnLongPress = true;

  /// 长按移动容差；为空时使用官方设备容差。
  double? longPressSlopTolerance;

  /// 相邻连续点击允许的最大位置间距。
  double? consecutiveTapDistance = defaultConsecutiveTapDistance;

  /// 有双击订阅时是否等待窗口结束再通知单击，不延迟释放或持有竞技场。
  bool? deferTap = false;

  /// 是否向祖先冒泡侧键事件；关闭时仅最近订阅该按钮的成员接收。
  bool bubbleSideButtons = true;

  /// 释放阶段截断后是否继续通知祖先；关闭仍会结清祖先反馈和内部跟踪。
  bool bubbleReleaseAfterStop = true;

  /// 祖先坐标系的稳定参考点；移动超过设备容差会永久取消本轮点击。
  Offset? Function()? ancestorOriginResolver;

  /// 触摸反馈点亮前的等待时间，不延迟按压或点击通知。
  Duration feedbackDelay = Duration.zero;

  /// 触摸反馈从物理按下开始计算的最短时间，未点亮的轻触不会补播。
  Duration minimumFeedbackDuration = Duration.zero;

  /// 通用反馈状态变化通知；不包含样式、尺寸或宿主类型。
  void Function(bool value)? onFeedbackChanged;

  /// 当前是否有仍在有效范围内的主键按压。
  bool get isPressed => _sequences.any(
    (sequence) =>
        sequence.group.down.buttons == kPrimaryButton &&
        sequence.group.up == null &&
        sequence.downVisible &&
        _isCurrent(sequence) &&
        _allows(sequence),
  );

  /// 当前反馈是否亮起，可能因延迟进入或最短时长而不同于 [isPressed]。
  bool get isFeedbackActive => _feedback?.value ?? false;

  /// 是否仍在跟踪本成员的按压或等待释放结算，不含延迟单击和反馈保留。
  @override
  bool get hasActiveInput => _sequences.any((sequence) => !sequence.group.completing && _isCurrent(sequence));

  _PressFeedback? _feedback;

  bool get _hasPrimaryCallbacks =>
      _primaryPhases.any((phase) => phase != ElEventPhase.longPress && callbacks[phase] != null);

  _PressSettings get _settings {
    final settings = (
      doubleTapInterval: doubleTapInterval ?? kDoubleTapTimeout,
      tripleTapInterval: tripleTapInterval ?? kDoubleTapTimeout,
      longPressDelay: longPressDelay ?? kLongPressTimeout,
      tapSlopTolerance: tapSlopTolerance,
      secondaryTapSlopTolerance: secondaryTapSlopTolerance,
      longPressSlopTolerance: longPressSlopTolerance,
      consecutiveTapDistance: consecutiveTapDistance ?? defaultConsecutiveTapDistance,
      deferTap: deferTap ?? false,
    );
    assert(settings.doubleTapInterval >= Duration.zero);
    assert(settings.tripleTapInterval >= Duration.zero);
    assert(settings.longPressDelay >= Duration.zero);
    assert(settings.tapSlopTolerance == null || settings.tapSlopTolerance! >= 0);
    assert(settings.secondaryTapSlopTolerance == null || settings.secondaryTapSlopTolerance! >= 0);
    assert(settings.longPressSlopTolerance == null || settings.longPressSlopTolerance! >= 0);
    assert(settings.consecutiveTapDistance >= 0);
    return settings;
  }

  /// 订阅按压阶段，仅响应 tapDown 至 tapCancel 范围内的阶段。
  Map<ElEventPhase, PressGestureCallback?> callbacks = {};

  /// 长按整链通知后执行的默认动作；祖先否决或候选失效时不调用。
  PressGestureCallback? onLongPressDefault;

  /// 物理释放对应的同步语义通知全部结束后调用，不等待延迟单击。
  PressGestureCallback? onReleased;

  _PressGroup? _primaryGroup;
  final Map<int, _PressGroup> _groups = {};

  bool _unregisterGroup(_PressGroup group) {
    if (identical(_primaryGroup, group)) _primaryGroup = null;
    if (!identical(_groups[group.down.pointer], group)) return false;
    _groups.remove(group.down.pointer);
    return true;
  }

  final Set<_PressSequence> _sequences = {};
  Timer? _historyTimer;
  _PressHistory? _history;
  int _nextGroup = 0;
  bool _disposing = false;

  @override
  PressRecognizer? get _bubbleParent {
    if (_cooperation?.matchParentGestures != true) return parent;
    var candidate = parent;
    while (candidate != null && candidate.competeForTap != competeForTap) {
      candidate = candidate.parent;
    }
    return candidate;
  }

  @override
  _GestureCallback? _handlerFor(ElEventPhase phase) {
    if (phase.index < callbackPhases.first.index || phase.index > callbackPhases.last.index) return null;
    final handler = callbacks[phase];
    final feedback = onFeedbackChanged != null && (phase == ElEventPhase.tapDown || phase == ElEventPhase.tapCancel);
    if (handler == null && !feedback && !(phase == ElEventPhase.longPress && onLongPressDefault != null)) return null;
    return (details) {
      final press = details as PressGestureDetails;
      if (phase == ElEventPhase.tapDown && onFeedbackChanged != null) {
        assert(feedbackDelay >= Duration.zero && minimumFeedbackDuration >= Duration.zero);
        (_feedback ??= _PressFeedback(
          (value) => invokeCallback<void>('feedback', () => onFeedbackChanged?.call(value)),
        )).down(press.downEvent, feedbackDelay, minimumFeedbackDuration);
      } else if (phase == ElEventPhase.tapCancel) {
        _feedback?.cancel(
          contact: press.downEvent,
          preserveMinimum: press.cancelReason == PressCancelReason.ineligible,
        );
      }
      if (press.isActive) handler?.call(press);
    };
  }

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (_disposed || _disposing || _canceling) return false;
    if (_isDelegated(event.pointer)) return true;
    if (!super.isPointerAllowed(event)) return false;
    final phases = _pressPhases(event.buttons);
    if (phases == null) return false;
    return (event.buttons == kPrimaryButton ? _primaryPhases : [phases.$1, phases.$2, phases.$3]).any(
      _hasHandlerInChain,
    );
  }

  @override
  void handleNonAllowedPointer(PointerDownEvent event) {}

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_delegatePointer(event)) return;
    final competes =
        event.buttons != kPrimaryButton ||
        _snapshotChain().cast<PressRecognizer>().any((member) => member.competeForTap && member._hasPrimaryCallbacks);
    final passive = !competes && !_hasHandlerInChain(ElEventPhase.longPress);
    final parallel =
        allowMultiplePointers ||
        event.buttons != kPrimaryButton ||
        _primaryGroup != null && _primaryGroup!.down.buttons != kPrimaryButton;
    final registered = _groups[event.pointer];
    final previous = passive && identical(registered, _primaryGroup)
        ? null
        : passive || parallel
        ? registered
        : _primaryGroup;
    // 已失去点击资格的首指仍承担释放通知，追加触点不能销毁这项义务。
    if (previous != null &&
        previous.up == null &&
        previous.sequences.values.every((sequence) => !sequence.tapEligible && !sequence.longPressEligible)) {
      return;
    }
    if (previous != null) {
      final stillDown = previous.up == null;
      _abortGroup(previous, PressCancelReason.rejected, previous.lastEvent);
      if (stillDown || _disposed || _disposing || _primaryGroup != null) return;
    }
    final route = _beginRoute(event);
    final group = _PressGroup(route, event, passive: passive, competeForTap: competes);
    _groups[event.pointer] = group;
    if (!passive && (!parallel || _primaryGroup == null)) _primaryGroup = group;
    group.accepted = passive;
    final sideTarget = event.buttons == kPrimaryButton
        ? null
        : route.members.cast<PressRecognizer>().where((member) {
            final phases = _pressPhases(event.buttons)!;
            return member._handlerFor(phases.$1) != null ||
                member._handlerFor(phases.$2) != null ||
                member._handlerFor(phases.$3) != null;
          }).firstOrNull;
    for (final node in route.members.cast<PressRecognizer>()) {
      if (sideTarget != null && !sideTarget.bubbleSideButtons && !identical(node, sideTarget)) continue;
      final settings = node._settings;
      final sequence = _PressSequence(node, group, settings);
      group.sequences[node] = sequence;
      node._sequences.add(sequence);
    }
    // 纯观察复用可移交的输入记录，但不因此报名官方竞技场。
    _trackPointer(event.pointer, event.transform, compete: !passive);
  }

  @override
  void handleEvent(PointerEvent event) {
    final group = _groups[event.pointer];
    if (group == null) return;
    group.lastEvent = event;
    if (event is PointerDownEvent) {
      for (final sequence in group.sequences.values) {
        sequence.downVisible =
            sequence.node._registeredFor(group.route, event.pointer) && sequence.node._participates(event.pointer);
      }
      _emit(group, _pressPhases(event.buttons)!.$1, event);
      for (final sequence in group.sequences.values.toList()) {
        final node = sequence.node;
        if (!node._isCurrent(sequence) || event.buttons != kPrimaryButton) {
          continue;
        }
        final count = node._consecutiveCount(sequence, event);
        if (count > 1) {
          _emit(
            group,
            count == 2 ? ElEventPhase.doubleTapDown : ElEventPhase.tripleTapDown,
            event,
            only: sequence,
            tapCount: count,
          );
        }
        if (node._isCurrent(sequence) &&
            (node.callbacks[ElEventPhase.longPress] != null || node.onLongPressDefault != null) &&
            _allows(sequence)) {
          if (sequence.settings.longPressDelay == Duration.zero) {
            // 零延迟在本次按下收尾时生效，仍复用存活和取消资格检查。
            scheduleMicrotask(() => sequence.group.owner._longPressDeadline(sequence));
          } else {
            sequence.longPressTimer = Timer(
              sequence.settings.longPressDelay,
              () => sequence.group.owner._longPressDeadline(sequence),
            );
          }
        }
      }
      return;
    }
    if (event is PointerMoveEvent && event.buttons != group.down.buttons && group.down.buttons == kPrimaryButton) {
      for (final sequence in group.sequences.values.toList()) {
        sequence.tapEligible = sequence.longPressEligible = false;
        sequence.longPressTimer?.cancel();
        sequence.node._resetHistory();
        _notifyCancel(sequence, PressCancelReason.rejected, event);
      }
      return;
    }
    if (event is PointerCancelEvent || event is PointerMoveEvent && event.buttons != group.down.buttons) {
      _abortGroup(
        group,
        event is PointerCancelEvent ? PressCancelReason.pointerCanceled : PressCancelReason.rejected,
        event,
      );
      return;
    }
    if (event is PointerMoveEvent || event is PointerUpEvent) {
      for (final sequence in group.sequences.values.toList()) {
        _updatePosition(sequence, event);
      }
    }
    if (event is PointerUpEvent && identical(group.owner._groups[event.pointer], group)) {
      group.up = event;
      for (final sequence in group.sequences.values) {
        sequence.longPressTimer?.cancel();
      }
      if (group.accepted || !group.competeForTap) {
        group.owner._completeAccepted(group);
      } else if (!group.sequences.values.any(
        (sequence) =>
            sequence.tapEligible &&
            sequence.node._isCurrent(sequence) &&
            (sequence.eligible?.call(_pressPhases(group.down.buttons)!.$3, event) ?? true),
      )) {
        // 自己放弃点击仍须结清物理释放，但不占用官方席位阻挡其他候选。
        group.owner._completeAccepted(group, releaseOnly: true);
      } else {
        // 释放交给官方 sweep；不能在 up 抢先接受而越过更内层的官方 Tap。
        group.owner.stopTrackingPointer(event.pointer);
      }
    }
  }

  bool _isCurrent(_PressSequence sequence) =>
      !_disposed &&
      !sequence.canceled &&
      !sequence.released &&
      !sequence.canceling &&
      sequence.group.route.active &&
      _registeredFor(sequence.group.route, sequence.group.down.pointer);

  static bool _allows(_PressSequence sequence) {
    final route = sequence.group.route;
    final index = route.members.indexOf(sequence.node);
    return index >= 0 && index <= (route.cutoffs[_GestureFamily.press] ?? route.members.length - 1);
  }

  void _updatePosition(_PressSequence sequence, PointerEvent event) {
    if (!sequence.node._isCurrent(sequence)) return;
    final origin = sequence.downOrigin;
    final currentOrigin = sequence.originResolver?.call();
    if (!sequence.node._isCurrent(sequence)) return;
    if (sequence.tapEligible &&
        origin != null &&
        currentOrigin != null &&
        (currentOrigin - origin).distance > computeHitSlop(sequence.group.down.kind, sequence.node.gestureSettings)) {
      sequence.tapEligible = false;
      sequence.longPressEligible = false;
      sequence.longPressTimer?.cancel();
      sequence.node._resetHistory();
      _notifyCancel(sequence, PressCancelReason.rejected, event);
      return;
    }
    final distance = (event.position - sequence.group.down.position).distance;
    if (distance > sequence.longPressSlop) {
      sequence.longPressEligible = false;
      sequence.longPressTimer?.cancel();
      sequence.longPressTimer = null;
    }
    if (sequence.tapEligible && distance > sequence.tapSlop) {
      sequence.tapEligible = false;
      _notifyCancel(sequence, PressCancelReason.rejected, event);
    }
    if (event is PointerMoveEvent && sequence.tapEligible && sequence.group.down.buttons == kPrimaryButton) {
      final eligible = sequence.eligible?.call(ElEventPhase.tap, event) ?? true;
      if (!sequence.node._isCurrent(sequence)) return;
      if (!eligible) {
        _notifyCancel(sequence, PressCancelReason.ineligible, event);
      } else if (!sequence.downVisible && _allows(sequence)) {
        sequence.downVisible = true;
        _emit(sequence.group, ElEventPhase.tapDown, event, only: sequence);
      }
    }
  }

  void _longPressDeadline(_PressSequence sequence) {
    sequence.longPressTimer = null;
    final group = sequence.group;
    _updatePosition(sequence, group.lastEvent);
    if (!sequence.node._isCurrent(sequence) ||
        group.longPressFired ||
        !sequence.longPressEligible ||
        group.up != null ||
        !_allows(sequence) ||
        !(sequence.eligible?.call(ElEventPhase.longPress, group.lastEvent) ?? true)) {
      return;
    }
    sequence.longPressRequested = true;
    if (group.accepted) {
      _deliverLongPress(sequence);
    } else {
      group.owner.resolvePointer(group.down.pointer, GestureDisposition.accepted);
    }
  }

  void _deliverLongPress(_PressSequence sequence) {
    final group = sequence.group;
    if (!sequence.node._isCurrent(sequence) ||
        !sequence.longPressRequested ||
        group.longPressFired ||
        !_allows(sequence)) {
      return;
    }
    final observers = <PressRecognizer, _PressSequence>{...group.sequences};
    final dispatch = group.owner._cooperation?._observations[group.down.pointer]?.dispatch;
    for (final input in dispatch?.members ?? const <_PointerObservation>[]) {
      for (final member in input.team._members.whereType<PressRecognizer>()) {
        final other = member._groups[group.down.pointer]?.sequences[member];
        if (other != null && member._isCurrent(other) && _allows(other) && member._participates(group.down.pointer)) {
          observers[member] = other;
        }
      }
    }
    for (final member in observers.values.toList()) {
      _updatePosition(member, group.lastEvent);
    }
    if (!sequence.node._isCurrent(sequence) || !sequence.longPressEligible) return;
    for (final member in observers.values) {
      member.group.longPressFired = true;
      member.longPressTimer?.cancel();
    }
    final members = observers.keys.toList();
    if (dispatch != null) {
      members.sort((a, b) => dispatch.indexOfTeam(a._cooperation!).compareTo(dispatch.indexOfTeam(b._cooperation!)));
    }
    final route = members.length == group.sequences.length ? group.route : _GestureRoute(group.owner, members);
    for (final member in observers.values) {
      route.subscription(member.node).downs = member.group.route.subscription(member.node).downs;
    }
    // 共享长按阶段，不合并不同点击意图的官方席位或释放路线。
    final result = _emit(
      group,
      ElEventPhase.longPress,
      group.down,
      phaseRoute: route,
      phaseObservers: observers,
      select: (member) =>
          _allows(member) &&
          member.longPressEligible &&
          (member.eligible?.call(ElEventPhase.longPress, group.lastEvent) ?? true),
    );
    for (final member in observers.values) {
      if (member.node.onFeedbackChanged == null) member.node._feedback?.cancel(contact: member.group.down);
    }
    if (result == null || result.defaultPrevented || !group.route.active) return;
    // 长按回调可以移除触发成员；默认动作仍由冻结路线中的存活成员承接。
    final current = sequence.node._isCurrent(sequence)
        ? sequence
        : observers.values.where((member) => member.node._isCurrent(member) && _allows(member)).firstOrNull;
    if (current == null) return;
    final node = current.node;
    _updatePosition(current, group.lastEvent);
    bool active() =>
        node._isCurrent(current) &&
        current.longPressEligible &&
        (current.eligible?.call(ElEventPhase.longPress, group.lastEvent) ?? true);
    if (!active() || result.defaultPrevented) return;
    result._isActive = active;
    result._updateTransform(group.route.subscription(node).downs[group.down.pointer]?.transform);
    final defaultAction = node.onLongPressDefault;
    if (defaultAction != null) {
      node.invokeCallback<void>('longPressDefault', () => defaultAction(result));
    }
    if (!active() || result.defaultPrevented) return;
    for (final member in observers.values.toList()) {
      if (member.node._isCurrent(member) && member.cancelTapOnLongPress) {
        member.tapEligible = false;
        member.node._resetHistory();
        _notifyCancel(member, PressCancelReason.longPressAccepted, group.lastEvent);
      }
    }
  }

  @override
  void acceptGesture(int pointer) {
    final group = _groups[pointer];
    if (group == null || group.down.pointer != pointer || group.accepted) {
      return;
    }
    group.accepted = true;
    resolvePointer(pointer, GestureDisposition.accepted);
    _notifyAccepted(group.route, pointer);
    for (final sequence in group.sequences.values.toList()) {
      if (sequence.longPressRequested) _deliverLongPress(sequence);
    }
    if (identical(group.owner._groups[pointer], group) && group.up != null) group.owner._completeAccepted(group);
  }

  @override
  void rejectGesture(int pointer) {
    final group = _groups[pointer];
    if (group != null && group.down.pointer == pointer) {
      _abortGroup(group, PressCancelReason.arenaRejected, group.lastEvent);
    }
  }

  @override
  void _requestAccept(_GestureRoute route, int pointer) {
    if (!_disposing && !_canceling && identical(_groups[pointer]?.route, route)) {
      resolvePointer(pointer, GestureDisposition.accepted);
    }
  }

  @override
  void _cancelRoutePointer(_GestureRoute route, int pointer, PointerEvent? event) {
    final group = _groups[pointer];
    if (group != null && identical(group.route, route) && group.down.pointer == pointer) {
      _abortGroup(group, PressCancelReason.canceled, event ?? group.lastEvent);
    }
  }

  /// 永久取消当前成员的点击资格，保留释放通知；配置沉降可关闭业务取消通知。
  void rejectTap(int pointer, {PressCancelReason reason = PressCancelReason.rejected, bool notify = true}) {
    for (final sequence in _sequences.toList()) {
      if (sequence.group.down.pointer != pointer || !_isCurrent(sequence)) {
        continue;
      }
      sequence.tapEligible = false;
      sequence.longPressEligible = false;
      sequence.longPressTimer?.cancel();
      _resetHistory();
      if (notify) {
        sequence.group.owner._notifyCancel(sequence, reason, sequence.group.lastEvent);
      } else {
        sequence.downVisible = false;
        sequence.node._feedback?.cancel(contact: sequence.group.down);
      }
    }
  }

  /// 终止当前成员及其待发点击，不终止同一路线的父子成员。
  void cancelMember([int? pointer]) {
    _cancelMember(pointer, PressCancelReason.canceled);
  }

  /// 清除旧声明的连击、延迟点击和长按等待，保留物理按压、释放义务及反馈。
  void invalidateDiscretePending() {
    _resetHistory();
    for (final sequence in _sequences.toList()) {
      sequence.longPressTimer?.cancel();
      sequence.longPressTimer = null;
      sequence.longPressEligible = false;
      if (sequence.group.deferredTap?.remove(sequence) ?? false) _releaseSequence(sequence);
    }
  }

  /// 结构声明替换时结清侧键候选，不影响主键按压与释放。
  void cancelSideButtons() {
    for (final sequence in _sequences.toList()) {
      if (sequence.group.down.buttons != kPrimaryButton) {
        _cancelSequence(sequence, PressCancelReason.canceled, sequence.group.lastEvent);
      }
    }
  }

  /// 更新已参赛候选的点击订阅，沿用原官方席位和物理释放通知。
  void refreshActiveSubscription() {
    for (final sequence in _sequences.toList()) {
      if (!_isCurrent(sequence) || sequence.group.passive) continue;
      sequence.competeForTap = competeForTap;
      if (competeForTap) sequence.group.competeForTap = true;
    }
  }

  void _cancelMember(int? pointer, PressCancelReason reason) {
    final feedbackContact = _feedback?.contact;
    // 反馈回调可能同步创建新输入，本轮取消只清理入口时的连击窗口。
    final history = _historyTimer;
    for (final sequence in _sequences.toList()) {
      if (pointer == null || sequence.group.down.pointer == pointer) {
        _cancelSequence(sequence, reason, sequence.group.lastEvent, resetHistory: identical(_historyTimer, history));
      }
    }
    if (feedbackContact != null && (pointer == null || feedbackContact.pointer == pointer)) {
      _feedback?.cancel(contact: feedbackContact);
    }
    if (pointer == null && identical(_historyTimer, history)) _resetHistory();
  }

  @override
  void cancel() {
    if (_disposed || _canceling) return;
    _canceling = true;
    try {
      final groups = _sequences.map((sequence) => sequence.group).toSet();
      if (_primaryGroup != null) groups.add(_primaryGroup!);
      groups.addAll(_groups.values);
      for (final group in groups) {
        if (identical(group.owner, this)) {
          _abortGroup(group, PressCancelReason.canceled, group.lastEvent);
        } else {
          final sequence = group.sequences[this];
          if (sequence != null) {
            _cancelSequence(sequence, PressCancelReason.canceled, group.lastEvent);
          }
        }
      }
      _resetHistory();
      _feedback?.cancel();
    } finally {
      _canceling = false;
    }
  }

  void _completeAccepted(_PressGroup group, {bool releaseOnly = false, bool afterRouting = false}) {
    final up = group.up;
    if (up == null || group.completing || !group.route.active) return;
    if (!afterRouting &&
        group.owner._cooperation?._deferRelease(up, group, () {
              group.owner._completeAccepted(group, releaseOnly: releaseOnly, afterRouting: true);
            }) ==
            true) {
      return;
    }
    group.completing = true;
    _unregisterGroup(group);
    _releaseRoutePointers(group.route);
    group.owner.stopTrackingPointer(group.down.pointer);
    if (releaseOnly || !group.competeForTap) {
      resolvePointer(group.down.pointer, GestureDisposition.rejected);
    }
    for (final sequence in group.sequences.values) {
      sequence.longPressTimer?.cancel();
    }
    _emit(group, _pressPhases(group.down.buttons)!.$2, up);
    for (final sequence in group.sequences.values) {
      sequence.downVisible = false;
    }
    final counts = <_PressSequence, int>{};
    final deferred = <_PressSequence>{};
    final deferredControl = GestureControl();
    _PressSequence? deferSource;
    var deferredCount = 0, deferredGroup = 0;
    for (final sequence in group.sequences.values.toList()) {
      final node = sequence.node;
      if (!node._isCurrent(sequence)) continue;
      final eligible =
          sequence.tapEligible &&
          (sequence.eligible?.call(_pressPhases(group.down.buttons)!.$3, up) ?? true) &&
          _allows(sequence);
      // 资格回调可同步取消成员或拒绝点击，返回后不能沿用调用前的候选资格。
      if (!node._isCurrent(sequence)) continue;
      if (!sequence.tapEligible || !eligible) {
        node._feedback?.cancel(contact: group.down);
        node._resetHistory();
        continue;
      }
      if (releaseOnly || group.down.buttons == kPrimaryButton && !sequence.competeForTap) continue;
      final count = group.down.buttons == kPrimaryButton ? node._consecutiveCount(sequence, up) : 1;
      counts[sequence] = count;
      if (group.down.buttons != kPrimaryButton) continue;
      final hasDouble = node.callbacks[ElEventPhase.doubleTap] != null;
      final hasTriple =
          node.callbacks[ElEventPhase.tripleTap] != null || node.callbacks[ElEventPhase.tripleTapDown] != null;
      final needsHistory = hasDouble || hasTriple || node.callbacks[ElEventPhase.doubleTapDown] != null;
      final historyGroup = count > 1 ? node._history?.group ?? 0 : ++node._nextGroup;
      if (needsHistory) {
        node._recordHistory(sequence, up, count, historyGroup, hasTriple: hasTriple);
      }
      if (deferSource == null && sequence.settings.deferTap && hasDouble) {
        deferSource = sequence;
        deferredCount = count;
        deferredGroup = historyGroup;
        if (count > 1) node._cancelDeferredGroup(historyGroup);
      }
      if (deferSource != null) {
        deferred.add(sequence);
        if (deferredCount == 1) {
          final pending = group.deferredTap ??= _DeferredPressTap(
            group,
            up,
            deferredGroup,
            deferSource.node,
            deferredControl,
          );
          pending.add(sequence, deferSource.settings.doubleTapInterval);
        }
      } else if (count > 1) {
        node._cancelDeferredGroup(historyGroup);
      }
    }
    final primary = group.down.buttons == kPrimaryButton;
    _emit(
      group,
      _pressPhases(group.down.buttons)!.$3,
      up,
      select: (sequence) => counts.containsKey(sequence) && !deferred.contains(sequence),
      counts: counts,
    );
    if (primary) {
      _emit(group, ElEventPhase.doubleTap, group.down, select: (sequence) => counts[sequence] == 2, tapCount: 2);
      _emit(group, ElEventPhase.tripleTap, group.down, select: (sequence) => counts[sequence] == 3, tapCount: 3);
    }
    for (final sequence in group.sequences.values.toList()) {
      final node = sequence.node;
      node._feedback?.up(group.down);
      final callback = node.onReleased;
      if (!node._disposed && callback != null) {
        node.invokeCallback<void>('released', () => callback(group.details(_pressPhases(group.down.buttons)!.$2, up)));
      }
    }
    for (final sequence in group.sequences.values.toList()) {
      if (!sequence.pending) sequence.node._releaseSequence(sequence);
    }
  }

  int _consecutiveCount(_PressSequence sequence, PointerEvent event) {
    final history = _history;
    if (history == null ||
        history.settings != sequence.settings ||
        !(_historyTimer?.isActive ?? false) ||
        event.timeStamp > history.deadline ||
        (event.position - history.position).distance > sequence.settings.consecutiveTapDistance) {
      return 1;
    }
    return (history.count + 1).clamp(1, 3);
  }

  void _recordHistory(_PressSequence sequence, PointerUpEvent up, int count, int group, {required bool hasTriple}) {
    _resetHistory();
    if (count == 3 || count == 2 && !hasTriple) return;
    final interval = count == 2 ? sequence.settings.tripleTapInterval : sequence.settings.doubleTapInterval;
    _history = (
      count: count,
      settings: sequence.settings,
      group: group,
      position: up.position,
      deadline: up.timeStamp + interval,
    );
    _historyTimer = Timer(interval, _resetHistory);
  }

  void _resetHistory() {
    _historyTimer?.cancel();
    _historyTimer = null;
    _history = null;
  }

  void _cancelDeferredGroup(int group) {
    for (final sequence in _sequences.toList()) {
      final pending = sequence.group.deferredTap;
      if (sequence.pending && pending?.group == group && identical(pending?.anchor, this)) pending!.cancel();
    }
  }

  void _notifyCancel(_PressSequence sequence, PressCancelReason reason, PointerEvent event) {
    sequence.node._feedback?.cancel(
      contact: sequence.group.down,
      preserveMinimum: reason == PressCancelReason.ineligible,
    );
    final index = sequence.group.route.members.indexOf(sequence.node);
    if (!sequence.downVisible || index > (sequence.group.route.observedEnds[_GestureFamily.press] ?? -1)) {
      sequence.downVisible = false;
      return;
    }
    sequence.downVisible = false;
    _emit(sequence.group, ElEventPhase.tapCancel, event, only: sequence, cancelReason: reason);
  }

  void _cancelSequence(
    _PressSequence sequence,
    PressCancelReason reason,
    PointerEvent event, {
    bool resetHistory = true,
  }) {
    sequence.group.route.invalidate(this, _GestureFamily.press);
    if (sequence.canceled || sequence.released || sequence.canceling) return;
    sequence.canceling = true;
    sequence.longPressTimer?.cancel();
    if (resetHistory) _resetHistory();
    sequence.group.deferredTap?.remove(sequence);
    sequence.group.owner._notifyCancel(sequence, reason, event);
    sequence.canceled = true;
    // 边界传播可能重入取消；已结算的成员不得再次接收合成 TapCancel。
    sequence.group.route.subscription(this).phase(_GestureFamily.press).excluded = true;
    _releaseSequence(sequence);
  }

  void _abortGroup(_PressGroup group, PressCancelReason reason, PointerEvent event) {
    if (group.canceling) return;
    if (group.completing && group.route.terminalDispatchDepth > 0) {
      // Up 内销毁只阻止后续业务点击，已经公开的父级释放仍须兑现。
      for (final sequence in group.sequences.values) {
        sequence.tapEligible = false;
        sequence.longPressTimer?.cancel();
        sequence.node._resetHistory();
      }
      return;
    }
    group.canceling = true;
    _unregisterGroup(group);
    _releaseRoutePointers(group.route);
    resolvePointer(group.down.pointer, GestureDisposition.rejected);
    group.owner.stopTrackingPointer(group.down.pointer);
    for (final sequence in group.sequences.values.toList()) {
      sequence.node._cancelSequence(sequence, reason, event);
    }
    _endRoute(group.route);
  }

  void _releaseSequence(_PressSequence sequence) {
    if (sequence.released) return;
    sequence.released = true;
    _sequences.remove(sequence);
    if (sequence.group.sequences.values.every((member) => member.released)) {
      final group = sequence.group;
      final owner = group.owner;
      final primary = identical(owner._primaryGroup, group);
      if (owner._unregisterGroup(group)) {
        if (primary) owner.resolvePointer(group.down.pointer, GestureDisposition.rejected);
        group.owner.stopTrackingPointer(group.down.pointer);
      }
      owner._endRoute(group.route);
    }
  }

  @override
  void _stopOtherRoutes(_GestureRoute route, GestureDetails details) {
    if (_cooperation?.matchParentGestures != true || details.phase != ElEventPhase.tapDown) {
      return;
    }
    // 点击意图不同的祖先独立参赛，但仍遵守内层 Down 的冒泡边界。
    final dispatch = _cooperation?._observations[details.pointer]?.dispatch;
    if (dispatch == null) return;
    final start = dispatch.indexOfTeam(_cooperation!);
    for (final input in dispatch.members.skip(start + 1)) {
      for (final ancestor in input.team._members.whereType<PressRecognizer>()) {
        if (!route.members.contains(ancestor)) {
          ancestor.cancelMember(details.pointer);
        }
      }
    }
  }

  PressGestureDetails? _emit(
    _PressGroup group,
    ElEventPhase phase,
    PointerEvent event, {
    _PressSequence? only,
    bool Function(_PressSequence sequence)? select,
    Map<_PressSequence, int>? counts,
    int tapCount = 0,
    PressCancelReason? cancelReason,
    GestureControl? control,
    _GestureRoute? phaseRoute,
    Map<PressRecognizer, _PressSequence>? phaseObservers,
  }) {
    if (!group.route.active) return null;
    if (only != null && !_allows(only) && !phase._terminal) return null;
    final shared = group.details(phase, event, cancelReason: cancelReason).._sequenceIdentity = group.route;
    if (control != null) {
      shared._controlSource = control;
      shared._dispatchIdentity = control;
    }
    final memberIndex = only == null ? null : group.route.members.indexOf(only.node);
    if (memberIndex != null && memberIndex < 0) return null;
    group.owner._dispatchGesture(
      phaseRoute ?? group.route,
      shared,
      sequenceIdentity: group.route,
      firstMember: memberIndex ?? 0,
      lastMember: memberIndex,
      isolatedMember: only != null,
      prepare: (member) {
        final sequence = (phaseObservers ?? group.sequences)[member];
        if (sequence == null ||
            sequence.canceled ||
            sequence.released ||
            sequence.canceling && phase != ElEventPhase.tapCancel ||
            only != null && !identical(only, sequence) ||
            !(select?.call(sequence) ?? true)) {
          return null;
        }
        return group.details(phase, event, tapCount: counts?[sequence] ?? tapCount, cancelReason: cancelReason)
          .._dispatchIdentity = shared.dispatchIdentity;
      },
    );
    return shared;
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}
  @override
  String get debugDescription => 'el press';
  @override
  void dispose() {
    if (_disposed || _disposing || _canceling) return;
    _disposing = true;
    final groups = _sequences.map((sequence) => sequence.group).toSet();
    if (_primaryGroup != null) groups.add(_primaryGroup!);
    groups.addAll(_groups.values);
    for (final group in groups) {
      if (identical(group.owner, this)) {
        if (group.completing && group.route.terminalDispatchDepth > 0) {
          // 自身 Up 已开始，不能再补 Cancel；存活祖先继续原来的释放与点击。
          group.sequences[this]?.downVisible = false;
        }
        final successor = group.route.members.cast<PressRecognizer>().where((node) {
          final sequence = group.sequences[node];
          return !identical(node, this) &&
              !node._disposed &&
              !node._disposing &&
              !node._canceling &&
              sequence != null &&
              node._isCurrent(sequence) &&
              _allows(sequence) &&
              !group.route.subscription(node).excluded;
        }).firstOrNull;
        if (successor == null) {
          _abortGroup(group, PressCancelReason.canceled, group.lastEvent);
          continue;
        }
        final pointer = group.down.pointer;
        final tracking = _unregisterGroup(group);
        group.route.owner = successor;
        _transferTrackingTo(successor, pointer);
        if (tracking) {
          successor._groups[pointer] = group;
          if (successor._primaryGroup == null && !group.passive) successor._primaryGroup = group;
        }
      }
      final sequence = group.sequences[this];
      if (sequence != null) _cancelSequence(sequence, PressCancelReason.canceled, group.lastEvent);
    }
    _resetHistory();
    _feedback?.cancel();
    super.dispose();
  }
}

// 反馈计时与手势资格分开；只输出布尔值，不引用样式或宿主。
final class _PressFeedback {
  _PressFeedback(this.onChanged);

  final void Function(bool value) onChanged;
  PointerEvent? _contact;
  bool _released = false;
  Timer? _enter;
  Timer? _minimum;
  bool value = false;

  PointerEvent? get contact => _contact;

  void _set(bool next) {
    if (value == next) return;
    value = next;
    onChanged(next);
  }

  void down(PointerEvent source, Duration delay, Duration minimum) {
    final contact = source.original ?? source;
    final touch = contact.kind == PointerDeviceKind.touch;
    _enter?.cancel();
    if (!identical(_contact, contact)) {
      _minimum?.cancel();
      _contact = contact;
      _released = false;
      if (touch && minimum > Duration.zero) {
        _minimum = Timer(minimum, () {
          _minimum = null;
          if (identical(_contact, contact) && _released) cancel(contact: contact);
        });
      }
    }
    if (!touch || delay == Duration.zero) {
      _set(true);
    } else {
      _enter = Timer(delay, () {
        _enter = null;
        if (identical(_contact, contact) && !_released) _set(true);
      });
    }
  }

  void up(PointerEvent source) {
    final contact = source.original ?? source;
    if (!identical(_contact, contact)) return;
    _released = true;
    _enter?.cancel();
    _enter = null;
    if (!value || !(_minimum?.isActive ?? false)) cancel(contact: contact);
  }

  void cancel({PointerEvent? contact, bool preserveMinimum = false}) {
    final expected = contact?.original ?? contact;
    if (contact != null && !identical(_contact, expected)) return;
    _enter?.cancel();
    _enter = null;
    if (!preserveMinimum) {
      _minimum?.cancel();
      _minimum = null;
      _contact = null;
    }
    _set(false);
  }
}

final class _PressGroup {
  _PressGroup(this.route, this.down, {required this.passive, required this.competeForTap}) : lastEvent = down;
  // 逻辑所有者只以冻结路线为准，移交时不维护第二份状态。
  PressRecognizer get owner => route.owner as PressRecognizer;
  final _GestureRoute route;
  final PointerDownEvent down;
  final bool passive;
  bool competeForTap;
  final Map<PressRecognizer, _PressSequence> sequences = {};
  PointerEvent lastEvent;
  PointerUpEvent? up;
  bool accepted = false;
  bool completing = false;
  bool canceling = false;
  bool longPressFired = false;
  _DeferredPressTap? deferredTap;

  PressGestureDetails details(
    ElEventPhase phase,
    PointerEvent event, {
    int tapCount = 0,
    PressCancelReason? cancelReason,
  }) => PressGestureDetails(
    phase: phase,
    originalEvent: event,
    downEvent: down,
    globalPosition: event.position,
    buttons: down.buttons,
    tapCount: tapCount,
    cancelReason: cancelReason,
  );
}

final class _PressSequence {
  // 按下时一次冻结识别参数、设备容差与宿主资格，后续更新只影响新序列。
  _PressSequence(this.node, this.group, this.settings)
    : tapSlop =
          (group.down.buttons == kPrimaryButton
              ? settings.tapSlopTolerance
              : settings.secondaryTapSlopTolerance ?? settings.tapSlopTolerance) ??
          computeHitSlop(group.down.kind, node.gestureSettings),
      longPressSlop = settings.longPressSlopTolerance ?? computeHitSlop(group.down.kind, node.gestureSettings),
      eligible = node.isEligible,
      cancelTapOnLongPress = node.cancelTapOnLongPress,
      competeForTap = node.competeForTap,
      originResolver = node.ancestorOriginResolver {
    downOrigin = originResolver?.call();
  }
  final PressRecognizer node;
  final _PressGroup group;
  final _PressSettings settings;
  final double tapSlop;
  final double longPressSlop;
  final bool Function(ElEventPhase, PointerEvent)? eligible;
  final bool cancelTapOnLongPress;
  bool competeForTap;
  final Offset? Function()? originResolver;
  late final Offset? downOrigin;
  Timer? longPressTimer;
  bool downVisible = false;
  bool tapEligible = true;
  bool longPressEligible = true;
  bool longPressRequested = false;
  bool canceled = false;
  bool canceling = false;
  // 计时器归成员所有，延期资格不再另存标志或反向集合。
  Timer? tapTimer;
  bool get pending => tapTimer != null;
  bool released = false;
}

final class _DeferredPressTap {
  _DeferredPressTap(this.physical, this.up, this.group, this.anchor, this.control);
  final _PressGroup physical;
  final PointerUpEvent up;
  final int group;
  final PressRecognizer anchor;
  final GestureControl control;

  void add(_PressSequence sequence, Duration delay) {
    sequence.tapTimer = Timer(delay, () {
      if (remove(sequence)) _dispatch(sequence);
    });
  }

  bool remove(_PressSequence sequence) {
    final timer = sequence.tapTimer;
    if (timer == null) return false;
    sequence.tapTimer = null;
    timer.cancel();
    return true;
  }

  void cancel() {
    for (final sequence in physical.sequences.values.toList()) {
      if (remove(sequence)) sequence.node._releaseSequence(sequence);
    }
  }

  void _dispatch(_PressSequence sequence) {
    try {
      if (sequence.node._isCurrent(sequence)) {
        physical.owner._emit(physical, ElEventPhase.tap, up, only: sequence, tapCount: 1, control: control);
      }
    } finally {
      sequence.node._releaseSequence(sequence);
    }
  }
}

(ElEventPhase, ElEventPhase, ElEventPhase)? _pressPhases(int buttons) => switch (buttons) {
  kPrimaryButton => (ElEventPhase.tapDown, ElEventPhase.tapUp, ElEventPhase.tap),
  kSecondaryButton => (ElEventPhase.secondaryTapDown, ElEventPhase.secondaryTapUp, ElEventPhase.secondaryTap),
  kTertiaryButton => (ElEventPhase.tertiaryTapDown, ElEventPhase.tertiaryTapUp, ElEventPhase.tertiaryTap),
  kForwardMouseButton => (ElEventPhase.forwardTapDown, ElEventPhase.forwardTapUp, ElEventPhase.forwardTap),
  kBackMouseButton => (ElEventPhase.backTapDown, ElEventPhase.backTapUp, ElEventPhase.backTap),
  _ => null,
};

typedef _PressHistory = ({int count, int group, Offset position, Duration deadline, _PressSettings settings});

typedef _PressSettings = ({
  Duration doubleTapInterval,
  Duration tripleTapInterval,
  Duration longPressDelay,
  double? tapSlopTolerance,
  double? secondaryTapSlopTolerance,
  double? longPressSlopTolerance,
  double consecutiveTapDistance,
  bool deferTap,
});
