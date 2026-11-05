// ignore_for_file: prefer_initializing_formals

// 滚动视口的输入、指标、reveal 与样式继承基座。
//
// 实际视口负责业务成员布局与统一层序呈现；公共物理、事件和几何接线
// 保留在同一 library，避免为内部协作暴露多余 API。

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode, precisionErrorTolerance, setEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'
    show
        HardwareKeyboard,
        LogicalKeyboardKey,
        MouseCursor,
        MouseTrackerAnnotation,
        PointerEnterEventListener,
        PointerExitEventListener;
import 'package:flutter/widgets.dart';

import '../../../../utils/internal/bit_mask.dart';
import '../../../../utils/internal/layout_reference.dart';
import '../../../layout/stack/stack_view.dart' show ElStackParentData, RenderStackingBox;
import '../../../selection/common/selection_core.dart';
import '../../../view/event/dispatcher.dart';
import '../../../view/event/event.dart';
import '../../../view/render/scroll_cursor_freeze.dart';
import '../../../view/style/inheritance/inheritable_node.dart';
import '../../../view/style/resolved/resolved_style.dart';
import '../../scroll_state.dart';
import '../../scroll_view.dart' show ElScrollView;
import '../../smooth_scroll/smooth_pointer_scroll.dart';
import '../../smooth_scroll/smooth_scroll.dart';
import '../../virtual/virtual_scroll_geometry.dart';
import '../nested/scroll_delta_interceptor.dart';
import '../pointer/scroll_drag_controller.dart';
import '../pointer/scroll_input_transaction.dart';
import '../pointer/scroll_pointer_chain.dart';
import '../pointer/scroll_pointer_motion.dart';
import '../pointer/scroll_touch_event_latch.dart';
import '../pointer/scroll_touch_gate.dart';
import '../viewport/scroll_engine_position.dart';
import '../viewport/scroll_position_binding.dart';
import '../viewport/scroll_viewport.dart';

export '../../../layout/geometry/pixel_grid.dart' show snapVirtualItemExtentToPixelGrid;

part '../../virtual/render/render_virtual_scroll_view.dart';
part 'scroll_semantics.dart';

/// 直接滚动成员的公共 ParentData，沿用 Stack 的原生定位和层序协议。
class ScrollChildParentData extends ElStackParentData {}

/// 实际滚动视口提供的可见成员窗口，与布局模型及绘制边界同源。
abstract interface class VirtualContentVisibleWindow {
  /// 当前可见 item 窗口 `[start, end)`（实时自推，jumpTo 后同帧即新值）。
  ({int start, int end}) visibleItemWindow();
}

