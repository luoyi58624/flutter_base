part of 'selection_core.dart';

/// 工具条「是否放选区上方」的预估占位（本体高度 + 间距）；build 期未知真实
/// 尺寸，用与 overflow pad 等值的估计做翻转判定，真实位置由定位 render 钳制。
const double _toolbarEstimatedExtent = 48.0;

/// 工具条与选区上边缘的间距（上方形态）。
const double _toolbarGapAbove = 6.0;

/// 工具条与选区下边缘的间距（下方形态，需让开悬挂的 handles）。
const double _toolbarGapBelow = 32.0;

Offset _identityGlobalToLocal(Offset global) => global;

/// 选区 handles 与 magnifier 的树内 chrome。
class SelectionOverlayChrome extends StatefulWidget {
  /// 创建。
  const SelectionOverlayChrome({
    super.key,
    required this.endpointsListenable,
    required this.dragInfoListenable,
    required this.scrollActivityListenable,
    required this.lineGeometryProvider,
    this.globalToLocal = _identityGlobalToLocal,
    required this.controls,
    required this.handleColor,
    required this.showHandles,
    required this.showMagnifier,
    required this.showToolbar,
    required this.toolbarActions,
    this.toolbarActionsListenable,
    required this.onHandleDragBegin,
    required this.onHandleDragEnd,
  });

  /// 端点几何通道。
  final ValueListenable<SelectionEndpointsInfo?> endpointsListenable;

  /// 拖动状态通道。
  final ValueListenable<SelectionDragInfo?> dragInfoListenable;

  /// 滚动状态通道。
  final ValueListenable<bool> scrollActivityListenable;

  /// 被拖端点的行几何 provider。
  final SelectionMagnifierLineGeometryProvider lineGeometryProvider;

  /// 全局坐标到 chrome 本地坐标的换算器。
  final Offset Function(Offset global) globalToLocal;

  /// 生效的平台 controls。
  final SelectionControls controls;

  /// handle 颜色。
  final Color handleColor;

  /// 是否显示 handles。
  final bool showHandles;

  /// 是否显示 magnifier。
  final bool showMagnifier;

  /// 是否显示移动端浮动工具条。
  final bool showToolbar;

  /// 工具条动作集（复制 / 全选，由 [ElSelectionView] 转发 controller 能力）。
  final SelectionActions toolbarActions;

  /// 实时工具条动作通道；非 null 时优先于 [toolbarActions]。
  final ValueListenable<SelectionActions>? toolbarActionsListenable;

  /// handle 开始拖动。
  final void Function(SelectionHandleSide side, Offset globalPosition, {int? pointer, PointerDeviceKind? kind})
  onHandleDragBegin;

  /// handle 拖动结束。
  final VoidCallback onHandleDragEnd;

  @override
  State<SelectionOverlayChrome> createState() => _SelectionOverlayChromeState();
}

class _SelectionOverlayChromeState extends State<SelectionOverlayChrome> {
  final ValueNotifier<Rect?> _magnifierRectSink = ValueNotifier<Rect?>(null);

  @override
  void dispose() {
    _magnifierRectSink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        if (widget.showHandles)
          _HandlesLayer(
            endpointsListenable: widget.endpointsListenable,
            dragInfoListenable: widget.dragInfoListenable,
            scrollActivityListenable: widget.scrollActivityListenable,
            magnifierRectListenable: _magnifierRectSink,
            globalToLocal: widget.globalToLocal,
            controls: widget.controls,
            handleColor: widget.handleColor,
            onHandleDragBegin: widget.onHandleDragBegin,
            onHandleDragEnd: widget.onHandleDragEnd,
          ),
        if (widget.showMagnifier)
          SelectionMagnifierView(
            endpointsListenable: widget.endpointsListenable,
            dragInfoListenable: widget.dragInfoListenable,
            lineGeometryProvider: widget.lineGeometryProvider,
            globalToLocal: widget.globalToLocal,
            magnifierRectSink: _magnifierRectSink,
            controls: widget.controls,
          ),
        if (widget.showToolbar)
          _ToolbarLayer(
            endpointsListenable: widget.endpointsListenable,
            dragInfoListenable: widget.dragInfoListenable,
            scrollActivityListenable: widget.scrollActivityListenable,
            globalToLocal: widget.globalToLocal,
            controls: widget.controls,
            actions: widget.toolbarActions,
            actionsListenable: widget.toolbarActionsListenable,
          ),
      ],
    );
  }
}

/// 移动端浮动工具条层：选区存在且无进行中拖动 / 滚动时，把
/// [SelectionControls.buildToolbar] 的产物摆到选区上方（放不下时下方）。
class _ToolbarLayer extends StatefulWidget {
  const _ToolbarLayer({
    required this.endpointsListenable,
    required this.dragInfoListenable,
    required this.scrollActivityListenable,
    required this.globalToLocal,
    required this.controls,
    required this.actions,
    required this.actionsListenable,
  });

  final ValueListenable<SelectionEndpointsInfo?> endpointsListenable;
  final ValueListenable<SelectionDragInfo?> dragInfoListenable;
  final ValueListenable<bool> scrollActivityListenable;
  final Offset Function(Offset global) globalToLocal;
  final SelectionControls controls;
  final SelectionActions actions;
  final ValueListenable<SelectionActions>? actionsListenable;

  @override
  State<_ToolbarLayer> createState() => _ToolbarLayerState();
}

class _ToolbarLayerState extends State<_ToolbarLayer> {
  bool _setStateDeferred = false;

  @override
  void initState() {
    super.initState();
    _listen(widget);
  }

