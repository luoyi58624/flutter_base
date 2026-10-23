import 'package:flutter/widgets.dart';

/// 事件回调签名。
typedef ElEventHandler = void Function(ElEventCallback event);

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

  /// 主指针按下。
  tapDown,

  /// 主指针抬起。
  tapUp,

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
  secondaryTapDown,

  /// 第二按钮抬起。
  secondaryTapUp,

  /// 第二按钮点击。
  secondaryTap,

  /// 第三按钮按下，通常对应鼠标中键。
  tertiaryTapDown,

  /// 第三按钮抬起。
  tertiaryTapUp,

  /// 第三按钮点击。
  tertiaryTap,

  /// 前进按钮按下。
  forwardTapDown,

  /// 前进按钮抬起。
  forwardTapUp,

  /// 前进按钮点击。
  forwardTap,

  /// 后退按钮按下。
  backTapDown,

  /// 后退按钮抬起。
  backTapUp,

  /// 后退按钮点击。
  backTap,

  /// 长按。
  longPress,

  /// Tap 候选被取消。
  tapCancel,

  /// 拖拽开始。
  dragStart,

  /// 拖拽更新。
  dragUpdate,

  /// 拖拽结束。
  dragEnd,

  /// 拖拽取消。
  dragCancel,

  /// 缩放开始。
  scaleStart,

  /// 缩放更新。
  scaleUpdate,

  /// 缩放结束。
  scaleEnd,

  /// 缩放取消。
  scaleCancel,

  /// 旋转更新。
  rotationUpdate,

  /// 拖拽候选按下。
  dragDown,
}

/// `onTapCancel` 与合成 `onPointerCancel` 的语义原因。
///
/// 取消原因描述当前交互为何结束，让组件无需检查
/// [ElEventCallback.originalEvent] 的 Flutter 原始类型。
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

/// 事件回调参数。
///
/// 同一个对象会被沿冒泡链复用，每跳前由 dispatcher 重写 [localPosition] /
/// [localDelta] 为当前目标本地坐标，回调中不要再用 `globalToLocal` 自行换算。
class ElEventCallback {
  /// 创建事件回调参数。
  ElEventCallback({
    required this.phase,
    required this.globalPosition,
    required this.localPosition,
    this.delta = Offset.zero,
    this.localDelta = Offset.zero,
    Offset? remainingDelta,
    Offset? remainingLocalDelta,
    this.dragOffset = Offset.zero,
    this.dragDirection,
    this.dragAxis,
    this.velocity = Velocity.zero,
    this.primaryVelocity,
    this.buttons = 0,
    this.tapCount = 0,
    this.pointerCount = 0,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.logScaleVelocity = 0.0,
    ElEventCancelReason? cancelReason,
    this.originalEvent,
    this.sampleTimeStamp,
  }) : assert(
         phase == ElEventPhase.tapCancel ||
             phase == ElEventPhase.pointerCancel ||
             cancelReason == null,
         'cancelReason 只能用于 ElEventPhase.tapCancel 或 ElEventPhase.pointerCancel。',
       ),
       cancelReason = switch (phase) {
         ElEventPhase.tapCancel => cancelReason ?? ElEventCancelReason.external,
         ElEventPhase.pointerCancel =>
           cancelReason ?? ElEventCancelReason.pointerCanceled,
         _ => null,
       },
       remainingDelta = remainingDelta ?? delta,
       remainingLocalDelta = remainingLocalDelta ?? localDelta;

  /// 事件阶段。
  final ElEventPhase phase;

  /// 合成采样的实际时刻；为 null 时沿用原始事件时间，不以复用的 raw 事件代替采样帧。
  final Duration? sampleTimeStamp;

  /// 全局坐标。
  final Offset globalPosition;

  /// 当前目标本地坐标（冒泡时会被重写）。
  Offset localPosition;

  /// 全局移动增量。
  final Offset delta;

  /// 当前目标本地移动增量（冒泡时会被重写）。
  Offset localDelta;

