import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, internal, setEquals;
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kMaxFlingVelocity, kMinFlingVelocity;

/// 点击、连击、长按与拖拽的识别参数。
///
/// 通过 `ElEvent.config` 配置当前事件宿主，省略的参数采用内部默认值或
/// 设备自适应值；配置不向后代继承，也不依赖全局配置。
final class ElEventConfig {
  /// 创建事件配置。传 `null`（缺省）的字段回落 getter 内部默认/自适应值。
  const ElEventConfig({
    this._doubleTapInterval,
    this._tripleTapInterval,
    this._longPressDelay,
    this._longPressCancelDistance,
    this._tapCancelDistance,
    this._tapCancelOnMove,
    this._delayTouchDown,
    this._delayTouchUp,
    this._deferTap,
    this.dragStartDistance,
    this._dragDevices,
    this._dragHorizontalAngle,
    this.dragMinFlingDistance,
    this._dragMinFlingVelocity,
    this._dragMaxFlingVelocity,
    this._dragResampling,
  }) : assert(
         _longPressCancelDistance == null || _longPressCancelDistance >= 0,
         'longPressCancelDistance 必须大于等于 0。',
       ),
       assert(
         _dragHorizontalAngle == null ||
             (_dragHorizontalAngle > 0 && _dragHorizontalAngle < math.pi / 2),
         'dragHorizontalAngle 是水平捕获锥的半角（弧度），必须落在 (0, π/2) 开区间。',
       );

  /// Tap、连击与长按参数是否和 [other] 使用相同的局部覆盖，仅供事件状态迁移。
  /// 不比较交互反馈参数 [delayTouchDown]、[delayTouchUp]，避免调节反馈时打断手势识别。
  @internal
  bool hasSameTapConfiguration(ElEventConfig? other) =>
      _doubleTapInterval == other?._doubleTapInterval &&
      _tripleTapInterval == other?._tripleTapInterval &&
      _longPressDelay == other?._longPressDelay &&
      _longPressCancelDistance == other?._longPressCancelDistance &&
      _tapCancelDistance == other?._tapCancelDistance &&
      _tapCancelOnMove == other?._tapCancelOnMove &&
      _deferTap == other?._deferTap;

  // --- 点击家族 --------------------------------------------------------------

  final Duration? _doubleTapInterval;

  /// 双击识别间隔，同时也是 [deferTap] 为 true 时 onTap 的延迟时长。
  /// 默认 300ms。
  Duration get doubleTapInterval =>
      _doubleTapInterval ?? const Duration(milliseconds: 300);

  final Duration? _tripleTapInterval;

  /// 三击识别间隔。第三次 PointerUp 与第二次的间隔 ≤ 此值且距离 ≤
  /// [tapCancelDistance] 时识别为三击。默认 300ms。
  Duration get tripleTapInterval =>
      _tripleTapInterval ?? const Duration(milliseconds: 300);

  final Duration? _longPressDelay;

  /// 长按识别等待时间。默认 500ms。
  Duration get longPressDelay =>
      _longPressDelay ?? const Duration(milliseconds: 500);

  final double? _longPressCancelDistance;

  /// 长按等待期间允许的最大移动距离；null 表示按指针设备采用系统 hit slop。
  double? get longPressCancelDistance => _longPressCancelDistance;

  final double? _tapCancelDistance;

  /// 指针按下后移动超过该距离，最终 tap 激活资格取消（含侧键 `*Tap`）。
  /// 默认 10.0。
  ///
  /// 仅在 [tapCancelOnMove] 为 true 时参与主键 tap 判定；侧键 `*Tap` 与连击
  /// 窗口的位置判定恒使用该距离。
  double get tapCancelDistance => _tapCancelDistance ?? 10.0;

  final bool? _tapCancelOnMove;

  /// 主键 tap 是否按**移动距离**取消。
  ///
  /// - `false`（默认）：按**元素边界**判定，对齐 iOS UIControl 的
  ///   `touchDragExit` / `touchDragEnter` 语义。指针拖出宿主命中范围时
  ///   触发 `onTapCancel`，但保留候选；指针拖回范围内会重新触发
  ///   `onTapDown`，此时抬手照常触发 `onTapUp` / `onTap`。
  ///   抬手位置在范围外才最终不触发点击。
  /// - `true`：移动超过 [tapCancelDistance] 即**永久**取消最终 `onTap`
  ///   （移回也不恢复），但物理抬起仍兑现 `onTapUp`。
  ///
  /// `onTapUp` 是按压释放通知，不表示 tap 激活成功；只有 PointerCancel、节点
  /// 失去该 pointer 归属或被移除时不触发。
  bool get tapCancelOnMove => _tapCancelOnMove ?? false;