  @override
  void didUpdateWidget(covariant _ToolbarLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unlisten(oldWidget);
    _listen(widget);
  }

  @override
  void dispose() {
    _unlisten(widget);
    super.dispose();
  }

  void _listen(_ToolbarLayer source) {
    source.endpointsListenable.addListener(_handleChanged);
    source.dragInfoListenable.addListener(_handleChanged);
    source.scrollActivityListenable.addListener(_handleChanged);
    source.actionsListenable?.addListener(_handleChanged);
  }

  void _unlisten(_ToolbarLayer source) {
    source.endpointsListenable.removeListener(_handleChanged);
    source.dragInfoListenable.removeListener(_handleChanged);
    source.scrollActivityListenable.removeListener(_handleChanged);
    source.actionsListenable?.removeListener(_handleChanged);
  }

  void _handleChanged() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.transientCallbacks) {
      if (_setStateDeferred) return;
      _setStateDeferred = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _setStateDeferred = false;
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final endpoints = widget.endpointsListenable.value;
    if (endpoints == null) return const SizedBox.shrink();
    // 拖动（长按扩选 / handle）与滚动期间隐藏，松手 / 停稳后复现。
    if (widget.dragInfoListenable.value != null) return const SizedBox.shrink();
    if (widget.scrollActivityListenable.value) return const SizedBox.shrink();
    final start = endpoints.start;
    final end = endpoints.end;
    if (!start.visible && !end.visible) return const SizedBox.shrink();
    final midX = (start.globalPosition.dx + end.globalPosition.dx) / 2;
    final topGlobal = Offset(midX, math.min(start.globalPosition.dy, end.globalPosition.dy));
    final bottomGlobal = Offset(midX, math.max(start.globalBottom.dy, end.globalBottom.dy));
    final safeTop = MediaQuery.maybePaddingOf(context)?.top ?? 0.0;
    final isAbove = topGlobal.dy - _toolbarEstimatedExtent >= safeTop;
    final media = MediaQuery.maybeOf(context);
    final view = View.maybeOf(context);
    final globalViewport = media == null
        ? Offset.zero &
              (view == null
                  ? Size.zero
                  : Size(
                      view.physicalSize.width / view.devicePixelRatio,
                      view.physicalSize.height / view.devicePixelRatio,
                    ))
        : media.padding.deflateRect(Offset.zero & media.size);
    final projection = SelectionChromeProjectionScope.maybeOf(context);
    final viewportCorners = <Offset>[
      widget.globalToLocal(globalViewport.topLeft),
      widget.globalToLocal(globalViewport.topRight),
      widget.globalToLocal(globalViewport.bottomLeft),
      widget.globalToLocal(globalViewport.bottomRight),
    ];
    final localViewport =
        projection?.hostRectFromGlobal(globalViewport) ??
        Rect.fromLTRB(
          viewportCorners.map((point) => point.dx).reduce(math.min),
          viewportCorners.map((point) => point.dy).reduce(math.min),
          viewportCorners.map((point) => point.dx).reduce(math.max),
          viewportCorners.map((point) => point.dy).reduce(math.max),
        );
    final toolbar = widget.controls.buildToolbar(
      context,
      SelectionToolbarDetails(actions: widget.actionsListenable?.value ?? widget.actions, isAbove: isAbove),
    );
    if (toolbar == null) return const SizedBox.shrink();
    final anchorGlobal = isAbove
        ? topGlobal - const Offset(0, _toolbarGapAbove)
        : bottomGlobal + const Offset(0, _toolbarGapBelow);
    return _ToolbarPositioner(
      anchor: widget.globalToLocal(anchorGlobal),
      isAbove: isAbove,
      localViewport: localViewport,
      projection: projection,
      topAnchor: widget.globalToLocal(topGlobal),
      bottomAnchor: widget.globalToLocal(bottomGlobal),
      child: ElView(
        key: selectionToolbarKey,
        style: ElStyle(pointerEvents: .auto),
        // 移动工具条保留正文输入焦点，避免按钮临时取焦清空选区交互状态。
        child: ExcludeFocus(child: toolbar),
      ),
    );
  }
}

/// 工具条定位壳：撑满 chrome 层，按测得的子尺寸把工具条水平居中到锚点、
/// 上方形态锚点为工具条底边、下方形态为顶边，并钳制在 chrome 边界内。
class _ToolbarPositioner extends SingleChildRenderObjectWidget {
  const _ToolbarPositioner({
    required this.anchor,
    required this.isAbove,
    required this.localViewport,
    required this.projection,
    required this.topAnchor,
    required this.bottomAnchor,
    required super.child,
  });

  /// chrome 本地坐标的锚点（水平中心 + 上/下边缘基线）。
  final Offset anchor;

  /// 上方形态（锚点为工具条底边）。
  final bool isAbove;

  /// 当前 Flutter View 安全区换算到 chrome 本地后的矩形。
  final Rect localViewport;
  final SelectionChromeProjection? projection;
  final Offset topAnchor;
  final Offset bottomAnchor;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderToolbarPositioner(anchor, isAbove, localViewport, projection, topAnchor, bottomAnchor);

  @override
  void updateRenderObject(BuildContext context, covariant _RenderToolbarPositioner renderObject) {
    renderObject
      ..anchor = anchor
      ..isAbove = isAbove
      ..localViewport = localViewport
      ..projection = projection
      ..topAnchor = topAnchor
      ..bottomAnchor = bottomAnchor;
  }
}

class _RenderToolbarPositioner extends RenderShiftedBox {
  _RenderToolbarPositioner(
    this._anchor,
    this._isAbove,
    this._localViewport,
    this._projection,
    this._topAnchor,
    this._bottomAnchor,
  ) : super(null);

