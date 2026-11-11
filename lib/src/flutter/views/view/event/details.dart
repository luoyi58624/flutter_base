import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Axis, AxisDirection;

/// ElEvent 支持的事件阶段。
enum ElEventPhase {
  /// 鼠标进入、移动与离开。
  pointerEnter,
  pointerHover,
  pointerExit,

  /// 原始指针生命周期。
  pointerDown,
  pointerMove,
  pointerUp,
  pointerCancel,

  /// 原始触控板平移缩放与指针信号。
  pointerPanZoomStart,
  pointerPanZoomUpdate,
  pointerPanZoomEnd,
  pointerSignal,

  /// 主键点击及连击。
  tapDown,
  tapUp,
  tap,
  doubleTap,
  doubleTapDown,
  tripleTap,
  tripleTapDown,

  /// 右键、中键和鼠标侧键。
  secondaryTapDown,
  secondaryTapUp,
  secondaryTap,
  tertiaryTapDown,
  tertiaryTapUp,
  tertiaryTap,
  forwardTapDown,
  forwardTapUp,
  forwardTap,
  backTapDown,
  backTapUp,
  backTap,
  longPress,
  tapCancel,

  /// 拖拽与缩放。
  dragDown,
  dragStart,
  dragUpdate,
  dragEnd,
  dragCancel,
  scaleStart,
  scaleUpdate,
  scaleEnd,
  scaleCancel,
  rotationUpdate,

  /// 键盘与焦点。
  keyDown,
  keyRepeat,
  keyUp,
  focus,
  blur;

  /// 拖拽的开始、更新和终止阶段。
  static const dragPhases = <ElEventPhase>[dragStart, dragUpdate, dragEnd, dragCancel];

  /// 缩放的开始、更新和终止阶段。
  static const zoomPhases = <ElEventPhase>[scaleStart, scaleUpdate, scaleEnd, scaleCancel];

  /// 缩放和旋转的变换阶段。
  static const scalePhases = <ElEventPhase>[...zoomPhases, rotationUpdate];
}

/// 焦点变化的来源。
enum ElFocusReason { programmatic, pointer, keyboard, lifecycle }

/// 指针或手势取消的原因。
enum ElEventCancelReason { tapRejected, selfGestureAccepted, otherGestureAccepted, pointerCanceled, external }