  final Duration? _delayTouchDown;

  /// 触摸按下后等待多久激活 `hasTap`，默认立即激活；鼠标与笔不延迟。
  /// 负值在读取时触发断言，以保留常量构造能力。
  Duration get delayTouchDown {
    final value = _delayTouchDown ?? Duration.zero;
    assert(value >= Duration.zero, 'delayTouchDown 必须大于等于 0。');
    return value;
  }

  final Duration? _delayTouchUp;

  /// 从触摸按下起算的最短 `hasTap` 反馈时间，默认 100ms；正常抬手只补剩余时间，不延迟点击。
  ///
  /// 尚未激活的状态不补播，取消、拖拽接管、禁用与卸载立即清理；零值关闭保留。
  /// 负值在读取时触发断言，以保留常量构造能力。
  Duration get delayTouchUp {
    final value = _delayTouchUp ?? const Duration(milliseconds: 100);
    assert(value >= Duration.zero, 'delayTouchUp 必须大于等于 0。');
    return value;
  }

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
  /// null 表示按设备采用系统阈值：单轴拖拽与双轴竞争的垂直轴采用
  /// hit slop，自由拖拽与双轴竞争的水平轴采用 pan slop。
  /// 显式值直接用于所有轴向，未激活前允许根据后续位移重新判轴。
  final double? dragStartDistance;

  final Set<PointerDeviceKind>? _dragDevices;

  /// 可参与拖拽识别的设备；null 表示不限制。
  Set<PointerDeviceKind>? get dragDevices => _dragDevices;

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

  final Set<TargetPlatform>? _dragResampling;

  /// 允许本节点启用拖拽重采样（帧驱动插值）的平台集合。
  ///
  /// `null` 回落内部默认 **{android}**；声明即**整值覆写**（集合整体替换，
  /// 不做并集）。
  /// 指针矩阵由 dispatcher 判定：Android 收 touch；Windows 仅在显式加入后
  /// 收 touch + mouse；管线未接入的平台放进集合也不生效
  /// （iOS/macOS 系统按刷新率对齐投递触摸，无此需求）。全局调试总闸见
  /// `ElEventDispatcher.enableDragResampling`。
  Set<TargetPlatform> get dragResampling =>
      _dragResampling ?? _kDefaultDragResamplingPlatforms;

  static const Set<TargetPlatform> _kDefaultDragResamplingPlatforms = {
    TargetPlatform.android,
  };

  // ---------------------------------------------------------------------------

  bool get _allSet =>
      _doubleTapInterval != null &&
      _tripleTapInterval != null &&
      _longPressDelay != null &&
      _longPressCancelDistance != null &&
      _tapCancelDistance != null &&
      _tapCancelOnMove != null &&
      _delayTouchDown != null &&
      _delayTouchUp != null &&
      _deferTap != null &&
      dragStartDistance != null &&
      _dragDevices != null &&
      _dragHorizontalAngle != null &&
      dragMinFlingDistance != null &&
      _dragMinFlingVelocity != null &&
      _dragMaxFlingVelocity != null &&
      _dragResampling != null;

  bool get _allUnset =>
      _doubleTapInterval == null &&
      _tripleTapInterval == null &&
      _longPressDelay == null &&
      _longPressCancelDistance == null &&
      _tapCancelDistance == null &&
      _tapCancelOnMove == null &&
      _delayTouchDown == null &&
      _delayTouchUp == null &&
      _deferTap == null &&
      dragStartDistance == null &&
      _dragDevices == null &&
      _dragHorizontalAngle == null &&
      dragMinFlingDistance == null &&
      _dragMinFlingVelocity == null &&
      _dragMaxFlingVelocity == null &&
      _dragResampling == null;

  /// 以 [base] 为底合并：本配置已设置的字段覆盖，未设置的沿用 [base]。
  ///
  /// 字段级覆盖的折叠算子。
  ElEventConfig withFallback(ElEventConfig base) {
    if (identical(this, base) || _allSet) return this;
    if (_allUnset) return base;
    return ElEventConfig(
      doubleTapInterval: _doubleTapInterval ?? base._doubleTapInterval,
      tripleTapInterval: _tripleTapInterval ?? base._tripleTapInterval,
      longPressDelay: _longPressDelay ?? base._longPressDelay,
      longPressCancelDistance:
          _longPressCancelDistance ?? base._longPressCancelDistance,
      tapCancelDistance: _tapCancelDistance ?? base._tapCancelDistance,
      tapCancelOnMove: _tapCancelOnMove ?? base._tapCancelOnMove,
      delayTouchDown: _delayTouchDown ?? base._delayTouchDown,
      delayTouchUp: _delayTouchUp ?? base._delayTouchUp,
      deferTap: _deferTap ?? base._deferTap,
      dragStartDistance: dragStartDistance ?? base.dragStartDistance,
      dragDevices: _dragDevices ?? base._dragDevices,
      dragHorizontalAngle: _dragHorizontalAngle ?? base._dragHorizontalAngle,
      dragMinFlingDistance: dragMinFlingDistance ?? base.dragMinFlingDistance,
      dragMinFlingVelocity: _dragMinFlingVelocity ?? base._dragMinFlingVelocity,
      dragMaxFlingVelocity: _dragMaxFlingVelocity ?? base._dragMaxFlingVelocity,
      dragResampling: _dragResampling ?? base._dragResampling,
    );
  }