  Offset _anchor;

  set anchor(Offset value) {
    if (_anchor == value) return;
    _anchor = value;
    markNeedsLayout();
  }

  bool _isAbove;

  set isAbove(bool value) {
    if (_isAbove == value) return;
    _isAbove = value;
    markNeedsLayout();
  }

  Rect _localViewport;

  set localViewport(Rect value) {
    if (_localViewport == value) return;
    _localViewport = value;
    markNeedsLayout();
  }

  SelectionChromeProjection? _projection;

  set projection(SelectionChromeProjection? value) {
    if (identical(_projection, value)) return;
    _projection = value;
    layer = null;
    markNeedsPaint();
  }

  Offset _topAnchor;

  set topAnchor(Offset value) {
    if (_topAnchor == value) return;
    _topAnchor = value;
    markNeedsLayout();
  }

  Offset _bottomAnchor;

  set bottomAnchor(Offset value) {
    if (_bottomAnchor == value) return;
    _bottomAnchor = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _projection != null || super.alwaysNeedsCompositing;

  @override
  void detach() {
    layer = null;
    super.detach();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final child = this.child;
    if (child == null) return;
    final loose = constraints.loosen();
    final projection = _projection;
    child.layout(
      projection == null
          ? loose
          : BoxConstraints(
              maxWidth: math.min(loose.maxWidth, math.max(_localViewport.width, 0.0)),
              maxHeight: math.min(loose.maxHeight, math.max(_localViewport.height, 0.0)),
            ),
      parentUsesSize: true,
    );
    final childSize = child.size;
    if (projection != null) {
      (child.parentData! as BoxParentData).offset = _topAnchor;
      return;
    }
    var viewport = _localViewport.intersect(Offset.zero & size);
    if (viewport.isEmpty) viewport = Offset.zero & size;
    final maxX = math.max(viewport.left, viewport.right - childSize.width);
    final maxY = math.max(viewport.top, viewport.bottom - childSize.height);
    final dx = (_anchor.dx - childSize.width / 2).clamp(viewport.left, maxX);
    final dy = (_isAbove ? _anchor.dy - childSize.height : _anchor.dy).clamp(viewport.top, maxY);
    (child.parentData! as BoxParentData).offset = Offset(dx, dy);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final projection = _projection;
    final child = this.child;
    if (projection == null || child == null) {
      super.paint(context, offset);
      return;
    }
    var unitLayer = layer;
    if (unitLayer is! SelectionChromeToolbarUnitLayer) {
      unitLayer = SelectionChromeToolbarUnitLayer(
        transformLink: projection.transformLink,
        paintAnchor: _topAnchor,
        topAnchor: _topAnchor,
        bottomAnchor: _bottomAnchor,
        childSize: child.size,
        viewport: _localViewport,
        gapAbove: _toolbarGapAbove,
        gapBelow: _toolbarGapBelow,
      );
      layer = unitLayer;
    } else {
      unitLayer
        ..transformLink = projection.transformLink
        ..paintAnchor = _topAnchor
        ..topAnchor = _topAnchor
        ..bottomAnchor = _bottomAnchor
        ..childSize = child.size
        ..viewport = _localViewport
        ..gapAbove = _toolbarGapAbove
        ..gapBelow = _toolbarGapBelow;
    }
    context.pushLayer(
      unitLayer,
      (paintingContext, layerOffset) => paintingContext.paintChild(child, layerOffset + _topAnchor),
      offset,
      childPaintBounds: const Rect.fromLTRB(
        double.negativeInfinity,
        double.negativeInfinity,
        double.infinity,
        double.infinity,
      ),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final projection = _projection;
    final child = this.child;
    final unitLayer = layer;
    if (projection == null || child == null || unitLayer is! SelectionChromeToolbarUnitLayer) {
      return super.hitTestChildren(result, position: position);
    }
    if (!unitLayer.lastVisible) return false;
    return result.addWithPaintTransform(
      transform: unitLayer.getLastTransform(),
      position: position,
      hitTest: (result, transformed) => result.addWithPaintOffset(
        offset: _topAnchor,
        position: transformed,
        hitTest: (result, transformed) => child.hitTest(result, position: transformed),
      ),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final unitLayer = layer;
    if (_projection == null || unitLayer is! SelectionChromeToolbarUnitLayer) {
      super.applyPaintTransform(child, transform);
      return;
    }
    final unitTransform = unitLayer.getLastTransform();
    if (unitTransform != null) transform.multiply(unitTransform);
    transform.translateByDouble(_topAnchor.dx, _topAnchor.dy, 0.0, 1.0);
  }

  @override
  bool hitTestSelf(Offset position) => false;
}

class _HandlesLayer extends StatefulWidget {
  const _HandlesLayer({
    required this.endpointsListenable,
    required this.dragInfoListenable,
    required this.scrollActivityListenable,
    required this.magnifierRectListenable,
    required this.globalToLocal,
    required this.controls,
    required this.handleColor,
    required this.onHandleDragBegin,
    required this.onHandleDragEnd,
  });

  final ValueListenable<SelectionEndpointsInfo?> endpointsListenable;
  final ValueListenable<SelectionDragInfo?> dragInfoListenable;
  final ValueListenable<bool> scrollActivityListenable;
  final ValueListenable<Rect?> magnifierRectListenable;
  final Offset Function(Offset global) globalToLocal;
  final SelectionControls controls;
  final Color handleColor;
  final void Function(SelectionHandleSide side, Offset globalPosition, {int? pointer, PointerDeviceKind? kind})
  onHandleDragBegin;
  final VoidCallback onHandleDragEnd;

  @override
  State<_HandlesLayer> createState() => _HandlesLayerState();
}

class _HandlesLayerState extends State<_HandlesLayer> {
  bool _setStateDeferred = false;

  @override
  void initState() {
    super.initState();
    _listen(widget);
  }

  @override
  void didUpdateWidget(covariant _HandlesLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unlisten(oldWidget);
    _listen(widget);
  }

  @override
  void dispose() {
    _unlisten(widget);
    super.dispose();
  }

  void _listen(_HandlesLayer source) {
    source.endpointsListenable.addListener(_handleChanged);
  }

  void _unlisten(_HandlesLayer source) {
    source.endpointsListenable.removeListener(_handleChanged);
  }

  void _handleChanged() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.transientCallbacks) {
      if (_setStateDeferred) return;
      _setStateDeferred = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _setStateDeferred = false;
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final endpoints = widget.endpointsListenable.value;
    if (endpoints == null) return const SizedBox.shrink();
    // 显隐由定位 RenderObject 控制，卸载句柄会发送 PointerCancel 并中断在途拖拽。
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [_buildHandle(context, endpoints.start), _buildHandle(context, endpoints.end)],
    );
  }

  Widget _buildHandle(BuildContext context, SelectionHandleEndpoint endpoint) {
    final type = _handleType(endpoint);
    final visualSize = widget.controls.resolveHandleSize(context, type, endpoint.lineHeight);
    final anchor = widget.controls.resolveHandleAnchor(context, type, endpoint.lineHeight);
    final visualRect = Rect.fromLTWH(
      endpoint.globalBottom.dx - anchor.dx,
      endpoint.globalBottom.dy - anchor.dy,
      visualSize.width,
      visualSize.height,
    );
    final hitRect = widget.controls.resolveHandleHitRect(context, type, endpoint.lineHeight, visualRect);
    final projection = SelectionChromeProjectionScope.maybeOf(context);
    return _HandlePositioner(
      endpointsListenable: widget.endpointsListenable,
      dragInfoListenable: widget.dragInfoListenable,
      scrollActivityListenable: widget.scrollActivityListenable,
      magnifierRectListenable: widget.magnifierRectListenable,
      side: endpoint.side,
      hitTopLeftFromBottom: hitRect.topLeft - endpoint.globalBottom,
      visualTopLeftFromBottom: visualRect.topLeft - endpoint.globalBottom,
      hitSize: hitRect.size,
      visualSize: visualSize,
      hideDraggedHandle: widget.controls.resolveHideDraggedHandle(context),
      hideHandlesWhileScrolling: widget.controls.resolveHideHandlesWhileScrolling(context),
      hideHandleBehindMagnifier: widget.controls.resolveHideHandleBehindMagnifier(context),
      globalToLocal: widget.globalToLocal,
      projection: projection,
      child: ElView(
        style: ElStyle(pointerEvents: .auto),
        event: ElEvent(
          onPointerDown: (callback) {
            final event = callback.originalEvent;
            // 不收的 kind 必须放行冒泡：先 stopPropagation 再拒绝会把 handle
            // 命中区变成吞事件死区（下层滚动/选区全收不到这一下）。
            if (event is! PointerDownEvent || !widget.controls.acceptsHandlePointer(event.kind)) {
              return;
            }
            callback.eagerGesture(cancelSelfTap: true);
            callback.stopPropagation();
            widget.onHandleDragBegin(endpoint.side, event.position, pointer: event.pointer, kind: event.kind);
          },
          onPointerUp: _endHandleDrag,
          onPointerCancel: _endHandleDrag,
        ),
        child: _HandleVisualOffset(
          childOffset: visualRect.topLeft - hitRect.topLeft,
          // 端点各用各 participant 色；端点未携带（旧快照/兜底）用根级色。
          child: widget.controls.buildHandle(
            context,
            type,
            endpoint.lineHeight,
            endpoint.handleColor ?? widget.handleColor,
          ),
        ),
      ),
    );
  }

  void _endHandleDrag(ElEventDetails callback) {
    callback.stopPropagation();
    widget.onHandleDragEnd();
  }

  TextSelectionHandleType _handleType(SelectionHandleEndpoint endpoint) {
    final isStart = endpoint.side == SelectionHandleSide.start;
    final pointsLeft = endpoint.textDirection == TextDirection.rtl ? !isStart : isStart;
    return pointsLeft ? TextSelectionHandleType.left : TextSelectionHandleType.right;
  }
}

class _HandlePositioner extends SingleChildRenderObjectWidget {
  const _HandlePositioner({
    required this.endpointsListenable,
    required this.dragInfoListenable,
    required this.scrollActivityListenable,
    required this.magnifierRectListenable,
    required this.side,
    required this.hitTopLeftFromBottom,
    required this.visualTopLeftFromBottom,
    required this.hitSize,
    required this.visualSize,
    required this.hideDraggedHandle,
    required this.hideHandlesWhileScrolling,
    required this.hideHandleBehindMagnifier,
    required this.globalToLocal,
    required this.projection,
    required super.child,
  });

