import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable, internal, precisionErrorTolerance;
import 'package:flutter/gestures.dart' show PointerDeviceKind, PointerRemovedEvent;
import 'package:flutter/physics.dart' show FrictionSimulation, SpringDescription, SpringSimulation, Tolerance;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_base/src/flutter/views/view/event/event.dart';
import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart';
import 'package:flutter_base/src/flutter/views/view/style/animation/driver.dart' show elDisableAnimations;
import 'package:flutter_base/src/flutter/views/view/view.dart';

/// 缩放视图的可控变换值；[offset] 是相对 [ElZoomView.alignment] 基位的平移。
@immutable
final class ElZoomTransform {
  /// 创建缩放、旋转和平移的不可变快照。
  const ElZoomTransform({this.scale = 1.0, this.rotation = 0.0, this.offset = Offset.zero})
    : assert(scale > 0 && scale < double.infinity),
      assert(rotation > double.negativeInfinity && rotation < double.infinity);

  /// 缩放倍数，必须有限且大于零。
  final double scale;

  /// 顺时针旋转弧度。
  final double rotation;

  /// 视口逻辑坐标中的平移。
  final Offset offset;

  /// 复制并替换指定分量。
  ElZoomTransform copyWith({double? scale, double? rotation, Offset? offset}) =>
      ElZoomTransform(scale: scale ?? this.scale, rotation: rotation ?? this.rotation, offset: offset ?? this.offset);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElZoomTransform && other.scale == scale && other.rotation == rotation && other.offset == offset;

  @override
  int get hashCode => Object.hash(scale, rotation, offset);
}

/// 读取、跳转或动画控制一个 live [ElZoomView]；同一时刻只能绑定一个宿主。
final class ElZoomController extends ChangeNotifier {
  /// 创建控制器；未挂载时完整保留 [initialValue]，挂载后由宿主边界钳制。
  ElZoomController({ElZoomTransform initialValue = const ElZoomTransform()}) {
    _validate(initialValue);
    _scale = initialValue.scale;
    _rotation = initialValue.rotation;
    _offset = initialValue.offset;
  }

  late double _scale;
  late double _rotation;
  late Offset _offset;
  _ZoomViewState? _host;
  bool _disposed = false;

  /// 当前变换快照。
  ElZoomTransform get value => ElZoomTransform(scale: _scale, rotation: _rotation, offset: _offset);

  /// 立即应用新值；挂载时由宿主钳制后回写实际值。
  set value(ElZoomTransform value) => jumpTo(value);

  /// 立即跳转到 [value]。
  void jumpTo(ElZoomTransform value) {
    _validate(value);
    final host = _host;
    if (host != null) {
      host._applyControllerTransform(value);
    } else {
      _setValue(value.scale, value.rotation, value.offset);
    }
  }

  /// 动画到 [value]；未挂载时立即落最终值并返回已完成 Future。
  Future<void> animateTo(
    ElZoomTransform value, {
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeOutCubic,
  }) {
    _validate(value);
    final host = _host;
    if (host == null) {
      _setValue(value.scale, value.rotation, value.offset);
      return Future<void>.value();
    }
    return host._animateToTransform(value, duration: duration, curve: curve);
  }

  /// 回到 identity；挂载时 identity 会继续受 min/max 与边界钳制。
  Future<void> reset({bool animate = true}) {
    if (animate) return animateTo(const ElZoomTransform());
    jumpTo(const ElZoomTransform());
    return Future<void>.value();
  }

  /// 设置不进入 [value] 的临时屏幕平移，仅供 Preview 无跳变交接使用。
  @internal
  void setTransientTranslation(double dx, double dy) => _host?._setTransientTranslation(dx, dy);

  /// 停止当前动画，并可同步完成尚未结束的内部归位，仅供 Preview 协调交互使用。
  @internal
  void stopAnimation({bool settlePendingTransform = true}) =>
      _host?._stopControlledAnimation(settlePendingTransform: settlePendingTransform);

  void _attach(_ZoomViewState host) {
    if (_disposed) throw FlutterError('已 dispose 的 ElZoomController 不能再次绑定。');
    final current = _host;
    if (current != null && !identical(current, host)) {
      throw FlutterError('一个 ElZoomController 同一时刻只能绑定一个 live ElZoomView。');
    }
    _host = host;
    host._applyControllerTransform(value, stopAnimation: false);
  }

  void _detach(_ZoomViewState host) {
    if (identical(_host, host)) _host = null;
  }

  void _syncFromHost(double scale, double rotation, Offset offset) {
    if (!_disposed) _setValue(scale, rotation, offset);
  }

  void _setValue(double scale, double rotation, Offset offset) {
    if (_scale == scale && _rotation == rotation && _offset == offset) return;
    _scale = scale;
    _rotation = rotation;
    _offset = offset;
    notifyListeners();
  }

  static void _validate(ElZoomTransform value) {
    if (!value.scale.isFinite ||
        value.scale <= 0 ||
        !value.rotation.isFinite ||
        !value.offset.dx.isFinite ||
        !value.offset.dy.isFinite) {
      throw ArgumentError.value(value, 'value', 'ElZoomTransform 的全部分量必须有限且 scale > 0');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _host = null;
    super.dispose();
  }
}

/// 双指缩放视图：捏合缩放 / 缩放后单指平移 / 双击缩放切换 / 触控板捏合 /
/// 松手惯性平移与可选的对数缩放惯性。
///
/// 内容可紧约束到视口或按实际尺寸布局，变换只作用于自定义 render 的
/// paint/hit/semantics 同源矩阵。手势/动画逐帧只更新缓存矩阵并重绘，业务
/// child 零重建零重排。典型用途：图片查看器、画布、图表。
///
/// ## 手势归属（与滚动共存的关键语义）
///
/// - **双指捏合**：事件层在捏合成立时对参与指针的全部序列 eager 独占
///   （见 `_claimEagerForScalePointers`），祖先滚动不会并行消费；
/// - **已缩放单指平移走 drag 通道**（滚动级体验的关键）：起手阈值压到
///   8px（≤ 真机滚动设备 slop），dragStart 即
///   [ElEventDetails.eagerGesture] 独占——嵌在滚动/翻页容器里也由本组件
///   消费；velocity 走拖拽速度栈，松手惯性与滚动同源。已接受的拖拽整段
///   持有手势（单指 scale 起步让位，见 [_ScaleMachine]），双指落下捏合
///   仍可接管（dragCancel → 焦点通道续接）；
/// - **未缩放单指滑动**：本组件不消费、不独占——dragStart 空转放行，祖先
///   滚动在同一 move 里照常接受（列表里嵌图片查看器的场景）；
/// - **双击**：第二次按下立即在 [minScale] 与 [doubleTapScale] 之间切换，围绕点击位置锚定；
/// - **触控板**：`onPointerPanZoomUpdate` 的捏合缩放直接消费（stopPropagation
///   阻断祖先），纯平移在未缩放时放行给祖先滚动。
///
/// 祖先 Scroll 已开始消费第一指时会保留本 Scale shadow；第二指加入后原子
/// 取消 Scroll 并接管，两指减回一指后首帧继续平移。缩放后单指拖到内容边界
/// 时，只在 [ElEvent.dragProxy] 管线中登记实际位移，余量可同帧交给分页宿主。
class ElZoomView extends StatefulWidget {
  /// 创建双指缩放视图。
  const ElZoomView({
    super.key,
    required this.child,
    this.controller,
    this.minScale = 1.0,
    this.maxScale = 4.0,
    this.doubleTapScale = 2.0,
    this.scaleSensitivity = 1.0,
    this.enableDoubleTapZoom = true,
    this.enablePan = true,
    this.enableRotation = false,
    this.panInertia = true,
    this.scaleInertia = false,
    this.mouseWheelZoom = false,
    this.mouseDragPan = true,
    this.wheelScaleSensitivity = 0.002,
    this.elasticScaleBounds = false,
    this.lockScaleRotationIntent = false,
    this.constrained = true,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.hardEdge,
    this.onZoomChanged,
    this.onTransformChanged,
    this.interactionEnabled = true,
    this.onPanEnd,
    this.onPanCancel,
    this.onPointerCountChanged,
  }) : assert(minScale > 0 && minScale < double.infinity, 'minScale 必须为有限正数'),
       assert(maxScale >= minScale && maxScale < double.infinity, 'maxScale 必须有限且不得小于 minScale'),
       assert(scaleSensitivity > 0 && scaleSensitivity < double.infinity, 'scaleSensitivity 必须为有限正数'),
       assert(wheelScaleSensitivity > 0 && wheelScaleSensitivity < double.infinity, 'wheelScaleSensitivity 必须为有限正数');

