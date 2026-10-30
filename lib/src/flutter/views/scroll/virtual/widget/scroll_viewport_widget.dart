// 滚动 viewport 的既有 Widget 与 Element 接线。
// ignore_for_file: prefer_initializing_formals

part of '../virtual_pipeline.dart';

class _ScrollViewport extends RenderObjectWidget {
  const _ScrollViewport({
    super.key,
    required this.controller,
    required this.scrollbar,
    required this.scrollbarDetails,
    required this.position,
    required this.horizontalPosition,
    required this.horizontalAxisDirection,
    required this.physics,
    required this.axis,
    required this.axisDirection,
    required this.shrinkWrap,
    required this.velocityTrackerBuilder,
    required this.multitouchDragStrategy,
    required this.devicePixelRatio,
    required this.dragDevices,
    required this.pointerAxisModifiers,
    required this.mouseWheelHorizontalModifiers,
    required this.gestureSettings,
    required this.clipBehavior,
    required this.excludeSemantics,
    required this.semanticsRole,
    required this.ignorePointer,
    required this.canDrag,
    required this.dragStartDistance,
    required this.onScrollbarDragChanged,
    required this.onScrollbarMetricsChanged,
    required this.onLayoutMetrics,
    required this.event,
    required this.deltaInterceptor,
    required this.horizontalDeltaInterceptor,
    required this.onScrollInputActivityChanged,
    required this.smoothScroll,
  });

  final _ScrollMountController controller;
  final ElScrollbar scrollbar;
  final ScrollbarController scrollbarDetails;

  final ScrollPosition position;

  /// 双轴模式下的水平轴 position；单轴为 null。
  final ScrollPosition? horizontalPosition;
  final AxisDirection horizontalAxisDirection;
  final ScrollPhysics physics;
  final Axis axis;
  final AxisDirection axisDirection;

  /// 是否按完整子内容布局并让容器宽高遵循内容（`ElScrollView.shrinkWrap` 透传）。
  final bool shrinkWrap;
  final GestureVelocityTrackerBuilder velocityTrackerBuilder;
  final MultitouchDragStrategy multitouchDragStrategy;
  final double devicePixelRatio;
  final Set<PointerDeviceKind>? dragDevices;
  final Set<LogicalKeyboardKey> pointerAxisModifiers;
  final Iterable<LogicalKeyboardKey>? mouseWheelHorizontalModifiers;
  final DeviceGestureSettings? gestureSettings;
  final Clip clipBehavior;

  /// 是否把可见成员从语义树剔除（基座消费，语义窗口整体短路）。
  final bool excludeSemantics;

  /// 滚动语义节点的可选结构角色。
  final SemanticsRole? semanticsRole;

  final bool ignorePointer;
  final bool canDrag;
  final double? dragStartDistance;
  final ValueChanged<VirtualScrollbarDragStatus> onScrollbarDragChanged;
  final VoidCallback onScrollbarMetricsChanged;

  /// 布局期度量回调，替代原 LayoutBuilder（见 render 侧 onLayoutMetrics 注释）。
  final void Function(double viewportExtent, double crossAxisExtent) onLayoutMetrics;
  final ElEvent? event;
  final ElScrollDeltaInterceptor? deltaInterceptor;
  final ElScrollDeltaInterceptor? horizontalDeltaInterceptor;
  final void Function(Axis axis, ElScrollActivityType? activity)? onScrollInputActivityChanged;
  final ElSmoothScroll? smoothScroll;

  @override
  RenderObjectElement createElement() => _ScrollViewportElement(this);