  final ValueListenable<SelectionEndpointsInfo?> endpointsListenable;
  final ValueListenable<SelectionDragInfo?> dragInfoListenable;
  final ValueListenable<bool> scrollActivityListenable;
  final ValueListenable<Rect?> magnifierRectListenable;
  final SelectionHandleSide side;
  final Offset hitTopLeftFromBottom;
  final Offset visualTopLeftFromBottom;
  final Size hitSize;
  final Size visualSize;
  final bool hideDraggedHandle;
  final bool hideHandlesWhileScrolling;
  final bool hideHandleBehindMagnifier;
  final Offset Function(Offset global) globalToLocal;
  final SelectionChromeProjection? projection;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderHandlePositioner(
      endpointsListenable: endpointsListenable,
      dragInfoListenable: dragInfoListenable,
      scrollActivityListenable: scrollActivityListenable,
      magnifierRectListenable: magnifierRectListenable,
      side: side,
      hitTopLeftFromBottom: hitTopLeftFromBottom,
      visualTopLeftFromBottom: visualTopLeftFromBottom,
      hitSize: hitSize,
      visualSize: visualSize,
      hideDraggedHandle: hideDraggedHandle,
      hideHandlesWhileScrolling: hideHandlesWhileScrolling,
      hideHandleBehindMagnifier: hideHandleBehindMagnifier,
      globalToLocal: globalToLocal,
      projection: projection,
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderHandlePositioner renderObject) {
    renderObject
      ..endpointsListenable = endpointsListenable
      ..dragInfoListenable = dragInfoListenable
      ..scrollActivityListenable = scrollActivityListenable
      ..magnifierRectListenable = magnifierRectListenable
      ..side = side
      ..hitTopLeftFromBottom = hitTopLeftFromBottom
      ..visualTopLeftFromBottom = visualTopLeftFromBottom
      ..hitSize = hitSize
      ..visualSize = visualSize
      ..hideDraggedHandle = hideDraggedHandle
      ..hideHandlesWhileScrolling = hideHandlesWhileScrolling
      ..hideHandleBehindMagnifier = hideHandleBehindMagnifier
      ..chromeGlobalToLocal = globalToLocal
      ..projection = projection;
  }
}

class _RenderHandlePositioner extends RenderShiftedBox {
  _RenderHandlePositioner({
    required ValueListenable<SelectionEndpointsInfo?> endpointsListenable,
    required ValueListenable<SelectionDragInfo?> dragInfoListenable,
    required ValueListenable<bool> scrollActivityListenable,
    required ValueListenable<Rect?> magnifierRectListenable,
    required SelectionHandleSide side,
    required Offset hitTopLeftFromBottom,
    required Offset visualTopLeftFromBottom,
    required Size hitSize,
    required Size visualSize,
    required bool hideDraggedHandle,
    required bool hideHandlesWhileScrolling,
    required bool hideHandleBehindMagnifier,
    required Offset Function(Offset global) globalToLocal,
    required SelectionChromeProjection? projection,
  }) : this._(
         endpointsListenable: endpointsListenable,
         dragInfoListenable: dragInfoListenable,
         scrollActivityListenable: scrollActivityListenable,
         magnifierRectListenable: magnifierRectListenable,
         side: side,
         hitTopLeftFromBottom: hitTopLeftFromBottom,
         visualTopLeftFromBottom: visualTopLeftFromBottom,
         hitSize: hitSize,
         visualSize: visualSize,
         hideDraggedHandle: hideDraggedHandle,
         hideHandlesWhileScrolling: hideHandlesWhileScrolling,
         hideHandleBehindMagnifier: hideHandleBehindMagnifier,
         globalToLocal: globalToLocal,
         projection: projection,
       );