  /// 被缩放的任意 Widget；布局方式由 [constrained] 决定。
  final Widget child;

  /// 外部变换控制器；同一个实例只能绑定一个 live 宿主。
  final ElZoomController? controller;

  /// 最小缩放倍数。捏合缩小止步于此；小于 1.0 时缩小后的内容轴向居中。
  final double minScale;

  /// 最大缩放倍数。
  final double maxScale;

  /// 双击缩放的目标倍数（自动钳制到 [minScale]..[maxScale]）。
  final double doubleTapScale;

  /// 双指捏合的对数缩放增益；1 表示严格跟随原始指距比例。
  final double scaleSensitivity;

  /// 是否启用双击缩放切换。
  final bool enableDoubleTapZoom;

  /// 是否允许缩放后单指平移。
  final bool enablePan;

  /// 是否把触摸 Scale 的旋转分量应用到内容。
  /// 边界按旋转后 projected AABB 约束，不自动放大内容去裁切填满四角。
  final bool enableRotation;

  /// 是否在手指释放后继续平移惯性。
  final bool panInertia;

  /// 是否在双指近同时释放后按对数缩放速度继续缩放惯性。
  final bool scaleInertia;

  /// 是否让物理鼠标滚轮围绕光标缩放；默认关闭以免抢走祖先滚动。
  final bool mouseWheelZoom;

  /// 是否允许鼠标主键参与内容平移；触摸与手写笔不受此开关影响。
  final bool mouseDragPan;

  /// 鼠标滚轮每个逻辑像素对应的对数缩放量。
  final double wheelScaleSensitivity;

  /// 是否允许直接捏合临时越过缩放边界并在结束后回弹，仅供 Preview 开启。
  @internal
  final bool elasticScaleBounds;

  /// 是否启用 Preview 双指稳定策略：双指不平移，缩放锁旋转而旋转可同步缩放，松手吸附直角。
  @internal
  final bool lockScaleRotationIntent;

  /// true 时 child 紧约束到视口；false 时按自身实际尺寸布局。
  /// false 时 child 需自行选择有限尺寸。
  final bool constrained;

  /// 内容小于视口时的基位与边界对齐方式。
  final Alignment alignment;

  /// 视口裁剪方式。
  final Clip clipBehavior;

  /// 缩放倍数变化回调（手势与动画期间逐帧触发）。
  final ValueChanged<double>? onZoomChanged;

  /// 变换变化回调；仅声明时才为当前帧构造 [ElZoomTransform] 快照。
  final ValueChanged<ElZoomTransform>? onTransformChanged;

  /// 是否创建手势入口与动画 ticker，仅供预加载宿主关闭非当前页交互。
  @internal
  final bool interactionEnabled;

  /// 把 drag 通道终速交给 Preview；返回 true 时由 Preview 接管 settle。
  @internal
  final bool Function(Velocity velocity)? onPanEnd;

  /// 通知 Preview 当前 drag 通道被取消。
  @internal
  final VoidCallback? onPanCancel;

  /// 把当前活动指针数回传给 Preview，用于 Scale 独占后协调外层交接收尾。
  @internal
  final ValueChanged<int>? onPointerCountChanged;

  @override
  State<ElZoomView> createState() => _ZoomViewState();
}

enum _TouchTransformIntent { scale, rotation }

class _ZoomViewState extends State<ElZoomView> with TickerProviderStateMixin {
  /// 官方 InteractiveViewer 同款惯性阻力系数。
  static const double _kDrag = 0.0000135;

  /// 对数缩放使用独立阻力，避免沿用像素平移参数后甩动过冲。
  static const double _kScaleDrag = 0.0027;
  static const double _kPanStopVelocity = 10;
  static const double _kMinLogScaleVelocity = 0.1, _kMaxLogScaleVelocity = 8;

  /// 为边界回弹预留反向承接末速的行程，避免有界 controller 截断负进度。
  static const double _kElasticSpringStart = 0.2;
  static const double _kElasticScaleExtent = 0.15, _kElasticScaleFriction = 0.52;
  static const double _kTouchScaleIntentThreshold = 0.03;
  static const double _kTouchRotationIntentThreshold = math.pi / 60;
  static const Duration _kWheelAnimationDuration = Duration(milliseconds: 120);
  static const SpringDescription _kScaleSpring = SpringDescription(mass: 1, stiffness: 820, damping: 60);
  static const Tolerance _kScaleSpringTolerance = Tolerance(distance: 0.0005, velocity: 0.01);
  static const Set<PointerDeviceKind> _nonMouseDragDevices = {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };

  late double _scale;
  double _rotation = 0.0;
  double _transientDx = 0.0;
  double _transientDy = 0.0;

  /// 内容左上角在视口坐标系中的位置（缩放锚点恒为左上，位移显式记账）。
  Offset _offset = Offset.zero;
  Size _viewSize = Size.zero;
  Size _childSize = Size.zero;
  bool _geometryNeedsReclamp = false;
  bool _geometryNotificationScheduled = false;
  bool _geometryShellRebuildScheduled = false;
  bool _eventHasPanExtent = false;
  bool _eventShellRebuildDeferred = false;
  int _activePointerCount = 0;

  /// 变换宿主 render：手势/动画 tick 只对它 markNeedsPaint。
  _RenderZoomTransform? _render;

  // --- 手势基线 -------------------------------------------------------------
  double _gestureBaseScale = 1.0;
  double _gestureScaleSensitivity = 1.0;
  double _gestureBaseRotation = 0.0;
  bool _gestureActive = false;
  Offset? _gestureFocal;
  bool _gestureRotationEnabled = false;
  bool _touchTransformIntentLockActive = false;
  _TouchTransformIntent? _touchTransformIntent;
  bool _multiPointerTransformSeen = false;
  bool _rotationIntentSeen = false;
  double _touchSegmentBaseEventScale = 1.0;
  double _touchSegmentBaseEventRotation = 0.0;
  double _lastTouchEventScale = 1.0;
  double _lastTouchEventRotation = 0.0;

  /// scale 手势是否由缩放视图消费（双指捏合恒消费；单指仅在已缩放时消费）。
  bool _consuming = false;

  /// 已缩放单指平移（drag 通道）是否在消费中。
  bool _dragConsuming = false;

  /// 当前 drag 是否实际改变过 offset，防止后代 Scroll 的终速误启动本层惯性。
  bool _dragApplied = false;
  late final ElDragProxy _dragProxy = ElDragProxy(onDragOverflow: _onDragUpdate);

  // --- 触控板基线 -----------------------------------------------------------
  double _panZoomBaseScale = 1.0;
  double _panZoomScaleSensitivity = 1.0;
  bool _panZoomPinching = false;

  // --- 动画（双击缩放 / 松手惯性共用一个 controller） -------------------------
  /// 非当前预加载页不创建 ticker，激活后才建立并在失活时释放。
  AnimationController? _animation;
  Animation<double>? _scaleAnimation;
  Animation<double>? _rotationAnimation;
  Animation<Offset>? _offsetAnimation;
  Animation<Offset>? _panDeltaAnimation;
  FrictionSimulation? _logScaleFriction;
  FrictionSimulation? _panFrictionX;
  FrictionSimulation? _panFrictionY;
  double _logScaleFrictionEndTime = 0.0;
  double? _logScaleFrictionTarget;
  double _panFrictionEndTimeX = 0.0;
  double _panFrictionEndTimeY = 0.0;
  double? _anchoredStartLogScale;
  double? _anchoredTargetLogScale;
  Offset? _ballisticAnchorChild;
  Offset? _ballisticAnchorViewport;
  Offset _elasticOffsetCorrection = Offset.zero;
  bool _elasticScaleAnimation = false;
  bool _deferOffsetClampAnimation = false;
  double? _pendingSettleRotation;
  Completer<void>? _animationCompleter;

  @override
  void initState() {
    super.initState();
    _scale = 1.0.clamp(widget.minScale, widget.maxScale);
    if (widget.interactionEnabled) _ensureAnimation();
    widget.controller?._attach(this);
  }

  /// 当前缩放倍数（供测试与外部读取）。
  double get zoomScale => _scale;

  /// 当前内容平移（供测试与外部读取）。
  Offset get zoomOffset => _offset;

  ElZoomTransform get _transform => ElZoomTransform(scale: _scale, rotation: _rotation, offset: _offset);

  bool get _zoomed => _scale > widget.minScale + precisionErrorTolerance;

