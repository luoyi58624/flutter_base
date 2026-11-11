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

  /// Flutter 识别器的主轴释放速度。
  final double? primaryVelocity,

  /// 当前触点数量。
  var int pointerCount = 0,

  /// 指针按键位。
  final int buttons = 0,

  /// Flutter 连击计数。
  final int tapCount = 0,

  /// 本段缩放比例。
  final double scale = 1,

  /// 本段旋转角度，单位为弧度。
  final double rotation = 0,

  /// 缩放比例的对数速度。
  final double logScaleVelocity = 0,

  /// 焦点变化来源。
  final ElFocusReason? focusReason,

  ElEventCancelReason? cancelReason,
}) {
  /// 尚未消费的全局位移。
  Offset remainingDelta = remainingDelta ?? delta;

  /// 尚未消费的局部位移。
  Offset remainingLocalDelta = remainingLocalDelta ?? localDelta;

  /// 当前阶段的取消原因。
  final ElEventCancelReason? cancelReason = switch (phase) {
    .pointerCancel => cancelReason ?? .pointerCanceled,
    .tapCancel || .dragCancel || .scaleCancel => cancelReason ?? .external,
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

  ElEventDetails? _control;
  bool _stopped = false, _prevented = false, _focusPreserved = false, _keyboardTapMatched = false;
  Offset Function(Offset)? _toLocalDelta;

  /// 当前阶段是否已停止传播。
  bool get propagationStopped => (_control ?? this)._stopped;

  /// 当前阶段是否已拒绝默认动作。
  bool get defaultPrevented => (_control ?? this)._prevented;

  /// 停止当前阶段的后续 ElEvent 派发。
  void stopPropagation() => (_control ?? this)._stopped = true;

  /// 拒绝当前阶段的组件默认动作。
  void preventDefault() => (_control ?? this)._prevented = true;

  /// 指针按下时保留现有焦点。
  void preserveFocus() => (_control ?? this)._focusPreserved = true;

  /// 旧组件的传播截断入口，两个旧参数不再影响手势归属。
  void eagerGesture({bool cancelSelfTap = false, bool allowScaleUpgrade = false}) => stopPropagation();

  /// 旧版组件的拖拽代理状态。
  bool get dragPipelineActive => false;

  /// 旧版组件的边界交接状态。
  bool get dragBoundaryHandoff => false;

  /// 旧版组件的祖先余量消费状态。
  bool get hasAncestorDragConsumer => false;

  /// 消费同方向的位移，最多消耗当前余量。
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

/// 供包内宿主转接传播、坐标和键盘按压状态。
extension EventDetailsAccess on ElEventDetails {
  bool get focusPreserved => (_control ?? this)._focusPreserved;
  bool get keyboardTapMatched => _keyboardTapMatched;
  set keyboardTapMatched(bool value) => _keyboardTapMatched = value;
  void shareControl(ElEventDetails source) => _control = source._control ?? source;
  void resolveLocalDelta(Offset Function(Offset) resolver) => _toLocalDelta = resolver;
}