  _RenderHandlePositioner._({
    required this._endpointsListenable,
    required this._dragInfoListenable,
    required this._scrollActivityListenable,
    required this._magnifierRectListenable,
    required this._side,
    required this._hitTopLeftFromBottom,
    required this._visualTopLeftFromBottom,
    required this._hitSize,
    required this._visualSize,
    required this._hideDraggedHandle,
    required this._hideHandlesWhileScrolling,
    required this._hideHandleBehindMagnifier,
    required this._globalToLocal,
    required this._projection,
  }) : super(null);

  ValueListenable<SelectionEndpointsInfo?> _endpointsListenable;
  ValueListenable<SelectionDragInfo?> _dragInfoListenable;
  ValueListenable<bool> _scrollActivityListenable;
  ValueListenable<Rect?> _magnifierRectListenable;
  SelectionHandleSide _side;
  Offset _hitTopLeftFromBottom;
  Offset _visualTopLeftFromBottom;
  Size _hitSize;
  Size _visualSize;
  bool _hideDraggedHandle;
  bool _hideHandlesWhileScrolling;
  bool _hideHandleBehindMagnifier;
  Offset Function(Offset global) _globalToLocal;
  Offset _childOffset = Offset.zero;
  Offset _unitAnchor = Offset.zero;
  SelectionChromeProjection? _projection;
  bool _layoutDeferred = false;

  set endpointsListenable(ValueListenable<SelectionEndpointsInfo?> value) {
    if (identical(_endpointsListenable, value)) return;
    if (attached) _endpointsListenable.removeListener(_handleGeometryChanged);
    _endpointsListenable = value;
    if (attached) _endpointsListenable.addListener(_handleGeometryChanged);
    markNeedsLayout();
  }

  set dragInfoListenable(ValueListenable<SelectionDragInfo?> value) {
    if (identical(_dragInfoListenable, value)) return;
    if (attached) _dragInfoListenable.removeListener(_handleGeometryChanged);
    _dragInfoListenable = value;
    if (attached) _dragInfoListenable.addListener(_handleGeometryChanged);
    markNeedsLayout();
  }

  set scrollActivityListenable(ValueListenable<bool> value) {
    if (identical(_scrollActivityListenable, value)) return;
    if (attached) _scrollActivityListenable.removeListener(_handleGeometryChanged);
    _scrollActivityListenable = value;
    if (attached) _scrollActivityListenable.addListener(_handleGeometryChanged);
    markNeedsLayout();
  }

