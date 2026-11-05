import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show internal, setEquals;
import 'package:flutter/gestures.dart' show PointerDeviceKind, kMaxFlingVelocity, kMinFlingVelocity;
import 'package:flutter/widgets.dart';

import '../../../../../dart.dart';
import 'press.dart';

export 'press.dart' show ElEventPhase, ElEventDetails, ElEventCancelReason, ElFocusReason;

part 'event.g.dart';

/// 事件回调签名。
typedef ElEventHandler = void Function(ElEventDetails event);

/// 事件识别参数配置：点击家族（单击 / 连击 / 长按 / 侧键 tap）与拖拽
/// （起手阈 / 判轴锥角 / fling 阈值）。
///
/// 挂到 `ElEvent.config`。所有字段可空，`null` 表示**未设置**：
///
/// - **节点直参 + 内部默认**：配置只对声明它的那个节点生效；未设置的字段在
///   读取时落 getter 内部默认值（各 getter 内注明），**不读任何全局状态**。
/// - 读取端（getter）总是返回生效值——`null` 只存在于存储层，
///   [ElEventConfig] 实例对外表现为一份完整配置。
///
/// 配置不沿 render 树向子组件注入，也不存在任何全局入口：祖先的 config 不会
/// 影响后代，组件需要特殊手感时在自己的 `ElEvent.config` 中声明。
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

  /// Tap、连击与长按参数是否和 [other] 使用相同的局部覆盖，仅供事件状态迁移。
  /// 不比较视觉与键盘参数，避免调节反馈或重复间隔时打断指针手势。
  @internal
  bool hasSameTapConfiguration(ElEventConfig? other) =>
      _doubleTapInterval == other?._doubleTapInterval &&
      _tripleTapInterval == other?._tripleTapInterval &&
      _longPressDelay == other?._longPressDelay &&
      longPressCancelDistance == other?.longPressCancelDistance &&
      _tapCancelDistance == other?._tapCancelDistance &&
      _tapCancelByDistance == other?._tapCancelByDistance &&
      _deferTap == other?._deferTap;

  // --- 点击家族 --------------------------------------------------------------

  final Duration? _doubleTapInterval;

  /// 双击识别间隔，同时也是 [deferTap] 为 true 时 onTap 的延迟时长。
  /// 默认 300ms。
  Duration get doubleTapInterval => _doubleTapInterval ?? const Duration(milliseconds: 300);

  final Duration? _tripleTapInterval;

  /// 三击识别间隔。第三次 PointerUp 与第二次的间隔 ≤ 此值且距离 ≤
  /// [tapCancelDistance] 时识别为三击。默认 300ms。
  Duration get tripleTapInterval => _tripleTapInterval ?? const Duration(milliseconds: 300);

  final Duration? _longPressDelay;

  /// 长按识别等待时间。默认 500ms。
  Duration get longPressDelay => _longPressDelay ?? const Duration(milliseconds: 500);

  /// 长按等待期间允许的最大移动距离；null 表示按指针设备采用系统 hit slop。
  final double? longPressCancelDistance;

  final double? _tapCancelDistance;

  /// 指针按下后移动超过该距离，最终 tap 激活资格取消（含侧键 `*Tap`）。
  /// 默认 10.0。
  ///
  /// 仅在 [tapCancelByDistance] 为 true 时参与主键 tap 判定；侧键 `*Tap` 与连击
  /// 窗口的位置判定恒使用该距离。
  double get tapCancelDistance => _tapCancelDistance ?? 10.0;

  final bool? _tapCancelByDistance;

  /// 主键 tap 是否按**移动距离**取消。
  ///
  /// - `false`（默认）：按**元素边界**判定，对齐 iOS UIControl 的
  ///   `touchDragExit` / `touchDragEnter` 语义。指针拖出宿主命中范围时
  ///   fire `onTapCancel` 并复位按压态（`onTap` 变体随之熄灭），但候选**不销毁**；
  ///   指针拖回范围内会重新 fire `onTapDown`、按压态重新点亮，此时抬手照常
  ///   fire `onTapUp` / `onTap`。抬手位置在范围外才最终不触发点击。
  /// - `true`：移动超过 [tapCancelDistance] 即**永久**取消最终 `onTap`
  ///   （移回也不恢复），但物理抬起仍兑现 `onTapUp`。
  ///
  /// `onTapUp` 是按压释放通知，不表示 tap 激活成功；只有 PointerCancel、节点
  /// 失去该 pointer 归属或被移除时不触发。
  bool get tapCancelByDistance => _tapCancelByDistance ?? false;

  final Duration? _delayTouchDown;

  /// 触摸按下后等待多久激活 `ElStyle.onTap`，默认立即激活；鼠标与笔不延迟。
  Duration get delayTouchDown => _delayTouchDown ?? Duration.zero;

  final Duration? _delayTouchUp;

  /// 从触摸按下起算的最短反馈时间，默认 100ms；正常抬手只补剩余时间，不延迟点击。
  ///
  /// 尚未激活的样式不补播，取消、拖拽接管、禁用与卸载立即清理；零值关闭保留。
  Duration get delayTouchUp => _delayTouchUp ?? const Duration(milliseconds: 100);

  final Duration? _keyRepeatInterval;

  /// 同一物理按键的重复回调最小间隔，默认 100ms，零值关闭限流。
  ///
  /// 首次按下和释放立即派发；过密的 KeyRepeat 直接跳过，不排队，也不影响按压样式。
  Duration get keyRepeatInterval => _keyRepeatInterval ?? const Duration(milliseconds: 100);

  final bool? _deferTap;

  /// 同时声明 onTap 和 onDoubleTap 时，是否延迟 onTap 等待双击判定。
  ///
  /// - `false`（默认）：双击不影响单击执行。单击立即在 PointerUp 时 fire
  ///   onTap；双击场景里 onTap 仍 fire（来自第二次 PointerUp），同时
  ///   再 fire 一次 onDoubleTap。
  /// - `true`：跟 Flutter 官方 `GestureDetector` 同时配置 onTap / onDoubleTap
  ///   的行为一致。PointerUp 后用 Timer 延迟 [doubleTapInterval] 才 fire
  ///   onTap；其间若识别为双击，pending 的 onTap 被取消，只 fire onDoubleTap。
  ///
  /// 该开关**只影响 onTap 的触发时机**，不影响 onTapDown / onTapUp /
  /// onTapCancel 等任何其他回调——它们仍按原本时序触发。
  bool get deferTap => _deferTap ?? false;

  // --- 拖拽 ------------------------------------------------------------------

  /// 累计移动超过该距离后触发拖拽开始。
  ///
  /// `null`（默认）表示设备自适应：轴向拖拽取设备 hit slop（Android 真机
  /// ≈8-9 逻辑px，测试环境 18）；**双轴组竞争中胜出的水平轴**取 pan slop
  /// （hit slop × 2）——水平比垂直更易被起手噪声误判，加长确认距离给纵向
  /// 意图留翻盘窗口（未激活期间判轴方向仍是活的）；自由拖拽取 pan slop
  /// ——与官方对应 recognizer 的启动阈一致。显式设置则按值生效（不分轴、
  /// 不放大），不再有 `kTouchSlop` 哨兵语义。
  final double? dragStartDistance;

  /// 可参与拖拽识别的设备；null 表示不限制。
  final Set<PointerDeviceKind>? dragDevices;

  final double? _dragHorizontalAngle;

  /// 拖拽起手方向判轴的水平捕获锥半角（弧度），默认 π/4（45°）：
  /// `|dx| >= |dy|` 判横向，`|dy| > |dx|` 判垂直，两个方向各占一半。
  ///
  /// 双轴竞争的水平轴仍使用 pan slop 启动阈，垂直轴使用 hit slop；角度只
  /// 负责判定用户意图方向，不改变各轴的设备启动距离。
  ///
  /// 起手方向与水平轴的夹角在 ±[dragHorizontalAngle] 内判为水平，否则判为
  /// 垂直；默认 45° 时两个方向等分。作用于：
  ///
  /// - **双轴组同挂**（onVerticalDrag* + onHorizontalDrag* 组）：起手锁轴
  ///   按此锥裁决，2D 位移越过胜出轴的 [dragStartDistance] 即激活；
  /// - 自由拖拽（onDrag*）的 dragDirection 方向分类；
  /// - 轻扫救援（未过起手阈直接抬手）按速度向量方向同款判轴。
  ///
  /// 只挂单一轴向组时也参与判定：累计方向不在该轴捕获锥内就继续等待，
  /// 允许后续轨迹转向后再激活，避免浅角横滑误启动垂直行为。
  double get dragHorizontalAngle => _dragHorizontalAngle ?? math.pi / 4;

  /// 拖拽结束判定为 fling 的最小拖动距离。
  ///
  /// 轴向拖拽按主轴位移比较；自由拖拽按二维位移比较。`null`（默认）表示
  /// 设备自适应（hit slop），与官方 DragGestureRecognizer 的
  /// `minFlingDistance ?? computeHitSlop(...)` 语义一致。
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