  ElEventConfig? get _eventConfig {
    if (!widget.enablePan) return null;
    if (widget.mouseDragPan) {
      return _eventHasPanExtent ? const ElEventConfig(dragStartDistance: 8.0) : null;
    }
    return _eventHasPanExtent
        ? const ElEventConfig(dragStartDistance: 8.0, dragDevices: _nonMouseDragDevices)
        : const ElEventConfig(dragDevices: _nonMouseDragDevices);
  }

  bool get _hasPanExtent {
    if (_viewSize.isEmpty || _childSize.isEmpty) return _zoomed;
    final cos = _rotation == 0.0 ? 1.0 : math.cos(_rotation).abs();
    final sin = _rotation == 0.0 ? 0.0 : math.sin(_rotation).abs();
    final width = (cos * _childSize.width + sin * _childSize.height) * _scale;
    final height = (sin * _childSize.width + cos * _childSize.height) * _scale;
    return width > _viewSize.width + precisionErrorTolerance || height > _viewSize.height + precisionErrorTolerance;
  }

  bool _canPanToward(ElEventDetails event) {
    var delta = event.remainingLocalDelta;
    if (delta == Offset.zero) {
      delta = switch (event.dragDirection) {
        AxisDirection.left => const Offset(-1, 0),
        AxisDirection.right => const Offset(1, 0),
        AxisDirection.up => const Offset(0, -1),
        AxisDirection.down => const Offset(0, 1),
        null => Offset.zero,
      };
    }
    return delta != Offset.zero && _clampOffset(_offset + delta, _scale) != _offset;
  }