  set magnifierRectListenable(ValueListenable<Rect?> value) {
    if (identical(_magnifierRectListenable, value)) return;
    if (attached) _magnifierRectListenable.removeListener(_handleGeometryChanged);
    _magnifierRectListenable = value;
    if (attached) _magnifierRectListenable.addListener(_handleGeometryChanged);
    markNeedsLayout();
  }

  set side(SelectionHandleSide value) {
    if (_side == value) return;
    _side = value;
    markNeedsLayout();
  }

  set hitTopLeftFromBottom(Offset value) {
    if (_hitTopLeftFromBottom == value) return;
    _hitTopLeftFromBottom = value;
    markNeedsLayout();
  }

  set visualTopLeftFromBottom(Offset value) {
    if (_visualTopLeftFromBottom == value) return;
    _visualTopLeftFromBottom = value;
    markNeedsLayout();
  }

  set hitSize(Size value) {
    if (_hitSize == value) return;
    _hitSize = value;
    markNeedsLayout();
  }

  set visualSize(Size value) {
    if (_visualSize == value) return;
    _visualSize = value;
    markNeedsLayout();
  }

  set hideDraggedHandle(bool value) {
    if (_hideDraggedHandle == value) return;
    _hideDraggedHandle = value;
    markNeedsLayout();
  }

  set hideHandlesWhileScrolling(bool value) {
    if (_hideHandlesWhileScrolling == value) return;
    _hideHandlesWhileScrolling = value;
    markNeedsLayout();
  }

  set hideHandleBehindMagnifier(bool value) {
    if (_hideHandleBehindMagnifier == value) return;
    _hideHandleBehindMagnifier = value;
    markNeedsLayout();
  }

  set chromeGlobalToLocal(Offset Function(Offset global) value) {
    if (identical(_globalToLocal, value)) return;
    _globalToLocal = value;
    markNeedsLayout();
  }

  set projection(SelectionChromeProjection? value) {
    if (identical(_projection, value)) return;
    _projection = value;
    layer = null;
    markNeedsLayout();
  }

  @override
  bool get alwaysNeedsCompositing => _projection != null || super.alwaysNeedsCompositing;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _endpointsListenable.addListener(_handleGeometryChanged);
    _dragInfoListenable.addListener(_handleGeometryChanged);
    _scrollActivityListenable.addListener(_handleGeometryChanged);
    _magnifierRectListenable.addListener(_handleGeometryChanged);
  }

  @override
  void detach() {
    _endpointsListenable.removeListener(_handleGeometryChanged);
    _dragInfoListenable.removeListener(_handleGeometryChanged);
    _scrollActivityListenable.removeListener(_handleGeometryChanged);
    _magnifierRectListenable.removeListener(_handleGeometryChanged);
    layer = null;
    super.detach();
  }

  void _handleGeometryChanged() {
    if (!attached) return;
    if (owner?.debugDoingLayout ?? false) {
      if (_layoutDeferred) return;
      _layoutDeferred = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _layoutDeferred = false;
        if (attached) markNeedsLayout();
      });
      return;
    }
    markNeedsLayout();
  }

  SelectionHandleEndpoint? get _endpoint {
    final endpoints = _endpointsListenable.value;
    if (endpoints == null) return null;
    return _side == SelectionHandleSide.start ? endpoints.start : endpoints.end;
  }

  bool get _visible {
    final endpoint = _endpoint;
    if (endpoint == null || !endpoint.visible) return false;
    final drag = _dragInfoListenable.value;
    if (drag?.kind == SelectionDragKind.longPress) return false;
    if (_hideDraggedHandle && drag?.kind == SelectionDragKind.handle && drag?.side == _side) return false;
    if (_hideHandlesWhileScrolling && _scrollActivityListenable.value) return false;
    final magnifierRect = drag == null ? null : _magnifierRectListenable.value;
    if (_hideHandleBehindMagnifier && magnifierRect != null) {
      final visualRect = Rect.fromLTWH(
        endpoint.globalBottom.dx + _visualTopLeftFromBottom.dx,
        endpoint.globalBottom.dy + _visualTopLeftFromBottom.dy,
        _visualSize.width,
        _visualSize.height,
      );
      if (magnifierRect.overlaps(visualRect)) return false;
    }
    return true;
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final child = this.child;
    if (child == null) return;
    child.layout(BoxConstraints.tight(_hitSize), parentUsesSize: true);
    final endpoint = _endpoint;
    if (endpoint == null) {
      _unitAnchor = Offset.zero;
      _childOffset = Offset.zero;
    } else if (_projection == null) {
      _unitAnchor = Offset.zero;
      _childOffset = _globalToLocal(endpoint.globalBottom + _hitTopLeftFromBottom);
    } else {
      _unitAnchor = _globalToLocal(endpoint.globalBottom);
      _childOffset = _unitAnchor + _hitTopLeftFromBottom;
    }
    (child.parentData! as BoxParentData).offset = _childOffset;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || !_visible) return;
    final projection = _projection;
    if (projection == null) {
      context.paintChild(child, offset + _childOffset);
      return;
    }
    var unitLayer = layer;
    if (unitLayer is! SelectionChromeUnitLayer) {
      unitLayer = SelectionChromeUnitLayer(
        transformLink: projection.transformLink,
        anchor: _unitAnchor,
        screenOffset: Offset.zero,
        screenRectFromAnchor: _hitTopLeftFromBottom & _hitSize,
      );
      layer = unitLayer;
    } else {
      unitLayer
        ..transformLink = projection.transformLink
        ..anchor = _unitAnchor
        ..screenOffset = Offset.zero
        ..screenRectFromAnchor = _hitTopLeftFromBottom & _hitSize;
    }
    context.pushLayer(
      unitLayer,
      (paintingContext, layerOffset) => paintingContext.paintChild(child, layerOffset + _childOffset),
      offset,
      childPaintBounds: const Rect.fromLTRB(
        double.negativeInfinity,
        double.negativeInfinity,
        double.infinity,
        double.infinity,
      ),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null || !_visible) return false;
    final unitLayer = layer;
    if (_projection != null && unitLayer is SelectionChromeUnitLayer) {
      if (!unitLayer.lastVisible) return false;
      return result.addWithPaintTransform(
        transform: unitLayer.getLastTransform(),
        position: position,
        hitTest: (result, transformed) => result.addWithPaintOffset(
          offset: _childOffset,
          position: transformed,
          hitTest: (result, transformed) => child.hitTest(result, position: transformed),
        ),
      );
    }
    return result.addWithPaintOffset(
      offset: _childOffset,
      position: position,
      hitTest: (result, transformed) => child.hitTest(result, position: transformed),
    );
  }

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final unitLayer = layer;
    if (_projection == null || unitLayer is! SelectionChromeUnitLayer) {
      super.applyPaintTransform(child, transform);
      return;
    }
    final unitTransform = unitLayer.getLastTransform();
    if (unitTransform != null) transform.multiply(unitTransform);
    transform.translateByDouble(_childOffset.dx, _childOffset.dy, 0.0, 1.0);
  }
}