  /// 当前事件还未被默认行为消费的全局移动增量。
  ///
  /// 拖拽类默认行为可以消费一部分 delta。dragStart / dragUpdate 的跨成员
  /// 记账走 `ElEvent.dragProxy` 声明的三段管线：pre（外→内）→ 主段 → overflow
  /// （内→外），阶段间通过 [remainingDelta] 传递余量（[consumeDelta] /
  /// [consumePrimaryDelta] 记账）。高频 dragUpdate 不冒泡，非管线路径下祖先
  /// 拦截应发生在 dragStart 或更早阶段。
  Offset remainingDelta;

  /// 当前事件还未被默认行为消费的本地移动增量（冒泡时会被重写）。
  Offset remainingLocalDelta;

  /// 自拖拽激活（dragStart）起的累计偏移，恒等于已派发 delta 的累计。
  ///
  /// down→激活之间的 slop 段位移**永不计入**（与 delta 流同口径）：若把
  /// 激活前段追账进来，激活后首个 dragUpdate 会把整段激活距离一口气同步给
  /// dragOffset 消费者，视觉上跳一下。
  final Offset dragOffset;

  /// 拖拽开始时由按下位置到当前位置推导出的方向。
  final AxisDirection? dragDirection;

  /// 本次拖拽手势的胜出轴向。
  ///
  /// 由起手方向竞争决出：宿主只声明 `onVerticalDrag*` 时恒为
  /// [Axis.vertical]；只声明 `onHorizontalDrag*` 时恒为 [Axis.horizontal]；
  /// 两组同时声明时按起手方向先过各自 slop 者胜出。自由拖拽
  /// （`onDrag*`）为 `null`。仅 drag 家族 phase 有意义。
  final Axis? dragAxis;

  /// 拖拽结束速度。
  final Velocity velocity;

  /// 拖拽结束主轴速度。
  ///
  /// 仅轴向拖拽有值；自由拖拽为 `null`，与 Flutter [DragEndDetails]
  /// 的 `primaryVelocity` 语义一致。
  final double? primaryVelocity;

  /// 当前指针按键位。
  final int buttons;

  /// 当前连续点击次数。
  final int tapCount;

  /// 当前目标参与本阶段的指针数量。
  ///
  /// pointerDown / pointerMove 包含当前指针，pointerUp / pointerCancel 为终止
  /// 后余数；dragCancel 为取消结算后仍活跃的数量。scale 家族表示参与变换的
  /// 指针数（对齐官方 ScaleUpdateDetails.pointerCount），其余 phase 恒 0。
  /// 冒泡时会按当前目标重写。
  int pointerCount;

  /// 当前触控板缩放值。
  final double scale;

  /// 当前触控板旋转弧度。
  final double rotation;

  /// 对数缩放速度 `d(log(scale))/dt`，单位为每秒；仅 scaleEnd 有意义。
  final double logScaleVelocity;

  /// 取消原因，仅 [ElEventPhase.tapCancel] 与 [ElEventPhase.pointerCancel] 有值。
  final ElEventCancelReason? cancelReason;

  /// 原始 Flutter 事件。
  final Object? originalEvent;

  Offset Function(Offset globalDelta)? _localDeltaResolver;
  void Function(
    ElEventCallback callback,
    bool cancelSelfTap,
    bool allowScaleUpgrade,
  )?
  _eagerGestureHandler;

  bool _propagationStopped = false;
  bool _defaultPrevented = false;
  bool _callbackInvoked = false;

  /// 当前回调是否处于拖拽代理位移分配管线中。
  bool dragPipelineActive = false;

  /// 当前拖拽路由是否仍有订阅同轴事件的活跃祖先；代理管线中不使用此值。
  bool hasAncestorDragConsumer = false;

  /// 全局 x 坐标。
  double get globalX => globalPosition.dx;

  /// 全局 y 坐标。
  double get globalY => globalPosition.dy;

  /// 本地 x 坐标。
  double get localX => localPosition.dx;

  /// 本地 y 坐标。
  double get localY => localPosition.dy;

  /// 是否已经停止冒泡。
  bool get propagationStopped => _propagationStopped;

  /// 是否已取消当前阶段的后续默认动作，具体动作由事件宿主或消费者定义。
  bool get defaultPrevented => _defaultPrevented;

  /// 是否已经调用过至少一个事件处理器。
  bool get callbackInvoked => _callbackInvoked;

