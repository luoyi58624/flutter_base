import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/painting.dart' show Axis;
import 'package:flutter/rendering.dart' show HitTestBehavior, MouseCursor;

import 'callback.dart';
import 'config.dart';

export 'config.dart';

bool _sameTapConfiguration(ElEventConfig? left, ElEventConfig? right) =>
    left?.hasSameTapConfiguration(right) ??
    right?.hasSameTapConfiguration(null) ??
    true;

/// 可通过 [ElEvent.copyWith] 显式清除的可空字段。
enum ElEventClearField {
  /// 清除局部识别配置。
  config,

  /// 清除拖拽代理配置。
  dragProxy,

  /// 清除onPointerEnter 回调。
  onPointerEnter,

  /// 清除onPointerHover 回调。
  onPointerHover,

  /// 清除onPointerExit 回调。
  onPointerExit,

  /// 清除onPointerDown 回调。
  onPointerDown,

  /// 清除onPointerMove 回调。
  onPointerMove,

  /// 清除onPointerUp 回调。
  onPointerUp,

  /// 清除onPointerCancel 回调。
  onPointerCancel,

  /// 清除onPointerPanZoomStart 回调。
  onPointerPanZoomStart,

  /// 清除onPointerPanZoomUpdate 回调。
  onPointerPanZoomUpdate,

  /// 清除onPointerPanZoomEnd 回调。
  onPointerPanZoomEnd,

  /// 清除onPointerSignal 回调。
  onPointerSignal,

  /// 清除onTapDown 回调。
  onTapDown,

  /// 清除onTapUp 回调。
  onTapUp,

  /// 清除onTap 回调。
  onTap,

  /// 清除onDoubleTap 回调。
  onDoubleTap,

  /// 清除onDoubleTapDown 回调。
  onDoubleTapDown,

  /// 清除onTripleTap 回调。
  onTripleTap,

  /// 清除onTripleTapDown 回调。
  onTripleTapDown,

  /// 清除onSecondaryTapDown 回调。
  onSecondaryTapDown,

  /// 清除onSecondaryTapUp 回调。
  onSecondaryTapUp,

  /// 清除onSecondaryTap 回调。
  onSecondaryTap,

  /// 清除onTertiaryTapDown 回调。
  onTertiaryTapDown,

  /// 清除onTertiaryTapUp 回调。
  onTertiaryTapUp,

  /// 清除onTertiaryTap 回调。
  onTertiaryTap,

  /// 清除onForwardTapDown 回调。
  onForwardTapDown,

  /// 清除onForwardTapUp 回调。
  onForwardTapUp,

  /// 清除onForwardTap 回调。
  onForwardTap,

  /// 清除onBackTapDown 回调。
  onBackTapDown,

  /// 清除onBackTapUp 回调。
  onBackTapUp,

  /// 清除onBackTap 回调。
  onBackTap,

  /// 清除onLongPress 回调。
  onLongPress,

  /// 清除onTapCancel 回调。
  onTapCancel,

  /// 清除onDragDown 回调。
  onDragDown,

  /// 清除onDragStart 回调。
  onDragStart,

  /// 清除onDragUpdate 回调。
  onDragUpdate,

  /// 清除onDragEnd 回调。
  onDragEnd,

  /// 清除onDragCancel 回调。
  onDragCancel,

  /// 清除onVerticalDragStart 回调。
  onVerticalDragStart,

  /// 清除onVerticalDragUpdate 回调。
  onVerticalDragUpdate,

  /// 清除onVerticalDragEnd 回调。
  onVerticalDragEnd,

  /// 清除onVerticalDragCancel 回调。
  onVerticalDragCancel,

  /// 清除onHorizontalDragStart 回调。
  onHorizontalDragStart,

  /// 清除onHorizontalDragUpdate 回调。
  onHorizontalDragUpdate,

  /// 清除onHorizontalDragEnd 回调。
  onHorizontalDragEnd,

  /// 清除onHorizontalDragCancel 回调。
  onHorizontalDragCancel,

  /// 清除onScaleStart 回调。
  onScaleStart,

  /// 清除onScaleUpdate 回调。
  onScaleUpdate,

  /// 清除onScaleEnd 回调。
  onScaleEnd,

  /// 清除onScaleCancel 回调。
  onScaleCancel,

  /// 清除onRotationUpdate 回调。
  onRotationUpdate,

  /// 清除光标配置。
  cursor,
}

/// 拖拽代理配置，用于沿祖先链分配后代拖拽产生的位移。
///
/// [onDragPreUpdate] 在拖拽处理器消费位移前由外向内执行，
/// [onDragOverflow] 在其后由内向外执行；各阶段通过
/// [ElEventCallback.remainingDelta] 与消费方法共享剩余位移。
/// 代理回调中的停止冒泡与独占请求不影响管线。
///
/// 等值比较使用 [axis] 和回调的空性，重建时替换闭包可保留手势状态。
final class ElDragProxy {
  /// 创建拖拽代理配置。
  const ElDragProxy({this.axis, this.onDragPreUpdate, this.onDragOverflow});