class _HandleVisualOffset extends SingleChildRenderObjectWidget {
  const _HandleVisualOffset({required this.childOffset, required super.child});

  final Offset childOffset;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderHandleVisualOffset(childOffset);
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderHandleVisualOffset renderObject) {
    renderObject.childOffset = childOffset;
  }
}

class _RenderHandleVisualOffset extends RenderProxyBox {
  _RenderHandleVisualOffset(this._childOffset);

  Offset _childOffset;

  set childOffset(Offset value) {
    if (_childOffset == value) return;
    _childOffset = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    child?.layout(constraints.loosen(), parentUsesSize: true);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null) context.paintChild(child, offset + _childOffset);
  }
}

/// 被拖端点的焦点几何。
typedef SelectionMagnifierFocus = ({double caretX, SelectionLineGeometry line});

/// 返回当前被拖端点的焦点几何。
typedef SelectionMagnifierLineGeometryProvider = SelectionMagnifierFocus? Function();

/// controls 驱动的选区 magnifier 层。
class SelectionMagnifierView extends StatefulWidget {
  /// 创建。
  const SelectionMagnifierView({
    super.key,
    required this.endpointsListenable,
    required this.dragInfoListenable,
    required this.lineGeometryProvider,
    this.globalToLocal = _identityGlobalToLocal,
    required this.magnifierRectSink,
    required this.controls,
  });

  /// 端点几何通道。
  final ValueListenable<SelectionEndpointsInfo?> endpointsListenable;

  /// 拖动状态通道。
  final ValueListenable<SelectionDragInfo?> dragInfoListenable;

  /// 被拖端点的行几何 provider。
  final SelectionMagnifierLineGeometryProvider lineGeometryProvider;

  /// 全局坐标到本地坐标的换算器。
  final Offset Function(Offset global) globalToLocal;

  /// 当前 magnifier 矩形输出通道。
  final ValueNotifier<Rect?> magnifierRectSink;

  /// 生效的平台 controls。
  final SelectionControls controls;

  @override
  State<SelectionMagnifierView> createState() => _SelectionMagnifierViewState();
}

class _SelectionMagnifierViewState extends State<SelectionMagnifierView> with TickerProviderStateMixin {
  late final AnimationController _positionController = AnimationController(vsync: this, duration: Duration.zero)
    ..addListener(_handleAnimationTick);
  late final AnimationController _visibilityController = AnimationController(
    vsync: this,
    duration: Duration.zero,
    reverseDuration: Duration.zero,
  )..addListener(_handleAnimationTick);

  MagnifierInfo? _info;
  Offset? _targetCenter;
  Offset? _flightFromCenter;
  bool _setStateDeferred = false;

  @override
  void initState() {
    super.initState();
    _listen(widget);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimationDurations();
    _updateFromInputs(initial: _targetCenter == null);
  }

  @override
  void didUpdateWidget(covariant SelectionMagnifierView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unlisten(oldWidget);
    _listen(widget);
    _updateAnimationDurations();
    _updateFromInputs(initial: !identical(oldWidget.controls, widget.controls));
  }

  @override
  void dispose() {
    _unlisten(widget);
    _positionController.dispose();
    _visibilityController.dispose();
    if (widget.magnifierRectSink.value != null) {
      widget.magnifierRectSink.value = null;
    }
    super.dispose();
  }

  void _listen(SelectionMagnifierView source) {
    source.dragInfoListenable.addListener(_handleSourceChanged);
    source.endpointsListenable.addListener(_handleSourceChanged);
  }

  void _unlisten(SelectionMagnifierView source) {
    source.dragInfoListenable.removeListener(_handleSourceChanged);
    source.endpointsListenable.removeListener(_handleSourceChanged);
  }

  void _updateAnimationDurations() {
    _positionController.duration = widget.controls.resolveMagnifierPositionDuration(context);
    _visibilityController
      ..duration = widget.controls.resolveMagnifierEnterDuration(context)
      ..reverseDuration = widget.controls.resolveMagnifierExitDuration(context);
  }

