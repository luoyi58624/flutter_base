import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show internal, setEquals;
import 'package:flutter/gestures.dart' show PointerDeviceKind, kMaxFlingVelocity, kMinFlingVelocity;
import 'package:flutter/widgets.dart';

import '../../../../../dart.dart';
import 'details.dart';

export 'details.dart' show ElEventPhase, ElEventDetails, ElEventCancelReason, ElFocusReason;

part 'event.g.dart';

/// 事件回调签名。
typedef ElEventHandler = void Function(ElEventDetails event);

/// 当前宿主的点击、反馈和拖拽配置。
@ElModelGenerator.copy()
final class ElEventConfig with Equatable {
  /// 创建事件配置。传 `null`（缺省）的字段回落 getter 内部默认/自适应值。
  const ElEventConfig({
    this._doubleTapInterval,
    this._tripleTapInterval,
    this._longPressDelay,
    this.longPressCancelDistance,
    this._tapCancelDistance,
    this._tapCancelByDistance,
    this._delayTouchDown,
    this._delayTouchUp,
    this._keyRepeatInterval,
    this._deferTap,
    this.dragStartDistance,
    this.dragDevices,
    this._dragHorizontalAngle,
    this.dragMinFlingDistance,
    this._dragMinFlingVelocity,
    this._dragMaxFlingVelocity,
  }) : assert(longPressCancelDistance == null || longPressCancelDistance >= 0, 'longPressCancelDistance 必须大于等于 0。'),
       assert(_delayTouchDown == null || _delayTouchDown >= Duration.zero, 'delayTouchDown 必须大于等于 0。'),
       assert(_delayTouchUp == null || _delayTouchUp >= Duration.zero, 'delayTouchUp 必须大于等于 0。'),
       assert(_keyRepeatInterval == null || _keyRepeatInterval >= Duration.zero, 'keyRepeatInterval 必须大于等于 0。'),
       assert(
         _dragHorizontalAngle == null || (_dragHorizontalAngle > 0 && _dragHorizontalAngle < math.pi / 2),
         'dragHorizontalAngle 是水平捕获锥的半角（弧度），必须落在 (0, π/2) 开区间。',
       );

  final Duration? _doubleTapInterval;

  /// 旧版双击间隔配置，连击采用 Flutter 的识别窗口。
  Duration get doubleTapInterval => _doubleTapInterval ?? const Duration(milliseconds: 300);

  final Duration? _tripleTapInterval;

  /// 旧版三击间隔配置，连击采用 Flutter 的识别窗口。
  Duration get tripleTapInterval => _tripleTapInterval ?? const Duration(milliseconds: 300);

  final Duration? _longPressDelay;

  /// 长按识别等待时间。默认 500ms。
  Duration get longPressDelay => _longPressDelay ?? const Duration(milliseconds: 500);

  /// 旧版长按移动容差，Flutter 按设备计算长按容差。
  final double? longPressCancelDistance;

  final double? _tapCancelDistance;

  /// 普通 Tap 的自定义移动容差。
  double get tapCancelDistance => _tapCancelDistance ?? 10.0;

  final bool? _tapCancelByDistance;

  /// 普通 Tap 是否覆盖 Flutter 默认移动容差。
  bool get tapCancelByDistance => _tapCancelByDistance ?? false;

  final Duration? _delayTouchDown;

  /// 旧版触摸反馈延迟配置，ElView 随输入直接更新样式。
  Duration get delayTouchDown => _delayTouchDown ?? Duration.zero;

  final Duration? _delayTouchUp;

  /// 旧版触摸反馈保留时间，ElView 随释放和取消直接更新样式。
  Duration get delayTouchUp => _delayTouchUp ?? const Duration(milliseconds: 100);

  final Duration? _keyRepeatInterval;

  /// 旧版键盘重复间隔配置，ElView 按 Flutter 的节奏转发。
  Duration get keyRepeatInterval => _keyRepeatInterval ?? const Duration(milliseconds: 100);

  final bool? _deferTap;

  /// 旧版延期点击配置，Flutter 连击按每次成功点击派发。
  bool get deferTap => _deferTap ?? false;

  /// Flutter 拖拽的触摸起手容差。
  final double? dragStartDistance;

  /// 允许参与拖拽和缩放的设备，null 表示允许所有设备。
  final Set<PointerDeviceKind>? dragDevices;

  final double? _dragHorizontalAngle;

  /// 自由拖拽的方向分类使用的水平半角。
  double get dragHorizontalAngle => _dragHorizontalAngle ?? math.pi / 4;

  /// Flutter 判定甩动的最小距离。
  final double? dragMinFlingDistance;

  final double? _dragMinFlingVelocity;

  /// 拖拽结束速度的最小阈值。默认 [kMinFlingVelocity]（50）。
  double get dragMinFlingVelocity => _dragMinFlingVelocity ?? kMinFlingVelocity;

  final double? _dragMaxFlingVelocity;

  /// 拖拽结束速度的最大幅度。默认 [kMaxFlingVelocity]（8000）。
  double get dragMaxFlingVelocity => _dragMaxFlingVelocity ?? kMaxFlingVelocity;

  /// 以 base 为底叠加本配置，未设置字段沿用 base。
  ElEventConfig withFallback(ElEventConfig base) => base.merge(this);

  @override
  List<Object?> get props => _props;
}

/// 旧版预览等组件使用的拖拽代理声明。
///
/// Flutter 拖拽的更新直接送给获胜宿主。跨组件的位移分配需要由组件接入。
@ElModelGenerator.copy(generateProps: false)
final class ElDragProxy {
  /// 创建拖拽代理配置。
  const ElDragProxy({this.axis, this.onDragPreUpdate, this.onDragOverflow, this.boundaryHandoff = const {}});