  /// 拷贝并覆盖部分字段（缺省字段保持原状态，含"未设置"状态）。
  ElEventConfig copyWith({
    Duration? doubleTapInterval,
    Duration? tripleTapInterval,
    Duration? longPressDelay,
    double? longPressCancelDistance,
    double? tapCancelDistance,
    bool? tapCancelOnMove,
    Duration? delayTouchDown,
    Duration? delayTouchUp,
    bool? deferTap,
    double? dragStartDistance,
    Set<PointerDeviceKind>? dragDevices,
    double? dragHorizontalAngle,
    double? dragMinFlingDistance,
    double? dragMinFlingVelocity,
    double? dragMaxFlingVelocity,
    Set<TargetPlatform>? dragResampling,
  }) {
    return ElEventConfig(
      doubleTapInterval: doubleTapInterval ?? _doubleTapInterval,
      tripleTapInterval: tripleTapInterval ?? _tripleTapInterval,
      longPressDelay: longPressDelay ?? _longPressDelay,
      longPressCancelDistance:
          longPressCancelDistance ?? _longPressCancelDistance,
      tapCancelDistance: tapCancelDistance ?? _tapCancelDistance,
      tapCancelOnMove: tapCancelOnMove ?? _tapCancelOnMove,
      delayTouchDown: delayTouchDown ?? _delayTouchDown,
      delayTouchUp: delayTouchUp ?? _delayTouchUp,
      deferTap: deferTap ?? _deferTap,
      dragStartDistance: dragStartDistance ?? this.dragStartDistance,
      dragDevices: dragDevices ?? _dragDevices,
      dragHorizontalAngle: dragHorizontalAngle ?? _dragHorizontalAngle,
      dragMinFlingDistance: dragMinFlingDistance ?? this.dragMinFlingDistance,
      dragMinFlingVelocity: dragMinFlingVelocity ?? _dragMinFlingVelocity,
      dragMaxFlingVelocity: dragMaxFlingVelocity ?? _dragMaxFlingVelocity,
      dragResampling: dragResampling ?? _dragResampling,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ElEventConfig &&
        other._doubleTapInterval == _doubleTapInterval &&
        other._tripleTapInterval == _tripleTapInterval &&
        other._longPressDelay == _longPressDelay &&
        other._longPressCancelDistance == _longPressCancelDistance &&
        other._tapCancelDistance == _tapCancelDistance &&
        other._tapCancelOnMove == _tapCancelOnMove &&
        other._delayTouchDown == _delayTouchDown &&
        other._delayTouchUp == _delayTouchUp &&
        other._deferTap == _deferTap &&
        other.dragStartDistance == dragStartDistance &&
        setEquals(other._dragDevices, _dragDevices) &&
        other._dragHorizontalAngle == _dragHorizontalAngle &&
        other.dragMinFlingDistance == dragMinFlingDistance &&
        other._dragMinFlingVelocity == _dragMinFlingVelocity &&
        other._dragMaxFlingVelocity == _dragMaxFlingVelocity &&
        // Set 无深比较，用 setEquals（乱序等值集合视为同配置，避免 rebuild
        // 新建集合被误判结构替换）。
        setEquals(other._dragResampling, _dragResampling);
  }

  @override
  int get hashCode => Object.hash(
    _doubleTapInterval,
    _tripleTapInterval,
    _longPressDelay,
    _longPressCancelDistance,
    _tapCancelDistance,
    _tapCancelOnMove,
    _delayTouchDown,
    _delayTouchUp,
    _deferTap,
    dragStartDistance,
    _dragDevices == null ? null : Object.hashAllUnordered(_dragDevices),
    _dragHorizontalAngle,
    dragMinFlingDistance,
    _dragMinFlingVelocity,
    _dragMaxFlingVelocity,
    // 与 setEquals 口径配套：等值集合必须同 hash（无序聚合）。
    _dragResampling == null ? null : Object.hashAllUnordered(_dragResampling),
  );
}