  void _handleSourceChanged() {
    if (!mounted) return;
    _updateFromInputs();
    _safeSetState();
  }

  void _handleAnimationTick() {
    _safeSetState();
  }

  void _safeSetState([VoidCallback? fn]) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.transientCallbacks) {
      if (fn != null) fn();
      if (_setStateDeferred) return;
      _setStateDeferred = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _setStateDeferred = false;
        if (mounted) setState(() {});
      });
      return;
    }
    setState(fn ?? () {});
  }

  MagnifierInfo? _resolveInfo() {
    final drag = widget.dragInfoListenable.value;
    final focus = drag == null ? null : widget.lineGeometryProvider();
    if (drag == null || focus == null || focus.line.lineHeight <= 0.0) return null;
    final line = focus.line;
    return MagnifierInfo(
      globalGesturePosition: drag.globalPosition,
      caretRect: Rect.fromLTWH(focus.caretX - 1.0, line.lineTop, 2.0, line.lineHeight),
      currentLineBoundaries: Rect.fromLTWH(
        line.lineLeft,
        line.lineTop,
        line.lineRight - line.lineLeft,
        line.lineHeight,
      ),
      fieldBounds: Offset.zero & MediaQuery.sizeOf(context),
    );
  }

  void _updateFromInputs({bool initial = false}) {
    final info = _resolveInfo();
    if (info == null || !widget.controls.shouldShowMagnifier(context, info)) {
      _hide();
      return;
    }
    _info = info;
    _show();
    final target = widget.controls.resolveMagnifierCenter(context, info);
    final shown = _shownCenter;
    if (initial || shown == null || _positionController.duration == Duration.zero) {
      _flightFromCenter = null;
      _targetCenter = target;
      _positionController
        ..stop()
        ..value = 1.0;
      return;
    }
    if (target == shown) return;
    if (_positionController.isAnimating) {
      final value = _positionController.value;
      final remaining = 1.0 - value;
      _flightFromCenter = remaining <= 1e-6
          ? shown
          : Offset(
              widget.controls.resolveAnimateMagnifierX(context)
                  ? (shown.dx - target.dx * value) / remaining
                  : target.dx,
              widget.controls.resolveAnimateMagnifierY(context)
                  ? (shown.dy - target.dy * value) / remaining
                  : target.dy,
            );
      _targetCenter = target;
      return;
    }
    _flightFromCenter = shown;
    _targetCenter = target;
    _positionController.forward(from: 0.0);
  }

  void _show() {
    final duration = _visibilityController.duration;
    if (duration == null || duration == Duration.zero) {
      _visibilityController.value = 1.0;
    } else {
      _visibilityController.forward();
    }
  }

  void _hide() {
    final duration = _visibilityController.reverseDuration;
    if (duration == null || duration == Duration.zero) {
      _visibilityController.value = 0.0;
      _clearHiddenState();
    } else {
      _visibilityController.reverse().whenComplete(() {
        if (mounted && _visibilityController.value == 0.0) {
          _safeSetState(_clearHiddenState);
        }
      });
    }
  }

  void _clearHiddenState() {
    _info = null;
    _targetCenter = null;
    _flightFromCenter = null;
    _positionController
      ..stop()
      ..value = 0.0;
    _publishRect(null);
  }

  Offset? get _shownCenter {
    final target = _targetCenter;
    if (target == null) return null;
    final from = _flightFromCenter;
    if (from == null || _positionController.value >= 1.0) return target;
    final curve = widget.controls.resolveMagnifierPositionCurve(context);
    final value = curve.transform(_positionController.value);
    return Offset(
      widget.controls.resolveAnimateMagnifierX(context) ? from.dx + (target.dx - from.dx) * value : target.dx,
      widget.controls.resolveAnimateMagnifierY(context) ? from.dy + (target.dy - from.dy) * value : target.dy,
    );
  }

  void _publishRect(Rect? rect) {
    final sink = widget.magnifierRectSink;
    if (sink.value == rect) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && sink.value != rect) sink.value = rect;
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final center = _shownCenter;
    final visibility = widget.controls.resolveMagnifierVisibilityCurve(context).transform(_visibilityController.value);
    if (info == null || center == null || visibility <= 0.0) {
      _publishRect(null);
      return const SizedBox.shrink();
    }

    final media = MediaQuery.of(context);
    final size = widget.controls.resolveMagnifierSize(context);
    var rect = Rect.fromCenter(center: center, width: size.width, height: size.height);
    rect = widget.controls.constrainMagnifierRect(context, rect, media.size, media.padding);
    final dpr = media.devicePixelRatio > 0.0 ? media.devicePixelRatio : 1.0;
    rect = Rect.fromLTWH(
      (rect.left * dpr).roundToDouble() / dpr,
      (rect.top * dpr).roundToDouble() / dpr,
      rect.width,
      rect.height,
    );
    _publishRect(rect);

    final focalPoint = widget.controls.resolveMagnifierFocalPoint(context, info, rect);
    final localTopLeft = widget.globalToLocal(rect.topLeft);
    final visual = IgnorePointer(
      child: widget.controls.buildMagnifier(
        context,
        info,
        size: size,
        focalPointOffset: focalPoint - rect.center,
        animationValue: visibility,
      ),
    );
    final projection = SelectionChromeProjectionScope.maybeOf(context);
    if (projection != null) {
      return SelectionChromeUnitPositioner(
        projection: projection,
        anchor: localTopLeft,
        childSize: rect.size,
        child: visual,
      );
    }
    return Positioned(
      left: localTopLeft.dx,
      top: localTopLeft.dy,
      width: rect.width,
      height: rect.height,
      child: visual,
    );
  }
}