  /// 代理声明可接收的轴向，null 表示任意轴。
  final Axis? axis;

  /// 主消费者应用位移前的回调。
  final ElEventHandler? onDragPreUpdate;

  /// 主消费者用完位移后的余量回调。
  final ElEventHandler? onDragOverflow;

  /// 声明代理需要接管滚动边界余量的方向。
  final Set<AxisDirection> boundaryHandoff;

  /// 是否包含任意 proxy handler。
  bool get hasAnyHandler => onDragPreUpdate != null || onDragOverflow != null;

  int get _handlerShapeMask => (onDragPreUpdate != null ? 1 : 0) | (onDragOverflow != null ? 2 : 0);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ElDragProxy &&
        other.axis == axis &&
        other._handlerShapeMask == _handlerShapeMask &&
        setEquals(other.boundaryHandoff, boundaryHandoff);
  }

  @override
  int get hashCode => Object.hash(axis, _handlerShapeMask, Object.hashAllUnordered(boundaryHandoff));

  /// 两份代理的 handler 是否为同一批闭包实例（shape 相等之上的强判定）。
  bool identicalHandlers(ElDragProxy other) {
    return identical(other.onDragPreUpdate, onDragPreUpdate) && identical(other.onDragOverflow, onDragOverflow);
  }
}

/// ElView 声明的事件回调，等值比较使用回调空性。
@ElModelGenerator.copy(generateProps: false)
class const ElEvent({
  /// 当前节点的手势配置。
  final ElEventConfig? config,

  /// 为现有组件保留的拖拽代理声明。
  final ElDragProxy? dragProxy,

  /// 事件宿主的命中行为，默认覆盖布局盒。
  final HitTestBehavior behavior = HitTestBehavior.opaque,

  /// 基础光标；null 表示未声明，ElView 生效的样式光标优先。
  final MouseCursor? cursor,

  /// 是否禁用事件宿主的交互。
  final bool disabled = false,

  /// 为现有缩放组件保留的旋转起手配置。
  @internal final bool rotationStartEnabled = false,

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

  /// 拖拽候选按下时回调，可截断外层拖拽报名。
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

  /// Flutter 缩放开始回调，包含识别器接受的单指平移。
  final ElEventHandler? onScaleStart,

  /// 缩放更新回调。
  final ElEventHandler? onScaleUpdate,

  /// Flutter 结清当前缩放段时回调，增减触点也会结清当前段。
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
  bool get hasAnyCallback => _handlers.any((handler) => handler != null);

  static final _handlerCache = Expando<List<ElEventHandler?>>('ElEvent handlers');

  // 按 ElEventPhase 的顺序排列，轴向拖拽组接在末尾。
  List<ElEventHandler?> get _handlers => _handlerCache[this] ??= [
    onPointerEnter,
    onPointerHover,
    onPointerExit,
    onPointerDown,
    onPointerMove,
    onPointerUp,
    onPointerCancel,
    onPointerPanZoomStart,
    onPointerPanZoomUpdate,
    onPointerPanZoomEnd,
    onPointerSignal,
    onTapDown,
    onTapUp,
    onTap,
    onDoubleTap,
    onDoubleTapDown,
    onTripleTap,
    onTripleTapDown,
    onSecondaryTapDown,
    onSecondaryTapUp,
    onSecondaryTap,
    onTertiaryTapDown,
    onTertiaryTapUp,
    onTertiaryTap,
    onForwardTapDown,
    onForwardTapUp,
    onForwardTap,
    onBackTapDown,
    onBackTapUp,
    onBackTap,
    onLongPress,
    onTapCancel,
    onDragDown,
    onDragStart,
    onDragUpdate,
    onDragEnd,
    onDragCancel,
    onScaleStart,
    onScaleUpdate,
    onScaleEnd,
    onScaleCancel,
    onRotationUpdate,
    onKeyDown,
    onKeyRepeat,
    onKeyUp,
    onFocus,
    onBlur,
    onHorizontalDragStart,
    onHorizontalDragUpdate,
    onHorizontalDragEnd,
    onHorizontalDragCancel,
    onVerticalDragStart,
    onVerticalDragUpdate,
    onVerticalDragEnd,
    onVerticalDragCancel,
  ];

  /// 查找当前阶段声明的回调。
  @internal
  ElEventHandler? handlerFor(ElEventPhase phase, [Axis? axis]) {
    if (axis != null && phase.index >= ElEventPhase.dragStart.index && phase.index <= ElEventPhase.dragCancel.index) {
      final start = ElEventPhase.values.length + (axis == .horizontal ? 0 : 4);
      return _handlers[start + phase.index - ElEventPhase.dragStart.index];
    }
    return _handlers[phase.index];
  }

  /// 识别配置和回调结构相同的重建可沿用已报名的识别器。
  @internal
  bool hasSameGestureShape(ElEvent other) {
    if (identical(this, other)) return true;
    if (config != other.config) return false;
    for (var i = 0; i < _handlers.length; i++) {
      if ((_handlers[i] == null) != (other._handlers[i] == null)) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is ElEvent &&
      behavior == other.behavior &&
      cursor == other.cursor &&
      disabled == other.disabled &&
      dragProxy == other.dragProxy &&
      rotationStartEnabled == other.rotationStartEnabled &&
      hasSameGestureShape(other);

  @override
  int get hashCode => Object.hash(
    behavior,
    cursor,
    disabled,
    config,
    dragProxy,
    rotationStartEnabled,
    Object.hashAll(_handlers.map((handler) => handler != null)),
  );
}