/// 滚动视口的物理、事件、指标和继承基座，业务呈现由具体布局实现。
abstract class RenderScrollViewportBase extends RenderStackingBox<ScrollChildParentData>
    with LayoutReferenceBox
    implements
        RenderAbstractViewport,
        MouseTrackerAnnotation,
        InheritableNode,
        ScrollViewport,
        SelectionPaintOrderChildren {
  RenderScrollViewportBase({
    required ScrollPosition position,
    required Axis axis,
    required AxisDirection axisDirection,
    required ScrollPhysics physics,
    required GestureVelocityTrackerBuilder velocityTrackerBuilder,
    required MultitouchDragStrategy multitouchDragStrategy,
    required String debugHorizontalSmoothScrollLabel,
    ScrollPosition? horizontalPosition,
    AxisDirection horizontalAxisDirection = AxisDirection.right,
    double devicePixelRatio = 1.0,
    Set<PointerDeviceKind>? dragDevices,
    Set<LogicalKeyboardKey> pointerAxisModifiers = const <LogicalKeyboardKey>{},
    Iterable<LogicalKeyboardKey>? mouseWheelHorizontalModifiers = const <LogicalKeyboardKey>[
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
    ],
    DeviceGestureSettings? gestureSettings,
    Clip clipBehavior = Clip.hardEdge,
    EdgeInsets padding = EdgeInsets.zero,
    double mainAxisGap = 0.0,
    bool excludeSemantics = false,
    SemanticsRole? semanticsRole,
    bool ignorePointer = false,
    bool canDrag = false,
    double? dragStartDistance,
    ElEvent? event,
    ElScrollDeltaInterceptor? deltaInterceptor,
    ElScrollDeltaInterceptor? horizontalDeltaInterceptor,
    void Function(Axis axis, ElScrollActivityType? activity)? onScrollInputActivityChanged,
    ElSmoothScroll? smoothScroll,
  }) : assert(horizontalPosition == null || axis == Axis.vertical, '双轴模式的布局主轴恒为 vertical。'),
       _deltaInterceptor = deltaInterceptor,
       _horizontalDeltaInterceptor = horizontalDeltaInterceptor,
       onScrollInputActivityChanged = onScrollInputActivityChanged,
       _position = position,
       _horizontalPosition = horizontalPosition,
       _horizontalAxisDirection = horizontalAxisDirection,
       _axis = axis,
       _axisDirection = axisDirection,
       _physics = physics,
       _velocityTrackerBuilder = velocityTrackerBuilder,
       _multitouchDragStrategy = multitouchDragStrategy,
       _devicePixelRatio = devicePixelRatio,
       _dragDevices = dragDevices,
       _pointerAxisModifiers = pointerAxisModifiers,
       _mouseWheelHorizontalModifiers = mouseWheelHorizontalModifiers?.toSet(),
       _gestureSettings = gestureSettings,
       _clipBehavior = clipBehavior,
       _padding = padding,
       _mainAxisGap = mainAxisGap,
       _excludeSemantics = excludeSemantics,
       _semanticsRole = semanticsRole,
       _ignorePointer = ignorePointer,
       _canDrag = canDrag,
       _dragStartDistance = dragStartDistance {
    _smoothPointerScroll = SmoothPointerScrollController(
      position: () => _position,
      targetOffsetForDelta: _targetScrollOffsetForPointerScroll,
      algorithm: smoothScroll,
      pointerMotion: deltaInterceptor is ScrollPointerMotionInput ? deltaInterceptor as ScrollPointerMotionInput : null,
    );
    _horizontalSmoothPointerScroll = SmoothPointerScrollController(
      position: () => _horizontalPosition!,
      targetOffsetForDelta: _targetHorizontalScrollOffsetForPointerScroll,
      algorithm: smoothScroll,
      debugLabel: debugHorizontalSmoothScrollLabel,
      pointerMotion: horizontalDeltaInterceptor is ScrollPointerMotionInput
          ? horizontalDeltaInterceptor as ScrollPointerMotionInput
          : null,
    );
    _scrollDrag = ScrollViewDragController(
      owner: this,
      position: () => _position,
      axis: () => _axis,
      axisDirection: () => _axisDirection,
      physics: () => _physics,
      velocityTrackerBuilder: () => _velocityTrackerBuilder,
      canDrag: () => _canDrag,
      shouldAcceptUserOffset: () => _shouldAcceptUserOffset,
      resetSmoothPointerScroll: _resetSmoothPointerScroll,
      // 主轴走主拦截器；双轴横轴由独立拦截器接线。
      deltaInterceptor: () => _deltaInterceptor,
    );
    _horizontalScrollDrag = ScrollViewDragController(
      owner: this,
      position: () => _horizontalPosition!,
      axis: () => Axis.horizontal,
      axisDirection: () => _horizontalAxisDirection,
      physics: () => _physics,
      velocityTrackerBuilder: () => _velocityTrackerBuilder,
      canDrag: () => _canDrag,
      shouldAcceptUserOffset: () => _shouldAcceptHorizontalUserOffset,
      resetSmoothPointerScroll: _resetHorizontalSmoothPointerScroll,
      deltaInterceptor: () => _horizontalDeltaInterceptor,
    );
    _userEvent = event;
    _syncEventDispatcher();
  }

  /// 主轴 child 间距；子类以自己的公开名（`gap` / `spacing`）转发。
  double _mainAxisGap;

  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    didChangeDevicePixelRatio();
  }

  /// dpr 变化的脏级钩子：默认保守地标 paint；virtual 覆写成 layout
  /// 级——item extent 网格对齐参与布局，只重画不够。滚动 transform 本身
  /// 保留 raw 亚像素，不再依赖 dpr。
  @protected
  void didChangeDevicePixelRatio() => markNeedsPaint();

  /// layout 尾声通知 widget 层滚动条刷新快照——applyContentDimensions 不触发
  /// position 通知，仅 extent 收敛/内容增删而无像素移动时 host 快照会盲。
  VoidCallback? onScrollbarMetricsChanged;

  /// 双轴内容宽由实际挂载成员的布局结果提供。
  @protected
  double horizontalContentWidthForDualAxis() => _contentSize.width;

  /// 本次要发给 children 的约束（尺寸推导分化点之一）。
  @protected
  BoxConstraints childConstraintsForLayout();

  /// 双轴模式（CSS `overflow: auto` 语义）：水平轴 position 非空即启用。
  /// 此时 [_axis] 恒为 vertical（布局主轴），水平轴只做交叉轴平移。
  bool get _dualAxis => _horizontalPosition != null;

  @override
  ScrollPosition get position => _position;

  ScrollPosition _position;

  set position(ScrollPosition value) {
    if (identical(_position, value)) return;
    if (attached) _position.removeListener(_handleScrollOffsetChanged);
    _position = value;
    if (attached) _position.addListener(_handleScrollOffsetChanged);
    _cancelActiveScrollDrag();
    _resetSmoothPointerScroll();
    markNeedsLayout();
  }

  /// 双轴模式的水平轴 position；null = 单轴。
  ScrollPosition? get horizontalPosition => _horizontalPosition;

  ScrollPosition? _horizontalPosition;

  set horizontalPosition(ScrollPosition? value) {
    if (identical(_horizontalPosition, value)) return;
    final old = _horizontalPosition;
    if (attached && old != null) old.removeListener(_handleHorizontalScrollOffsetChanged);
    _horizontalPosition = value;
    if (attached && value != null) value.addListener(_handleHorizontalScrollOffsetChanged);
    _horizontalScrollDrag.cancelActiveDrag();
    onScrollInputActivityChanged?.call(Axis.horizontal, null);
    _resetHorizontalSmoothPointerScroll();
    // 双轴开关影响 effective event 的水平拖拽组挂载。
    _syncEventDispatcher();
    markNeedsLayout();
  }

  AxisDirection get horizontalAxisDirection => _horizontalAxisDirection;

  AxisDirection _horizontalAxisDirection;

  set horizontalAxisDirection(AxisDirection value) {
    if (_horizontalAxisDirection == value) return;
    _horizontalAxisDirection = value;
    _invalidateScrollPaintCache();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  Axis get axis => _axis;

  Axis _axis;

  set axis(Axis value) {
    if (_axis == value) return;
    _axis = value;
    _syncEventDispatcher();
    markNeedsLayout();
  }

  @override
  AxisDirection get axisDirection => _axisDirection;

  AxisDirection _axisDirection;

  set axisDirection(AxisDirection value) {
    if (_axisDirection == value) return;
    _axisDirection = value;
    _invalidateScrollPaintCache();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  ScrollPhysics get physics => _physics;

  ScrollPhysics _physics;

  set physics(ScrollPhysics value) {
    if (identical(_physics, value)) return;
    _physics = value;
    _syncEventDispatcher();
  }

  GestureVelocityTrackerBuilder get velocityTrackerBuilder => _velocityTrackerBuilder;

  GestureVelocityTrackerBuilder _velocityTrackerBuilder;

  set velocityTrackerBuilder(GestureVelocityTrackerBuilder value) {
    if (identical(_velocityTrackerBuilder, value)) return;
    _velocityTrackerBuilder = value;
    // ScrollBehavior.velocityTrackerBuilder returns a fresh closure on every
    // build, so this setter fires on effectively every widget rebuild. The
    // effective event chain does not depend on it — push it straight to the
    // dispatcher instead of rebuilding the whole handler chain.
    _eventDispatcher?.velocityTrackerBuilder = value;
  }

  MultitouchDragStrategy get multitouchDragStrategy => _multitouchDragStrategy;

  MultitouchDragStrategy _multitouchDragStrategy;

  set multitouchDragStrategy(MultitouchDragStrategy value) {
    if (_multitouchDragStrategy == value) return;
    _multitouchDragStrategy = value;
    _syncEventDispatcher();
  }

  double get devicePixelRatio => _devicePixelRatio;

  double _devicePixelRatio;

  Set<PointerDeviceKind>? get dragDevices => _dragDevices;

  Set<PointerDeviceKind>? _dragDevices;

  set dragDevices(Set<PointerDeviceKind>? value) {
    if (setEquals(_dragDevices, value)) return;
    _dragDevices = value;
    _syncEventDispatcher();
  }

  @override
  Set<PointerDeviceKind> get effectiveContentDragDevices => _dragDevices ?? kViewportDragDevices;

  Set<LogicalKeyboardKey> get pointerAxisModifiers => _pointerAxisModifiers;

  Set<LogicalKeyboardKey> _pointerAxisModifiers;

  set pointerAxisModifiers(Set<LogicalKeyboardKey> value) {
    if (setEquals(_pointerAxisModifiers, value)) return;
    _pointerAxisModifiers = value;
  }

  Iterable<LogicalKeyboardKey>? get mouseWheelHorizontalModifiers => _mouseWheelHorizontalModifiers;

  Set<LogicalKeyboardKey>? _mouseWheelHorizontalModifiers;

  set mouseWheelHorizontalModifiers(Iterable<LogicalKeyboardKey>? value) {
    final next = value?.toSet();
    if (setEquals(_mouseWheelHorizontalModifiers, next)) return;
    _mouseWheelHorizontalModifiers = next;
  }

  DeviceGestureSettings? get gestureSettings => _gestureSettings;

  DeviceGestureSettings? _gestureSettings;

  set gestureSettings(DeviceGestureSettings? value) {
    if (_gestureSettings == value) return;
    _gestureSettings = value;
    _syncEventDispatcher();
  }

  @override
  Clip get clipBehavior => _clipBehavior;

  Clip _clipBehavior;

  set clipBehavior(Clip value) {
    if (_clipBehavior == value) return;
    _clipBehavior = value;
    markNeedsPaint();
  }

  EdgeInsets get padding => _padding;

  EdgeInsets _padding;

  set padding(EdgeInsets value) {
    assert(value.isNonNegative);
    if (_padding == value) return;
    _padding = value;
    markNeedsLayout();
  }

  bool get excludeSemantics => _excludeSemantics;

  bool _excludeSemantics;

  set excludeSemantics(bool value) {
    if (_excludeSemantics == value) return;
    _excludeSemantics = value;
    markNeedsSemanticsUpdate();
  }

  /// 当前滚动语义节点的可选结构角色。
  SemanticsRole? get semanticsRole => _semanticsRole;

  SemanticsRole? _semanticsRole;

  /// 更新滚动语义节点的结构角色。
  set semanticsRole(SemanticsRole? value) {
    if (_semanticsRole == value) return;
    _semanticsRole = value;
    markNeedsSemanticsUpdate();
  }

  bool get ignorePointer => _ignorePointer;

  bool _ignorePointer;

  set ignorePointer(bool value) {
    if (_ignorePointer == value) return;
    _ignorePointer = value;
    markNeedsPaint();
  }

  bool get canDrag => _canDrag;

  bool _canDrag;

  set canDrag(bool value) {
    if (_canDrag == value) return;
    _canDrag = value;
    if (!_canDrag && !_hasActiveScrollEventSequence) _cancelActiveScrollDrag();
    _syncEventDispatcher();
  }

  double? get dragStartDistance => _dragStartDistance;

  double? _dragStartDistance;

  set dragStartDistance(double? value) {
    assert(value == null || value >= 0.0);
    if (_dragStartDistance == value) return;
    _dragStartDistance = value;
    _syncEventDispatcher();
  }

  /// 滚动 delta 输入拦截器；null = 无拦截，热路径短路。
  /// 鼠标滚轮平滑滚动算法（双轴共用；null = 直滚不动画。对进行中的动画段
  /// 不生效，下一段生效）。
  ElSmoothScroll? get smoothScroll => _smoothPointerScroll.algorithm;

  set smoothScroll(ElSmoothScroll? value) {
    if (identical(_smoothPointerScroll.algorithm, value)) return;
    _smoothPointerScroll.algorithm = value;
    _horizontalSmoothPointerScroll.algorithm = value;
  }

  ElScrollDeltaInterceptor? get deltaInterceptor => _deltaInterceptor;

  ElScrollDeltaInterceptor? _deltaInterceptor;

  set deltaInterceptor(ElScrollDeltaInterceptor? value) {
    if (identical(_deltaInterceptor, value)) return;
    _deltaInterceptor = value;
    _smoothPointerScroll.pointerMotion = value is ScrollPointerMotionInput ? value as ScrollPointerMotionInput : null;
  }

  ElScrollDeltaInterceptor? get horizontalDeltaInterceptor => _horizontalDeltaInterceptor;

  ElScrollDeltaInterceptor? _horizontalDeltaInterceptor;

  set horizontalDeltaInterceptor(ElScrollDeltaInterceptor? value) {
    if (identical(_horizontalDeltaInterceptor, value)) return;
    _horizontalDeltaInterceptor = value;
    _horizontalSmoothPointerScroll.pointerMotion = value is ScrollPointerMotionInput
        ? value as ScrollPointerMotionInput
        : null;
  }

  /// 输入来源切换通知；没有滚动 Mixin client 时为 null，事件热路径直接短路。
  void Function(Axis axis, ElScrollActivityType? activity)? onScrollInputActivityChanged;

  EventDispatcher? _eventDispatcher;

  ElEvent? _userEvent;

  bool _defaultPanZoomPrevented = false;

  bool _defaultDragPrevented = false;

  final ScrollTouchEventSyncLatch _touchEventSyncLatch = ScrollTouchEventSyncLatch();

  ElEvent? get event => _userEvent;

  bool get _hasActiveScrollEventSequence =>
      _touchEventSyncLatch.active || (_eventDispatcher?.hasActivePointerSequence ?? false);

  set event(ElEvent? value) {
    if (identical(_userEvent, value)) return;
    _userEvent = value;
    _syncEventDispatcher(deferForActiveTouch: _touchEventSyncLatch.hasDeferredSync);
  }

  bool deferStructuralUpdateForActiveTouch(VoidCallback callback) {
    if (_touchEventSyncLatch.deferCallbackIfActive(callback)) return true;
    if (_eventDispatcher?.hasActivePointerSequence ?? false) {
      _touchEventSyncLatch.deferCallback(callback);
      return true;
    }
    return false;
  }

  /// 接线谓词签名：effective event 的结构由这些谓词决定，而它们依赖
  /// position dimensions（layout 才就绪）。canDrag setter 只在自身值变化时
  /// sync——双轴下主轴 dimensions 先就绪触发 sync 时横轴还没 apply，随后
  /// 横轴就绪但 canDrag 值不再变化，翻转会被吞。layout 末尾做签名脏检查兜底。
  int _eventWiringSignature() {
    var mask = 0;
    if (_canDrag && _shouldAcceptUserOffset) mask |= 1;
    if (_dualAxis && _canDrag && _shouldAcceptHorizontalUserOffset) mask |= 2;
    if (_shouldAcceptUserOffset || _shouldAcceptHorizontalUserOffset) mask |= 4;
    return mask;
  }

  int _lastEventWiringSignature = 0;

  void _syncEventDispatcherForWiringChange() {
    final signature = _eventWiringSignature();
    if (signature == _lastEventWiringSignature) return;
    _lastEventWiringSignature = signature;
    _syncEventDispatcher();
  }

  void _syncEventDispatcher({bool deferForActiveTouch = true}) {
    if (deferForActiveTouch && _touchEventSyncLatch.deferIfActive()) return;
    if (deferForActiveTouch && (_eventDispatcher?.hasActivePointerSequence ?? false)) {
      _touchEventSyncLatch.markDeferred();
      return;
    }
    final effectiveEvent = _buildEffectiveEvent();
    if (effectiveEvent == null) {
      _eventDispatcher?.dispose();
      _eventDispatcher = null;
      return;
    }
    _ensureEventDispatcher().event = effectiveEvent;
  }

  EventDispatcher _ensureEventDispatcher() {
    final existing = _eventDispatcher;
    final dispatcher = existing ?? (_eventDispatcher = EventDispatcher(this));
    dispatcher
      ..dragDevices = _dragDevices
      ..gestureSettings = _gestureSettings
      ..multitouchDragStrategy = _multitouchDragStrategy
      ..velocityTrackerBuilder = _velocityTrackerBuilder
      ..onRoutedPointerRemoved = _handleRoutedPointerRemoved;
    return dispatcher;
  }

  void _handleRoutedPointerRemoved(PointerRemovedEvent event) {
    _cancelActiveScrollDrag();
    scheduleMicrotask(() {
      if (!attached) return;
      _touchEventSyncLatch.handleRoutedPointerRemoved(
        event,
        _syncEventDispatcher,
        externalActive: _eventDispatcher?.hasActivePointerSequence ?? false,
      );
    });
  }

  ElEvent? _buildEffectiveEvent() {
    final userEvent = _userEvent;
    final shouldWireScrollDrag = _canDrag && _shouldAcceptUserOffset;
    final shouldWireHorizontalScrollDrag = _dualAxis && _canDrag && _shouldAcceptHorizontalUserOffset;
    final anyWire = shouldWireScrollDrag || shouldWireHorizontalScrollDrag;
    final anyAcceptOffset = _shouldAcceptUserOffset || _shouldAcceptHorizontalUserOffset;
    var effective = (userEvent ?? const ElEvent()).copyWith(
      // pointer down/up/cancel 挂滚动 hold 生命周期——down 时 hold position
      // 立刻停住进行中的 ballistic（对齐 Flutter Scrollable 的 onDown 语义），
      // up/cancel 时若拖拽未起飞则释放 hold。
      onPointerDown: _chainScrollDragPointer(userEvent?.onPointerDown, _handleScrollDragPointerDown),
      onPointerUp: _chainScrollDragPointer(userEvent?.onPointerUp, _handleScrollDragPointerUpOrCancel),
      onPointerCancel: _chainScrollDragPointer(userEvent?.onPointerCancel, _handleScrollDragPointerUpOrCancel),
      onPointerPanZoomStart: anyWire
          ? _chainDefault(userEvent?.onPointerPanZoomStart, _handleScrollPanZoomStart)
          : userEvent?.onPointerPanZoomStart,
      onPointerPanZoomUpdate: anyWire
          ? _chainDefault(userEvent?.onPointerPanZoomUpdate, _handleScrollPanZoomUpdate)
          : userEvent?.onPointerPanZoomUpdate,
      onPointerPanZoomEnd: anyWire
          ? _chainDefault(userEvent?.onPointerPanZoomEnd, _handleScrollPanZoomEnd)
          : userEvent?.onPointerPanZoomEnd,
      onPointerSignal: anyAcceptOffset
          ? _chainDefault(userEvent?.onPointerSignal, _handleScrollPointerSignal)
          : userEvent?.onPointerSignal,
    );

    if (!shouldWireScrollDrag && !shouldWireHorizontalScrollDrag) {
      // 滚动不接线时不挂轴向组，只给用户各组回调包一层 scrollbar 阻断
      // （thumb 拖拽活跃时吞掉 drag 事件）；各组原位放回，识别语义不变。
      return effective.copyWith(
        onDragStart: _chainDefaultDrag(userEvent?.onDragStart, null),
        onDragUpdate: _chainDefaultDrag(userEvent?.onDragUpdate, null),
        onDragEnd: _chainDefaultDrag(userEvent?.onDragEnd, null),
        onDragCancel: _chainDefaultDrag(userEvent?.onDragCancel, null),
        onVerticalDragStart: _chainDefaultDrag(userEvent?.onVerticalDragStart, null),
        onVerticalDragUpdate: _chainDefaultDrag(userEvent?.onVerticalDragUpdate, null),
        onVerticalDragEnd: _chainDefaultDrag(userEvent?.onVerticalDragEnd, null),
        onVerticalDragCancel: _chainDefaultDrag(userEvent?.onVerticalDragCancel, null),
        onHorizontalDragStart: _chainDefaultDrag(userEvent?.onHorizontalDragStart, null),
        onHorizontalDragUpdate: _chainDefaultDrag(userEvent?.onHorizontalDragUpdate, null),
        onHorizontalDragEnd: _chainDefaultDrag(userEvent?.onHorizontalDragEnd, null),
        onHorizontalDragCancel: _chainDefaultDrag(userEvent?.onHorizontalDragCancel, null),
      );
    }

    // 滚动拖拽挂到滚动轴对应的轴向组。用户回调优先取同轴组；自由拖拽组
    // （onDrag*）视为想观察本容器的滚动手势，链入主轴组（对齐旧 dragAxis
    // 语义——回调收到的 callback.dragAxis 即滚动轴），链入后从 free 字段清除，
    // 否则与轴向组构成 pan/轴向互斥违例。
    //
    // 双轴模式同挂垂直、水平两组，起手方向按倾斜角竞争锁轴
    // （[ElEventConfig.dragHorizontalAngle]），胜出组独立驱动对应轴的 position。
    final isVertical = _axis == Axis.vertical;
    final userMainStart = isVertical
        ? (userEvent?.onVerticalDragStart ?? userEvent?.onDragStart)
        : (userEvent?.onHorizontalDragStart ?? userEvent?.onDragStart);
    final userMainUpdate = isVertical
        ? (userEvent?.onVerticalDragUpdate ?? userEvent?.onDragUpdate)
        : (userEvent?.onHorizontalDragUpdate ?? userEvent?.onDragUpdate);
    final userMainEnd = isVertical
        ? (userEvent?.onVerticalDragEnd ?? userEvent?.onDragEnd)
        : (userEvent?.onHorizontalDragEnd ?? userEvent?.onDragEnd);
    final userMainCancel = isVertical
        ? (userEvent?.onVerticalDragCancel ?? userEvent?.onDragCancel)
        : (userEvent?.onHorizontalDragCancel ?? userEvent?.onDragCancel);

    final mainStart = shouldWireScrollDrag
        ? _chainDefaultDrag(userMainStart, _handleScrollDragStart)
        : _chainDefaultDrag(userMainStart, null);
    final mainUpdate = shouldWireScrollDrag
        ? _chainDefaultDrag(userMainUpdate, _handleScrollDragUpdate)
        : _chainDefaultDrag(userMainUpdate, null);
    final mainEnd = shouldWireScrollDrag
        ? _chainDefaultDrag(userMainEnd, _handleScrollDragEnd)
        : _chainDefaultDrag(userMainEnd, null);
    final mainCancel = shouldWireScrollDrag
        ? _chainDefaultDrag(userMainCancel, _handleScrollDragCancel)
        : _chainDefaultDrag(userMainCancel, null);

    // 双轴的水平组：用户水平回调链入；单轴时交叉轴的用户轴组原位放回。
    final crossStart = shouldWireHorizontalScrollDrag
        ? _chainDefaultDrag(userEvent?.onHorizontalDragStart, _handleHorizontalScrollDragStart)
        : _chainDefaultDrag(isVertical ? userEvent?.onHorizontalDragStart : userEvent?.onVerticalDragStart, null);
    final crossUpdate = shouldWireHorizontalScrollDrag
        ? _chainDefaultDrag(userEvent?.onHorizontalDragUpdate, _handleHorizontalScrollDragUpdate)
        : _chainDefaultDrag(isVertical ? userEvent?.onHorizontalDragUpdate : userEvent?.onVerticalDragUpdate, null);
    final crossEnd = shouldWireHorizontalScrollDrag
        ? _chainDefaultDrag(userEvent?.onHorizontalDragEnd, _handleHorizontalScrollDragEnd)
        : _chainDefaultDrag(isVertical ? userEvent?.onHorizontalDragEnd : userEvent?.onVerticalDragEnd, null);
    final crossCancel = shouldWireHorizontalScrollDrag
        ? _chainDefaultDrag(userEvent?.onHorizontalDragCancel, _handleHorizontalScrollDragCancel)
        : _chainDefaultDrag(isVertical ? userEvent?.onHorizontalDragCancel : userEvent?.onVerticalDragCancel, null);

    effective = effective.copyWith(
      onDragStart: null,
      onDragUpdate: null,
      onDragEnd: null,
      onDragCancel: null,
      config: (userEvent?.config ?? const ElEventConfig()).copyWith(
        dragStartDistance: _dragStartDistance,
        // physics 的 minFlingDistance 默认值是常量 kTouchSlop(18)、不可空;
        // 保持旧行为:默认值视为"未设置"→ null → 设备自适应(真机 slop ≈8-9,
        // SLOP-1~3 守护)。显式设置其他值则原样生效。
        dragMinFlingDistance: _physics.minFlingDistance == kTouchSlop ? null : _physics.minFlingDistance,
        dragMinFlingVelocity: _physics.minFlingVelocity,
        dragMaxFlingVelocity: _physics.maxFlingVelocity,
      ),
      onVerticalDragStart: isVertical ? mainStart : crossStart,
      onVerticalDragUpdate: isVertical ? mainUpdate : crossUpdate,
      onVerticalDragEnd: isVertical ? mainEnd : crossEnd,
      onVerticalDragCancel: isVertical ? mainCancel : crossCancel,
      onHorizontalDragStart: isVertical ? crossStart : mainStart,
      onHorizontalDragUpdate: isVertical ? crossUpdate : mainUpdate,
      onHorizontalDragEnd: isVertical ? crossEnd : mainEnd,
      onHorizontalDragCancel: isVertical ? crossCancel : mainCancel,
    );
    return effective;
  }

  /// 先挂 scroll drag hold（down/up/cancel 的 hold 生命周期）→ 再 user handler。
  ElEventHandler _chainScrollDragPointer(
    ElEventHandler? userHandler,
    void Function(ElEventDetails event) scrollDragAction,
  ) {
    return (event) {
      scrollDragAction(event);
      userHandler?.call(event);
    };
  }

  ElEventHandler? _chainDefaultDrag(ElEventHandler? userHandler, void Function(ElEventDetails event)? defaultAction) {
    if (userHandler == null && defaultAction == null) return null;
    return (event) {
      userHandler?.call(event);
      if (_shouldRunDefaultAction(event)) {
        defaultAction?.call(event);
      }
    };
  }

  ElEventHandler _chainDefault(ElEventHandler? userHandler, void Function(ElEventDetails event) defaultAction) {
    return (event) {
      if (_mainAxisDeltaAlreadyConsumed(event)) return;
      userHandler?.call(event);
      if (_shouldRunDefaultAction(event)) {
        defaultAction(event);
      }
    };
  }

  bool _mainAxisDeltaAlreadyConsumed(ElEventDetails event) {
    switch (event.phase) {
      case ElEventPhase.pointerSignal:
        final original = event.originalEvent;
        if (original is! PointerScrollEvent) return false;
        return _pointerSignalDeltaAlreadyConsumed(original, event);
      case ElEventPhase.pointerPanZoomUpdate:
      case ElEventPhase.dragUpdate:
        break;
      default:
        return false;
    }
    if (_dualAxis) {
      return event.remainingPrimaryDelta(Axis.vertical) == 0.0 && event.remainingPrimaryDelta(Axis.horizontal) == 0.0;
    }
    return event.remainingPrimaryDelta(_axis) == 0.0;
  }

  bool _pointerSignalDeltaAlreadyConsumed(PointerScrollEvent original, ElEventDetails event) {
    for (final axisDelta in _pointerSignalEventDeltas(original)) {
      if (!_acceptsUserOffsetOnAxis(axisDelta.scrollAxis)) continue;
      if (event.remainingPrimaryDelta(axisDelta.inputAxis) != 0.0) return false;
    }
    return true;
  }

  bool _shouldRunDefaultAction(ElEventDetails event) {
    switch (event.phase) {
      case ElEventPhase.pointerPanZoomStart:
        _defaultPanZoomPrevented = event.defaultPrevented;
        return !_defaultPanZoomPrevented;
      case ElEventPhase.pointerPanZoomUpdate:
        if (event.defaultPrevented) {
          _defaultPanZoomPrevented = true;
          _cancelActiveScrollDrag();
          return false;
        }
        return !_defaultPanZoomPrevented;
      case ElEventPhase.pointerPanZoomEnd:
        final shouldRun = !_defaultPanZoomPrevented;
        _defaultPanZoomPrevented = false;
        return shouldRun;
      case ElEventPhase.dragStart:
        _defaultDragPrevented = event.defaultPrevented;
        return !_defaultDragPrevented;
      case ElEventPhase.dragUpdate:
        if (event.defaultPrevented) {
          _defaultDragPrevented = true;
          _cancelActiveScrollDrag();
          return false;
        }
        return !_defaultDragPrevented;
      case ElEventPhase.dragEnd:
      case ElEventPhase.dragCancel:
        _defaultDragPrevented = false;
        return true;
      default:
        return !event.defaultPrevented;
    }
  }

  bool get _shouldAcceptUserOffset =>
      _position.hasContentDimensions &&
      (_physics.shouldAcceptUserOffset(_position) ||
          (_deltaInterceptor is ScrollMotionInput && (_deltaInterceptor as ScrollMotionInput).hasMotionInputRange));

  int _debugLayoutCount = 0;

  /// 布局执行次数，供白盒诊断使用。
  int get debugLayoutCount => _debugLayoutCount;

  /// 上一次发给 children 的 [BoxConstraints]，供参照精确唤醒判据：约束不变
  /// 时 Flutter `layout()` 短路会跳过 children 的 performLayout，若参照发生
  /// 变化则需主动 mark 子树（主要覆盖双轴场景——两轴都是滚动轴，childConstraints
  /// 恒 (0, ∞)，视口宽变化不改变它，percent 消费者拿不到新参照会冻结）。
  BoxConstraints? _lastChildConstraints;

  List<RenderBox>? _childrenCache;

  Size _contentSize = Size.zero;

  double _maxScrollExtent = 0.0;

  double _maxHorizontalScrollExtent = 0.0;

  // --- Hot-path allocation cache (P1-1) ---
  Offset? _cachedScrollPaintOffset;

  double _cachedScrollPaintPixels = double.nan;

  /// paint offset 缓存的水平分量键（双轴；单轴恒 0）。
  double _cachedScrollPaintPixelsH = double.nan;

  /// 当前可见成员的起始索引。
  int get debugVisibleStart;

  /// 当前可见成员的结束索引，不包含该项。
  int get debugVisibleEnd;

  /// Full laid out content size, exposed for tests and diagnostics.
  Size get contentSize => _contentSize;

  int _debugScrollHitBoundsDirtyCount = 0;

  /// 滚动热路实际使命中边界失效的次数，仅供诊断。
  int get debugScrollHitBoundsDirtyCount => _debugScrollHitBoundsDirtyCount;

  /// Whether this scroll view currently holds the cursor freeze window.
  bool get debugCursorFreezeActive => ScrollCursorFreeze.ownedBy(this);

  /// Applies a small programmatic auto-scroll delta during selection dragging.
  ///
  /// Positive deltas move toward larger [ScrollPosition.pixels].
  @override
  double applySelectionAutoScrollDelta(double delta) {
    if (!_position.hasPixels || !_position.hasContentDimensions) return 0.0;
    _resetSmoothPointerScroll();
    final oldPixels = _position.pixels;
    final target = _targetScrollOffsetForPointerScroll(delta);
    if ((target - oldPixels).abs() <= precisionErrorTolerance) return 0.0;
    _position.jumpTo(target);
    return _position.pixels - oldPixels;
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  ResolvedStyle? get committedResolvedStyle {
    var p = parent;
    while (p != null) {
      if (p is InheritableNode) {
        return (p as InheritableNode).committedResolvedStyle;
      }
      p = p.parent;
    }
    return null;
  }

  @override
  bool get effectiveDarkForInheritance {
    var p = parent;
    while (p != null) {
      if (p is InheritableNode) return (p as InheritableNode).effectiveDarkForInheritance;
      p = p.parent;
    }
    return false;
  }

  /// **T11**：scroll 容器不 emit inherited 字段（自身无 ElStyle 声明），
  /// 显式设置位图恒 0。propagator 走 mask AND-NOT 时该分支永远不截断。
  @override
  FieldMask get explicitlySetMask => FieldMask.empty;

  @override
  void visitInheritableChildren(void Function(InheritableNode child) visitor) {
    visitChildren((child) => _walkInheritable(child, visitor));
  }

  void _walkInheritable(RenderObject node, void Function(InheritableNode child) visitor) {
    if (node is InheritableNode) {
      visitor(node as InheritableNode);
    } else {
      node.visitChildren((child) => _walkInheritable(child, visitor));
    }
  }

  @override
  FieldMask reresolveFromInheritance(
    ResolvedStyle? newParentResolved,
    FieldMask changedMask, {
    FieldMask inheritedThemeAnimationMask = FieldMask.empty,
  }) => inheritedThemeAnimationMask;

  @override
  void reresolveVarsFromInheritance(ResolvedStyle? newParentResolved) {
    visitInheritableChildren((child) => child.reresolveVarsFromInheritance(newParentResolved));
  }

  @override
  bool inheritDarkFromAncestor(bool dark) => true;

  /// **T-variant2** — 透明节点：走父链读响应式位。
  @override
  int get responsiveBitsForInheritance {
    var p = parent;
    while (p != null) {
      if (p is InheritableNode) return (p as InheritableNode).responsiveBitsForInheritance;
      p = p.parent;
    }
    return 0;
  }

  /// **T-variant2** — 透明节点：不阻断响应式位下推。
  @override
  bool inheritResponsiveFromAncestor(int bits) => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _position.addListener(_handleScrollOffsetChanged);
    _horizontalPosition?.addListener(_handleHorizontalScrollOffsetChanged);
    _syncEventDispatcher(deferForActiveTouch: false);
  }

  @override
  void detach() {
    _position.removeListener(_handleScrollOffsetChanged);
    _horizontalPosition?.removeListener(_handleHorizontalScrollOffsetChanged);
    _touchEventSyncLatch.reset();
    // 重挂（临时离树、同帧 attach 回来）不中断：dispatcher 与在途滚动拖拽原样
    // 保留，与 ElRenderView 同一规则；真销毁交给 dispose 结算。
    _defaultDragPrevented = false;
    _defaultPanZoomPrevented = false;
    _resetSmoothPointerScroll();
    _resetHorizontalSmoothPointerScroll();
    _releasePointerScrollChain();
    if (ScrollCursorFreeze.ownedBy(this)) {
      ScrollCursorFreeze.release(updateMouseTracker: false);
    }
    super.detach();
  }

  @override
  Listenable get scrollOffsetListenable => _scrollOffsetRelay;

  final ScrollOffsetRelay _scrollOffsetRelay = ScrollOffsetRelay();

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ScrollChildParentData) {
      child.parentData = ScrollChildParentData();
    }
  }

  @override
  void insert(RenderBox child, {RenderBox? after}) {
    _invalidateChildStructureCache();
    super.insert(child, after: after);
  }

  @override
  void move(RenderBox child, {RenderBox? after}) {
    _invalidateChildStructureCache();
    super.move(child, after: after);
  }

  @override
  void remove(RenderBox child) {
    _invalidateChildStructureCache();
    super.remove(child);
  }

  @override
  void removeAll() {
    _invalidateChildStructureCache();
    super.removeAll();
  }

  void _invalidateChildStructureCache() {
    _childrenCache = null;
  }

  @override
  void markNeedsLayout() {
    _invalidateScrollPaintCache();
    super.markNeedsLayout();
  }

  List<RenderBox> _children() {
    final cache = _childrenCache;
    if (cache != null) return cache;
    // Build list via manual loop to avoid sync* generator allocation on
    // first access after markNeedsLayout.
    final result = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      result.add(child);
      final parentData = child.parentData as ScrollChildParentData;
      child = parentData.nextSibling;
    }
    return _childrenCache = result;
  }

  double _mainExtent(Size size) => _axis == Axis.vertical ? size.height : size.width;

  bool get _isAxisReversed => axisDirectionIsReversed(_axisDirection);

  double _contentScrollPixels([double? positionPixels]) {
    // 内容渲染口径必须用 position.pixels：含回弹/过度滚动等物理附加偏移，
    // 正文由此跟随回弹与拉伸；原生定位成员使用自己的视口坐标。
    final pixels = positionPixels ?? (_position.hasPixels ? _position.pixels : 0.0);
    return _isAxisReversed ? _maxScrollExtent - pixels : pixels;
  }

  double _positionPixelsForContentScroll(double contentScrollPixels) {
    return _isAxisReversed ? _maxScrollExtent - contentScrollPixels : contentScrollPixels;
  }

  Offset _scrollPaintOffsetFor(double pixels) {
    // P1: cache scroll paint offset — reused across paint, hitTest, applyPaintTransform
    final horizontalPixels = _dualAxis ? _paintHorizontalScrollPixels() : 0.0;
    if (pixels == _cachedScrollPaintPixels &&
        horizontalPixels == _cachedScrollPaintPixelsH &&
        _cachedScrollPaintOffset != null) {
      return _cachedScrollPaintOffset!;
    }
    _cachedScrollPaintPixels = pixels;
    _cachedScrollPaintPixelsH = horizontalPixels;
    return _cachedScrollPaintOffset = _axis == Axis.vertical
        ? Offset(-horizontalPixels, -pixels)
        : Offset(-pixels, -horizontalPixels);
  }

  /// 主轴口径的相对平移（reveal 计算用）：不掺当前水平偏移、不污染缓存。
  Offset _mainAxisPaintShift(double pixels) {
    return _axis == Axis.vertical ? Offset(0.0, -pixels) : Offset(-pixels, 0.0);
  }

  double _paintHorizontalScrollPixels() {
    return _horizontalContentScrollPixels();
  }

  /// 上次**实际绘制**时使用的主轴逻辑像素。
  ///
  /// 必须保留亚像素：高刷慢拖与缓动尾段常小于 1 物理像素/帧，
  /// 若先 round 再判定重绘，会把多个真实帧合并成“停住后跳一格”。
  double _lastPaintedScrollPixels = double.nan;

  /// 水平轴口径的 [_lastPaintedScrollPixels]（仅双轴模式绘制时更新）。
  double _lastPaintedHorizontalScrollPixels = double.nan;

  void _invalidateScrollPaintCache() {
    _cachedScrollPaintPixels = double.nan;
    _cachedScrollPaintPixelsH = double.nan;
    _cachedScrollPaintOffset = null;
  }

  double _paintScrollPixels() => _contentScrollPixels();

  @override
  double computeMinIntrinsicWidth(double height) {
    if (_axis == Axis.horizontal) {
      return _intrinsicMain(isMin: true, extent: height) + _padding.horizontal;
    }
    return _intrinsicCross(isMin: true, extent: height) + _padding.horizontal;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (_axis == Axis.horizontal) {
      return _intrinsicMain(isMin: false, extent: height) + _padding.horizontal;
    }
    return _intrinsicCross(isMin: false, extent: height) + _padding.horizontal;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (_axis == Axis.vertical) {
      return _intrinsicMain(isMin: true, extent: width) + _padding.vertical;
    }
    return _intrinsicCross(isMin: true, extent: width) + _padding.vertical;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (_axis == Axis.vertical) {
      return _intrinsicMain(isMin: false, extent: width) + _padding.vertical;
    }
    return _intrinsicCross(isMin: false, extent: width) + _padding.vertical;
  }

  double _intrinsicMain({required bool isMin, required double extent}) {
    final children = _children();
    var total = 0.0;
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      total += _axis == Axis.vertical
          ? (isMin ? child.getMinIntrinsicHeight(extent) : child.getMaxIntrinsicHeight(extent))
          : (isMin ? child.getMinIntrinsicWidth(extent) : child.getMaxIntrinsicWidth(extent));
    }
    return total + math.max(0, children.length - 1) * _mainAxisGap;
  }

  double _intrinsicCross({required bool isMin, required double extent}) {
    final children = _children();
    var maxCross = 0.0;
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final childCross = _axis == Axis.vertical
          ? (isMin ? child.getMinIntrinsicWidth(extent) : child.getMaxIntrinsicWidth(extent))
          : (isMin ? child.getMinIntrinsicHeight(extent) : child.getMaxIntrinsicHeight(extent));
      maxCross = math.max(maxCross, childCross);
    }
    return maxCross;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToHighestActualBaseline(baseline);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_shouldClip()) {
      _clipRectLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        _paintViewportChildrenCallback,
        clipBehavior: _clipBehavior,
        oldLayer: _clipRectLayer.layer,
      );
    } else {
      _clipRectLayer.layer = null;
      paintViewportChildren(context, offset);
    }
  }

  late final PaintingContextCallback _paintViewportChildrenCallback = paintViewportChildren;

  bool _shouldClip() {
    if (_clipBehavior == Clip.none) return false;
    final paintOffset = _scrollPaintOffsetFor(_paintScrollPixels());
    return paintOffset.dx < 0.0 ||
        paintOffset.dy < 0.0 ||
        paintOffset.dx + _contentSize.width > size.width ||
        paintOffset.dy + _contentSize.height > size.height;
  }

  /// 绘制裁剪的镜像口径（官方 RenderViewportBase 同款契约）：实际裁剪时向
  /// 消费者（语义、选区阅读序排序等）报告子内容被裁进自身盒，让卷出视口的
  /// 部分不参与可见几何；不裁剪（Clip.none 或内容未溢出）返回 null 放行。
  @override
  Rect? describeApproximatePaintClip(RenderObject child) => _shouldClip() ? Offset.zero & size : null;

  final LayerHandle<ClipRectLayer> _clipRectLayer = LayerHandle<ClipRectLayer>();

  // --- 溢出命中边界协议（ElOverflowHitBounds） --------------------------------
  // 视口默认裁剪（_shouldClip true）= 封口，聚合恒为自身盒、滚动零重算；
  // Clip.none 或内容未超视口（不建 clip 层，行溢出可视）时放行子聚合。

  @override
  Rect get selfHitRect => Offset.zero & size;

  @override
  bool get clipsHitBounds => _shouldClip();

  @override
  void visitHitBoundsChildren(void Function(RenderBox child, Offset offset) visitor);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // 拖拽指针锁：整树吞命中 + 锁光标（见 [DragPointerLock] 类注）。
    if (DragPointerLock.blocksHitTesting) {
      result.add(HitTestEntry(dragPointerLockBarrier));
      return true;
    }
    if (!size.contains(position)) {
      // 未封口（Clip.none / 内容未超视口）时行溢出画得出来，须可命中。
      if (!hitBoundsContains(position)) return false;
      final hit = hitTestChildren(result, position: position);
      if (hit) result.add(BoxHitTestEntry(this, position));
      return hit;
    }
    final hit = hitTestChildren(result, position: position) || hitTestSelf(position);
    if (hit) result.add(BoxHitTestEntry(this, position));
    return hit;
  }

  /// 命中屏蔽窗口：`_ignorePointer` 是官方活动级要求（[BallisticScrollActivity]
  /// 继承拖拽期的值、DrivenScrollActivity 恒真），再叠一道
  /// [fingerDragScrolling] 把本判据收敛到**手指拖拽期**——程序驱动动画
  /// （animateTo / smoothScroll）期间内容仍可直接点到；触摸 fling 的屏蔽由
  /// 判据 3 独立承担。判据在命中现场取，不用推送标志，drag→ballistic 交接
  /// 零延迟。
  bool get _fingerDragScrolling {
    final horizontal = _horizontalPosition;
    return fingerDragScrolling(_position) || (horizontal != null && fingerDragScrolling(horizontal));
  }

  /// 内容退出命中路径的完整窗口，三个来源取或：
  /// 1. 手指拖着 position 滚（[_fingerDragScrolling]）；
  /// 2. 位移被拦截器吃走的拖拽（下拉刷新拉出期：delta 整笔进指示器、
  ///    position 不动，压根没有 DragScrollActivity 可查）；
  /// 3. 触摸起飞的 fling 仍在飞（[touchFlingScrolling]）——整段屏蔽直到
  ///    停稳（2026-08-02 用户裁决，尾段放行仍偶发误触），落下的触摸只停住
  ///    滚动，不点亮/激活内容；程序驱动动画不在此列，内容照常可点。
  bool get _dragSuppressesContentHits {
    if (_scrollDrag.gestureClaimedByInterceptor) return true;
    if (_dualAxis && _horizontalScrollDrag.gestureClaimedByInterceptor) return true;
    if (_ignorePointer && _fingerDragScrolling) return true;
    final horizontal = _horizontalPosition;
    return touchFlingScrolling(_position) || (horizontal != null && touchFlingScrolling(horizontal));
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  RevealedOffset getOffsetToReveal(RenderObject target, double alignment, {Rect? rect, Axis? axis}) {
    final horizontalRequest = _dualAxis && axis == Axis.horizontal;
    if (axis != null && axis != _axis && !horizontalRequest) {
      return RevealedOffset(offset: _position.pixels, rect: rect ?? target.paintBounds);
    }
    rect ??= target.paintBounds;
    if (target is! RenderBox) {
      return RevealedOffset(offset: (horizontalRequest ? _horizontalPosition! : _position).pixels, rect: rect);
    }

    final currentRect = MatrixUtils.transformRect(target.getTransformTo(this), rect);
    if (horizontalRequest) {
      final currentContentScroll = _horizontalContentScrollPixels();
      final contentMain = currentRect.left + currentContentScroll;
      final targetContentScroll = contentMain - (size.width - currentRect.width) * alignment;
      final targetPositionPixels = _horizontalPositionPixelsForContentScroll(targetContentScroll);
      final revealedRect = currentRect.shift(Offset(-(targetContentScroll - currentContentScroll), 0.0));
      return RevealedOffset(offset: targetPositionPixels, rect: revealedRect);
    }
    final currentMain = _axis == Axis.vertical ? currentRect.top : currentRect.left;
    final targetExtent = _axis == Axis.vertical ? currentRect.height : currentRect.width;
    final currentContentScroll = _contentScrollPixels();
    final contentMain = currentMain + currentContentScroll;
    final targetContentScroll = contentMain - (_mainExtent(size) - targetExtent) * alignment;
    final targetPositionPixels = _positionPixelsForContentScroll(targetContentScroll);
    final revealedRect = currentRect.shift(_mainAxisPaintShift(targetContentScroll - currentContentScroll));
    return RevealedOffset(offset: targetPositionPixels, rect: revealedRect);
  }

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    if (!_position.allowImplicitScrolling) {
      return super.showOnScreen(descendant: descendant, rect: rect, duration: duration, curve: curve);
    }

    final newRect = RenderViewportBase.showInViewport(
      descendant: descendant,
      viewport: this,
      offset: _position,
      rect: rect,
      duration: duration,
      curve: curve,
    );
    if (_dualAxis && descendant != null && (_horizontalPosition?.allowImplicitScrolling ?? false)) {
      _revealHorizontally(descendant, rect, duration, curve);
    }
    super.showOnScreen(rect: newRect, duration: duration, curve: curve);
  }

  /// 双轴的水平向 reveal：目标不在水平视窗内时滚动最小距离使其可见
  /// （对齐 [RenderViewportBase.showInViewport] 的就近语义）。
  void _revealHorizontally(RenderObject descendant, Rect? rect, Duration duration, Curve curve) {
    final horizontal = _horizontalPosition!;
    if (!horizontal.hasPixels || !horizontal.hasContentDimensions) return;
    final leading = getOffsetToReveal(descendant, 0.0, rect: rect, axis: Axis.horizontal).offset;
    final trailing = getOffsetToReveal(descendant, 1.0, rect: rect, axis: Axis.horizontal).offset;
    final lower = math.min(leading, trailing);
    final upper = math.max(leading, trailing);
    final current = horizontal.pixels;
    double? target;
    if (current < lower) {
      target = lower;
    } else if (current > upper) {
      target = upper;
    }
    if (target == null) return;
    target = target.clamp(horizontal.minScrollExtent, horizontal.maxScrollExtent).toDouble();
    if ((target - current).abs() <= precisionErrorTolerance) return;
    if (duration == Duration.zero) {
      horizontal.jumpTo(target);
    } else {
      horizontal.animateTo(target, duration: duration, curve: curve);
    }
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    super.handleEvent(event, entry);
    final shouldFlushTouchLatchAfterDispatch = _touchEventSyncLatch.beforeDispatch(event);
    if (event.kind == PointerDeviceKind.mouse &&
        (event is PointerHoverEvent || event is PointerMoveEvent || event is PointerDownEvent)) {
      // 只有真实是当前 owner 持有冻结时才 release，避免外层 viewport 把内层
      // 触发的 claim 立即释放掉，导致 cursor 在嵌套滚动时反复抖动。
      if (ScrollCursorFreeze.ownedBy(this)) {
        // 真实 mouse event 到达 handleEvent 前 MouseTracker 已用本次命中路径
        // 更新过光标；这里再 updateAllDevices 只会同步重跑一遍全树命中。
        ScrollCursorFreeze.release(updateMouseTracker: false);
      }
    }
    _eventDispatcher?.handleEvent(event, entry);
    if (shouldFlushTouchLatchAfterDispatch) {
      // raw 终态早于 PointerRouter 内的手势收尾，结构更新必须等两者都结束。
      scheduleMicrotask(() {
        if (attached) _touchEventSyncLatch.flushAfterDispatch(_syncEventDispatcher);
      });
    } else {
      _touchEventSyncLatch.flushIfIdle(
        _syncEventDispatcher,
        externalActive: _eventDispatcher?.hasActivePointerSequence ?? false,
      );
    }
    if (event is PointerRemovedEvent) {
      _handleRoutedPointerRemoved(event);
    }
  }

  late final SmoothPointerScrollController _smoothPointerScroll;

  late final SmoothPointerScrollController _horizontalSmoothPointerScroll;

  late final ScrollViewDragController _scrollDrag;

  late final ScrollViewDragController _horizontalScrollDrag;

  bool get _hasDirectPointerDrag =>
      _scrollDrag.isDirectPointerDragActive || _horizontalScrollDrag.isDirectPointerDragActive;

  void _markScrollHitBoundsDirtyIfNeeded() {
    // 视口已裁剪时，对外命中边界恒为自身盒；滚动只改变盒内
    // 内容的 paint transform，每 tick 向父链传播失效只会放大 MouseTracker 开销。
    if (hasSize && clipsHitBounds) return;
    _debugScrollHitBoundsDirtyCount++;
    markHitBoundsDirty();
  }

  void _resetHorizontalSmoothPointerScroll() {
    _horizontalSmoothPointerScroll.reset();
  }

  double _targetHorizontalScrollOffsetForPointerScroll(double delta, {double? from}) {
    final position = _horizontalPosition!;
    final base = from ?? position.pixels;
    return math.min(math.max(base + delta, position.minScrollExtent), position.maxScrollExtent);
  }

  bool get _shouldAcceptHorizontalUserOffset {
    final position = _horizontalPosition;
    return position != null &&
        position.hasContentDimensions &&
        (_physics.shouldAcceptUserOffset(position) ||
            (_horizontalDeltaInterceptor is ScrollMotionInput &&
                (_horizontalDeltaInterceptor as ScrollMotionInput).hasMotionInputRange));
  }

  bool get _isHorizontalAxisReversed => axisDirectionIsReversed(_horizontalAxisDirection);

  double _horizontalContentScrollPixels([double? positionPixels]) {
    final position = _horizontalPosition;
    final pixels = positionPixels ?? (position != null && position.hasPixels ? position.pixels : 0.0);
    return _isHorizontalAxisReversed ? _maxHorizontalScrollExtent - pixels : pixels;
  }

  double _horizontalPositionPixelsForContentScroll(double contentScrollPixels) {
    return _isHorizontalAxisReversed ? _maxHorizontalScrollExtent - contentScrollPixels : contentScrollPixels;
  }

  /// 水平轴滚动偏移变化：只影响 paint 平移与横向滚动条，不触碰主轴的可见
  /// 窗口（可见窗口按布局主轴裁剪，交叉轴只是平移）。
  void _handleHorizontalScrollOffsetChanged() {
    _markScrollHitBoundsDirtyIfNeeded();
    final contentPixels = _horizontalContentScrollPixels();
    final changed = _lastPaintedHorizontalScrollPixels.isNaN || contentPixels != _lastPaintedHorizontalScrollPixels;
    if (changed) {
      _cachedScrollPaintPixels = double.nan;
      _cachedScrollPaintOffset = null;
      if (attached && !_hasDirectPointerDrag) ScrollCursorFreeze.claim(this);
    }
    if (changed) {
      markNeedsPaintForScroll();
    }
    // 先完成内部缓存与重绘标记，再通知选区等外部消费者；选区会同步读取
    // paint transform，若通知在前会提前刷新缓存并让 changed 误判为 false。
    _scrollOffsetRelay.notify();
    if (owner?.semanticsOwner != null) {
      markNeedsSemanticsUpdate();
    }
  }

  bool _allowsDefaultContentDragScroll(ElEventDetails event) {
    final original = event.originalEvent;
    final kind = original is PointerEvent ? original.kind : null;
    if (kind == null) return true;
    final allowed = _dragDevices ?? kViewportDragDevices;
    return allowed.contains(kind);
  }

  void _handleScrollDragStart(ElEventDetails event) {
    if (!_allowsDefaultContentDragScroll(event)) return;
    onScrollInputActivityChanged?.call(_axis, ElScrollActivityType.touchDrag);
    _scrollDrag.handleDragStart(event);
  }

  void _handleScrollDragUpdate(ElEventDetails event) {
    if (!_allowsDefaultContentDragScroll(event)) return;
    _scrollDrag.handleDragUpdate(event);
  }

  void _handleScrollDragEnd(ElEventDetails event) {
    if (!_allowsDefaultContentDragScroll(event)) return;
    _scrollDrag.handleDragEnd(event, allowBallistic: !event.defaultPrevented);
    onScrollInputActivityChanged?.call(_axis, null);
  }

  void _handleScrollDragCancel(ElEventDetails event) {
    if (!_allowsDefaultContentDragScroll(event)) return;
    _scrollDrag.handleDragCancel(event);
    onScrollInputActivityChanged?.call(_axis, null);
  }

  void _handleHorizontalScrollDragStart(ElEventDetails event) {
    if (!_allowsDefaultContentDragScroll(event)) return;
    onScrollInputActivityChanged?.call(Axis.horizontal, ElScrollActivityType.touchDrag);
    _horizontalScrollDrag.handleDragStart(event);
  }

  void _handleHorizontalScrollDragUpdate(ElEventDetails event) {
    if (!_allowsDefaultContentDragScroll(event)) return;
    _horizontalScrollDrag.handleDragUpdate(event);
  }

  void _handleHorizontalScrollDragEnd(ElEventDetails event) {
    if (!_allowsDefaultContentDragScroll(event)) return;
    _horizontalScrollDrag.handleDragEnd(event, allowBallistic: !event.defaultPrevented);
    onScrollInputActivityChanged?.call(Axis.horizontal, null);
  }

  void _handleHorizontalScrollDragCancel(ElEventDetails event) {
    if (!_allowsDefaultContentDragScroll(event)) return;
    _horizontalScrollDrag.handleDragCancel(event);
    onScrollInputActivityChanged?.call(Axis.horizontal, null);
  }

  /// pointer down/up 的 hold 生命周期：双轴时两轴 position 都要 hold
  /// （按下即停住任一轴进行中的 ballistic——CSS 语义）。
  void _handleScrollDragPointerDown(ElEventDetails event) {
    _scrollDrag.handlePointerDown(event);
    if (_scrollDrag.isHolding) {
      onScrollInputActivityChanged?.call(_axis, ElScrollActivityType.hold);
    }
    if (_dualAxis) {
      _horizontalScrollDrag.handlePointerDown(event);
      if (_horizontalScrollDrag.isHolding) {
        onScrollInputActivityChanged?.call(Axis.horizontal, ElScrollActivityType.hold);
      }
    }
  }

  void _handleScrollDragPointerUpOrCancel(ElEventDetails event) {
    _scrollDrag.handlePointerUpOrCancel(event);
    if (!_scrollDrag.isHolding && !_scrollDrag.isDirectPointerDragActive) {
      onScrollInputActivityChanged?.call(_axis, null);
    }
    if (_dualAxis) {
      _horizontalScrollDrag.handlePointerUpOrCancel(event);
      if (!_horizontalScrollDrag.isHolding && !_horizontalScrollDrag.isDirectPointerDragActive) {
        onScrollInputActivityChanged?.call(Axis.horizontal, null);
      }
    }
  }

  void _cancelActiveScrollDrag() {
    _scrollDrag.cancelActiveDrag();
    _horizontalScrollDrag.cancelActiveDrag();
    onScrollInputActivityChanged?.call(_axis, null);
    if (_dualAxis) onScrollInputActivityChanged?.call(Axis.horizontal, null);
  }

  void _disposeActiveScrollDrag() {
    _scrollDrag.disposeActiveDrag();
    _horizontalScrollDrag.disposeActiveDrag();
  }

  double _targetScrollOffsetForPointerScroll(double delta, {double? from}) {
    final base = from ?? _position.pixels;
    return math.min(math.max(base + delta, _position.minScrollExtent), _position.maxScrollExtent);
  }

  /// 单事件轴分量 memo：同一物理滚轮事件在派发链上被多次走查（命中期
  /// _receivedPointerScroll、resolver flush 期 _axisDeltaFor、选区根路径），
  /// 分量只由事件与本视口配置决定，首次解算即缓存到下一个事件。
  /// 键取 `event.original ?? event`（与 pointerSignalResolver 同口径，覆盖
  /// 坐标变换副本）；缓存只跨单次事件派发，其间不会插入配置变更或帧边界。
  Object? _pointerScrollDeltasKey;

  List<_PointerScrollAxisDelta>? _pointerScrollDeltas;

  _PointerScrollAxisDelta _pointerSignalEventDelta(
    PointerScrollEvent event, {
    required Axis inputAxis,
    required Axis scrollAxis,
  }) {
    final inputDelta = switch (inputAxis) {
      Axis.horizontal => event.scrollDelta.dx,
      Axis.vertical => event.scrollDelta.dy,
    };
    return _PointerScrollAxisDelta(
      inputAxis: inputAxis,
      scrollAxis: scrollAxis,
      inputDelta: inputDelta,
      scrollDelta: _scrollDeltaForInput(scrollAxis, inputDelta),
    );
  }

  List<_PointerScrollAxisDelta> _pointerSignalEventDeltas(PointerScrollEvent event) {
    final key = event.original ?? event;
    final cached = _pointerScrollDeltas;
    if (cached != null && identical(_pointerScrollDeltasKey, key)) return cached;
    final deltas = _resolvePointerSignalEventDeltas(event);
    _pointerScrollDeltasKey = key;
    _pointerScrollDeltas = deltas;
    return deltas;
  }

  /// 滚轮/信号事件的按轴分量拆解。
  ///
  /// 单轴：现状主轴口径（modifier 翻转输入轴向），横向鼠标滚轮可由
  /// [mouseWheelHorizontalModifiers] 把纵向输入映射到横向滚动。双轴：dy 喂
  /// 垂直、dx 喂横向（触控板斜滚双轴同动），modifier 按住时交换分量
  /// （shift+滚轮横滚）。
  /// 键盘修饰态每次解算只取一次（官方 logicalKeysPressed getter 每调用拷贝
  /// 一个 Set），非鼠标设备先按 kind 短路，连拷贝都省掉。
  List<_PointerScrollAxisDelta> _resolvePointerSignalEventDeltas(PointerScrollEvent event) {
    final pressedKeys = event.kind == PointerDeviceKind.mouse ? HardwareKeyboard.instance.logicalKeysPressed : null;
    if (!_dualAxis) {
      final delta = _pointerSignalEventDelta(
        event,
        inputAxis: _singleAxisPointerScrollInputAxis(event, pressedKeys),
        scrollAxis: _axis,
      );
      return delta.isZero ? const <_PointerScrollAxisDelta>[] : <_PointerScrollAxisDelta>[delta];
    }
    final flipAxes = _hasPressedModifier(pressedKeys, _pointerAxisModifiers);
    final dx = flipAxes ? event.scrollDelta.dy : event.scrollDelta.dx;
    final dy = flipAxes ? event.scrollDelta.dx : event.scrollDelta.dy;
    return <_PointerScrollAxisDelta>[
      if (dy != 0.0)
        _PointerScrollAxisDelta(
          inputAxis: flipAxes ? Axis.horizontal : Axis.vertical,
          scrollAxis: Axis.vertical,
          inputDelta: dy,
          scrollDelta: _scrollDeltaForInput(Axis.vertical, dy),
        ),
      if (dx != 0.0)
        _PointerScrollAxisDelta(
          inputAxis: flipAxes ? Axis.vertical : Axis.horizontal,
          scrollAxis: Axis.horizontal,
          inputDelta: dx,
          scrollDelta: _scrollDeltaForInput(Axis.horizontal, dx),
        ),
    ];
  }

  Axis _singleAxisPointerScrollInputAxis(PointerScrollEvent event, Set<LogicalKeyboardKey>? pressedKeys) {
    if (_axis == Axis.horizontal && event.kind == PointerDeviceKind.mouse && event.scrollDelta.dy != 0.0) {
      final modifiers = _mouseWheelHorizontalModifiers;
      if (modifiers == null || _hasPressedModifier(pressedKeys, modifiers)) return Axis.vertical;
      return Axis.horizontal;
    }
    if (_hasPressedModifier(pressedKeys, _pointerAxisModifiers)) {
      return _axis == Axis.vertical ? Axis.horizontal : Axis.vertical;
    }
    return _axis;
  }

  bool _hasPressedModifier(Set<LogicalKeyboardKey>? pressedKeys, Set<LogicalKeyboardKey> modifiers) =>
      modifiers.isNotEmpty && pressedKeys != null && pressedKeys.any(modifiers.contains);

  double _scrollDeltaForInput(Axis scrollAxis, double inputDelta) {
    final reversed = scrollAxis == _axis ? axisDirectionIsReversed(_axisDirection) : _isHorizontalAxisReversed;
    return reversed ? -inputDelta : inputDelta;
  }

  /// 滚动轴对应的 smooth 滚轮控制器：主轴用主实例，非主轴仅双轴出现。
  SmoothPointerScrollController _smoothForAxis(Axis axis) =>
      axis == _axis ? _smoothPointerScroll : _horizontalSmoothPointerScroll;

  bool _acceptsUserOffsetOnAxis(Axis axis) =>
      axis == _axis ? _shouldAcceptUserOffset : _shouldAcceptHorizontalUserOffset;

  _PointerScrollAxisDelta? _axisDeltaFor(PointerScrollEvent event, Axis axis) {
    for (final delta in _pointerSignalEventDeltas(event)) {
      if (delta.scrollAxis == axis) return delta;
    }
    return null;
  }

  /// 触控板双指平移：双轴时两轴 controller 各消费各的分量（可斜滚——CSS
  /// 触控板语义，与触摸拖拽的竞争锁轴不同），台账天然按轴分账。
  void _handleScrollPanZoomStart(ElEventDetails event) {
    onScrollInputActivityChanged?.call(_axis, ElScrollActivityType.trackpad);
    if (_dualAxis) onScrollInputActivityChanged?.call(Axis.horizontal, ElScrollActivityType.trackpad);
    _scrollDrag.handlePanZoomStart(event);
    if (_dualAxis) _horizontalScrollDrag.handlePanZoomStart(event);
  }

  void _handleScrollPanZoomUpdate(ElEventDetails callback) {
    _scrollDrag.handlePanZoomUpdate(callback);
    if (_dualAxis) _horizontalScrollDrag.handlePanZoomUpdate(callback);
  }

  void _handleScrollPanZoomEnd(ElEventDetails event) {
    _scrollDrag.handlePanZoomEnd(event, allowBallistic: !event.defaultPrevented);
    if (_dualAxis) _horizontalScrollDrag.handlePanZoomEnd(event, allowBallistic: !event.defaultPrevented);
    onScrollInputActivityChanged?.call(_axis, null);
    if (_dualAxis) onScrollInputActivityChanged?.call(Axis.horizontal, null);
  }

  void _handleScrollPointerSignal(ElEventDetails callback) {
    final event = callback.originalEvent;
    if (event is PointerScrollEvent) {
      _receivedPointerScroll(event, callback);
    } else if (event is PointerScrollInertiaCancelEvent) {
      _resetSmoothPointerScroll();
      _resetHorizontalSmoothPointerScroll();
      _releasePointerScrollChain();
      _position.pointerScroll(0.0);
      _horizontalPosition?.pointerScroll(0.0);
    }
  }

  /// 处理视口外部代理区域转交的滚轮事件，保留平滑滚动、连击和边界语义。
  @override
  bool dispatchPointerScroll(PointerScrollEvent event) {
    var handled = false;
    for (final axisDelta in _pointerSignalEventDeltas(event)) {
      handled = _routePointerScroll(event, axisDelta, register: false) || handled;
    }
    return handled;
  }

  @override
  bool dispatchSelectionPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      var handled = false;
      for (final axisDelta in _pointerSignalEventDeltas(event)) {
        handled = _routePointerScroll(event, axisDelta, register: true) || handled;
      }
      return handled;
    }

    if (event is PointerScrollInertiaCancelEvent) {
      if (!_shouldAcceptUserOffset && !_shouldAcceptHorizontalUserOffset) return false;
      _resetSmoothPointerScroll();
      _resetHorizontalSmoothPointerScroll();
      _releasePointerScrollChain();
      _position.pointerScroll(0.0);
      _horizontalPosition?.pointerScroll(0.0);
      return true;
    }
    return false;
  }

  void _receivedPointerScroll(PointerScrollEvent event, ElEventDetails callback) {
    for (final axisDelta in _pointerSignalEventDeltas(event)) {
      final inputDelta = callback.remainingPrimaryDelta(axisDelta.inputAxis);
      if (inputDelta == 0 || inputDelta.sign != axisDelta.inputDelta.sign || axisDelta.inputDelta == 0) continue;
      if (_routePointerScroll(event, axisDelta, register: true, inputDelta: inputDelta)) {
        _consumePointerScrollInputDelta(callback, axisDelta.inputAxis, inputDelta);
      }
    }
  }

  // 正文、选区与滚动条代理共用接收规则；锁原始输入轴，dy 转横滚不能另开一笔输入。
  bool _routePointerScroll(
    PointerScrollEvent event,
    _PointerScrollAxisDelta axisDelta, {
    required bool register,
    double? inputDelta,
  }) {
    final chainOwner = _activePointerScrollChainOwnerAt(event.position, event: event, axis: axisDelta.inputAxis);
    if (chainOwner != null &&
        ScrollPointerChain.shouldDeferViewportToOwner(this, chainOwner, axis: axisDelta.inputAxis)) {
      // 祖先接收者沿真实路径冒泡；代理区域命中仍有效的后代接收者时直接转交。
      if (register && chainOwner.isAncestorOf(this)) return false;
      if (chainOwner is! RenderVirtualScrollView) return false;
      for (final ownerDelta in chainOwner._pointerSignalEventDeltas(event)) {
        if (ownerDelta.inputAxis == axisDelta.inputAxis) {
          return chainOwner._routePointerScroll(event, ownerDelta, register: register, inputDelta: inputDelta);
        }
      }
      return false;
    }
    if (!_acceptsUserOffsetOnAxis(axisDelta.scrollAxis)) return false;
    final scrollDelta = (inputDelta ?? axisDelta.inputDelta) * axisDelta.scrollDelta / axisDelta.inputDelta;
    final action = _smoothForAxis(axisDelta.scrollAxis).canConsumeDelta(scrollDelta)
        ? _pointerScrollActionForAxis(axisDelta.scrollAxis, scrollDelta: scrollDelta)
        : identical(chainOwner, this) || _shouldBlockPointerScrollBoundary(event, axisDelta, scrollDelta)
        ? _blockedPointerScrollActionForAxis(axisDelta.scrollAxis)
        : null;
    if (action == null) return false;
    if (!register) return action(event);
    ScrollPointerChain.registerPointerScrollAction(event, action, axis: axisDelta.inputAxis, owner: this);
    return true;
  }

  void _consumePointerScrollInputDelta(ElEventDetails callback, Axis axis, double inputDelta) {
    callback.consumePrimaryDelta(axis, inputDelta);
    if (callback.remainingDelta == Offset.zero) callback.stopPropagation();
  }

  @override
  bool canConsumePointerScrollEvent(PointerScrollEvent event) {
    for (final axisDelta in _pointerSignalEventDeltas(event)) {
      if (_smoothForAxis(axisDelta.scrollAxis).canConsumeDelta(axisDelta.scrollDelta) ||
          _shouldBlockPointerScrollBoundary(event, axisDelta, axisDelta.scrollDelta)) {
        return true;
      }
    }
    return false;
  }

  bool _shouldBlockPointerScrollBoundary(
    PointerScrollEvent event,
    _PointerScrollAxisDelta axisDelta,
    double scrollDelta,
  ) {
    // 输入轴被转译成另一个滚动轴时，边界也要吞原输入，避免 dy 漏给纵向祖先。
    if (axisDelta.inputAxis != axisDelta.scrollAxis && scrollDelta.abs() > precisionErrorTolerance) return true;
    return _smoothForAxis(axisDelta.scrollAxis).shouldLatchBoundaryPointerScroll(event, scrollDelta);
  }

  /// chain 注册用的按轴消费 action；已有内层消费时捕获剩余量，避免 flush
  /// 又从原始事件恢复成整笔滚轮输入。
  bool Function(PointerScrollEvent event) _pointerScrollActionForAxis(Axis axis, {double? scrollDelta}) {
    return (event) => _handlePointerScrollOnAxis(event, axis, scrollDelta: scrollDelta);
  }

  bool _handlePointerScrollOnAxis(PointerScrollEvent event, Axis axis, {double? scrollDelta}) {
    final axisDelta = scrollDelta == null ? _axisDeltaFor(event, axis) : null;
    if (scrollDelta == null && axisDelta == null) return false;
    final smooth = _smoothForAxis(axis);
    if (smooth.hasCoordinatedMotion) {
      final delta = scrollDelta ?? axisDelta!.scrollDelta;
      if (!smooth.canConsumeDelta(delta)) return false;
      ScrollCursorFreeze.claim(this);
      smooth.applyPointerScroll(event, delta);
      _claimPointerScrollChain(event, axis: axis);
      return true;
    }
    final interceptor = axis == _axis ? _deltaInterceptor : _horizontalDeltaInterceptor;
    final transaction = interceptor == null
        ? null
        : ScrollInputTransaction.begin(
            source: ElScrollInputSource.pointerSignal,
            rawEvent: event,
            participants: interceptor is ScrollInputTransactionSource
                ? interceptor as ScrollInputTransactionSource
                : null,
          );
    try {
      onScrollInputActivityChanged?.call(axis, ElScrollActivityType.pointerScroll);
      // 拦截量算作已消费，剩余走 smooth 控制器；剩余为 0 直接短路，
      // 也 claim 掉链避免祖先接手。
      final rawDelta = scrollDelta ?? axisDelta!.scrollDelta;
      final residualDelta = _applyPointerScrollDeltaInterceptor(axis, rawDelta);
      if (residualDelta.abs() <= precisionErrorTolerance) {
        // 全被拦截器吃了：认作命中并占链，不进物理。
        ScrollCursorFreeze.claim(this);
        _claimPointerScrollChain(event, axis: axis);
        return true;
      }
      if (_smoothForAxis(axis).canConsumeDelta(residualDelta)) {
        ScrollCursorFreeze.claim(this);
        _smoothForAxis(axis).applyPointerScroll(event, residualDelta);
        _claimPointerScrollChain(event, axis: axis);
        return true;
      }
      return false;
    } finally {
      try {
        onScrollInputActivityChanged?.call(axis, null);
      } finally {
        transaction?.close();
      }
    }
  }

  double _applyPointerScrollDeltaInterceptor(Axis axis, double delta) {
    final interceptor = axis == _axis ? _deltaInterceptor : _horizontalDeltaInterceptor;
    if (interceptor == null) return delta;
    if (delta.abs() <= precisionErrorTolerance) return delta;
    final consumed = interceptor.interceptScrollDelta(delta, ElScrollDeltaSource.pointerScroll);
    if (consumed == 0.0) return delta;
    if (consumed.sign != delta.sign) return delta;
    if (consumed.abs() > delta.abs()) return 0.0;
    return delta - consumed;
  }

  bool Function(PointerScrollEvent event) _blockedPointerScrollActionForAxis(Axis axis) {
    return (event) {
      _claimPointerScrollChain(event, axis: axis);
      return true;
    };
  }

  void _resetSmoothPointerScroll() {
    _smoothPointerScroll.reset();
  }

  @override
  void cancelPointerScrollActivity() {
    _resetSmoothPointerScroll();
    _resetHorizontalSmoothPointerScroll();
  }

  /// 传 `querier: this`：现役 owner 就是自己时，越过 latch slop 不解除 latch、
  /// 不硬停在途动画（同容器内挪鼠标也会越阈，硬停会让滚轮动画半路重起）。
  ScrollViewport? _activePointerScrollChainOwnerAt(Offset globalPosition, {PointerScrollEvent? event, Axis? axis}) {
    return ScrollPointerChain.ownerAt(globalPosition, event: event, axis: axis, querier: this);
  }

  @override
  bool containsGlobalPosition(Offset globalPosition) {
    if (!attached || !hasSize) return false;
    return size.contains(globalToLocal(globalPosition));
  }

  @override
  bool get hasActivePointerScrollActivity => _smoothPointerScroll.isActive || _horizontalSmoothPointerScroll.isActive;

  /// 指定滚动轴是否仍由 smooth pointer-scroll activity 驱动。
  bool hasActivePointerScrollActivityOn(Axis axis) => _smoothForAxis(axis).isActive;

  @override
  bool isAncestorOf(RenderObject node) {
    var current = node.parent;
    while (current != null) {
      if (identical(current, this)) return true;
      current = current.parent;
    }
    return false;
  }

  void _claimPointerScrollChain(PointerScrollEvent event, {Axis? axis}) {
    final inputAxis = axis == null ? null : _axisDeltaFor(event, axis)?.inputAxis;
    ScrollPointerChain.claimForPointerScroll(this, event, axis: inputAxis ?? axis);
  }

  void _releasePointerScrollChain() {
    ScrollPointerChain.release(this);
  }

  bool _jumpFromInput(ScrollPosition position, double target) {
    if (!position.hasPixels || !position.hasContentDimensions || !target.isFinite) return false;
    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target == position.pixels) return false;
    _smoothForAxis(axisDirectionToAxis(position.axisDirection)).reset();
    if (position is ScrollEnginePosition) {
      position.jumpToFromInput(target);
    } else {
      position.jumpTo(target);
    }
    return true;
  }

  /// 执行容器自身的键盘滚动；焦点宿主确认主焦点归属后调用，不监听后代冒泡。
  void handleKeyboardScroll(ElEventDetails event) {
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isAltPressed || keyboard.isMetaPressed) return;
    final key = event.logicalKey;
    final horizontalKey = key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight;
    final verticalKey = key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown;
    final position = horizontalKey && _dualAxis ? _horizontalPosition : _position;
    if (position == null || !position.hasContentDimensions || !position.hasPixels) return;
    final axis = axisDirectionToAxis(position.axisDirection);
    if ((horizontalKey && axis != Axis.horizontal) || (verticalKey && axis != Axis.vertical)) return;
    if (!(axis == _axis ? _shouldAcceptUserOffset : _shouldAcceptHorizontalUserOffset)) return;
    final reversed = axisDirectionIsReversed(position.axisDirection);
    final direction = reversed ? -1.0 : 1.0;
    final page = position.viewportDimension * .8;
    final target = switch (key) {
      LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowRight => position.pixels + 50 * direction,
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.arrowLeft => position.pixels - 50 * direction,
      LogicalKeyboardKey.pageDown => position.pixels + page * direction,
      LogicalKeyboardKey.pageUp => position.pixels - page * direction,
      LogicalKeyboardKey.home => reversed ? position.maxScrollExtent : position.minScrollExtent,
      LogicalKeyboardKey.end => reversed ? position.minScrollExtent : position.maxScrollExtent,
      _ => null,
    };
    // 子项优先处理；只有本层实际移动才阻止祖先重复执行默认滚动。
    if (target != null && _jumpFromInput(position, target)) event.preventDefault();
  }

  void _describeScrollSemantics(SemanticsConfiguration config) {
    if (_excludeSemantics) return;
    if (_semanticsRole case final role?) config.role = role;
    if (!_position.hasPixels || !_position.hasContentDimensions) return;

    config.isSemanticBoundary = true;
    config.scrollPosition = _position.pixels;
    config.scrollExtentMin = _position.minScrollExtent;
    config.scrollExtentMax = _position.maxScrollExtent;

    final line = _mainExtent(size) * 0.8;
    if (_position.pixels > _position.minScrollExtent) {
      if (_axis == Axis.vertical) {
        config.onScrollDown = () => _jumpFromInput(_position, _position.pixels - line);
      } else {
        config.onScrollRight = () => _jumpFromInput(_position, _position.pixels - line);
      }
    }
    if (_position.pixels < _position.maxScrollExtent) {
      if (_axis == Axis.vertical) {
        config.onScrollUp = () => _jumpFromInput(_position, _position.pixels + line);
      } else {
        config.onScrollLeft = () => _jumpFromInput(_position, _position.pixels + line);
      }
    }

    // 双轴：补水平方向动作。scrollPosition/extent 单值语义只报主轴（垂直），
    // 与官方 2D viewport 同等妥协。
    final horizontal = _horizontalPosition;
    if (_dualAxis && horizontal != null && horizontal.hasPixels && horizontal.hasContentDimensions) {
      final horizontalLine = size.width * 0.8;
      if (horizontal.pixels > horizontal.minScrollExtent) {
        config.onScrollRight = () => _jumpFromInput(horizontal, horizontal.pixels - horizontalLine);
      }
      if (horizontal.pixels < horizontal.maxScrollExtent) {
        config.onScrollLeft = () => _jumpFromInput(horizontal, horizontal.pixels + horizontalLine);
      }
    }
  }

  bool get _hasUserPointerEnter => _eventDispatcher?.event?.onPointerEnter != null;

  bool get _hasUserPointerExit => _eventDispatcher?.event?.onPointerExit != null;

  @override
  PointerEnterEventListener? get onEnter {
    if (!_hasUserPointerEnter) return null;
    return _eventDispatcher!.handlePointerEnter;
  }

  @override
  PointerExitEventListener? get onExit {
    if (!_hasUserPointerExit) return null;
    return _eventDispatcher!.handlePointerExit;
  }

  @override
  MouseCursor get cursor => ScrollCursorFreeze.ownedBy(this) ? MouseCursor.uncontrolled : MouseCursor.defer;

  @override
  bool get validForMouseTracker => attached && (ScrollCursorFreeze.ownedBy(this) || onEnter != null || onExit != null);

  /// 由虚拟布局更新完整内容尺寸，不创建中间 RenderBox。
  @protected
  void setVirtualContentSize(Size value) => _contentSize = value;

  /// 滚动条实际占用的边缘空间；overlay 滚动条保持零。
  @protected
  EdgeInsets get viewportLayoutInsets => EdgeInsets.zero;

  /// 正文实际可滚动的视口尺寸，与外层定位盒分离。
  @protected
  Size get scrollportSize => Size(
    math.max(0.0, size.width - viewportLayoutInsets.horizontal),
    math.max(0.0, size.height - viewportLayoutInsets.vertical),
  );

  @override
  Rect get contentViewportRect => Offset(viewportLayoutInsets.left, viewportLayoutInsets.top) & scrollportSize;

  /// 布局改变 position 前记录修正量，供宿主与实际运动分开归因。
  @protected
  void recordLayoutPositionCorrection(Axis axis, double pixelsDelta);

  /// 直接成员使用的实时滚动平移，保持亚像素精度。
  @protected
  Offset get contentPaintOffset {
    final scroll = _scrollPaintOffsetFor(_paintScrollPixels());
    final insets = viewportLayoutInsets;
    if (insets.left == 0.0 && insets.top == 0.0) return scroll;
    return scroll + Offset(insets.left, insets.top);
  }

  /// 吸顶等边界成员使用合法内容位置，正文越界平移仍保留在 contentPaintOffset。
  @protected
  Offset get boundedContentPaintOffset {
    final main = _paintScrollPixels().clamp(0.0, math.max(0.0, _maxScrollExtent));
    final cross = _dualAxis
        ? _paintHorizontalScrollPixels().clamp(0.0, math.max(0.0, _maxHorizontalScrollExtent))
        : 0.0;
    final insets = viewportLayoutInsets;
    return _axis == Axis.vertical
        ? Offset(insets.left - cross, insets.top - main)
        : Offset(insets.left - main, insets.top - cross);
  }

  /// 绘制时登记实际使用的偏移，避免相同位置重复请求重绘。
  @protected
  void recordPaintedScrollOffset() {
    _lastPaintedScrollPixels = _paintScrollPixels();
    if (_dualAxis) _lastPaintedHorizontalScrollPixels = _paintHorizontalScrollPixels();
  }

  /// 内容手势进行中是否应屏蔽业务命中，滚动条独立处理。
  @protected
  bool get suppressesContentHits => _dragSuppressesContentHits;

  /// 主轴布局收尾：算 maxScrollExtent、喂两轴 position、刷可见窗口与接线。
  ///
  /// [beforeApplyMainDimensions] 给 virtual 插 thumb 拖拽分数的 correctBy
  /// 修正——它必须在 applyContentDimensions 之前拿到本帧的 maxScrollExtent；
  /// 返回 false 表示滚动位置刚被修正，调用方必须用新位置重排本帧。
  @protected
  bool completeMainAxisLayout({void Function(double maxScrollExtent)? beforeApplyMainDimensions}) {
    final viewportExtent = _mainExtent(scrollportSize);
    final contentExtent = _mainExtent(_contentSize);
    final maxScrollExtent = math.max(contentExtent - viewportExtent, 0.0);
    final pixelsBeforeMainCorrection = _position.pixels;
    beforeApplyMainDimensions?.call(maxScrollExtent);
    var corrected = _position.pixels != pixelsBeforeMainCorrection;
    if (_maxScrollExtent != maxScrollExtent) {
      _maxScrollExtent = maxScrollExtent;
      _invalidateScrollPaintCache();
    }
    corrected = _correctPixelsForNewRange(_position, 0.0, maxScrollExtent) || corrected;
    if (_dualAxis) {
      final maxHorizontalExtent = math.max(horizontalContentWidthForDualAxis() - scrollportSize.width, 0.0);
      if (_maxHorizontalScrollExtent != maxHorizontalExtent) {
        _maxHorizontalScrollExtent = maxHorizontalExtent;
        _invalidateScrollPaintCache();
      }
      corrected = _correctPixelsForNewRange(_horizontalPosition!, 0.0, maxHorizontalExtent) || corrected;
    }
    if (corrected) return false;
    final pixelsBeforeDimensions = _position.pixels;
    final horizontalPixelsBeforeDimensions = _horizontalPosition?.pixels;
    final mainDimensionsAccepted =
        _position.applyViewportDimension(viewportExtent) && _position.applyContentDimensions(0.0, maxScrollExtent);
    var horizontalDimensionsAccepted = true;
    if (_dualAxis) {
      final horizontalPosition = _horizontalPosition!;
      horizontalDimensionsAccepted =
          horizontalPosition.applyViewportDimension(scrollportSize.width) &&
          horizontalPosition.applyContentDimensions(0.0, _maxHorizontalScrollExtent);
    }
    if (!mainDimensionsAccepted || !horizontalDimensionsAccepted) {
      if (_position.pixels != pixelsBeforeDimensions ||
          (_horizontalPosition != null && _horizontalPosition!.pixels != horizontalPixelsBeforeDimensions)) {
        _invalidateScrollPaintCache();
      }
      return false;
    }
    onScrollbarMetricsChanged?.call();
    _syncEventDispatcherForWiringChange();
    return true;
  }

  /// 新尺寸淘汰原合法位置时同帧回钳；旧位置已越界则交给 bouncing / 刷新物理。
  bool _correctPixelsForNewRange(ScrollPosition position, double minScrollExtent, double maxScrollExtent) {
    if (!position.hasPixels || !position.hasContentDimensions) return false;
    final pixels = position.pixels;
    if (pixels < position.minScrollExtent - precisionErrorTolerance ||
        pixels > position.maxScrollExtent + precisionErrorTolerance) {
      return false;
    }
    final target = pixels.clamp(minScrollExtent, maxScrollExtent).toDouble();
    if ((target - pixels).abs() <= precisionErrorTolerance) return false;
    position.correctBy(target - pixels);
    _invalidateScrollPaintCache();
    return true;
  }

  /// 在视口裁剪内按统一层序绘制直接成员。
  @protected
  void paintViewportChildren(PaintingContext context, Offset offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position});

  @override
  void visitSelectionChildrenInPaintOrder(RenderObjectVisitor visitor);

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform);

  /// 滚动位置变化后、绘制前更新依赖位置的成员层序。
  @protected
  void didChangeScrollOffset() {}

  /// 仅滚动平移改变时请求绘制，供直接定位层保留自身绘制缓存。
  @protected
  void markNeedsPaintForScroll() => markNeedsPaint();

  @override
  void markNeedsSemanticsUpdate() {
    super.markNeedsSemanticsUpdate();
    // 属性由外层宿主承载；视口保持透明，滚动变换才会刷新子项语义几何。
    if (parent case final _RenderScrollSemantics host) host.markNeedsSemanticsUpdate();
  }

  void _handleScrollOffsetChanged() {
    _scrollOffsetRelay.notify();
    // 未封口（Clip.none）时行落位含 scrollOffset，滚动即边界变化；封口时
    // 聚合恒为自身盒，不得每 tick 重绑父链溢出代理。
    _markScrollHitBoundsDirtyIfNeeded();
    didChangeScrollOffset();
    final contentPixels = _contentScrollPixels();
    // 与上次实际绘制的像素比较（而非共享快照缓存），见 _lastPaintedScrollPixels。
    final paintPixelsChanged = _lastPaintedScrollPixels.isNaN || contentPixels != _lastPaintedScrollPixels;

    if (paintPixelsChanged) {
      _cachedScrollPaintPixels = double.nan;
      _cachedScrollPaintOffset = null;
    }

    if (attached && paintPixelsChanged && !_hasDirectPointerDrag) {
      ScrollCursorFreeze.claim(this);
    }
    if (paintPixelsChanged) {
      markNeedsPaintForScroll();
    }
    if (owner?.semanticsOwner != null) {
      markNeedsSemanticsUpdate();
    }
  }

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    _scrollOffsetRelay.dispose();
    // 卸载取消活动会走 position 终态并持久化偏移，此时宿主 element 已 deactivate，
    // PageStorage 祖先查找会断言——先关掉写入再结算拖拽。
    final positionContext = _position.context;
    if (positionContext is ScrollPositionGeneration) {
      (positionContext as ScrollPositionGeneration).suppressOffsetPersistence();
    }
    final horizontalContext = _horizontalPosition?.context;
    if (horizontalContext is ScrollPositionGeneration) {
      (horizontalContext as ScrollPositionGeneration).suppressOffsetPersistence();
    }
    _disposeActiveScrollDrag();
    _resetSmoothPointerScroll();
    if (ScrollCursorFreeze.ownedBy(this)) {
      ScrollCursorFreeze.release(updateMouseTracker: false);
    }
    _smoothPointerScroll.dispose();
    _horizontalSmoothPointerScroll.dispose();
    _releasePointerScrollChain();
    _eventDispatcher?.dispose();
    _eventDispatcher = null;
    _touchEventSyncLatch.reset();
    _childrenCache = null;
    _cachedScrollPaintOffset = null;
    super.dispose();
  }
}

/// 一次 pointer signal 在某个轴上解出来的分量（两侧原本各持一份同构类）。
final class _PointerScrollAxisDelta {
  const _PointerScrollAxisDelta({
    required this.inputAxis,
    required this.scrollAxis,
    required this.inputDelta,
    required this.scrollDelta,
  });

  final Axis inputAxis;
  final Axis scrollAxis;
  final double inputDelta;
  final double scrollDelta;

  bool get isZero => inputDelta == 0.0;
}
