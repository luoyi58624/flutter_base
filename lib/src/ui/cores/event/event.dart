import 'package:equatable/equatable.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/src/dart/gen/index.dart';
import 'package:meta/meta.dart';

part 'event.g.dart';

bool _sameTapConfiguration(ElEventConfig? left, ElEventConfig? right) =>
    left?.hasSameTapConfiguration(right) ?? right?.hasSameTapConfiguration(null) ?? true;

/// 最近事件宿主的只读交互状态，供后代根据状态构建外观。
@immutable
@ElModelGenerator(copyWith: true)
final class ElEventState {
  /// 创建交互状态快照，默认没有活动交互。
  const ElEventState({this.hasTap = false, this.hasHover = false, this.disabled = false});

  /// 是否处于按压反馈中；触摸遵循 delayTouchDown 和 delayTouchUp。
  final bool hasTap;

  /// 是否有鼠标位于宿主内，与是否按下鼠标按键无关。
  final bool hasHover;

  /// 当前事件宿主是否禁用，禁用期间各交互状态均为 false。
  final bool disabled;
}

/// 拖拽代理配置，用于沿祖先链分配后代拖拽产生的位移。
///
/// [onDragPreUpdate] 在拖拽处理器消费位移前由外向内执行，
/// [onDragOverflow] 在其后由内向外执行；各阶段通过
/// [ElEventCallback.remainingDelta] 与消费方法共享剩余位移。
/// 代理回调中的停止冒泡与独占请求不影响管线。
///
/// 等值比较使用 [axis] 和回调的空性，重建时替换闭包可保留手势状态。
@ElModelGenerator(copyWith: true)
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

  int get _handlerShapeMask => (onDragPreUpdate != null ? 1 : 0) | (onDragOverflow != null ? 2 : 0);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ElDragProxy && other.axis == axis && other._handlerShapeMask == _handlerShapeMask;
  }

  @override
  int get hashCode => Object.hash(axis, _handlerShapeMask);

  /// 两份代理的 handler 是否为同一批闭包实例（shape 相等之上的强判定）。
  bool identicalHandlers(ElDragProxy other) {
    return identical(other.onDragPreUpdate, onDragPreUpdate) && identical(other.onDragOverflow, onDragOverflow);
  }
}

