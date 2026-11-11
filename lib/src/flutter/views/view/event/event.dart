import 'package:flutter/foundation.dart' show internal, setEquals;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';

import '../../../../../dart.dart';
import 'details.dart';
import 'shape.dart';

export 'details.dart' show ElEventPhase, ElEventDetails, ElEventCancelReason, ElFocusReason;

part 'event.g.dart';

/// 事件回调签名。
typedef ElEventHandler = void Function(ElEventDetails event);

/// ElView 声明的事件回调，等值比较使用回调空性。
@ElModelGenerator.copy(generateProps: false)
class const ElEvent({
  /// 双击、三击中相邻两次点击的最大间隔。
  final Duration doubleTapInterval = const Duration(milliseconds: 300),

  /// 声明连击时，单击等连击窗口结束才派发，避免双击同时触发单击。
  final bool deferTap = false,

  /// 长按识别等待时间。
  final Duration longPressDelay = const Duration(milliseconds: 500),

  /// 点击取消距离；null 时主键移出节点取消、移回恢复，与桌面按钮一致，侧键按 10 取消。
  final double? tapCancelDistance,

  /// 触摸按压反馈的延迟，滚动列表中可避免划过时闪烁。
  final Duration delayTouchDown = Duration.zero,

  /// 按压反馈的最短保持时间，快速轻点也能看到反馈。
  final Duration delayTouchUp = const Duration(milliseconds: 100),

  /// 同一按键重复事件的最小间隔，零表示不限流。
  final Duration keyRepeatInterval = const Duration(milliseconds: 100),

  /// 起拖距离，null 使用设备默认容差。
  final double? dragStartDistance,

  /// 允许拖拽和缩放的设备，null 表示全部设备。
  final Set<PointerDeviceKind>? dragDevices,

  /// 事件宿主的命中行为，默认覆盖布局盒。
  final HitTestBehavior behavior = HitTestBehavior.opaque,

  /// 基础光标；null 表示未声明，ElView 生效的样式光标优先。
  final MouseCursor? cursor,

  /// 是否禁用事件宿主的交互。
  final bool disabled = false,

  /// 指针进入回调。
  final ElEventHandler? onPointerEnter,

  /// 指针悬停回调。
  final ElEventHandler? onPointerHover,

  /// 指针离开回调。
  final ElEventHandler? onPointerExit,

  /// 指针按下回调。
  final ElEventHandler? onPointerDown,

  /// 指针移动回调。
  final ElEventHandler? onPointerMove,

  /// 指针抬起回调。
  final ElEventHandler? onPointerUp,

  /// 指针取消回调。
  final ElEventHandler? onPointerCancel,

  /// 触控板平移缩放开始回调。
  final ElEventHandler? onPointerPanZoomStart,

  /// 触控板平移缩放更新回调。
  final ElEventHandler? onPointerPanZoomUpdate,

  /// 触控板平移缩放结束回调。
  final ElEventHandler? onPointerPanZoomEnd,

  /// 鼠标滚轮或其他指针信号回调。
  final ElEventHandler? onPointerSignal,

  /// 主键点击候选或主焦点的激活键按下回调。
  final ElEventHandler? onTapDown,

  /// Flutter 确认主键点击或配对激活键释放时的回调。
  final ElEventHandler? onTapUp,

  /// 点击回调。
  final ElEventHandler? onTap,

  /// 连击计数达到二时回调。
  final ElEventHandler? onDoubleTap,

  /// 连击第二次按下时回调。
  final ElEventHandler? onDoubleTapDown,

  /// 连击计数达到三时回调。
  final ElEventHandler? onTripleTap,

  /// 连击第三次按下时回调。
  final ElEventHandler? onTripleTapDown,

  /// 第二按钮按下回调，通常对应鼠标右键。
  final ElEventHandler? onSecondaryTapDown,

  /// 第二按钮抬起回调。
  final ElEventHandler? onSecondaryTapUp,

  /// 第二按钮点击回调。
  final ElEventHandler? onSecondaryTap,

  /// 第三按钮按下回调，通常对应鼠标中键。
  final ElEventHandler? onTertiaryTapDown,

  /// 第三按钮抬起回调。
  final ElEventHandler? onTertiaryTapUp,

  /// 第三按钮点击回调。
  final ElEventHandler? onTertiaryTap,

  /// 前进按钮按下回调。
  final ElEventHandler? onForwardTapDown,

  /// 前进按钮抬起回调。
  final ElEventHandler? onForwardTapUp,

  /// 前进按钮点击回调。
  final ElEventHandler? onForwardTap,

  /// 后退按钮按下回调。
  final ElEventHandler? onBackTapDown,

  /// 后退按钮抬起回调。
  final ElEventHandler? onBackTapUp,

  /// 后退按钮点击回调。
  final ElEventHandler? onBackTap,

  /// Flutter 确认长按后回调。
  final ElEventHandler? onLongPress,

  /// 主键点击候选或激活键取消时的回调。
  final ElEventHandler? onTapCancel,

  /// 拖拽候选按下时回调，停止传播后外层不再参与本次拖拽。
  final ElEventHandler? onDragDown,

  /// 自由拖拽开始回调。
  final ElEventHandler? onDragStart,

  /// 自由拖拽更新回调。
  final ElEventHandler? onDragUpdate,

  /// 自由拖拽结束回调。
  final ElEventHandler? onDragEnd,

  /// 已开始的自由拖拽取消时回调。
  final ElEventHandler? onDragCancel,

  /// 垂直拖拽开始回调。
  final ElEventHandler? onVerticalDragStart,

  /// 垂直拖拽更新回调。
  final ElEventHandler? onVerticalDragUpdate,

  /// 垂直拖拽结束回调。
  final ElEventHandler? onVerticalDragEnd,

  /// 垂直拖拽取消回调。
  final ElEventHandler? onVerticalDragCancel,

  /// 水平拖拽开始回调（对应官方 `onHorizontalDragStart`）。
  final ElEventHandler? onHorizontalDragStart,

  /// 水平拖拽更新回调。
  final ElEventHandler? onHorizontalDragUpdate,

  /// 水平拖拽结束回调。
  final ElEventHandler? onHorizontalDragEnd,

  /// 水平拖拽取消回调。
  final ElEventHandler? onHorizontalDragCancel,

  /// 缩放开始回调；未声明拖拽时，单指平移也按缩放派发。
  final ElEventHandler? onScaleStart,

  /// 缩放更新回调。
  final ElEventHandler? onScaleUpdate,

  /// 缩放结束回调，增减触点会结束当前段并开始新段。
  final ElEventHandler? onScaleEnd,

  /// 缩放取消回调。
  final ElEventHandler? onScaleCancel,

  /// 旋转更新回调。
  final ElEventHandler? onRotationUpdate,

  /// 键盘按下回调。
  final ElEventHandler? onKeyDown,

  /// 键盘重复按下回调。
  final ElEventHandler? onKeyRepeat,

  /// 键盘抬起回调。
  final ElEventHandler? onKeyUp,

  /// 获得焦点回调。
  final ElEventHandler? onFocus,

  /// 失去焦点回调。
  final ElEventHandler? onBlur,
}) {
  this
    : assert(
        (onDragStart == null && onDragUpdate == null && onDragEnd == null && onDragCancel == null) ||
            (onVerticalDragStart == null &&
                onVerticalDragUpdate == null &&
                onVerticalDragEnd == null &&
                onVerticalDragCancel == null &&
                onHorizontalDragStart == null &&
                onHorizontalDragUpdate == null &&
                onHorizontalDragEnd == null &&
                onHorizontalDragCancel == null),
        '自由拖拽（onDrag*）与轴向拖拽（onVerticalDrag* / onHorizontalDrag*）互斥，'
        '不能同时声明——与官方 GestureDetector 的 pan 与 directional drag 约束一致。',
      );

  /// 是否包含点击语义相关回调。
  bool get hasTapLikeCallback =>
      onTap != null ||
      onTapDown != null ||
      onTapUp != null ||
      onDoubleTap != null ||
      onDoubleTapDown != null ||
      onTripleTap != null ||
      onTripleTapDown != null ||
      onLongPress != null;

  /// 是否包含键盘回调。
  bool get hasKeyboardCallback => onKeyDown != null || onKeyRepeat != null || onKeyUp != null;

  /// 是否声明了业务回调。
  bool get hasAnyCallback => shape.isNotEmpty;

  /// 是否声明了拖拽回调。
  bool get hasDragCallback => shape.drag;

  /// 是否声明了缩放回调。
  bool get hasScaleCallback =>
      onScaleStart != null ||
      onScaleUpdate != null ||
      onScaleEnd != null ||
      onScaleCancel != null ||
      onRotationUpdate != null;

  static final _shapeCache = Expando<EventShape>('ElEvent shape');

  /// 已声明回调的位图；普通不可变声明弱缓存复用，子类保留实时回调查询。
  @internal
  EventShape get shape =>
      runtimeType == ElEvent ? (_shapeCache[this] ??= EventShape.compile(handlerFor)) : EventShape.compile(handlerFor);

  /// 查找当前阶段声明的回调，[axis] 选择拖拽阶段的轴向组。
  @internal
  ElEventHandler? handlerFor(ElEventPhase phase, [Axis? axis]) => switch (phase) {
    .pointerEnter => onPointerEnter,
    .pointerHover => onPointerHover,
    .pointerExit => onPointerExit,
    .pointerDown => onPointerDown,
    .pointerMove => onPointerMove,
    .pointerUp => onPointerUp,
    .pointerCancel => onPointerCancel,
    .pointerPanZoomStart => onPointerPanZoomStart,
    .pointerPanZoomUpdate => onPointerPanZoomUpdate,
    .pointerPanZoomEnd => onPointerPanZoomEnd,
    .pointerSignal => onPointerSignal,
    .tapDown => onTapDown,
    .tapUp => onTapUp,
    .tap => onTap,
    .doubleTap => onDoubleTap,
    .doubleTapDown => onDoubleTapDown,
    .tripleTap => onTripleTap,
    .tripleTapDown => onTripleTapDown,
    .secondaryTapDown => onSecondaryTapDown,
    .secondaryTapUp => onSecondaryTapUp,
    .secondaryTap => onSecondaryTap,
    .tertiaryTapDown => onTertiaryTapDown,
    .tertiaryTapUp => onTertiaryTapUp,
    .tertiaryTap => onTertiaryTap,
    .forwardTapDown => onForwardTapDown,
    .forwardTapUp => onForwardTapUp,
    .forwardTap => onForwardTap,
    .backTapDown => onBackTapDown,
    .backTapUp => onBackTapUp,
    .backTap => onBackTap,
    .longPress => onLongPress,
    .tapCancel => onTapCancel,
    .dragDown => onDragDown,
    .dragStart => switch (axis) {
      null => onDragStart,
      .horizontal => onHorizontalDragStart,
      .vertical => onVerticalDragStart,
    },
    .dragUpdate => switch (axis) {
      null => onDragUpdate,
      .horizontal => onHorizontalDragUpdate,
      .vertical => onVerticalDragUpdate,
    },
    .dragEnd => switch (axis) {
      null => onDragEnd,
      .horizontal => onHorizontalDragEnd,
      .vertical => onVerticalDragEnd,
    },
    .dragCancel => switch (axis) {
      null => onDragCancel,
      .horizontal => onHorizontalDragCancel,
      .vertical => onVerticalDragCancel,
    },
    .scaleStart => onScaleStart,
    .scaleUpdate => onScaleUpdate,
    .scaleEnd => onScaleEnd,
    .scaleCancel => onScaleCancel,
    .rotationUpdate => onRotationUpdate,
    .keyDown => onKeyDown,
    .keyRepeat => onKeyRepeat,
    .keyUp => onKeyUp,
    .focus => onFocus,
    .blur => onBlur,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    // 只换闭包不改变相等性，回调只比较声明了哪些。
    return other is ElEvent &&
        behavior == other.behavior &&
        cursor == other.cursor &&
        disabled == other.disabled &&
        doubleTapInterval == other.doubleTapInterval &&
        deferTap == other.deferTap &&
        longPressDelay == other.longPressDelay &&
        tapCancelDistance == other.tapCancelDistance &&
        delayTouchDown == other.delayTouchDown &&
        delayTouchUp == other.delayTouchUp &&
        keyRepeatInterval == other.keyRepeatInterval &&
        dragStartDistance == other.dragStartDistance &&
        setEquals(dragDevices, other.dragDevices) &&
        shape == other.shape;
  }

  @override
  int get hashCode => Object.hash(
    behavior,
    cursor,
    disabled,
    doubleTapInterval,
    deferTap,
    longPressDelay,
    tapCancelDistance,
    delayTouchDown,
    delayTouchUp,
    keyRepeatInterval,
    dragStartDistance,
    Object.hashAllUnordered(dragDevices ?? const {}),
    shape,
  );
}