  /// 可代理的轴向；null 兼容任意轴向，自由拖拽仅匹配 null。
  final Axis? axis;

  /// 先扣阶段回调（roster 外→内）。
  final ElEventHandler? onDragPreUpdate;

  /// 溢出阶段回调（roster 内→外）。
  final ElEventHandler? onDragOverflow;

  /// 是否包含任意代理回调。
  bool get hasAnyHandler => onDragPreUpdate != null || onDragOverflow != null;

  int get _handlerShapeMask =>
      (onDragPreUpdate != null ? 1 : 0) | (onDragOverflow != null ? 2 : 0);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ElDragProxy &&
        other.axis == axis &&
        other._handlerShapeMask == _handlerShapeMask;
  }

  @override
  int get hashCode => Object.hash(axis, _handlerShapeMask);

  /// 两份代理的 handler 是否为同一批闭包实例（shape 相等之上的强判定）。
  bool identicalHandlers(ElDragProxy other) {
    return identical(other.onDragPreUpdate, onDragPreUpdate) &&
        identical(other.onDragOverflow, onDragOverflow);
  }
}

/// 独立事件宿主的回调声明与手势配置。
///
/// 等值比较使用配置值和回调的空性，不比较闭包身份；相同声明结构下替换
/// 回调可保留正在进行的连击、长按和拖拽状态。
class ElEvent {
  /// 创建事件配置。
  const ElEvent({
    this.config,
    this.dragProxy,
    this.behavior = HitTestBehavior.opaque,
    this.cursor,
    this.disabled = false,
    this.rotationStartEnabled = false,
    this.onPointerEnter,
    this.onPointerHover,
    this.onPointerExit,
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onPointerCancel,
    this.onPointerPanZoomStart,
    this.onPointerPanZoomUpdate,
    this.onPointerPanZoomEnd,
    this.onPointerSignal,
    this.onTapDown,
    this.onTapUp,
    this.onTap,
    this.onDoubleTap,
    this.onDoubleTapDown,
    this.onTripleTap,
    this.onTripleTapDown,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.onSecondaryTap,
    this.onTertiaryTapDown,
    this.onTertiaryTapUp,
    this.onTertiaryTap,
    this.onForwardTapDown,
    this.onForwardTapUp,
    this.onForwardTap,
    this.onBackTapDown,
    this.onBackTapUp,
    this.onBackTap,
    this.onLongPress,
    this.onTapCancel,
    this.onDragDown,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.onScaleCancel,
    this.onRotationUpdate,
  }) : assert(
         (onDragStart == null &&
                 onDragUpdate == null &&
                 onDragEnd == null &&
                 onDragCancel == null) ||
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

  /// 事件识别参数配置（点击家族 + 拖拽）。
  ///
  /// `null` 表示不声明局部覆盖，所有字段回落 [ElEventConfig] 的内部默认值。
  /// 非空时按**字段级**覆盖：只设置了的字段生效，未设置的字段同样回落内部
  /// 默认值。配置**只对声明它的那个节点生效**，不沿 render 树向子组件注入。
  /// 详见 [ElEventConfig]。
  final ElEventConfig? config;

  /// 拖拽分账代理。声明本节点参与后代拖拽序列的 pre/overflow 阶段管线。
  ///
  /// 详见 [ElDragProxy] 类文档。
  final ElDragProxy? dragProxy;

  /// 事件宿主的命中行为，默认覆盖布局盒。
  final HitTestBehavior behavior;

  /// 鼠标光标；null 表示不声明光标。
  final MouseCursor? cursor;

  /// 是否禁用事件宿主的交互。
  final bool disabled;

  /// 是否允许仅旋转的指针移动启动缩放旋转识别。
  @internal
  final bool rotationStartEnabled;

  /// 指针进入回调。
  final ElEventHandler? onPointerEnter;

  /// 指针悬停回调。
  final ElEventHandler? onPointerHover;

  /// 指针离开回调。
  final ElEventHandler? onPointerExit;

  /// 指针按下回调。
  final ElEventHandler? onPointerDown;

  /// 指针移动回调。
  final ElEventHandler? onPointerMove;

  /// 指针抬起回调。
  final ElEventHandler? onPointerUp;

  /// 指针取消回调。
  ///
  /// 平台 `PointerCancelEvent` 与 [ElEventCallback.eagerGesture] 淘汰当前节点时
  /// 都会触发；后者的 [ElEventCallback.originalEvent] 是合成
  /// `PointerCancelEvent`，原因见 [ElEventCallback.cancelReason]。
  final ElEventHandler? onPointerCancel;

  /// 触控板平移缩放开始回调。
  final ElEventHandler? onPointerPanZoomStart;

  /// 触控板平移缩放更新回调。
  final ElEventHandler? onPointerPanZoomUpdate;

  /// 触控板平移缩放结束回调。
  final ElEventHandler? onPointerPanZoomEnd;

  /// 鼠标滚轮或其他指针信号回调。
  final ElEventHandler? onPointerSignal;

  /// 主指针按下回调。
  final ElEventHandler? onTapDown;

  /// 主指针抬起回调。
  final ElEventHandler? onTapUp;

  /// 点击回调。
  final ElEventHandler? onTap;

  /// 双击回调；未声明三击家族时每两次点击独立结组，连续四击会触发两次。
  final ElEventHandler? onDoubleTap;

  /// 双击按下回调。第二次 PointerDown 与上次 tap 位置接近且在
  /// [ElEventConfig.doubleTapInterval] 内时立即触发。
  /// 未声明三击家族时连续按下第 2、4 次触发；声明三击后第 3 次归入
  /// 三击并结组，下一次双击从第 4 次重新计数、在第 5 次按下触发。
  final ElEventHandler? onDoubleTapDown;

  /// 三击回调。第三次 PointerUp 与第二次的间隔在 [ElEventConfig.tripleTapInterval] 内且
  /// 位置接近时触发。与 [onTap] / [onDoubleTap] 共存：第二次 PointerUp fire
  /// `onDoubleTap`，第三次 PointerUp fire `onTripleTap`，随后从下一次点击重新结组。
  final ElEventHandler? onTripleTap;

  /// 三击按下回调。第三次 PointerDown 与第二次 tap 位置接近且在
  /// [ElEventConfig.tripleTapInterval] 内时立即触发。
  final ElEventHandler? onTripleTapDown;

  /// 第二按钮按下回调，通常对应鼠标右键。
  final ElEventHandler? onSecondaryTapDown;

  /// 第二按钮抬起回调。
  final ElEventHandler? onSecondaryTapUp;

  /// 第二按钮点击回调。
  final ElEventHandler? onSecondaryTap;

  /// 第三按钮按下回调，通常对应鼠标中键。
  final ElEventHandler? onTertiaryTapDown;

  /// 第三按钮抬起回调。
  final ElEventHandler? onTertiaryTapUp;

  /// 第三按钮点击回调。
  final ElEventHandler? onTertiaryTap;

  /// 前进按钮按下回调。
  final ElEventHandler? onForwardTapDown;

  /// 前进按钮抬起回调。
  final ElEventHandler? onForwardTapUp;

  /// 前进按钮点击回调。
  final ElEventHandler? onForwardTap;

  /// 后退按钮按下回调。
  final ElEventHandler? onBackTapDown;

  /// 后退按钮抬起回调。
  final ElEventHandler? onBackTapUp;

  /// 后退按钮点击回调。
  final ElEventHandler? onBackTap;

  /// 长按成立回调。
  ///
  /// 回调链执行完成后，事件层默认认领当前 pointer 手势，并取消
  /// 本节点的后续 Tap 激活；普通使用无需再手动调用
  /// [ElEventCallback.eagerGesture]。如果长按成立后组件判定当前位置
  /// 不可处理，可在任意一层回调中调用 [ElEventCallback.preventDefault]
  /// 拒绝这项默认认领；此时 pointer 归属与 Tap 资格均保持不变。
  ///
  /// [ElEventCallback.stopPropagation] 只停止向祖先传播，不会取消默认认领。
  final ElEventHandler? onLongPress;

  /// Tap 候选取消回调；Tap 拒绝、手势让位与生命周期终止原因见
  /// [ElEventCallback.cancelReason]。
  final ElEventHandler? onTapCancel;

  /// 主指针成为拖拽候选时的按下回调，在轴向判定与拖拽接受之前触发。
  ///
  /// 此阶段调用 `stopPropagation()` 只截断祖先 Drag 家族，不影响 raw
  /// Pointer 与 Tap 家族；没有后续 [onDragStart] 时不要求终态配对。
  final ElEventHandler? onDragDown;

  /// 自由拖拽开始回调（任意方向，对应官方 `onPanStart`）。
  ///
  /// 与轴向拖拽组（[onVerticalDragStart] / [onHorizontalDragStart] 等）互斥，
  /// 不能同时声明。
  final ElEventHandler? onDragStart;

  /// 自由拖拽更新回调。
  final ElEventHandler? onDragUpdate;

  /// 自由拖拽结束回调。
  final ElEventHandler? onDragEnd;

  /// 自由拖拽取消回调。
  final ElEventHandler? onDragCancel;

  /// 垂直拖拽开始回调（对应官方 `onVerticalDragStart`）。
  ///
  /// 与 [onHorizontalDragStart] 组同时声明时，一次手势按起手方向竞争锁轴：
  /// 先越过自身 slop 的轴胜出，整个手势只派发胜出组的回调，
  /// [ElEventCallback.dragAxis] 携带胜出轴。
  final ElEventHandler? onVerticalDragStart;

  /// 垂直拖拽更新回调。
  final ElEventHandler? onVerticalDragUpdate;

  /// 垂直拖拽结束回调。
  final ElEventHandler? onVerticalDragEnd;

  /// 垂直拖拽取消回调。
  final ElEventHandler? onVerticalDragCancel;

  /// 水平拖拽开始回调（对应官方 `onHorizontalDragStart`）。
  final ElEventHandler? onHorizontalDragStart;

  /// 水平拖拽更新回调。
  final ElEventHandler? onHorizontalDragUpdate;

  /// 水平拖拽结束回调。
  final ElEventHandler? onHorizontalDragEnd;

  /// 水平拖拽取消回调。
  final ElEventHandler? onHorizontalDragCancel;

  /// 缩放开始回调。
  final ElEventHandler? onScaleStart;

  /// 缩放更新回调。
  final ElEventHandler? onScaleUpdate;

  /// 缩放结束回调。
  final ElEventHandler? onScaleEnd;

  /// 缩放取消回调。
  final ElEventHandler? onScaleCancel;

  /// 旋转更新回调。
  final ElEventHandler? onRotationUpdate;

  /// 复制配置并覆盖指定字段，通过 [clear] 显式清除可空字段。
  ///
  /// 可空参数省略或传 null 均保留原值，例如 `copyWith(onTap: null)`
  /// 不会清除回调；需将对应字段加入 [clear]。
  ElEvent copyWith({
    ElEventConfig? config,
    ElDragProxy? dragProxy,
    HitTestBehavior? behavior,
    MouseCursor? cursor,
    bool? disabled,
    bool? rotationStartEnabled,
    ElEventHandler? onPointerEnter,
    ElEventHandler? onPointerHover,
    ElEventHandler? onPointerExit,
    ElEventHandler? onPointerDown,
    ElEventHandler? onPointerMove,
    ElEventHandler? onPointerUp,
    ElEventHandler? onPointerCancel,
    ElEventHandler? onPointerPanZoomStart,
    ElEventHandler? onPointerPanZoomUpdate,
    ElEventHandler? onPointerPanZoomEnd,
    ElEventHandler? onPointerSignal,
    ElEventHandler? onTapDown,
    ElEventHandler? onTapUp,
    ElEventHandler? onTap,
    ElEventHandler? onDoubleTap,
    ElEventHandler? onDoubleTapDown,
    ElEventHandler? onTripleTap,
    ElEventHandler? onTripleTapDown,
    ElEventHandler? onSecondaryTapDown,
    ElEventHandler? onSecondaryTapUp,
    ElEventHandler? onSecondaryTap,
    ElEventHandler? onTertiaryTapDown,
    ElEventHandler? onTertiaryTapUp,
    ElEventHandler? onTertiaryTap,
    ElEventHandler? onForwardTapDown,
    ElEventHandler? onForwardTapUp,
    ElEventHandler? onForwardTap,
    ElEventHandler? onBackTapDown,
    ElEventHandler? onBackTapUp,
    ElEventHandler? onBackTap,
    ElEventHandler? onLongPress,
    ElEventHandler? onTapCancel,
    ElEventHandler? onDragDown,
    ElEventHandler? onDragStart,
    ElEventHandler? onDragUpdate,
    ElEventHandler? onDragEnd,
    ElEventHandler? onDragCancel,
    ElEventHandler? onVerticalDragStart,
    ElEventHandler? onVerticalDragUpdate,
    ElEventHandler? onVerticalDragEnd,
    ElEventHandler? onVerticalDragCancel,
    ElEventHandler? onHorizontalDragStart,
    ElEventHandler? onHorizontalDragUpdate,
    ElEventHandler? onHorizontalDragEnd,
    ElEventHandler? onHorizontalDragCancel,
    ElEventHandler? onScaleStart,
    ElEventHandler? onScaleUpdate,
    ElEventHandler? onScaleEnd,
    ElEventHandler? onScaleCancel,
    ElEventHandler? onRotationUpdate,
    Set<ElEventClearField> clear = const <ElEventClearField>{},
  }) {
    bool shouldClear(ElEventClearField field) => clear.contains(field);

    return ElEvent(
      config: shouldClear(ElEventClearField.config)
          ? null
          : config ?? this.config,
      dragProxy: shouldClear(ElEventClearField.dragProxy)
          ? null
          : dragProxy ?? this.dragProxy,
      behavior: behavior ?? this.behavior,
      cursor: shouldClear(ElEventClearField.cursor)
          ? null
          : cursor ?? this.cursor,
      disabled: disabled ?? this.disabled,
      rotationStartEnabled: rotationStartEnabled ?? this.rotationStartEnabled,
      onPointerEnter: shouldClear(ElEventClearField.onPointerEnter)
          ? null
          : onPointerEnter ?? this.onPointerEnter,
      onPointerHover: shouldClear(ElEventClearField.onPointerHover)
          ? null
          : onPointerHover ?? this.onPointerHover,
      onPointerExit: shouldClear(ElEventClearField.onPointerExit)
          ? null
          : onPointerExit ?? this.onPointerExit,
      onPointerDown: shouldClear(ElEventClearField.onPointerDown)
          ? null
          : onPointerDown ?? this.onPointerDown,
      onPointerMove: shouldClear(ElEventClearField.onPointerMove)
          ? null
          : onPointerMove ?? this.onPointerMove,
      onPointerUp: shouldClear(ElEventClearField.onPointerUp)
          ? null
          : onPointerUp ?? this.onPointerUp,
      onPointerCancel: shouldClear(ElEventClearField.onPointerCancel)
          ? null
          : onPointerCancel ?? this.onPointerCancel,
      onPointerPanZoomStart:
          shouldClear(ElEventClearField.onPointerPanZoomStart)
          ? null
          : onPointerPanZoomStart ?? this.onPointerPanZoomStart,
      onPointerPanZoomUpdate:
          shouldClear(ElEventClearField.onPointerPanZoomUpdate)
          ? null
          : onPointerPanZoomUpdate ?? this.onPointerPanZoomUpdate,
      onPointerPanZoomEnd: shouldClear(ElEventClearField.onPointerPanZoomEnd)
          ? null
          : onPointerPanZoomEnd ?? this.onPointerPanZoomEnd,
      onPointerSignal: shouldClear(ElEventClearField.onPointerSignal)
          ? null
          : onPointerSignal ?? this.onPointerSignal,
      onTapDown: shouldClear(ElEventClearField.onTapDown)
          ? null
          : onTapDown ?? this.onTapDown,
      onTapUp: shouldClear(ElEventClearField.onTapUp)
          ? null
          : onTapUp ?? this.onTapUp,
      onTap: shouldClear(ElEventClearField.onTap) ? null : onTap ?? this.onTap,
      onDoubleTap: shouldClear(ElEventClearField.onDoubleTap)
          ? null
          : onDoubleTap ?? this.onDoubleTap,
      onDoubleTapDown: shouldClear(ElEventClearField.onDoubleTapDown)
          ? null
          : onDoubleTapDown ?? this.onDoubleTapDown,
      onTripleTap: shouldClear(ElEventClearField.onTripleTap)
          ? null
          : onTripleTap ?? this.onTripleTap,
      onTripleTapDown: shouldClear(ElEventClearField.onTripleTapDown)
          ? null
          : onTripleTapDown ?? this.onTripleTapDown,
      onSecondaryTapDown: shouldClear(ElEventClearField.onSecondaryTapDown)
          ? null
          : onSecondaryTapDown ?? this.onSecondaryTapDown,
      onSecondaryTapUp: shouldClear(ElEventClearField.onSecondaryTapUp)
          ? null
          : onSecondaryTapUp ?? this.onSecondaryTapUp,
      onSecondaryTap: shouldClear(ElEventClearField.onSecondaryTap)
          ? null
          : onSecondaryTap ?? this.onSecondaryTap,
      onTertiaryTapDown: shouldClear(ElEventClearField.onTertiaryTapDown)
          ? null
          : onTertiaryTapDown ?? this.onTertiaryTapDown,
      onTertiaryTapUp: shouldClear(ElEventClearField.onTertiaryTapUp)
          ? null
          : onTertiaryTapUp ?? this.onTertiaryTapUp,
      onTertiaryTap: shouldClear(ElEventClearField.onTertiaryTap)
          ? null
          : onTertiaryTap ?? this.onTertiaryTap,
      onForwardTapDown: shouldClear(ElEventClearField.onForwardTapDown)
          ? null
          : onForwardTapDown ?? this.onForwardTapDown,
      onForwardTapUp: shouldClear(ElEventClearField.onForwardTapUp)
          ? null
          : onForwardTapUp ?? this.onForwardTapUp,
      onForwardTap: shouldClear(ElEventClearField.onForwardTap)
          ? null
          : onForwardTap ?? this.onForwardTap,
      onBackTapDown: shouldClear(ElEventClearField.onBackTapDown)
          ? null
          : onBackTapDown ?? this.onBackTapDown,
      onBackTapUp: shouldClear(ElEventClearField.onBackTapUp)
          ? null
          : onBackTapUp ?? this.onBackTapUp,
      onBackTap: shouldClear(ElEventClearField.onBackTap)
          ? null
          : onBackTap ?? this.onBackTap,
      onLongPress: shouldClear(ElEventClearField.onLongPress)
          ? null
          : onLongPress ?? this.onLongPress,
      onTapCancel: shouldClear(ElEventClearField.onTapCancel)
          ? null
          : onTapCancel ?? this.onTapCancel,
      onDragDown: shouldClear(ElEventClearField.onDragDown)
          ? null
          : onDragDown ?? this.onDragDown,
      onDragStart: shouldClear(ElEventClearField.onDragStart)
          ? null
          : onDragStart ?? this.onDragStart,
      onDragUpdate: shouldClear(ElEventClearField.onDragUpdate)
          ? null
          : onDragUpdate ?? this.onDragUpdate,
      onDragEnd: shouldClear(ElEventClearField.onDragEnd)
          ? null
          : onDragEnd ?? this.onDragEnd,
      onDragCancel: shouldClear(ElEventClearField.onDragCancel)
          ? null
          : onDragCancel ?? this.onDragCancel,
      onVerticalDragStart: shouldClear(ElEventClearField.onVerticalDragStart)
          ? null
          : onVerticalDragStart ?? this.onVerticalDragStart,
      onVerticalDragUpdate: shouldClear(ElEventClearField.onVerticalDragUpdate)
          ? null
          : onVerticalDragUpdate ?? this.onVerticalDragUpdate,
      onVerticalDragEnd: shouldClear(ElEventClearField.onVerticalDragEnd)
          ? null
          : onVerticalDragEnd ?? this.onVerticalDragEnd,
      onVerticalDragCancel: shouldClear(ElEventClearField.onVerticalDragCancel)
          ? null
          : onVerticalDragCancel ?? this.onVerticalDragCancel,
      onHorizontalDragStart:
          shouldClear(ElEventClearField.onHorizontalDragStart)
          ? null
          : onHorizontalDragStart ?? this.onHorizontalDragStart,
      onHorizontalDragUpdate:
          shouldClear(ElEventClearField.onHorizontalDragUpdate)
          ? null
          : onHorizontalDragUpdate ?? this.onHorizontalDragUpdate,
      onHorizontalDragEnd: shouldClear(ElEventClearField.onHorizontalDragEnd)
          ? null
          : onHorizontalDragEnd ?? this.onHorizontalDragEnd,
      onHorizontalDragCancel:
          shouldClear(ElEventClearField.onHorizontalDragCancel)
          ? null
          : onHorizontalDragCancel ?? this.onHorizontalDragCancel,
      onScaleStart: shouldClear(ElEventClearField.onScaleStart)
          ? null
          : onScaleStart ?? this.onScaleStart,
      onScaleUpdate: shouldClear(ElEventClearField.onScaleUpdate)
          ? null
          : onScaleUpdate ?? this.onScaleUpdate,
      onScaleEnd: shouldClear(ElEventClearField.onScaleEnd)
          ? null
          : onScaleEnd ?? this.onScaleEnd,
      onScaleCancel: shouldClear(ElEventClearField.onScaleCancel)
          ? null
          : onScaleCancel ?? this.onScaleCancel,
      onRotationUpdate: shouldClear(ElEventClearField.onRotationUpdate)
          ? null
          : onRotationUpdate ?? this.onRotationUpdate,
    );
  }

  /// 全量替换合并：[other] 非空时**整体取代**当前配置（含 null 字段——other 的
  /// null 会清掉 this 的同名 handler），为空时返回 this。
  ///
  /// 这不是逐字段叠加。需要"以 this 为底、覆盖部分字段"时用 [copyWith]。
  ElEvent merge([ElEvent? other]) => other ?? this;

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

  /// 是否包含任意事件回调。
  bool get hasAnyCallback =>
      onPointerEnter != null ||
      onPointerHover != null ||
      onPointerExit != null ||
      onPointerDown != null ||
      onPointerMove != null ||
      onPointerUp != null ||
      onPointerCancel != null ||
      onPointerPanZoomStart != null ||
      onPointerPanZoomUpdate != null ||
      onPointerPanZoomEnd != null ||
      onPointerSignal != null ||
      onTapDown != null ||
      onTapUp != null ||
      onTap != null ||
      onDoubleTap != null ||
      onDoubleTapDown != null ||
      onTripleTap != null ||
      onTripleTapDown != null ||
      onSecondaryTapDown != null ||
      onSecondaryTapUp != null ||
      onSecondaryTap != null ||
      onTertiaryTapDown != null ||
      onTertiaryTapUp != null ||
      onTertiaryTap != null ||
      onForwardTapDown != null ||
      onForwardTapUp != null ||
      onForwardTap != null ||
      onBackTapDown != null ||
      onBackTapUp != null ||
      onBackTap != null ||
      onLongPress != null ||
      onTapCancel != null ||
      onDragDown != null ||
      onDragStart != null ||
      onDragUpdate != null ||
      onDragEnd != null ||
      onDragCancel != null ||
      onVerticalDragStart != null ||
      onVerticalDragUpdate != null ||
      onVerticalDragEnd != null ||
      onVerticalDragCancel != null ||
      onHorizontalDragStart != null ||
      onHorizontalDragUpdate != null ||
      onHorizontalDragEnd != null ||
      onHorizontalDragCancel != null ||
      onScaleStart != null ||
      onScaleUpdate != null ||
      onScaleEnd != null ||
      onScaleCancel != null ||
      onRotationUpdate != null;

  // 分成两段 32 位掩码，避免 Web 位运算截断高位回调。
  int get _handlerShapeMaskLo =>
      (onPointerEnter != null ? 1 << 0 : 0) |
      (onPointerHover != null ? 1 << 1 : 0) |
      (onPointerExit != null ? 1 << 2 : 0) |
      (onPointerDown != null ? 1 << 3 : 0) |
      (onPointerMove != null ? 1 << 4 : 0) |
      (onPointerUp != null ? 1 << 5 : 0) |
      (onPointerCancel != null ? 1 << 6 : 0) |
      (onPointerPanZoomStart != null ? 1 << 7 : 0) |
      (onPointerPanZoomUpdate != null ? 1 << 8 : 0) |
      (onPointerPanZoomEnd != null ? 1 << 9 : 0) |
      (onPointerSignal != null ? 1 << 10 : 0) |
      (onTapDown != null ? 1 << 11 : 0) |
      (onTapUp != null ? 1 << 12 : 0) |
      (onTap != null ? 1 << 13 : 0) |
      (onDoubleTap != null ? 1 << 14 : 0) |
      (onDoubleTapDown != null ? 1 << 15 : 0) |
      (onTripleTap != null ? 1 << 16 : 0) |
      (onTripleTapDown != null ? 1 << 17 : 0) |
      (onSecondaryTapDown != null ? 1 << 18 : 0) |
      (onSecondaryTapUp != null ? 1 << 19 : 0) |
      (onSecondaryTap != null ? 1 << 20 : 0) |
      (onTertiaryTapDown != null ? 1 << 21 : 0) |
      (onTertiaryTapUp != null ? 1 << 22 : 0) |
      (onTertiaryTap != null ? 1 << 23 : 0) |
      (onForwardTapDown != null ? 1 << 24 : 0) |
      (onForwardTapUp != null ? 1 << 25 : 0) |
      (onForwardTap != null ? 1 << 26 : 0) |
      (onBackTapDown != null ? 1 << 27 : 0) |
      (onBackTapUp != null ? 1 << 28 : 0) |
      (onBackTap != null ? 1 << 29 : 0) |
      (onLongPress != null ? 1 << 30 : 0) |
      (onTapCancel != null ? 1 << 31 : 0);

  int get _handlerShapeMaskHi =>
      (onDragStart != null ? 1 << 0 : 0) |
      (onDragUpdate != null ? 1 << 1 : 0) |
      (onDragEnd != null ? 1 << 2 : 0) |
      (onDragCancel != null ? 1 << 3 : 0) |
      (onVerticalDragStart != null ? 1 << 4 : 0) |
      (onVerticalDragUpdate != null ? 1 << 5 : 0) |
      (onVerticalDragEnd != null ? 1 << 6 : 0) |
      (onVerticalDragCancel != null ? 1 << 7 : 0) |
      (onHorizontalDragStart != null ? 1 << 8 : 0) |
      (onHorizontalDragUpdate != null ? 1 << 9 : 0) |
      (onHorizontalDragEnd != null ? 1 << 10 : 0) |
      (onHorizontalDragCancel != null ? 1 << 11 : 0) |
      (onScaleStart != null ? 1 << 12 : 0) |
      (onScaleUpdate != null ? 1 << 13 : 0) |
      (onScaleEnd != null ? 1 << 14 : 0) |
      (onScaleCancel != null ? 1 << 15 : 0) |
      (onRotationUpdate != null ? 1 << 16 : 0) |
      (onDragDown != null ? 1 << 17 : 0);

  /// 除 Drag 家族外的声明结构是否完全一致。
  ///
  /// 仅供事件分发器判定动态挂卸 Drag 时能否保留 Tap / LongPress
  /// 的离散状态。Drag 家族包含 `onDragDown`、自由拖拽与轴向
  /// 拖拽；配置仅比较 Tap / 连击 / 长按字段，纯 Drag 参数变化可保留连击窗口。
  @internal
  bool hasSameNonDragShape(ElEvent other) {
    const nonDragMaskHi = 0x1f000;
    return _sameTapConfiguration(other.config, config) &&
        other.dragProxy == dragProxy &&
        other.rotationStartEnabled == rotationStartEnabled &&
        other._handlerShapeMaskLo == _handlerShapeMaskLo &&
        (other._handlerShapeMaskHi & nonDragMaskHi) ==
            (_handlerShapeMaskHi & nonDragMaskHi);
  }

  /// 识别配置与回调结构相等时，光标、命中行为变化只热更新声明。
  @internal
  bool hasSameGestureShape(ElEvent other) =>
      other.config == config &&
      other.dragProxy == dragProxy &&
      other.rotationStartEnabled == rotationStartEnabled &&
      other._handlerShapeMaskLo == _handlerShapeMaskLo &&
      other._handlerShapeMaskHi == _handlerShapeMaskHi;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ElEvent &&
        other.behavior == behavior &&
        other.cursor == cursor &&
        other.disabled == disabled &&
        hasSameGestureShape(other);
  }