/// 独立事件宿主的回调声明与手势配置。
///
/// 等值比较使用配置值和回调的空性，不比较闭包身份；相同声明结构下替换
/// 回调可保留正在进行的连击、长按和拖拽状态。
@ElModelGenerator(copyWith: true)
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

  /// 事件识别参数配置（点击家族 + 拖拽）。
  ///
  /// `null` 表示不声明局部覆盖，所有字段回落 [ElEventConfig] 的内部默认值。
  /// 非空时按**字段级**覆盖：只设置了的字段生效，未设置的字段同样回落内部
  /// 默认值。配置**只对声明它的那个节点生效**，不沿 render 树向子组件注入。
  /// 详见 [ElEventConfig]。
  // 替换局部声明时，未设置字段需要恢复识别器默认行为，不能隐式合并旧配置。
  @ElFieldGenerator(useMerge: false)
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
  /// 只有赢得官方竞技场后才通知。回调链执行完成后，事件宿主默认独占
  /// El 成员路线，并取消本节点的后续 Tap 激活；普通使用无需再手动调用
  /// [ElEventCallback.eagerGesture]。任意一层调用 [ElEventCallback.preventDefault]
  /// 可保留 El 冒泡与点击资格，但不能撤销官方竞技场已经确认的结果。
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
  /// 仅供 Render 宿主判定动态挂卸 Drag 时能否保留 Tap / LongPress
  /// 的离散状态。Drag 家族包含 `onDragDown`、自由拖拽与轴向
  /// 拖拽；配置仅比较 Tap / 连击 / 长按字段，纯 Drag 参数变化可保留连击窗口。
  @internal
  bool hasSameNonDragShape(ElEvent other) {
    const nonDragMaskHi = 0x1f000;
    return _sameTapConfiguration(other.config, config) &&
        other.dragProxy == dragProxy &&
        other.rotationStartEnabled == rotationStartEnabled &&
        other._handlerShapeMaskLo == _handlerShapeMaskLo &&
        (other._handlerShapeMaskHi & nonDragMaskHi) == (_handlerShapeMaskHi & nonDragMaskHi);
  }

  /// 变换回调与代理结构相等时保留当前识别，新的参数由下一轮序列采用。
  @internal
  bool hasSameTransformShape(ElEvent other) =>
      other.dragProxy == dragProxy &&
      other.rotationStartEnabled == rotationStartEnabled &&
      other._handlerShapeMaskHi == _handlerShapeMaskHi;

  /// 识别配置与回调结构相等时，光标、命中行为变化只热更新声明。
  @internal
  bool hasSameGestureShape(ElEvent other, {bool compareConfig = true}) =>
      (!compareConfig || other.config == config) &&
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
  /// Render 用它区分"同构热替换"与"完全相同无需处理"。
  bool identicalHandlers(ElEvent other) {
    final proxyOwn = dragProxy;
    final proxyOther = other.dragProxy;
    final proxyIdentical =
        (proxyOwn == null) == (proxyOther == null) && (proxyOwn == null || proxyOwn.identicalHandlers(proxyOther!));
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

/// 当前元素的事件参数声明，空值交由识别器或 Render 采用默认行为。
@ElModelGenerator.copy()
final class ElEventConfig with Equatable {
  /// 创建局部配置，不继承祖先配置，也不在此解析默认值。
  const ElEventConfig({
    this.doubleTapInterval,
    this.tripleTapInterval,
    this.longPressDelay,
    this.longPressCancelDistance,
    this.tapCancelDistance,
    this.tapCancelOnMove,
    this.delayTouchDown,
    this.delayTouchUp,
    this.deferTap,
    this.dragStartDistance,
    this.dragDevices,
    this.dragHorizontalAngle,
    this.dragMinFlingDistance,
    this.dragMinFlingVelocity,
    this.dragMaxFlingVelocity,
  });

  /// 第二击与前一击的最长间隔，默认由 Press 采用官方双击时限。
  final Duration? doubleTapInterval;

  /// 第三击与前一击的最长间隔，默认由 Press 采用官方双击时限。
  final Duration? tripleTapInterval;

  /// 长按等待时间，默认由 Press 采用官方长按时限。
  final Duration? longPressDelay;

  /// 长按允许的移动距离，空值采用官方设备容差。
  final double? longPressCancelDistance;

  /// 移动取消、侧键点击与连续点击的位置容差，默认由 Press 管理。
  final double? tapCancelDistance;

  /// 为 true 时按距离永久取消主键点击，否则由 Render 判断元素边界。
  ///
  /// 边界模式允许移回后重新按下；释放通知并不表示最终点击成立。
  final bool? tapCancelOnMove;

  /// 触摸按下反馈的延迟，Render 默认立即激活，不延迟鼠标与笔。
  final Duration? delayTouchDown;

  /// 触摸反馈从物理按下起算的最短时间，Render 默认采用 100ms，不延迟业务点击。
  final Duration? delayTouchUp;

  /// 同时监听单击和双击时，是否等待双击窗口再通知单击。
  final bool? deferTap;

  /// 拖拽开始的距离，空值由 Transform 按设备与轴向采用官方容差。
  final double? dragStartDistance;

  /// 可参与变换识别的设备，空值表示不限制。
  final Set<PointerDeviceKind>? dragDevices;

  /// 水平捕获锥的半角，Transform 默认采用 π/4。
  final double? dragHorizontalAngle;

  /// 产生释放速度的最小距离，空值采用官方设备容差。
  final double? dragMinFlingDistance;

  /// 产生甩动的最小速度，Transform 默认采用官方阈值。
  final double? dragMinFlingVelocity;

  /// 释放速度的最大值，Transform 默认采用官方上限。
  final double? dragMaxFlingVelocity;

  /// 点击识别参数是否相同，反馈时间变化不打断正在进行的手势。
  @internal
  bool hasSameTapConfiguration(ElEventConfig? other) =>
      doubleTapInterval == other?.doubleTapInterval &&
      tripleTapInterval == other?.tripleTapInterval &&
      longPressDelay == other?.longPressDelay &&
      longPressCancelDistance == other?.longPressCancelDistance &&
      tapCancelDistance == other?.tapCancelDistance &&
      tapCancelOnMove == other?.tapCancelOnMove &&
      deferTap == other?.deferTap;

  /// 用当前已设置的字段覆盖底层配置。
  ElEventConfig withFallback(ElEventConfig base) => base.merge(this);

  @override
  List<Object?> get props => _props;
}

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

  /// 其他节点或复合手势已接受，当前节点只取消 Tap/主手势资格。
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
/// 同一个对象会被沿冒泡链复用，每跳前由 Render 适配 [localPosition] /
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
  }) : assert(
         phase == ElEventPhase.tapCancel || phase == ElEventPhase.pointerCancel || cancelReason == null,
         'cancelReason 只能用于 ElEventPhase.tapCancel 或 ElEventPhase.pointerCancel。',
       ),
       cancelReason = switch (phase) {
         ElEventPhase.tapCancel => cancelReason ?? ElEventCancelReason.external,
         ElEventPhase.pointerCancel => cancelReason ?? ElEventCancelReason.pointerCanceled,
         _ => null,
       },
       remainingDelta = remainingDelta ?? delta,
       remainingLocalDelta = remainingLocalDelta ?? localDelta;

  /// 事件阶段。
  final ElEventPhase phase;

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

  /// 当前目标的连续点击次数，父子成员独立计数时会随冒泡目标更新。
  int tapCount;

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
  void Function(ElEventCallback callback, bool cancelSelfTap, bool allowScaleUpgrade)? _eagerGestureHandler;

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
  /// 请求须通过官方竞技场接受；已经被官方手势淘汰时无效，不能重新报名抢回。
  ///
  /// [cancelSelfTap] 取消当前宿主本序列的点击资格，保留指针跟踪与拖拽生命周期。
  /// [allowScaleUpgrade] 允许同一命中链的多指缩放随后接管此序列。
  void eagerGesture({bool cancelSelfTap = false, bool allowScaleUpgrade = false}) {
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
  /// 长按阶段可阻止 El 成员自动独占和取消点击，不能撤销官方归属；
  /// 指针信号可阻止平台继续处理该信号；
  /// 其他默认动作由使用事件的组件自行读取此标记决定。
  void preventDefault() {
    _defaultPrevented = true;
  }

  /// 标记已有处理器被调用。仅供Render 元素使用。
  void markCallbackInvoked() {
    _callbackInvoked = true;
  }

  /// 复位 [propagationStopped]。仅供Render 元素使用（`ElEvent.dragProxy`
  /// 三段管线包装每段调用后复位，防止 proxy handler 内误用
  /// [stopPropagation] 打断管线）。
  void resetPropagation() {
    _propagationStopped = false;
  }

  /// 更新当前目标的本地增量换算器。仅供Render 元素使用。
  void updateLocalDeltaResolver(Offset Function(Offset globalDelta)? resolver) {
    _localDeltaResolver = resolver;
    // 余量尚未被消费时，当前目标的 localDelta 就是本地余量；
    // 避免每个 drag/scale update 再做两次全局坐标反解。
    remainingLocalDelta = remainingDelta == delta ? localDelta : resolver?.call(remainingDelta) ?? remainingDelta;
  }

  /// 更新当前目标的 eager gesture 处理器。仅供Render 元素使用。
  void updateEagerGestureHandler(
    void Function(ElEventCallback callback, bool cancelSelfTap, bool allowScaleUpgrade)? handler,
  ) {
    _eagerGestureHandler = handler;
  }

  /// 消费一段拖拽 delta。
  void consumeDelta(Offset delta) {
    final consumed = _consumableDelta(delta);
    if (consumed == Offset.zero) return;
    remainingDelta -= consumed;
    remainingLocalDelta = _localDeltaResolver?.call(remainingDelta) ?? remainingDelta;
  }

  /// 消费指定轴向上的拖拽 delta。
  void consumePrimaryDelta(Axis axis, double delta) {
    consumeDelta(axis == Axis.vertical ? Offset(0.0, delta) : Offset(delta, 0.0));
  }

  /// 消费全部剩余拖拽 delta。
  void consumeAllDelta() {
    remainingDelta = Offset.zero;
    remainingLocalDelta = Offset.zero;
  }

  /// 读取指定轴向上尚未消费的拖拽 delta。
  double remainingPrimaryDelta(Axis axis) => axis == Axis.vertical ? remainingDelta.dy : remainingDelta.dx;

  Offset _consumableDelta(Offset delta) {
    return Offset(_consumableComponent(remainingDelta.dx, delta.dx), _consumableComponent(remainingDelta.dy, delta.dy));
  }

  static double _consumableComponent(double remaining, double requested) {
    if (remaining == 0.0 || requested == 0.0) return 0.0;
    if (remaining.sign != requested.sign) return 0.0;
    return requested.abs() >= remaining.abs() ? remaining : requested;
  }
}