  /// 将当前指针序列声明为当前事件宿主独占，并取消其他宿主的交互资格。
  ///
  /// 其他宿主会同步收到取消事件，后续不再参与本指针序列；独占不影响其他
  /// 指针或鼠标真实命中，也不隐式停止当前事件的传播。
  ///
  /// [cancelSelfTap] 取消当前宿主本序列的点击资格，保留指针跟踪与拖拽生命周期。
  /// [allowScaleUpgrade] 允许同一命中链的多指缩放随后接管此序列。
  void eagerGesture({
    bool cancelSelfTap = false,
    bool allowScaleUpgrade = false,
  }) {
    _eagerGestureHandler?.call(this, cancelSelfTap, allowScaleUpgrade);
  }

  /// 停止当前阶段向祖先事件宿主传播，并建立对应交互家族的后续传播边界。
  ///
  /// 指针按下会阻断祖先整条指针链；点击阶段仅影响后续点击家族，拖拽候选、
  /// 拖拽开始、缩放开始与触控板开始分别约束自己的家族路由。
  /// 高频指针移动与拖拽更新不做通用冒泡；独占整条指针序列请用 [eagerGesture]。
  void stopPropagation() {
    _propagationStopped = true;
  }

  /// 取消本阶段尚未执行的默认动作，不停止传播、不独占手势也不消费位移。
  ///
  /// 同一阶段的祖先能读取 [defaultPrevented]，标记不会延续到下一阶段。
  /// 长按阶段可阻止自动独占和取消点击；指针信号可阻止平台继续处理该信号；
  /// 其他默认动作由使用事件的组件自行读取此标记决定。
  void preventDefault() {
    _defaultPrevented = true;
  }

  /// 标记已有处理器被调用。仅供事件分发器使用。
  void markCallbackInvoked() {
    _callbackInvoked = true;
  }

  /// 复位 [propagationStopped]。仅供事件分发器使用（`ElEvent.dragProxy`
  /// 三段管线包装每段调用后复位，防止 proxy handler 内误用
  /// [stopPropagation] 打断管线）。
  void resetPropagation() {
    _propagationStopped = false;
  }

  /// 更新当前目标的本地增量换算器。仅供事件分发器使用。
  void updateLocalDeltaResolver(Offset Function(Offset globalDelta)? resolver) {
    _localDeltaResolver = resolver;
    // 余量尚未被消费时，当前目标的 localDelta 就是本地余量；
    // 避免每个 drag/scale update 再做两次全局坐标反解。
    remainingLocalDelta = remainingDelta == delta
        ? localDelta
        : resolver?.call(remainingDelta) ?? remainingDelta;
  }

  /// 更新当前目标的 eager gesture 处理器。仅供事件分发器使用。
  void updateEagerGestureHandler(
    void Function(
      ElEventCallback callback,
      bool cancelSelfTap,
      bool allowScaleUpgrade,
    )?
    handler,
  ) {
    _eagerGestureHandler = handler;
  }

  /// 消费一段拖拽 delta。
  void consumeDelta(Offset delta) {
    final consumed = _consumableDelta(delta);
    if (consumed == Offset.zero) return;
    remainingDelta -= consumed;
    remainingLocalDelta =
        _localDeltaResolver?.call(remainingDelta) ?? remainingDelta;
  }

  /// 消费指定轴向上的拖拽 delta。
  void consumePrimaryDelta(Axis axis, double delta) {
    consumeDelta(
      axis == Axis.vertical ? Offset(0.0, delta) : Offset(delta, 0.0),
    );
  }

  /// 消费全部剩余拖拽 delta。
  void consumeAllDelta() {
    remainingDelta = Offset.zero;
    remainingLocalDelta = Offset.zero;
  }

  /// 读取指定轴向上尚未消费的拖拽 delta。
  double remainingPrimaryDelta(Axis axis) =>
      axis == Axis.vertical ? remainingDelta.dy : remainingDelta.dx;

  Offset _consumableDelta(Offset delta) {
    return Offset(
      _consumableComponent(remainingDelta.dx, delta.dx),
      _consumableComponent(remainingDelta.dy, delta.dy),
    );
  }

  static double _consumableComponent(double remaining, double requested) {
    if (remaining == 0.0 || requested == 0.0) return 0.0;
    if (remaining.sign != requested.sign) return 0.0;
    return requested.abs() >= remaining.abs() ? remaining : requested;
  }
}