  @override
  void didUpdateWidget(covariant ElZoomView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_gestureActive && widget.enableRotation != oldWidget.enableRotation) _eventShellRebuildDeferred = true;
    if (!identical(widget.controller, oldWidget.controller)) {
      _stopAnimation();
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (widget.interactionEnabled != oldWidget.interactionEnabled) {
      if (widget.interactionEnabled) {
        _ensureAnimation();
      } else {
        _cancelDirectScale();
        _stopAnimation();
        _disposeAnimation();
      }
    }
    final scaleBoundsChanged = widget.minScale != oldWidget.minScale || widget.maxScale != oldWidget.maxScale;
    if (scaleBoundsChanged && _elasticScaleAnimation) _stopAnimation();
    if (scaleBoundsChanged) {
      _apply(_scale, _offset);
    }
    if (!_elasticScaleAnimation &&
        _anchoredTargetLogScale != null &&
        (scaleBoundsChanged ||
            !widget.mouseWheelZoom ||
            widget.wheelScaleSensitivity != oldWidget.wheelScaleSensitivity)) {
      _stopAnimation();
    }
    if (widget.constrained != oldWidget.constrained || widget.alignment != oldWidget.alignment) {
      _geometryNeedsReclamp = true;
      _render?.markNeedsLayout();
    } else if (widget.clipBehavior != oldWidget.clipBehavior) {
      _render?.markNeedsPaint();
      _render?.markNeedsSemanticsUpdate();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _disposeAnimation();
    super.dispose();
  }

  // ---------------------------------------------------------------------------

  void _apply(double scale, Offset offset, {double? rotation, bool elastic = false}) {
    if (!scale.isFinite || scale <= 0 || !offset.dx.isFinite || !offset.dy.isFinite) return;
    final nextScale = elastic ? scale : scale.clamp(widget.minScale, widget.maxScale);
    final nextRotation = rotation ?? _rotation;
    if (!nextRotation.isFinite) return;
    final clamped = elastic ? offset : _clampOffset(offset, nextScale, nextRotation);
    if (nextScale == _scale && nextRotation == _rotation && clamped == _offset) return;
    final scaleChanged = nextScale != _scale;
    final extentChanged = scaleChanged || nextRotation != _rotation;
    final wasZoomed = _zoomed;
    _scale = nextScale;
    _rotation = nextRotation;
    _offset = clamped;
    // 逐帧变换只落在自定义 render 上（markNeedsPaint + 语义几何失效），
    // 零 setState、零 shell 子树重建。
    _render?.noteTransformChanged();
    // 越过缩放档位边界才重建 shell：事件起手阈随 _zoomed 切换（罕见路径）。
    var rebuildShell = _zoomed != wasZoomed;
    if (extentChanged) {
      final hasPanExtent = _hasPanExtent;
      if (hasPanExtent != _eventHasPanExtent) {
        _eventHasPanExtent = hasPanExtent;
        rebuildShell = true;
      }
    }
    if (rebuildShell) _requestEventShellRebuild();
    widget.controller?._syncFromHost(_scale, _rotation, _offset);
    if (scaleChanged) widget.onZoomChanged?.call(_scale);
    final onTransformChanged = widget.onTransformChanged;
    if (onTransformChanged != null) onTransformChanged(_transform);
  }

  /// 按旋转后 projected AABB 钳制中心；小内容按 [ElZoomView.alignment] 对齐。
  Offset _clampOffset(Offset offset, double scale, [double? rotation]) {
    if (_viewSize.isEmpty || _childSize.isEmpty) return offset;
    final angle = rotation ?? _rotation;
    final cos = angle == 0.0 ? 1.0 : math.cos(angle).abs();
    final sin = angle == 0.0 ? 0.0 : math.sin(angle).abs();
    final halfWidth = (cos * _childSize.width + sin * _childSize.height) * scale / 2;
    final halfHeight = (sin * _childSize.width + cos * _childSize.height) * scale / 2;
    final base = _alignedChildCenter;
    final center = base + offset;
    final clampedCenter = Offset(
      _clampCenter(center.dx, _viewSize.width, halfWidth, widget.alignment.x),
      _clampCenter(center.dy, _viewSize.height, halfHeight, widget.alignment.y),
    );
    return clampedCenter - base;
  }

  double _clampCenter(double center, double view, double halfExtent, double alignment) {
    if (halfExtent * 2 <= view) return (view - halfExtent * 2) * (alignment + 1) / 2 + halfExtent;
    return center.clamp(view - halfExtent, halfExtent);
  }

  Offset get _alignedChildCenter => Offset(
    (_viewSize.width - _childSize.width) * (widget.alignment.x + 1) / 2 + _childSize.width / 2,
    (_viewSize.height - _childSize.height) * (widget.alignment.y + 1) / 2 + _childSize.height / 2,
  );

  Offset get _transformedChildCenter => _alignedChildCenter + _offset + Offset(_transientDx, _transientDy);

  Offset _rotate(Offset value, double angle) {
    if (angle == 0.0) return value;
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Offset(value.dx * cos - value.dy * sin, value.dx * sin + value.dy * cos);
  }

  Offset _childPointAt(Offset viewportPoint) {
    final base = _alignedChildCenter;
    final translated = Offset(
      viewportPoint.dx - base.dx - _offset.dx - _transientDx,
      viewportPoint.dy - base.dy - _offset.dy - _transientDy,
    );
    return _rotate(translated, -_rotation) / _scale + _childSize.center(Offset.zero);
  }

  Offset _offsetForAnchor(Offset childPoint, Offset viewportPoint, double scale, double rotation) {
    final base = _alignedChildCenter;
    final projected = _rotate(childPoint - _childSize.center(Offset.zero), rotation) * scale;
    return Offset(
      viewportPoint.dx - base.dx - _transientDx - projected.dx,
      viewportPoint.dy - base.dy - _transientDy - projected.dy,
    );
  }

  void _setTransientTranslation(double dx, double dy) {
    if (!dx.isFinite || !dy.isFinite || (_transientDx == dx && _transientDy == dy)) return;
    _transientDx = dx;
    _transientDy = dy;
    _render?.noteTransformChanged();
  }

  /// render 布局回报视口与实际 child 尺寸，并在同一 layout 后重算矩阵。
  void _handleGeometryChanged(Size viewSize, Size childSize) {
    if (viewSize == _viewSize && childSize == _childSize && !_geometryNeedsReclamp) return;
    final preserveAnchor = !_geometryNeedsReclamp;
    final oldChildSize = _childSize;
    final screenAnchor = _gestureFocal ?? _viewSize.center(Offset.zero);
    final oldChildAnchor = !preserveAnchor || _viewSize.isEmpty || oldChildSize.isEmpty
        ? null
        : _childPointAt(screenAnchor);
    _geometryNeedsReclamp = false;
    _viewSize = viewSize;
    _childSize = childSize;
    final previousOffset = _offset;
    var nextOffset = _offset;
    if (oldChildAnchor != null && (Offset.zero & oldChildSize).contains(oldChildAnchor) && !childSize.isEmpty) {
      final resizedAnchor = Offset(
        oldChildAnchor.dx * childSize.width / oldChildSize.width,
        oldChildAnchor.dy * childSize.height / oldChildSize.height,
      );
      final nextScreenAnchor = _gestureFocal ?? viewSize.center(Offset.zero);
      nextOffset = _offsetForAnchor(resizedAnchor, nextScreenAnchor, _scale, _rotation);
    }
    _offset = _clampOffset(nextOffset, _scale);
    final hasPanExtent = _hasPanExtent;
    if (hasPanExtent != _eventHasPanExtent) {
      _eventHasPanExtent = hasPanExtent;
      if (!_geometryShellRebuildScheduled) {
        _geometryShellRebuildScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _geometryShellRebuildScheduled = false;
          _requestEventShellRebuild();
        });
      }
    }
    if (_offset == previousOffset ||
        _geometryNotificationScheduled ||
        (widget.controller == null && widget.onTransformChanged == null)) {
      return;
    }
    _geometryNotificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _geometryNotificationScheduled = false;
      if (!mounted) return;
      widget.controller?._syncFromHost(_scale, _rotation, _offset);
      final onTransformChanged = widget.onTransformChanged;
      if (onTransformChanged != null) onTransformChanged(_transform);
    });
  }

  AnimationController _ensureAnimation() {
    return _animation ??= AnimationController(vsync: this)
      ..addListener(_onAnimationTick)
      ..addStatusListener(_onAnimationStatus);
  }

  void _disposeAnimation() {
    final animation = _animation;
    _animation = null;
    animation?.stop();
    _finishAnimationState(settleElastic: false);
    animation?.dispose();
  }

  void _stopAnimation({bool settleElastic = true}) {
    _animation?.stop();
    _finishAnimationState(settleElastic: settleElastic);
  }

  void _stopControlledAnimation({required bool settlePendingTransform}) {
    _stopAnimation();
    if (settlePendingTransform) _resumePendingTransformSettle(animate: false);
  }

  void _finishAnimationState({required bool settleElastic, bool settleDeferredOffset = false}) {
    final completedDeferredSettle = settleDeferredOffset && _deferOffsetClampAnimation;
    double? targetScale;
    Offset? targetOffset;
    if (settleElastic && _elasticScaleAnimation) {
      targetScale = _scale.clamp(widget.minScale, widget.maxScale);
      targetOffset = _clampOffset(
        _offsetForAnchor(_ballisticAnchorChild!, _ballisticAnchorViewport!, targetScale, _rotation),
        targetScale,
      );
    } else if (completedDeferredSettle) {
      targetScale = _scale.clamp(widget.minScale, widget.maxScale);
      targetOffset = _clampOffset(_offset, targetScale);
    }
    _clearAnimationValues();
    if (completedDeferredSettle) _pendingSettleRotation = null;
    _completeAnimationCommand();
    if (targetScale != null) _apply(targetScale, targetOffset!);
  }

  void _clearAnimationValues() {
    _scaleAnimation = null;
    _rotationAnimation = null;
    _offsetAnimation = null;
    _panDeltaAnimation = null;
    _logScaleFriction = null;
    _panFrictionX = null;
    _panFrictionY = null;
    _logScaleFrictionEndTime = 0.0;
    _logScaleFrictionTarget = null;
    _panFrictionEndTimeX = 0.0;
    _panFrictionEndTimeY = 0.0;
    _anchoredStartLogScale = null;
    _anchoredTargetLogScale = null;
    _ballisticAnchorChild = null;
    _ballisticAnchorViewport = null;
    _elasticOffsetCorrection = Offset.zero;
    _elasticScaleAnimation = false;
    _deferOffsetClampAnimation = false;
  }

  void _onAnimationTick() {
    final logScaleFriction = _logScaleFriction;
    final anchoredStart = _anchoredStartLogScale;
    final anchoredTarget = _anchoredTargetLogScale;
    final animation = _animation;
    final animationProgress = animation?.value ?? 1.0;
    final elapsed = animationProgress * (animation?.duration?.inMicroseconds ?? 0) / Duration.microsecondsPerSecond;
    final elasticProgress = _elasticScaleAnimation
        ? (animationProgress - _kElasticSpringStart) / (1 - _kElasticSpringStart)
        : animationProgress;
    if (_elasticScaleAnimation && elasticProgress >= 1) return;
    final double scale;
    if (anchoredStart != null && anchoredTarget != null) {
      final progress = _elasticScaleAnimation ? elasticProgress : Curves.easeOutCubic.transform(animationProgress);
      scale = math.exp(anchoredStart + (anchoredTarget - anchoredStart) * progress);
    } else if (logScaleFriction != null) {
      final logScale = animationProgress >= 1
          ? _logScaleFrictionTarget!
          : logScaleFriction
                .x(math.min(elapsed, _logScaleFrictionEndTime))
                .clamp(math.log(widget.minScale), math.log(widget.maxScale));
      scale = math.exp(logScale);
    } else {
      scale = _scaleAnimation?.value ?? _scale;
    }
    final rotation = _rotationAnimation?.value ?? _rotation;
    final anchorChild = _ballisticAnchorChild;
    final anchorViewport = _ballisticAnchorViewport;
    final panDelta = _elasticScaleAnimation
        ? _elasticOffsetCorrection * elasticProgress
        : _panDeltaAnimation?.value ?? Offset.zero;
    final panFrictionX = _panFrictionX;
    final panFrictionY = _panFrictionY;
    final frictionOffset = panFrictionX == null && panFrictionY == null
        ? null
        : Offset(
            panFrictionX?.x(math.min(elapsed, _panFrictionEndTimeX)) ?? _offset.dx,
            panFrictionY?.x(math.min(elapsed, _panFrictionEndTimeY)) ?? _offset.dy,
          );
    final offset = anchorChild == null || anchorViewport == null
        ? frictionOffset ?? _offsetAnimation?.value ?? _offset
        : _offsetForAnchor(anchorChild, anchorViewport, scale, rotation) + panDelta;
    _apply(scale, offset, rotation: rotation, elastic: _elasticScaleAnimation || _deferOffsetClampAnimation);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      final resumePendingSettle = _pendingSettleRotation != null && !_deferOffsetClampAnimation;
      _finishAnimationState(settleElastic: true, settleDeferredOffset: true);
      if (resumePendingSettle && !(_animation?.isAnimating ?? false)) _resumePendingTransformSettle();
    }
  }

  void _completeAnimationCommand() {
    final completer = _animationCompleter;
    _animationCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _applyControllerTransform(ElZoomTransform value, {bool stopAnimation = true}) {
    _pendingSettleRotation = null;
    if (stopAnimation) _stopAnimation();
    _apply(value.scale, value.offset, rotation: value.rotation);
    widget.controller?._syncFromHost(_scale, _rotation, _offset);
  }

  Future<void> _animateToTransform(
    ElZoomTransform value, {
    required Duration duration,
    required Curve curve,
    bool deferOffsetClamp = false,
    bool preservePendingTransform = false,
  }) {
    if (!preservePendingTransform) _pendingSettleRotation = null;
    _stopAnimation();
    final targetScale = value.scale.clamp(widget.minScale, widget.maxScale);
    final targetOffset = _clampOffset(value.offset, targetScale, value.rotation);
    if (targetScale == _scale && value.rotation == _rotation && targetOffset == _offset) {
      if (deferOffsetClamp) _pendingSettleRotation = null;
      return Future<void>.value();
    }
    if (duration == Duration.zero || elDisableAnimations) {
      _apply(targetScale, targetOffset, rotation: value.rotation);
      if (deferOffsetClamp) {
        _pendingSettleRotation = null;
      } else if (preservePendingTransform) {
        _resumePendingTransformSettle(animate: false);
      }
      return Future<void>.value();
    }
    final animation = _ensureAnimation();
    final curved = animation.drive(CurveTween(curve: curve));
    _scaleAnimation = targetScale == _scale ? null : curved.drive(Tween<double>(begin: _scale, end: targetScale));
    _rotationAnimation = value.rotation == _rotation
        ? null
        : curved.drive(Tween<double>(begin: _rotation, end: value.rotation));
    _offsetAnimation = targetOffset == _offset ? null : curved.drive(Tween<Offset>(begin: _offset, end: targetOffset));
    _deferOffsetClampAnimation = deferOffsetClamp;
    final completer = Completer<void>();
    _animationCompleter = completer;
    animation
      ..duration = duration
      ..forward(from: 0);
    return completer.future;
  }

  bool _settleTransformBounds({double? targetRotation, bool animate = true}) {
    final rotation = targetRotation ?? _rotation;
    final targetScale = _scale.clamp(widget.minScale, widget.maxScale);
    final targetOffset = _clampOffset(_offset, targetScale, rotation);
    if (targetScale == _scale && rotation == _rotation && targetOffset == _offset) {
      _pendingSettleRotation = null;
      return false;
    }
    _pendingSettleRotation = rotation;
    unawaited(
      _animateToTransform(
        ElZoomTransform(scale: targetScale, rotation: rotation, offset: targetOffset),
        duration: animate ? const Duration(milliseconds: 180) : Duration.zero,
        curve: Curves.easeOutCubic,
        // 只按最终朝向计算一次边界，避免中间角度逐帧钳制造成漂移。
        deferOffsetClamp: true,
        preservePendingTransform: true,
      ),
    );
    return true;
  }

  bool _resumePendingTransformSettle({bool animate = true}) {
    final rotation = _pendingSettleRotation;
    if (rotation == null) return false;
    _pendingSettleRotation = null;
    return _settleTransformBounds(targetRotation: rotation, animate: animate);
  }

  void _snapRotationToRightAngle({bool animate = true}) {
    _settleTransformBounds(targetRotation: (_rotation / (math.pi / 2)).round() * (math.pi / 2), animate: animate);
  }

  // --- 触摸捏合 / 已缩放单指平移 ----------------------------------------------

  _TouchTransformIntent? _resolveTouchTransformIntent(double scale, double rotation) {
    if (!scale.isFinite || scale <= 0 || !rotation.isFinite) return null;
    final scaleDelta = scale >= 1 ? scale - 1 : 1 / scale - 1;
    final scaleScore = scaleDelta / _kTouchScaleIntentThreshold;
    final rotationScore = rotation.abs() / _kTouchRotationIntentThreshold;
    if (scaleScore <= precisionErrorTolerance && rotationScore <= precisionErrorTolerance) return null;
    return scaleScore >= rotationScore ? .scale : .rotation;
  }

  void _beginTouchTransformSegment() {
    _touchTransformIntent = null;
    _touchSegmentBaseEventScale = _lastTouchEventScale;
    _touchSegmentBaseEventRotation = _lastTouchEventRotation;
    _gestureBaseScale = _rawGestureScale(_scale);
    _gestureBaseRotation = _rotation;
  }

  void _onScaleStart(ElEventDetails e) {
    _stopAnimation(settleElastic: !_elasticScaleAnimation);
    _gestureActive = true;
    _gestureRotationEnabled = widget.enableRotation;
    _touchTransformIntentLockActive = widget.lockScaleRotationIntent && _gestureRotationEnabled;
    _touchTransformIntent = null;
    _multiPointerTransformSeen = e.pointerCount >= 2;
    _rotationIntentSeen = false;
    _gestureBaseScale = _rawGestureScale(_scale);
    // 增益在一次手势内冻结，热更新只影响下一手，避免累计比例重算后跳变。
    _gestureScaleSensitivity = widget.scaleSensitivity;
    _gestureBaseRotation = _rotation;
    _touchSegmentBaseEventScale = 1.0;
    _touchSegmentBaseEventRotation = 0.0;
    _lastTouchEventScale = 1.0;
    _lastTouchEventRotation = 0.0;
    _gestureFocal = e.localPosition;
    // 双指捏合事件层已整体独占；单指只有已缩放才归本组件（eager 阻断祖先
    // 滚动），未缩放时让给祖先。
    _consuming = e.pointerCount >= 2 || _hasPanExtent;
    if (_consuming) e.eagerGesture(cancelSelfTap: true);
    // 独占会取消分页祖先的 raw 输入，随后用真实 Scale 触点数恢复门禁。
    widget.onPointerCountChanged?.call(e.pointerCount);
  }

  void _onPointerDown(ElEventDetails e) {
    _activePointerCount = e.pointerCount;
    widget.onPointerCountChanged?.call(e.pointerCount);
    if (!_elasticScaleAnimation) _stopAnimation();
    if (_gestureActive && _touchTransformIntentLockActive && e.pointerCount == 2) {
      // 补指时事件机保留累计值；组件另开相对片段，避免旧意图锁死或矩阵跳变。
      _beginTouchTransformSegment();
    }
  }

  void _onPointerTerminal(ElEventDetails e) {
    _activePointerCount = e.pointerCount;
    widget.onPointerCountChanged?.call(e.pointerCount);
    if (_activePointerCount == 0 && _eventShellRebuildDeferred) {
      _eventShellRebuildDeferred = false;
      // raw PointerUp 早于 Tap 状态机结算；延到当前事件派发结束后再换配置，
      // 否则第二次按下启动缩放会把下一轮连击窗口一并清掉。
      scheduleMicrotask(() {
        if (mounted && (_render?.attached ?? false)) setState(() {});
      });
    }
    if (e.pointerCount != 0 || _pendingSettleRotation == null) return;
    scheduleMicrotask(() {
      if (!mounted || _gestureActive || _dragConsuming || (_animation?.isAnimating ?? false)) return;
      _resumePendingTransformSettle();
    });
  }

  void _requestEventShellRebuild() {
    if (!mounted || !(_render?.attached ?? false)) return;
    if (_activePointerCount != 0) {
      _eventShellRebuildDeferred = true;
      return;
    }
    setState(() {});
  }

  void _onScaleUpdate(ElEventDetails e) {
    if (!_gestureActive) return;
    widget.onPointerCountChanged?.call(e.pointerCount);
    final focal = e.localPosition;
    _gestureFocal = focal;
    if (!_consuming && e.pointerCount >= 2) {
      _consuming = true;
      e.eagerGesture(cancelSelfTap: true);
    }
    if (!_consuming) return;
    if (e.pointerCount >= 2) _multiPointerTransformSeen = true;
    final locksIntent = _touchTransformIntentLockActive;
    final relativeScale = locksIntent && _touchSegmentBaseEventScale > precisionErrorTolerance
        ? e.scale / _touchSegmentBaseEventScale
        : e.scale;
    final relativeRotation = locksIntent ? e.rotation - _touchSegmentBaseEventRotation : e.rotation;
    final effectiveRelativeScale = math.pow(relativeScale, _gestureScaleSensitivity).toDouble();
    if (locksIntent && _touchTransformIntent == null && e.pointerCount >= 2) {
      _touchTransformIntent = _resolveTouchTransformIntent(effectiveRelativeScale, relativeRotation);
      if (_touchTransformIntent == _TouchTransformIntent.rotation) _rotationIntentSeen = true;
    }
    final applyRotation =
        _gestureRotationEnabled && (!locksIntent || _touchTransformIntent == _TouchTransformIntent.rotation);
    final targetScale = _gestureScale(_gestureBaseScale * effectiveRelativeScale);
    final targetRotation = locksIntent
        ? _gestureBaseRotation + (applyRotation ? relativeRotation : 0.0)
        : _gestureBaseRotation + (applyRotation ? e.rotation : 0.0);
    _lastTouchEventScale = e.scale;
    _lastTouchEventRotation = e.rotation;
    if (widget.lockScaleRotationIntent && e.pointerCount >= 2) {
      // Preview 的双指变换只改变 scale/rotation，平移始终留给单指通道。
      _apply(targetScale, _offset, rotation: targetRotation, elastic: true);
      return;
    }
    final previousFocal = focal - e.localDelta;
    final anchor = _childPointAt(previousFocal);
    final targetFocal = widget.enablePan ? focal : previousFocal;
    _apply(
      targetScale,
      _offsetForAnchor(anchor, targetFocal, targetScale, targetRotation),
      rotation: targetRotation,
      elastic: _isScaleOutOfBounds(targetScale),
    );
  }

  void _onScaleEnd(ElEventDetails e) {
    widget.onPointerCountChanged?.call(0);
    if (!_gestureActive) return;
    _gestureActive = false;
    final locksIntent = _touchTransformIntentLockActive;
    _touchTransformIntentLockActive = false;
    final touchTransformIntent = _touchTransformIntent;
    _touchTransformIntent = null;
    final stableTouchTransform = widget.lockScaleRotationIntent && _multiPointerTransformSeen;
    _multiPointerTransformSeen = false;
    final rotationSeen = locksIntent && _rotationIntentSeen;
    _rotationIntentSeen = false;
    final rawLogScaleVelocity = locksIntent && touchTransformIntent != _TouchTransformIntent.scale
        ? 0.0
        : e.logScaleVelocity;
    final logScaleVelocity = (rawLogScaleVelocity * _gestureScaleSensitivity)
        .clamp(-_kMaxLogScaleVelocity, _kMaxLogScaleVelocity)
        .toDouble();
    final focal = stableTouchTransform && !rotationSeen
        ? _transformedChildCenter
        : logScaleVelocity == 0
        ? _gestureFocal ?? e.localPosition
        : e.localPosition;
    _gestureFocal = null;
    final consumed = _consuming;
    _consuming = false;
    if (!consumed) return;
    if (rotationSeen) {
      _snapRotationToRightAngle();
      return;
    }
    if (_settleScaleBounds(focal, logScaleVelocity: widget.scaleInertia ? logScaleVelocity : 0)) return;
    if (stableTouchTransform && _settleTransformBounds(targetRotation: _pendingSettleRotation)) return;
    if (locksIntent && touchTransformIntent == null) return;
    final panVelocity = !stableTouchTransform && widget.enablePan && widget.panInertia && _hasPanExtent
        ? e.velocity.pixelsPerSecond
        : Offset.zero;
    if (widget.scaleInertia && logScaleVelocity.abs() > _kMinLogScaleVelocity) {
      _startScaleFling(logScaleVelocity, panVelocity, focal);
    } else if (panVelocity != Offset.zero) {
      _startFling(panVelocity);
    }
  }

  void _onScaleCancel(ElEventDetails e) {
    widget.onPointerCountChanged?.call(0);
    final rotationSeen = _touchTransformIntentLockActive && _rotationIntentSeen;
    final stableTouchTransform = widget.lockScaleRotationIntent && _multiPointerTransformSeen;
    final focal = stableTouchTransform ? _transformedChildCenter : _gestureFocal ?? e.localPosition;
    final consumed = _consuming;
    _gestureActive = false;
    _touchTransformIntentLockActive = false;
    _touchTransformIntent = null;
    _rotationIntentSeen = false;
    _multiPointerTransformSeen = false;
    _gestureFocal = null;
    _consuming = false;
    if (!consumed) return;
    if (rotationSeen) {
      _snapRotationToRightAngle(animate: false);
    } else {
      _settleScaleBounds(focal, animate: false);
      if (stableTouchTransform || _pendingSettleRotation != null) {
        _settleTransformBounds(targetRotation: _pendingSettleRotation, animate: false);
      }
    }
  }

  void _cancelDirectScale() {
    final rotationSeen = _touchTransformIntentLockActive && _rotationIntentSeen;
    final stableTouchTransform = widget.lockScaleRotationIntent && _multiPointerTransformSeen;
    final focal = stableTouchTransform ? _transformedChildCenter : _gestureFocal ?? _viewSize.center(Offset.zero);
    _gestureActive = false;
    _consuming = false;
    _panZoomPinching = false;
    _touchTransformIntentLockActive = false;
    _touchTransformIntent = null;
    _rotationIntentSeen = false;
    _multiPointerTransformSeen = false;
    _gestureFocal = null;
    if (_elasticScaleAnimation) _stopAnimation();
    if (rotationSeen) {
      _snapRotationToRightAngle(animate: false);
    } else {
      _settleScaleBounds(focal, animate: false);
      if (stableTouchTransform || _pendingSettleRotation != null) {
        _settleTransformBounds(targetRotation: _pendingSettleRotation, animate: false);
      }
    }
  }

  void _handleRoutedPointerRemoved(PointerRemovedEvent event) {
    _cancelDirectScale();
    widget.onPointerCountChanged?.call(_render?._eventDispatcher?.activePointerCount ?? 0);
  }

  double _gestureScale(double rawScale) {
    if (!rawScale.isFinite || rawScale <= 0) return _scale;
    if (!widget.elasticScaleBounds) return rawScale.clamp(widget.minScale, widget.maxScale);
    if (rawScale > widget.maxScale) {
      final overflow = rawScale / widget.maxScale - 1;
      return widget.maxScale * (1 + _rubberScaleOverflow(overflow));
    }
    if (rawScale < widget.minScale) {
      final overflow = widget.minScale / rawScale - 1;
      return widget.minScale / (1 + _rubberScaleOverflow(overflow));
    }
    return rawScale;
  }

  double _rubberScaleOverflow(double overflow) =>
      _kElasticScaleExtent *
      _kElasticScaleFriction *
      overflow /
      (_kElasticScaleExtent + _kElasticScaleFriction * overflow);

  double _rawGestureScale(double visualScale) {
    final bound = visualScale > widget.maxScale
        ? widget.maxScale
        : visualScale < widget.minScale
        ? widget.minScale
        : null;
    if (bound == null) return visualScale;
    final resisted = visualScale > bound ? visualScale / bound - 1 : bound / visualScale - 1;
    final overflow =
        resisted *
        _kElasticScaleExtent /
        (_kElasticScaleFriction * math.max(precisionErrorTolerance, _kElasticScaleExtent - resisted));
    return visualScale > bound ? bound * (1 + overflow) : bound / (1 + overflow);
  }

  bool _isScaleOutOfBounds(double scale) => scale < widget.minScale || scale > widget.maxScale;

  bool _settleScaleBounds(Offset focal, {bool animate = true, double logScaleVelocity = 0.0}) {
    if (!widget.elasticScaleBounds || !_isScaleOutOfBounds(_scale)) return false;
    final targetScale = _scale.clamp(widget.minScale, widget.maxScale);
    final anchor = _childPointAt(focal);
    if (!animate || !widget.interactionEnabled || elDisableAnimations) {
      _stopAnimation();
      _apply(targetScale, _offsetForAnchor(anchor, focal, targetScale, _rotation));
      return true;
    }
    _stopAnimation();
    final startLogScale = math.log(_scale);
    final targetLogScale = math.log(targetScale);
    _anchoredStartLogScale = startLogScale;
    _anchoredTargetLogScale = targetLogScale;
    _ballisticAnchorChild = anchor;
    _ballisticAnchorViewport = focal;
    _elasticScaleAnimation = true;
    final animation = _ensureAnimation();
    final anchoredTargetOffset = _offsetForAnchor(anchor, focal, targetScale, _rotation);
    _elasticOffsetCorrection = _clampOffset(anchoredTargetOffset, targetScale) - anchoredTargetOffset;
    final progressVelocity = (logScaleVelocity / (targetLogScale - startLogScale)).clamp(-12.0, 12.0).toDouble();
    animation.animateWith(
      SpringSimulation(
        _kScaleSpring,
        _kElasticSpringStart,
        1,
        progressVelocity * (1 - _kElasticSpringStart),
        snapToEnd: true,
        tolerance: _kScaleSpringTolerance,
      ),
    );
    return true;
  }

  // --- 已缩放单指平移（drag 通道：与滚动同阈值起手、同源 velocity） -------------

  void _onDragStart(ElEventDetails e) {
    // 未缩放：不消费、不独占——本 dragStart 空转，祖先滚动在同一 move 里
    // 照常接受并 latch。
    _dragApplied = false;
    if (!widget.enablePan || (e.dragPipelineActive ? !_hasPanExtent : !_canPanToward(e))) return;
    _stopAnimation();
    _dragConsuming = true;
    if (!e.dragPipelineActive) e.eagerGesture(cancelSelfTap: true, allowScaleUpgrade: true);
  }

  void _onDragUpdate(ElEventDetails e) {
    if (!_dragConsuming) return;
    if (widget.lockScaleRotationIntent && e.pointerCount >= 2) {
      _dragApplied = false;
      e.consumeAllDelta();
      return;
    }
    final before = _offset;
    _apply(_scale, _offset + e.remainingLocalDelta);
    if (_offset != before) _dragApplied = true;
    if (e.dragPipelineActive) _consumeLocalDelta(e, _offset - before);
  }

  void _onDragEnd(ElEventDetails e) {
    if (!_dragConsuming) return;
    _dragConsuming = false;
    final applied = _dragApplied;
    _dragApplied = false;
    final delegated = widget.onPanEnd?.call(e.velocity) ?? false;
    if (applied && !delegated && widget.panInertia) _startFling(e.velocity.pixelsPerSecond);
  }

  void _onDragCancel(ElEventDetails e) {
    // 单指移动超 pan slop 后 scale 机接管同宿主拖拽（cancelForScaleGesture）：
    // 平移由随后的焦点通道续接，此处只交棒不惯性。
    _dragConsuming = false;
    _dragApplied = false;
    widget.onPanCancel?.call();
  }

  void _consumeLocalDelta(ElEventDetails event, Offset localDelta) {
    if (localDelta == Offset.zero) return;
    final render = _render;
    if (render == null) {
      event.consumeDelta(localDelta);
      return;
    }
    final start = render.localToGlobal(event.localPosition);
    final end = render.localToGlobal(event.localPosition + localDelta);
    event.consumeDelta(end - start);
  }

  // --- 松手惯性 ---------------------------------------------------------------

  void _startFling(Offset velocity) {
    if (elDisableAnimations || velocity == Offset.zero || !_hasPanExtent) return;
    _stopAnimation();
    final durationX = _frictionDuration(velocity.dx);
    final durationY = _frictionDuration(velocity.dy);
    final simulationX = durationX == 0 ? null : FrictionSimulation(_kDrag, _offset.dx, velocity.dx);
    final simulationY = durationY == 0 ? null : FrictionSimulation(_kDrag, _offset.dy, velocity.dy);
    final rawEnd = Offset(simulationX?.x(durationX) ?? _offset.dx, simulationY?.x(durationY) ?? _offset.dy);
    final end = _clampOffset(rawEnd, _scale);
    final boundedDurationX = _boundedFrictionDuration(simulationX, durationX, end.dx);
    final boundedDurationY = _boundedFrictionDuration(simulationY, durationY, end.dy);
    final duration = math.max(boundedDurationX, boundedDurationY);
    if (!duration.isFinite || duration <= 0) return;
    _panFrictionX = simulationX;
    _panFrictionY = simulationY;
    _panFrictionEndTimeX = boundedDurationX;
    _panFrictionEndTimeY = boundedDurationY;
    final animation = _ensureAnimation();
    animation
      ..duration = Duration(milliseconds: math.max(1, (duration * 1000).ceil()))
      ..forward(from: 0);
  }

  void _startScaleFling(double logScaleVelocity, Offset panVelocity, Offset focal) {
    if (elDisableAnimations) return;
    if ((_scale <= widget.minScale + precisionErrorTolerance && logScaleVelocity < 0) ||
        (_scale >= widget.maxScale - precisionErrorTolerance && logScaleVelocity > 0)) {
      if (panVelocity != Offset.zero) _startFling(panVelocity);
      return;
    }
    final scaleDuration = _frictionDuration(logScaleVelocity, drag: _kScaleDrag, stopVelocity: _kMinLogScaleVelocity);
    final panDuration = _frictionDuration(panVelocity.distance);
    final startLogScale = math.log(_scale);
    final scaleSimulation = FrictionSimulation(_kScaleDrag, startLogScale, logScaleVelocity);
    final endLogScale = scaleSimulation
        .x(scaleDuration)
        .clamp(math.log(widget.minScale), math.log(widget.maxScale))
        .toDouble();
    if (endLogScale == startLogScale) {
      if (panVelocity != Offset.zero) _startFling(panVelocity);
      return;
    }
    final boundedScaleDuration = endLogScale == scaleSimulation.x(scaleDuration)
        ? scaleDuration
        : scaleSimulation.timeAtX(endLogScale).clamp(0.0, scaleDuration).toDouble();
    final duration = math.max(boundedScaleDuration, panDuration);
    if (!duration.isFinite || duration <= 0) {
      if (panVelocity != Offset.zero) _startFling(panVelocity);
      return;
    }
    var endPanDelta = Offset.zero;
    if (panVelocity != Offset.zero) {
      final panSimulationX = FrictionSimulation(_kDrag, 0, panVelocity.dx);
      final panSimulationY = FrictionSimulation(_kDrag, 0, panVelocity.dy);
      endPanDelta = Offset(panSimulationX.x(panDuration), panSimulationY.x(panDuration));
    }
    final anchorChild = _childPointAt(focal);
    _stopAnimation();
    final animation = _ensureAnimation();
    _logScaleFriction = scaleSimulation;
    _logScaleFrictionEndTime = boundedScaleDuration;
    _logScaleFrictionTarget = endLogScale;
    if (endPanDelta != Offset.zero) {
      final panProgress = animation.drive(
        CurveTween(
          curve: panDuration >= duration
              ? Curves.decelerate
              : Interval(0, panDuration / duration, curve: Curves.decelerate),
        ),
      );
      _panDeltaAnimation = panProgress.drive(Tween<Offset>(begin: Offset.zero, end: endPanDelta));
    }
    _ballisticAnchorChild = anchorChild;
    _ballisticAnchorViewport = focal;
    animation
      ..duration = Duration(milliseconds: math.max(1, (duration * 1000).round()))
      ..forward(from: 0);
  }

  double _frictionDuration(double velocity, {double drag = _kDrag, double stopVelocity = _kPanStopVelocity}) {
    final speed = velocity.abs();
    return speed <= stopVelocity ? 0.0 : math.log(stopVelocity / speed) / math.log(drag);
  }

  double _boundedFrictionDuration(FrictionSimulation? simulation, double duration, double end) {
    if (simulation == null || duration <= 0) return 0.0;
    if ((simulation.x(duration) - end).abs() <= precisionErrorTolerance) return duration;
    final hitTime = simulation.timeAtX(end);
    return hitTime.isFinite ? hitTime.clamp(0.0, duration).toDouble() : 0.0;
  }

  // --- 双击缩放 --------------------------------------------------------------

  void _onDoubleTapDown(ElEventDetails e) {
    final target = _zoomed ? widget.minScale : widget.doubleTapScale.clamp(widget.minScale, widget.maxScale);
    final focal = e.localPosition;
    final anchor = _childPointAt(focal);
    _animateToTransform(
      ElZoomTransform(scale: target, rotation: _rotation, offset: _offsetForAnchor(anchor, focal, target, _rotation)),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      preservePendingTransform: true,
    );
  }

  // --- 触控板捏合 ------------------------------------------------------------

  void _onPointerSignal(ElEventDetails e) {
    if (!widget.mouseWheelZoom) return;
    final delta = e.remainingDelta.dy;
    if (delta == 0) return;
    if (_elasticScaleAnimation) _stopAnimation();
    final activeWheelTarget = _anchoredTargetLogScale;
    final baseLogScale = activeWheelTarget ?? math.log(_scale);
    final desiredLogScale = baseLogScale - delta * widget.wheelScaleSensitivity;
    final targetLogScale = desiredLogScale.clamp(math.log(widget.minScale), math.log(widget.maxScale)).toDouble();
    if (targetLogScale == baseLogScale) return;
    final consumed = targetLogScale == desiredLogScale
        ? delta
        : -(targetLogScale - baseLogScale) / widget.wheelScaleSensitivity;
    e.consumePrimaryDelta(Axis.vertical, consumed);
    final focal = e.localPosition;
    final anchor = _childPointAt(focal);
    final targetScale = math.exp(targetLogScale);
    if (elDisableAnimations) {
      _stopAnimation();
      _apply(targetScale, _offsetForAnchor(anchor, focal, targetScale, _rotation));
      return;
    }
    final visualLogScale = math.log(_scale);
    if (activeWheelTarget == null) {
      _stopAnimation();
      if ((targetLogScale - visualLogScale).abs() <= precisionErrorTolerance) {
        _apply(targetScale, _offsetForAnchor(anchor, focal, targetScale, _rotation));
        return;
      }
      _anchoredStartLogScale = visualLogScale;
    } else {
      final progress = Curves.easeOutCubic.transform(_animation?.value ?? 0.0);
      _anchoredStartLogScale = progress >= 1.0 - precisionErrorTolerance
          ? visualLogScale
          : (visualLogScale - targetLogScale * progress) / (1.0 - progress);
    }
    _anchoredTargetLogScale = targetLogScale;
    _ballisticAnchorChild = anchor;
    _ballisticAnchorViewport = focal;
    final animation = _ensureAnimation();
    if (!animation.isAnimating) {
      animation
        ..duration = _kWheelAnimationDuration
        ..forward(from: 0);
    }
  }

  void _onPanZoomStart(ElEventDetails e) {
    _stopAnimation(settleElastic: !_elasticScaleAnimation);
    _panZoomBaseScale = _rawGestureScale(_scale);
    _panZoomScaleSensitivity = widget.scaleSensitivity;
    _panZoomPinching = false;
    _gestureFocal = e.localPosition;
  }

  void _onPanZoomUpdate(ElEventDetails e) {
    final pinching = (e.scale - 1.0).abs() > precisionErrorTolerance;
    if (pinching && !_panZoomPinching) {
      _panZoomPinching = true;
      widget.onPanCancel?.call();
    }
    if (!_panZoomPinching && (!widget.enablePan || !_hasPanExtent)) return;
    final targetScale = _gestureScale(_panZoomBaseScale * math.pow(e.scale, _panZoomScaleSensitivity).toDouble());
    final elastic = _isScaleOutOfBounds(targetScale);
    final focal = _gestureFocal ?? e.localPosition;
    final anchor = _childPointAt(focal);
    final rawAnchorOffset = _offsetForAnchor(anchor, focal, targetScale, _rotation);
    // Windows 捏合会同时附带双指平移量；缩放时只锚定固定鼠标位置，避免内容被额外拖走。
    if (_panZoomPinching) {
      _apply(targetScale, rawAnchorOffset, elastic: elastic);
      e.stopPropagation();
      return;
    }
    final anchorOnlyOffset = elastic ? rawAnchorOffset : _clampOffset(rawAnchorOffset, targetScale);
    _apply(targetScale, rawAnchorOffset + e.remainingLocalDelta, elastic: elastic);
    _consumeLocalDelta(e, _offset - anchorOnlyOffset);
  }

  void _onPanZoomEnd(ElEventDetails e) {
    final pinching = _panZoomPinching;
    final focal = _gestureFocal ?? e.localPosition;
    _panZoomPinching = false;
    _gestureFocal = null;
    if ((pinching || _isScaleOutOfBounds(_scale)) && _settleScaleBounds(focal)) return;
    _resumePendingTransformSettle();
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ElView(
      event: widget.interactionEnabled
          ? ElEvent(
              // 已缩放平移的起手阈必须 ≤ 祖先滚动的设备 slop（真机 ≈8-9）：
              // 起手竞争按 move 逐帧判定、内层先喂——只要内层先越阈就先
              // eager 独占；若仍用自由拖拽默认的 pan slop(36)，慢速平移会在
              // 8~36px 区间被外层滚动抢走。未缩放态保持默认，继续让祖先翻页。
              config: _eventConfig,
              dragProxy: widget.enablePan ? _dragProxy : null,
              rotationStartEnabled:
                  widget.lockScaleRotationIntent && (_gestureActive ? _gestureRotationEnabled : widget.enableRotation),
              onPointerDown: _onPointerDown,
              onPointerUp: _onPointerTerminal,
              onPointerCancel: _onPointerTerminal,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              onScaleCancel: _onScaleCancel,
              onDragStart: widget.enablePan ? _onDragStart : null,
              onDragUpdate: widget.enablePan ? _onDragUpdate : null,
              onDragEnd: widget.enablePan ? _onDragEnd : null,
              onDragCancel: widget.enablePan ? _onDragCancel : null,
              onDoubleTapDown: widget.enableDoubleTapZoom ? _onDoubleTapDown : null,
              onPointerSignal: widget.mouseWheelZoom ? _onPointerSignal : null,
              onPointerPanZoomStart: _onPanZoomStart,
              onPointerPanZoomUpdate: _onPanZoomUpdate,
              onPointerPanZoomEnd: _onPanZoomEnd,
            )
          : null,
      child: _ZoomTransform(
        state: this,
        child: _ZoomContent(child: widget.child),
      ),
    );
  }
}