bool _sameTapConfiguration(ElEventConfig? left, ElEventConfig? right) =>
    left?.hasSameTapConfiguration(right) ?? right?.hasSameTapConfiguration(null) ?? true;

/// 拖拽代理配置：声明本节点参与后代拖拽序列的 delta 分账管线。
///
/// 挂到 [ElEvent.dragProxy] 上。当后代 dispatcher 接受一次拖拽（driver）时，
/// 事件层沿 driver 的祖先链收集所有声明了兼容 proxy 的成员组成 roster：
///
/// - **pre 阶段**：driver 每帧应用 delta **之前**由 roster 外→内依次调用
///   [onDragPreUpdate]，通过 [ElEventDetails.consumeDelta] /
///   [ElEventDetails.consumePrimaryDelta] 记账剩余量。
/// - **主段**：driver 按现状逻辑消费剩余 delta（滚动组件的边界 clamp、
///   ScrollPhysics 等）。
/// - **overflow 阶段**：driver 消费后由 roster 内→外依次调用 [onDragOverflow]，
///   接收 driver 未吃掉的余量。
///
/// 三段共用同一个 [ElEventDetails]，管线通过 [ElEventDetails.remainingDelta]
/// 台账协作。任何阶段把余量按 [axis] 投影为 0 → 短路后续阶段。
///
/// ## 语义约束
///
/// - roster 成员由祖先链快照收集，**不依赖自身 hit-test**；纯 proxy 节点无需
///   声明 [ElEvent.onDragStart] 等回调。但含 dragProxy 的 [ElEvent] 非 null 时
///   宿主仍会分配 dispatcher，链收集才能可见。
/// - roster 成员的 [onDragPreUpdate] / [onDragOverflow] 内**禁用**
///   [ElEventDetails.stopPropagation] 与 [ElEventDetails.eagerGesture]：调用
///   被静默忽略并复位。用户代码应通过 `consumeDelta` 表达"这一段我吃了"。
/// - roster 成员的 [ElEvent.onDragStart] / [ElEvent.onDragEnd] /
///   [ElEvent.onDragCancel] 仍会收到 driver 冒泡的生命周期事件，作为手势
///   起止信号（例如面板 snap 依赖 `onDragEnd.primaryVelocity`）。
///
/// ## shape 等值
///
/// 与 [ElEvent] 一致：`==` 比 [axis] 值 + 回调空性掩码。widget rebuild 传入
/// 新闭包但结构相同时属于同构替换，dispatcher 热替换回调引用、管线不断。
@ElModelGenerator.copy(generateProps: false)
final class ElDragProxy {
  /// 创建拖拽代理配置。
  const ElDragProxy({this.axis, this.onDragPreUpdate, this.onDragOverflow, this.boundaryHandoff = const {}});