/// 当前阶段的输入、宿主坐标和传播控制。
class ElEventDetails({
  /// 当前阶段。
  required final ElEventPhase phase,

  /// Flutter 原始指针或键盘事件。
  final Object? originalEvent,

  /// 当前全局位置。
  required final Offset globalPosition,

  /// 当前接收节点的局部位置。
  required var Offset localPosition,

  /// 本次全局位移。
  final Offset delta = Offset.zero,

  /// 本次局部位移。
  var Offset localDelta = Offset.zero,

  /// 尚未消费的全局位移。
  Offset? remainingDelta,

  /// 尚未消费的局部位移。
  Offset? remainingLocalDelta,

  /// 起拖后的累计位移。
  final Offset dragOffset = Offset.zero,

  /// 获胜的轴向，Pan 为 null。
  final Axis? dragAxis,

  /// 拖拽起手方向。
  final AxisDirection? dragDirection,

  /// 释放速度。
  final Velocity velocity = Velocity.zero,

  /// 轴向拖拽的主轴释放速度。
  final double? primaryVelocity,

  /// 当前触点数量。
  var int pointerCount = 0,

  /// 指针按键位。
  final int buttons = 0,

  /// 连击计数。
  final int tapCount = 0,

  /// 本段缩放比例。
  final double scale = 1,

  /// 本段旋转角度，单位为弧度。
  final double rotation = 0,

  /// 缩放比例的对数速度。
  final double logScaleVelocity = 0,

  /// 焦点变化来源。
  final ElFocusReason? focusReason,

  /// 取消原因，仅 tapCancel 与 pointerCancel 可传入。
  ElEventCancelReason? cancelReason,
}) {
  this
    : assert(
        phase == ElEventPhase.tapCancel || phase == ElEventPhase.pointerCancel || cancelReason == null,
        'cancelReason 只能用于 ElEventPhase.tapCancel 或 ElEventPhase.pointerCancel。',
      );

  /// 尚未消费的全局位移。
  Offset remainingDelta = remainingDelta ?? delta;

  /// 尚未消费的局部位移。
  Offset remainingLocalDelta = remainingLocalDelta ?? localDelta;

  /// 业务取消原因，仅 tapCancel 与 pointerCancel 有值。
  final ElEventCancelReason? cancelReason = switch (phase) {
    .pointerCancel => cancelReason ?? .pointerCanceled,
    .tapCancel => cancelReason ?? .external,
    _ => null,
  };

  /// 对应的原始指针输入。
  PointerEvent? get pointerEvent => originalEvent is PointerEvent ? originalEvent as PointerEvent : null;

  /// 指针编号，非指针输入为零。
  int get pointer => pointerEvent?.pointer ?? 0;

  /// 原始指针时间。
  Duration get timeStamp => pointerEvent?.timeStamp ?? Duration.zero;

  /// 当前按键的逻辑键。
  LogicalKeyboardKey? get logicalKey => originalEvent is KeyEvent ? (originalEvent as KeyEvent).logicalKey : null;

  /// 当前按键的物理键。
  PhysicalKeyboardKey? get physicalKey => originalEvent is KeyEvent ? (originalEvent as KeyEvent).physicalKey : null;

  /// 当前按键产生的字符。
  String? get character => originalEvent is KeyEvent ? (originalEvent as KeyEvent).character : null;

  /// 当前局部横坐标。
  double get localX => localPosition.dx;

  /// 当前局部纵坐标。
  double get localY => localPosition.dy;

  /// 当前全局横坐标。
  double get globalX => globalPosition.dx;

  /// 当前全局纵坐标。
  double get globalY => globalPosition.dy;

  bool _stopped = false, _prevented = false, _focusPreserved = false, _keyboardTapMatched = false;
  Offset Function(Offset)? _toLocalDelta;
  double? _dragStartDistance;

  /// 当前阶段是否已停止传播。
  bool get propagationStopped => _stopped;

  /// 当前阶段是否已拒绝默认动作。
  bool get defaultPrevented => _prevented;

  /// 停止向外层节点传播；在按下阶段调用时，外层不再参与本次点击或拖拽。
  void stopPropagation() => _stopped = true;

  /// 拒绝当前阶段的组件默认动作。
  void preventDefault() => _prevented = true;

  /// 指针按下时保留现有焦点。
  void preserveFocus() => _focusPreserved = true;

  /// 消费同方向的位移，最多消耗当前余量，外层收到剩余部分。
  void consumeDelta(Offset requested) {
    final consumed = Offset(_consumed(remainingDelta.dx, requested.dx), _consumed(remainingDelta.dy, requested.dy));
    if (consumed == Offset.zero) return;
    remainingDelta -= consumed;
    remainingLocalDelta = _toLocalDelta?.call(remainingDelta) ?? remainingDelta;
  }

  static double _consumed(double remaining, double requested) =>
      requested.sign == remaining.sign ? requested.clamp(-remaining.abs(), remaining.abs()) : 0;

  /// 消费指定轴向的位移。
  void consumePrimaryDelta(Axis axis, double delta) =>
      consumeDelta(axis == .horizontal ? Offset(delta, 0) : Offset(0, delta));

  /// 消费全部剩余位移。
  void consumeAllDelta() => remainingDelta = remainingLocalDelta = Offset.zero;

  /// 读取指定轴向的剩余位移。
  double remainingPrimaryDelta(Axis axis) => axis == .horizontal ? remainingDelta.dx : remainingDelta.dy;
}

/// 供包内宿主读取焦点保留、键盘按压和局部位移换算。
extension EventDetailsAccess on ElEventDetails {
  bool get focusPreserved => _focusPreserved;
  bool get keyboardTapMatched => _keyboardTapMatched;
  set keyboardTapMatched(bool value) => _keyboardTapMatched = value;
  void resolveLocalDelta(Offset Function(Offset) resolver) => _toLocalDelta = resolver;

  /// 读取组件为本次拖拽指定的设备容差，不覆盖显式事件配置。
  double? get dragStartDistance => _dragStartDistance;

  /// 组件在拖拽按下阶段按输入设备确定本次起拖容差。
  void setDragStartDistance(double distance) {
    assert(phase == ElEventPhase.dragDown && distance.isFinite && distance >= 0);
    _dragStartDistance = distance;
  }
}