/// 缩放变换宿主 widget：把 shell 与逐帧变换解耦——变换值不进 widget 配置，
/// 手势/动画期间 shell 恒不重建。
class _ZoomTransform extends SingleChildRenderObjectWidget {
  const _ZoomTransform({required this.state, required super.child});

  final _ZoomViewState state;

  @override
  _RenderZoomTransform createRenderObject(BuildContext context) {
    final render = _RenderZoomTransform(state);
    state._render = render;
    return render;
  }

  @override
  void updateRenderObject(BuildContext context, _RenderZoomTransform renderObject) {
    renderObject.state = state;
    state._render = renderObject;
  }

  @override
  void didUnmountRenderObject(_RenderZoomTransform renderObject) {
    if (identical(renderObject.state._render, renderObject)) renderObject.state._render = null;
  }
}

/// 内容级重绘边界：外层矩阵逐帧变化时只复用 child layer。
class _ZoomContent extends SingleChildRenderObjectWidget {
  const _ZoomContent({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderZoomContent();
}

class _RenderZoomContent extends RenderProxyBox {
  @override
  bool get isRepaintBoundary => true;
}

/// 缩放变换宿主 render：视口撑满约束、child 按视口尺寸布局；paint 套
/// 裁剪 + 平移缩放变换，命中与语义几何经同一变换换算。
class _RenderZoomTransform extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  _RenderZoomTransform(this._state);

  _ZoomViewState _state;

  _ZoomViewState get state => _state;

  set state(_ZoomViewState value) {
    if (identical(_state, value)) return;
    _state = value;
    markNeedsLayout();
  }

  final LayerHandle<ClipRectLayer> _clipHandle = LayerHandle<ClipRectLayer>();
  final LayerHandle<TransformLayer> _transformHandle = LayerHandle<TransformLayer>();
  final Matrix4 _effectiveTransform = Matrix4.identity();
  late final PaintingContextCallback _paintTransformedCallback = _paintTransformed;
  late final PaintingContextCallback _paintChildCallback = _paintChild;
  Rect _viewportRect = Rect.zero;
  bool _isIdentity = true;
  EventDispatcher? _eventDispatcher;

  void _syncEventDispatcher() {
    if (!attached) return;
    final host = parent;
    final next = host is RenderBox ? EventDispatcher.of(host) : null;
    if (!identical(next, _eventDispatcher)) {
      _eventDispatcher?.onRoutedPointerRemoved = null;
      _eventDispatcher = next;
    }
    next?.onRoutedPointerRemoved = state._handleRoutedPointerRemoved;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    state._render = this;
    _syncEventDispatcher();
  }

  @override
  void detach() {
    _eventDispatcher?.onRoutedPointerRemoved = null;
    _eventDispatcher = null;
    if (identical(state._render, this)) state._render = null;
    state._cancelDirectScale();
    super.detach();
  }

  /// 手势侧变换已更新：只重绘 + 语义几何失效（与官方 RenderTransform 的
  /// transform setter 同口径），不触发任何 layout。
  void noteTransformChanged() {
    _updateTransform();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _updateTransform() {
    final childCenter = state._childSize.center(Offset.zero);
    final base = state._alignedChildCenter;
    final center = Offset(
      base.dx + state._offset.dx + state._transientDx,
      base.dy + state._offset.dy + state._transientDy,
    );
    _effectiveTransform
      ..setIdentity()
      ..translateByDouble(center.dx, center.dy, 0, 1);
    if (state._rotation != 0.0) _effectiveTransform.rotateZ(state._rotation);
    _effectiveTransform
      ..scaleByDouble(state._scale, state._scale, 1, 1)
      ..translateByDouble(-childCenter.dx, -childCenter.dy, 0, 1);
    _isIdentity =
        state._scale == 1.0 &&
        state._rotation == 0.0 &&
        state._transientDx == 0.0 &&
        state._transientDy == 0.0 &&
        center == childCenter;
  }

  @override
  void performLayout() {
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      throw FlutterError('ElZoomView 的视口必须同时具有有限宽高。');
    }
    size = constraints.biggest;
    _viewportRect = Offset.zero & size;
    final child = this.child;
    if (child != null) {
      child.layout(
        state.widget.constrained ? BoxConstraints.tight(size) : const BoxConstraints(),
        parentUsesSize: true,
      );
    }
    state._handleGeometryChanged(size, child?.size ?? Size.zero);
    _updateTransform();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: _effectiveTransform,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_effectiveTransform);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      state.widget.clipBehavior == Clip.none ? null : _viewportRect;

  void _paintChild(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null) context.paintChild(child, offset);
  }

  void _paintTransformed(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (_isIdentity) {
      _transformHandle.layer = null;
      context.paintChild(child, offset);
      return;
    }
    _transformHandle.layer = context.pushTransform(
      needsCompositing,
      offset,
      _effectiveTransform,
      _paintChildCallback,
      oldLayer: _transformHandle.layer,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (state.widget.clipBehavior == Clip.none) {
      _clipHandle.layer = null;
      _paintTransformed(context, offset);
      return;
    }
    _clipHandle.layer = context.pushClipRect(
      needsCompositing,
      offset,
      _viewportRect,
      _paintTransformedCallback,
      oldLayer: _clipHandle.layer,
      clipBehavior: state.widget.clipBehavior,
    );
  }

  @override
  void dispose() {
    _clipHandle.layer = null;
    _transformHandle.layer = null;
    super.dispose();
  }
}