  /// 兼容轴向。null 表示任意轴。
  ///
  /// driver 接受拖拽时以**胜出轴**为准（声明 `onVerticalDrag*` 组胜出为
  /// vertical、`onHorizontalDrag*` 组胜出为 horizontal、自由拖拽 `onDrag*`
  /// 为 null）：driver 胜出轴非 null 时，`axis == null` 或 `axis == 胜出轴`
  /// 才入 roster；driver 为自由拖拽时仅 `axis == null` 入 roster。
  final Axis? axis;

  /// 先扣阶段回调（roster 外→内）。
  final ElEventHandler? onDragPreUpdate;

  /// 溢出阶段回调（roster 内→外）。
  final ElEventHandler? onDragOverflow;

  /// 指定需要接管滚动边界余量的指针移动方向，默认保留后代的弹性滚动物理。
  ///
  /// 这些方向抵达边界后不再继续弹性越界，余量交给 [onDragOverflow]；
  /// 只声明本代理负责消费的方向，未声明方向仍使用原有物理。
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

/// 事件配置。
///
/// 声明式回调集合与手势识别配置，由 dispatcher 接入任意 RenderObject。
/// 识别器只处理通用输入，几何、焦点和组件反馈由宿主适配。
///
/// ## 等值语义（shape equality）
///
/// `==` 比较**配置字段的值 + 回调字段的空性**，不比较回调闭包本身：
/// `ElEvent(onTap: a) == ElEvent(onTap: b)` 为 true。这是刻意的——widget
/// rebuild 时内联闭包每次都是新实例，若按闭包身份比较，任何 rebuild 都会被
/// dispatcher 视为配置替换，从而重置进行中的双击窗口/长按识别。shape 相等的
/// 替换会被 dispatcher 视为同构配置，仅热替换回调引用、完整保留手势状态。
@ElModelGenerator.copy(generateProps: false)
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
    this.onKeyDown,
    this.onKeyRepeat,
    this.onKeyUp,
    this.onFocus,
    this.onBlur,
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
  final ElEventConfig? config;