  @override
  int get hashCode => Object.hash(
    config,
    dragProxy,
    behavior,
    cursor,
    disabled,
    rotationStartEnabled,
    _handlerShapeMaskLo,
    _handlerShapeMaskHi,
  );

  /// 两份配置的全部回调是否为同一批闭包实例（shape 相等之上的强判定）。
  ///
  /// dispatcher 用它区分"同构热替换"与"完全相同无需处理"。
  bool identicalHandlers(ElEvent other) {
    final proxyOwn = dragProxy;
    final proxyOther = other.dragProxy;
    final proxyIdentical =
        (proxyOwn == null) == (proxyOther == null) &&
        (proxyOwn == null || proxyOwn.identicalHandlers(proxyOther!));
    return proxyIdentical &&
        other.rotationStartEnabled == rotationStartEnabled &&
        identical(other.onPointerEnter, onPointerEnter) &&
        identical(other.onPointerHover, onPointerHover) &&
        identical(other.onPointerExit, onPointerExit) &&
        identical(other.onPointerDown, onPointerDown) &&
        identical(other.onPointerMove, onPointerMove) &&
        identical(other.onPointerUp, onPointerUp) &&
        identical(other.onPointerCancel, onPointerCancel) &&
        identical(other.onPointerPanZoomStart, onPointerPanZoomStart) &&
        identical(other.onPointerPanZoomUpdate, onPointerPanZoomUpdate) &&
        identical(other.onPointerPanZoomEnd, onPointerPanZoomEnd) &&
        identical(other.onPointerSignal, onPointerSignal) &&
        identical(other.onTapDown, onTapDown) &&
        identical(other.onTapUp, onTapUp) &&
        identical(other.onTap, onTap) &&
        identical(other.onDoubleTap, onDoubleTap) &&
        identical(other.onDoubleTapDown, onDoubleTapDown) &&
        identical(other.onTripleTap, onTripleTap) &&
        identical(other.onTripleTapDown, onTripleTapDown) &&
        identical(other.onSecondaryTapDown, onSecondaryTapDown) &&
        identical(other.onSecondaryTapUp, onSecondaryTapUp) &&
        identical(other.onSecondaryTap, onSecondaryTap) &&
        identical(other.onTertiaryTapDown, onTertiaryTapDown) &&
        identical(other.onTertiaryTapUp, onTertiaryTapUp) &&
        identical(other.onTertiaryTap, onTertiaryTap) &&
        identical(other.onForwardTapDown, onForwardTapDown) &&
        identical(other.onForwardTapUp, onForwardTapUp) &&
        identical(other.onForwardTap, onForwardTap) &&
        identical(other.onBackTapDown, onBackTapDown) &&
        identical(other.onBackTapUp, onBackTapUp) &&
        identical(other.onBackTap, onBackTap) &&
        identical(other.onLongPress, onLongPress) &&
        identical(other.onTapCancel, onTapCancel) &&
        identical(other.onDragDown, onDragDown) &&
        identical(other.onDragStart, onDragStart) &&
        identical(other.onDragUpdate, onDragUpdate) &&
        identical(other.onDragEnd, onDragEnd) &&
        identical(other.onDragCancel, onDragCancel) &&
        identical(other.onVerticalDragStart, onVerticalDragStart) &&
        identical(other.onVerticalDragUpdate, onVerticalDragUpdate) &&
        identical(other.onVerticalDragEnd, onVerticalDragEnd) &&
        identical(other.onVerticalDragCancel, onVerticalDragCancel) &&
        identical(other.onHorizontalDragStart, onHorizontalDragStart) &&
        identical(other.onHorizontalDragUpdate, onHorizontalDragUpdate) &&
        identical(other.onHorizontalDragEnd, onHorizontalDragEnd) &&
        identical(other.onHorizontalDragCancel, onHorizontalDragCancel) &&
        identical(other.onScaleStart, onScaleStart) &&
        identical(other.onScaleUpdate, onScaleUpdate) &&
        identical(other.onScaleEnd, onScaleEnd) &&
        identical(other.onScaleCancel, onScaleCancel) &&
        identical(other.onRotationUpdate, onRotationUpdate);
  }
}
