part of 'recognizers.dart';

/// 独立手势的回调阶段，不包含 Widget 的原始指针和样式事件。
enum ElGesturePhase {
  /// 主按钮按下候选。
  tapDown,

  /// 主按钮释放。
  tapUp,

  /// 单击。
  tap,

  /// 双击。
  doubleTap,

  /// 双击按下候选。
  doubleTapDown,

  /// 三击。
  tripleTap,

  /// 三击按下候选。
  tripleTapDown,

  /// 第二按钮按下候选。
  secondaryTapDown,

  /// 第二按钮释放。
  secondaryTapUp,

  /// 第二按钮点击。
  secondaryTap,

  /// 第三按钮按下候选。
  tertiaryTapDown,

  /// 第三按钮释放。
  tertiaryTapUp,

  /// 第三按钮点击。
  tertiaryTap,

  /// 前进按钮按下候选。
  forwardTapDown,

  /// 前进按钮释放。
  forwardTapUp,

  /// 前进按钮点击。
  forwardTap,

  /// 后退按钮按下候选。
  backTapDown,

  /// 后退按钮释放。
  backTapUp,

  /// 后退按钮点击。
  backTap,

  /// 长按成立。
  longPress,

  /// 按压候选取消。
  tapCancel,

  /// 拖拽按下候选。
  dragDown,

  /// 拖拽开始。
  dragStart,

  /// 拖拽更新。
  dragUpdate,

  /// 拖拽正常结束。
  dragEnd,

  /// 拖拽取消。
  dragCancel,

  /// 缩放或旋转开始。
  scaleStart,

  /// 缩放更新。
  scaleUpdate,

  /// 变换正常结束。
  scaleEnd,

  /// 变换取消。
  scaleCancel,

  /// 旋转更新。
  rotationUpdate,
}

/// 按压候选终止的原因，仅描述识别器自身的生命周期。
enum ElGestureCancelReason {
  /// 移动容差、按钮变化或追加指针使候选失效。
  rejected,

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
typedef ElPressGestureCallback = void Function(ElPressGestureDetails details);

/// 拖拽与变换回调，所有阶段都可以通过详情停止冒泡。
typedef ElTransformGestureCallback = void Function(
  ElTransformGestureDetails details,
);

typedef _ElGestureCallback = void Function(ElGestureDetails details);

/// 手势回调的坐标和冒泡控制；同一详情沿 parent 路线复用，本地坐标逐级换算。
sealed class ElGestureDetails {
  ElGestureDetails._({
    required this.phase,
    required this.originalEvent,
    required this.globalPosition,
  }) : _localPosition = globalPosition;

  /// 当前手势阶段。
  final ElGesturePhase phase;

  /// 触发当前通知的官方输入事件。
  final PointerEvent originalEvent;

  /// 当前通知对应的指针标识。
  int get pointer => originalEvent.pointer;

  /// 原始输入时间，不使用回调处理时间替代。
  Duration get timeStamp => originalEvent.timeStamp;

  /// 全局位置。
  final Offset globalPosition;

  Offset _localPosition;

  /// 当前冒泡成员的本地位置，使用其报名事件携带的官方变换。
  Offset get localPosition => _localPosition;

  /// 当前按钮位掩码。
  int get buttons => originalEvent.buttons;

  bool _propagationStopped = false;
  Object? _dispatchIdentity;
  Object? _sequenceIdentity;

  /// 同次语义派发的身份，用于宿主在各冒泡成员之间共享默认行为和消费结果。
  Object get dispatchIdentity => _dispatchIdentity ?? this;

  /// 本轮冻结路线的身份，延迟回调仍沿用原身份，便于宿主隔离配置代际。
  Object get sequenceIdentity => _sequenceIdentity ?? dispatchIdentity;

  /// 当前回调是否已经请求停止冒泡。
  bool get propagationStopped => _propagationStopped;

  /// 截断当前及相应后续阶段；已公开的生命周期仍会收到必要的终态清理。
  void stopPropagation() => _propagationStopped = true;

  void _updateTransform(Matrix4? transform) {
    _localPosition = PointerEvent.transformPosition(transform, globalPosition);
  }
}

/// 按压与连续点击详情，不包含拖拽、样式或宿主尺寸信息。
final class ElPressGestureDetails extends ElGestureDetails {
  /// 创建按压详情。
  ElPressGestureDetails({
    required super.phase,
    required super.originalEvent,
    required super.globalPosition,
    required this.buttons,
    this.tapCount = 0,
    this.cancelReason,
  }) : super._();

  /// 按下时的按钮，释放事件仍保留原按钮信息。
  @override
  final int buttons;

  /// 当前有效连续点击次数，候选阶段可为零。
  final int tapCount;

  /// tapCancel 的原因，其他阶段为空。
  final ElGestureCancelReason? cancelReason;
}

/// 拖拽、缩放与旋转详情；位移消费和业务事件适配由宿主完成。
final class ElTransformGestureDetails extends ElGestureDetails {
  /// 创建变换详情。
  ElTransformGestureDetails({
    required super.phase,
    required super.originalEvent,
    required super.globalPosition,
    this.delta = Offset.zero,
    this.dragOffset = Offset.zero,
    this.dragAxis,
    this.dragDirection,
    this.velocity = Velocity.zero,
    this.pointerCount = 0,
    this.scale = 1,
    this.rotation = 0,
    this.logScaleVelocity = 0,
  }) : _localDelta = delta,
       _localVelocity = velocity.pixelsPerSecond,
       super._();

  /// 本次全局位移。
  final Offset delta;

  Offset _localDelta;

  /// 当前冒泡成员的本地位移。
  Offset get localDelta => _localDelta;

  /// 正式拖拽开始后的累计全局位移。
  final Offset dragOffset;

  /// 本轮拖拽采用的轴，自由拖拽为空。
  final Axis? dragAxis;

  /// 起手方向。
  final AxisDirection? dragDirection;

  /// 释放时的全局速度。
  final Velocity velocity;

  Offset _localVelocity;

  /// 当前成员本地拖拽轴上的释放速度，自由拖拽为空。
  double? get primaryVelocity => switch (dragAxis) {
    Axis.horizontal => _localVelocity.dx,
    Axis.vertical => _localVelocity.dy,
    null => null,
  };

  /// 已接受的触点数量；一个触控板变换按两个触点计数。
  final int pointerCount;

  /// 本轮变换累计缩放比例。
  final double scale;

  /// 本轮变换累计旋转弧度。
  final double rotation;

  /// 对数缩放速度。
  final double logScaleVelocity;

  @override
  void _updateTransform(Matrix4? transform) {
    super._updateTransform(transform);
    Offset mapDelta(Offset value) => PointerEvent.transformDeltaViaPositions(
      transform: transform,
      untransformedDelta: value,
      untransformedEndPosition: globalPosition,
    );
    _localDelta = mapDelta(delta);
    _localVelocity = mapDelta(velocity.pixelsPerSecond);
  }
}