  @override
  _RenderVirtualViewport createRenderObject(BuildContext context) {
    final snapshot = controller.snapshot;
    return _RenderVirtualViewport(
        viewport: this,
        axis: snapshot.axis,
        dualAxis: snapshot.dualAxis,
        totalExtent: snapshot.totalExtent,
        padding: snapshot.padding,
        gap: snapshot.gap,
        crossAxisAlignment: snapshot.crossAxisAlignment,
        minimumCrossAxisExtent: snapshot.minimumCrossAxisExtent,
        firstIndex: snapshot.firstIndex,
        lastIndex: snapshot.lastIndex,
        dragOptimizeEnabled: snapshot.dragOptimizeEnabled,
        pinToEnd: snapshot.pinToEnd,
        preserveAnchor: snapshot.preserveAnchor,
        children: snapshot.sourceChildren,
        sectionPlan: snapshot.sectionPlan,
        measurementGeneration: snapshot.measurementGeneration,
        reportMeasuredExtentsWhenUnchanged: snapshot.reportMeasuredExtentsWhenUnchanged,
        extentIndex: snapshot.extentIndex,
        onItemExtentsChanged: snapshot.onItemExtentsChanged,
        onMeasurementsChanged: snapshot.onMeasurementsChanged,
      )
      .._updatePositionedDirection(Directionality.maybeOf(context) ?? TextDirection.ltr)
      ..onScrollbarMetricsChanged = onScrollbarMetricsChanged
      ..onLayoutMetrics = onLayoutMetrics
      ..verticalScrollbarInset = scrollbar.resolveInsetExtent(context, Axis.vertical)
      ..horizontalScrollbarInset = scrollbar.resolveInsetExtent(context, Axis.horizontal)
      ..verticalScrollbarLeading = scrollbar.resolveOrientation(context, Axis.vertical) == ScrollbarOrientation.left
      ..horizontalScrollbarLeading = scrollbar.resolveOrientation(context, Axis.horizontal) == ScrollbarOrientation.top;
  }

  @override
  void updateRenderObject(BuildContext context, _RenderVirtualViewport renderObject) {
    renderObject._updatePositionedDirection(Directionality.maybeOf(context) ?? TextDirection.ltr);
    // 虚拟窗口的局部 reconcile 不能把初次 build 的 canDrag/ignorePointer
    // 写回进行中的真实 activity；只有结构 Widget 换代才重配输入。
    if (identical(renderObject._viewportConfiguration, this)) {
      _ScrollMount._updateRenderObjectFromSnapshot(renderObject, controller.snapshot);
      return;
    }
    renderObject._viewportConfiguration = this;
    renderObject
      ..position = position
      ..horizontalPosition = horizontalPosition
      ..horizontalAxisDirection = horizontalAxisDirection
      ..axis = axis
      ..axisDirection = axisDirection
      ..shrinkWrap = shrinkWrap
      ..physics = physics
      ..velocityTrackerBuilder = velocityTrackerBuilder
      ..multitouchDragStrategy = multitouchDragStrategy
      ..devicePixelRatio = devicePixelRatio
      ..dragDevices = dragDevices
      ..pointerAxisModifiers = pointerAxisModifiers
      ..mouseWheelHorizontalModifiers = mouseWheelHorizontalModifiers
      ..gestureSettings = gestureSettings
      ..clipBehavior = clipBehavior
      ..excludeSemantics = excludeSemantics
      ..semanticsRole = semanticsRole
      ..ignorePointer = ignorePointer
      ..canDrag = canDrag
      ..dragStartDistance = dragStartDistance
      ..onScrollbarDragChanged = onScrollbarDragChanged
      ..onScrollbarMetricsChanged = onScrollbarMetricsChanged
      ..onLayoutMetrics = onLayoutMetrics
      ..event = event
      ..deltaInterceptor = deltaInterceptor
      ..horizontalDeltaInterceptor = horizontalDeltaInterceptor
      ..onScrollInputActivityChanged = onScrollInputActivityChanged
      ..smoothScroll = smoothScroll
      ..verticalScrollbarInset = scrollbar.resolveInsetExtent(context, Axis.vertical)
      ..horizontalScrollbarInset = scrollbar.resolveInsetExtent(context, Axis.horizontal)
      ..verticalScrollbarLeading = scrollbar.resolveOrientation(context, Axis.vertical) == ScrollbarOrientation.left
      ..horizontalScrollbarLeading = scrollbar.resolveOrientation(context, Axis.horizontal) == ScrollbarOrientation.top;
    _ScrollMount._updateRenderObjectFromSnapshot(renderObject, controller.snapshot);
  }
}