  /// 拖拽分账代理。声明本节点参与后代拖拽序列的 pre/overflow 阶段管线。
  ///
  /// 详见 [ElDragProxy] 类文档。
  final ElDragProxy? dragProxy;

  /// 事件宿主的命中行为，默认覆盖布局盒。
  final HitTestBehavior behavior;

  /// 基础光标；null 表示未声明，ElView 生效的样式光标优先。
  final MouseCursor? cursor;

  /// 是否禁用事件宿主的交互。
  final bool disabled;

  /// 是否允许纯角向移动启动 Scale 状态机，仅供变换组件开启。
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
  /// 平台 `PointerCancelEvent` 与 [ElEventDetails.eagerGesture] 淘汰当前节点时
  /// 都会触发；后者的 [ElEventDetails.originalEvent] 是合成
  /// `PointerCancelEvent`，原因见 [ElEventDetails.cancelReason]。
  final ElEventHandler? onPointerCancel;

  /// 触控板平移缩放开始回调。
  final ElEventHandler? onPointerPanZoomStart;

  /// 触控板平移缩放更新回调。
  final ElEventHandler? onPointerPanZoomUpdate;

  /// 触控板平移缩放结束回调。
  final ElEventHandler? onPointerPanZoomEnd;

  /// 鼠标滚轮或其他指针信号回调。
  final ElEventHandler? onPointerSignal;

  /// 主指针或主焦点节点的键盘激活键按下回调。
  final ElEventHandler? onTapDown;

  /// 主指针或已配对的键盘激活键释放回调。
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
  /// [ElEventDetails.eagerGesture]。如果长按成立后组件判定当前位置
  /// 不可处理，可在任意一层回调中调用 [ElEventDetails.preventDefault]
  /// 拒绝这项默认认领；此时 pointer 归属与 Tap 资格均保持不变。
  ///
  /// [ElEventDetails.stopPropagation] 只停止向祖先传播，不会取消默认认领。
  final ElEventHandler? onLongPress;

  /// Tap 候选取消回调；Tap 拒绝、手势让位与生命周期终止原因见
  /// [ElEventDetails.cancelReason]。
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
  /// [ElEventDetails.dragAxis] 携带胜出轴。
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

  /// 键盘按下回调。
  final ElEventHandler? onKeyDown;

  /// 键盘重复按下回调。
  final ElEventHandler? onKeyRepeat;

  /// 键盘抬起回调。
  final ElEventHandler? onKeyUp;

  /// 获得焦点回调。
  final ElEventHandler? onFocus;

  /// 失去焦点回调。
  final ElEventHandler? onBlur;

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

  /// 是否包含任意事件回调。
  bool get hasAnyCallback => _handlerShapeMaskLo != 0 || _handlerShapeMaskHi != 0;

  /// 回调字段空性位掩码低 32 位（bit i = 第 i 个 handler 非空），供 shape
  /// 等值使用。
  ///
  /// 直线位或表达式（[ElDragProxy._handlerShapeMask] 同款）而非闭包逐项累加：
  /// `==` / [hashCode] 落在 rebuild 热路径（updateRenderObject 的热替换判定），
  /// 每次比较双方各算一遍，55 次闭包调用是纯税；const 构造无处挂缓存字段，
  /// 用无分配的直算把单次成本压到底。
  ///
  /// **拆 lo/hi 双 int**（2026-07-30）：回调共 55 个，单 int 掩码在 Web JS
  /// 后端 `1 << 32` 起全部归 0——drag / 键盘 / 焦点回调的增删曾在 `==` 里
  /// 不可见（热替换判定漏更新）。两半各自 shift < 32，原生位运算安全。
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

  /// 回调字段空性位掩码高位段（drag / scale / rotation / 键盘 / 焦点，
  /// bit 0 = onDragStart .. bit 21 = onBlur，bit 22 = onDragDown）。拆分理由见
  /// [_handlerShapeMaskLo]。
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
      (onKeyDown != null ? 1 << 17 : 0) |
      (onKeyRepeat != null ? 1 << 18 : 0) |
      (onKeyUp != null ? 1 << 19 : 0) |
      (onFocus != null ? 1 << 20 : 0) |
      (onBlur != null ? 1 << 21 : 0) |
      (onDragDown != null ? 1 << 22 : 0);

  /// 除 Drag 家族外的声明结构是否完全一致。
  ///
  /// 仅供事件分发器判定动态挂卸 Drag 时能否保留 Tap / LongPress
  /// 的离散状态。Drag 家族包含 `onDragDown`、自由拖拽与轴向
  /// 拖拽；配置仅比较 Tap / 连击 / 长按字段，纯 Drag 参数变化可保留连击窗口。
  @internal
  bool hasSameNonDragShape(ElEvent other) =>
      _sameTapConfiguration(other.config, config) && _hasSameHandlerShape(other, maskHi: 0x3ff000);

  /// 识别配置与回调结构相等时，光标、命中行为变化只热更新声明。
  @internal
  bool hasSameGestureShape(ElEvent other) => other.config == config && _hasSameHandlerShape(other);

  bool _hasSameHandlerShape(ElEvent other, {int maskHi = 0x7fffff}) =>
      other.dragProxy == dragProxy &&
      other.rotationStartEnabled == rotationStartEnabled &&
      other._handlerShapeMaskLo == _handlerShapeMaskLo &&
      ((_handlerShapeMaskHi ^ other._handlerShapeMaskHi) & maskHi) == 0;

  /// 仅比较缩放与旋转声明，供分发器决定是否结清已有 Scale。
  @internal
  bool hasSameScaleShape(ElEvent other) =>
      rotationStartEnabled == other.rotationStartEnabled &&
      ((_handlerShapeMaskHi ^ other._handlerShapeMaskHi) & 0x1f000) == 0;

  int get _transformCallbackShape {
    final mask = _handlerShapeMaskHi;
    final freeDrag = mask & 0xf;
    // 轴向回调沿用自由拖拽回落，保持分发器按轴查找的空性语义。
    return (mask | (freeDrag << 4) | (freeDrag << 8)) & 0x41ffff;
  }

  /// 仅比较变换回调空性，不替代参数比较或活动 Drag 续接判断。
  @internal
  bool hasSameTransformCallbacks(ElEvent other) => _transformCallbackShape == other._transformCallbackShape;

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
}
