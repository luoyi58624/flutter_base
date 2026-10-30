part of 'selection_core.dart';

/// 根据生效选区宿主构建附属层的回调。
typedef SelectionChromePortalBuilder =
    Widget Function(BuildContext context, Offset Function(Offset global) globalToLocal);

/// 选区附属层的共享 portal：提升到页面宿主，缺失时回退树内兄弟层。
///
/// 挂载、更新、换宿主与销毁统一管理，文本选区与编辑器只提供几何和值通道。
class SelectionChromePortal extends StatefulWidget {
  /// 创建选区 Chrome portal。
  const SelectionChromePortal({
    super.key,
    required this.visible,
    this.visibilityListenable,
    required this.content,
    required this.fallbackGlobalToLocal,
    required this.chromeBuilder,
  });

  /// 是否需要挂载 Chrome。
  final bool visible;

  /// 可选的独立显隐通道；用于选区变化时只重建 portal，不打断正文手势。
  final ValueListenable<bool>? visibilityListenable;

  /// 正文内容。
  final Widget content;

  /// 没有页面宿主时的全局坐标到树内附属层坐标换算器。
  final Offset Function(Offset global) fallbackGlobalToLocal;

  /// Chrome 构建器。
  final SelectionChromePortalBuilder chromeBuilder;

  @override
  State<SelectionChromePortal> createState() => _SelectionChromePortalState();
}

class _SelectionChromePortalState extends State<SelectionChromePortal> {
  final LayerLink _layerLink = LayerLink();
  final SelectionChromeTransformLink _transformLink = SelectionChromeTransformLink();
  SelectionChromeHandle? _handle;
  SelectionChromeMountHost? _host;
  SelectionChromeMountHost? _targetHost;
  Listenable? _hostState;
  bool _syncScheduled = false;

  bool get _visible => widget.visibilityListenable?.value ?? widget.visible;

  @override
  void initState() {
    super.initState();
    widget.visibilityListenable?.addListener(_handleVisibilityChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleSync();
  }

  @override
  void didUpdateWidget(covariant SelectionChromePortal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.visibilityListenable, oldWidget.visibilityListenable)) {
      oldWidget.visibilityListenable?.removeListener(_handleVisibilityChanged);
      widget.visibilityListenable?.addListener(_handleVisibilityChanged);
    }
    _scheduleSync();
  }

  @override
  void dispose() {
    widget.visibilityListenable?.removeListener(_handleVisibilityChanged);
    _bindHostState(null);
    _closeHosted();
    super.dispose();
  }

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _sync();
    });
  }

  void _handleVisibilityChanged() {
    if (!mounted) return;
    _scheduleSync();
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.transientCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      SchedulerBinding.instance.ensureVisualUpdate();
      return;
    }
    setState(() {});
  }

  void _handleHostStateChanged() => _scheduleSync();

  void _bindHostState(Listenable? value) {
    if (identical(_hostState, value)) return;
    _hostState?.removeListener(_handleHostStateChanged);
    _hostState = value;
    _hostState?.addListener(_handleHostStateChanged);
  }

  void _sync() {
    final host = _targetHost;
    if (!_visible || host == null || !host.canMount) {
      _closeHosted();
      return;
    }
    final handle = _handle;
    if (handle != null && host == _host && handle.isOpen) {
      handle.update(_buildHostedChrome);
      return;
    }
    _closeHosted();
    _host = host;
    _handle = host.mount(context, builder: _buildHostedChrome);
  }

  void _closeHosted() {
    final handle = _handle;
    _handle = null;
    _host = null;
    handle?.close();
  }

  Widget _buildHostedChrome(BuildContext context) {
    return InheritedTheme.captureAll(
      this.context,
      ElView(
        style: const ElStyle(width: '100%', height: '100%', pointerEvents: .none),
        child: _SelectionChromeFollower(
          link: _layerLink,
          transformLink: _transformLink,
          offset: const Offset(-selectionChromeOverflowPad, -selectionChromeOverflowPad),
          child: _SelectionChromeExpandedViewport(
            overflow: selectionChromeOverflowPad,
            // endpoints 与本逆矩阵在同一几何发布中产生；祖先只更新 retained
            // TransformLayer 时二者保持旧局部坐标，由 follower 在合成期整体追随。
            child: SelectionChromeProjectionScope(
              projection: SelectionChromeProjection(
                transformLink: _transformLink,
                chromeCoordinateOrigin: const Offset(selectionChromeOverflowPad, selectionChromeOverflowPad),
                hostGlobalToLocal: (global) => _host?.globalToLocal(global),
              ),
              child: Builder(builder: (context) => widget.chromeBuilder(context, widget.fallbackGlobalToLocal)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final host = SelectionChromeSlot.maybeOf(context);
    _targetHost = host;
    // 内容隐藏时关闭附属层，恢复后仍通过原有内容宿主重新挂载。
    _bindHostState(host?.stateListenable);
    _scheduleSync();
    final hosted = host != null;
    return _SelectionChromeLeader(
      link: _layerLink,
      enabled: hosted && _visible,
      child: SelectionChromeHost(
        content: widget.content,
        chrome: !hosted && _visible ? widget.chromeBuilder(context, widget.fallbackGlobalToLocal) : null,
      ),
    );
  }
}

// 私有 leader/follower 壳：避免挂载 Flutter 行为类 Widget，同时让 overlay
// chrome 在祖先原生 Transform 只更新 retained layer 时仍于同一合成帧跟随。
class _SelectionChromeLeader extends SingleChildRenderObjectWidget {
  const _SelectionChromeLeader({required this.link, required this.enabled, required super.child});

  final LayerLink link;
  final bool enabled;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSelectionChromeLeader(link, enabled);

  @override
  void updateRenderObject(BuildContext context, _RenderSelectionChromeLeader renderObject) {
    renderObject
      ..link = link
      ..enabled = enabled;
  }
}

class _RenderSelectionChromeLeader extends RenderProxyBox {
  _RenderSelectionChromeLeader(this._link, this._enabled);

  LayerLink _link;
  bool _enabled;
  Size? _previousLayoutSize;

  LayerLink get link => _link;
  set link(LayerLink value) {
    if (identical(_link, value)) return;
    _link.leaderSize = null;
    _link = value;
    if (_enabled) _link.leaderSize = _previousLayoutSize;
    markNeedsPaint();
  }

  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _link.leaderSize = value ? _previousLayoutSize : null;
    if (!value) layer = null;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _enabled;

  @override
  void performLayout() {
    super.performLayout();
    _previousLayoutSize = size;
    _link.leaderSize = _enabled ? size : null;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_enabled) {
      super.paint(context, offset);
      return;
    }
    final LeaderLayer leader;
    if (layer case final LeaderLayer current) {
      leader = current
        ..link = _link
        ..offset = offset;
    } else {
      leader = LeaderLayer(link: _link, offset: offset);
      layer = leader;
    }
    context.pushLayer(leader, super.paint, Offset.zero);
    assert(() {
      leader.debugCreator = debugCreator;
      return true;
    }());
  }

  @override
  void dispose() {
    _link.leaderSize = null;
    layer = null;
    super.dispose();
  }
}

class _SelectionChromeFollower extends SingleChildRenderObjectWidget {
  const _SelectionChromeFollower({
    required this.link,
    required this.transformLink,
    required this.offset,
    required super.child,
  });

  final LayerLink link;
  final SelectionChromeTransformLink transformLink;
  final Offset offset;

  @override
  RenderFollowerLayer createRenderObject(BuildContext context) {
    return _RenderSelectionChromeFollower(
      link: link,
      transformLink: transformLink,
      showWhenUnlinked: false,
      offset: offset,
      leaderAnchor: Alignment.topLeft,
      followerAnchor: Alignment.topLeft,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderFollowerLayer renderObject) {
    renderObject
      ..link = link
      ..showWhenUnlinked = false
      ..offset = offset
      ..leaderAnchor = Alignment.topLeft
      ..followerAnchor = Alignment.topLeft;
    if (renderObject is _RenderSelectionChromeFollower) renderObject.transformLink = transformLink;
  }
}

class _RenderSelectionChromeFollower extends RenderFollowerLayer with ElOverflowHitBounds {
  _RenderSelectionChromeFollower({
    required super.link,
    required this._transformLink,
    super.showWhenUnlinked,
    super.offset,
    super.leaderAnchor,
    super.followerAnchor,
  });

  SelectionChromeTransformLink _transformLink;

  @override
  Rect get selfHitRect => Offset.zero & size;

  @override
  bool get clipsHitBounds => false;

  // 留白边界与 follower 绘制使用同一变换，避免祖先按正文盒提前剪枝。
  @override
  Matrix4? get hitBoundsTransform => getCurrentTransform();

  @override
  void visitHitBoundsChildren(void Function(RenderBox child, Offset offset) visitor) {
    final child = this.child;
    if (child != null) visitor(child, Offset.zero);
  }

  @override
  void performLayout() {
    super.performLayout();
    markHitBoundsDirty();
  }

  set transformLink(SelectionChromeTransformLink value) {
    if (identical(_transformLink, value)) return;
    _transformLink.bind(null);
    _transformLink = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    _transformLink.bind(layer);
    markHitBoundsDirty();
  }

  @override
  void detach() {
    _transformLink.bind(null);
    super.detach();
  }
}

class _SelectionChromeExpandedViewport extends SingleChildRenderObjectWidget {
  const _SelectionChromeExpandedViewport({required this.overflow, required super.child});

  final double overflow;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSelectionChromeExpandedViewport(overflow);

  @override
  void updateRenderObject(BuildContext context, _RenderSelectionChromeExpandedViewport renderObject) {
    renderObject.overflow = overflow;
  }
}

class _RenderSelectionChromeExpandedViewport extends RenderProxyBox with ElOverflowHitBounds {
  _RenderSelectionChromeExpandedViewport(this._overflow);

  double _overflow;

  @override
  Rect get selfHitRect => Offset.zero & size;

  @override
  bool get clipsHitBounds => false;

  @override
  void visitHitBoundsChildren(void Function(RenderBox child, Offset offset) visitor) {
    final child = this.child;
    if (child != null) visitor(child, Offset.zero);
  }

  set overflow(double value) {
    if (_overflow == value) return;
    _overflow = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    // 让紧包正文盒的祖先也能访问句柄留白，实际命中仍交给子树。
    markHitBoundsDirty();
    size = constraints.biggest;
    final child = this.child;
    if (child == null) return;
    child.layout(
      BoxConstraints.tight(Size(size.width + _overflow * 2, size.height + _overflow * 2)),
      parentUsesSize: true,
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    return child?.hitTest(result, position: position) ?? false;
  }
}

/// Portal follower 与屏幕空间子 layer 共享的实时合成变换句柄。
final class SelectionChromeTransformLink {
  FollowerLayer? _followerLayer;

  /// 最近一次 paint 创建的 follower layer；合成时其 transform 会实时刷新。
  FollowerLayer? get followerLayer => _followerLayer;

  /// Portal follower 在 paint 后登记当前 layer。
  void bind(FollowerLayer? layer) => _followerLayer = layer;

  /// 正文 leader 到 overlay host 之间祖先 clip 的 host 本地交集。
  ///
  /// ClipRect 精确；RRect/Path 取保守 AABB，避免误藏有效 chrome，不宣称角落
  /// 像素级 containment。
  Rect? currentLeaderClipRect() {
    final follower = _followerLayer;
    final leader = follower?.link.leader;
    if (follower == null || leader == null) return null;
    final followerAncestors = <Layer>{};
    Layer? node = follower;
    while (node != null) {
      followerAncestors.add(node);
      node = node.parent;
    }
    Rect? result;
    node = leader.parent;
    while (node != null && !followerAncestors.contains(node)) {
      final localClip = switch (node) {
        ClipRectLayer(:final clipRect) => clipRect,
        ClipRRectLayer(:final clipRRect) when clipRRect != null => clipRRect.outerRect,
        ClipPathLayer(:final clipPath) when clipPath != null => clipPath.getBounds(),
        _ => null,
      };
      final clipParent = node.parent;
      if (localClip != null && clipParent is ContainerLayer) {
        // Flutter clip layer 的几何明确位于 parent 坐标系，不能再把 clip
        // layer 自身当一次坐标原点，否则会重复消费 paint offset。
        final transform = _layerToLayerTransform(clipParent, follower);
        if (transform != null) {
          final projected = MatrixUtils.transformRect(transform, localClip);
          result = result == null ? projected : result.intersect(projected);
        }
      }
      node = node.parent;
    }
    return result;
  }
}

/// Overlay chrome 与正文 leader 之间的合成期坐标投影。
final class SelectionChromeProjection {
  /// 创建屏幕空间投影。
  const SelectionChromeProjection({
    required this.transformLink,
    required this.chromeCoordinateOrigin,
    required this.hostGlobalToLocal,
  });

  /// 外层 Flutter follower 的实时变换句柄。
  final SelectionChromeTransformLink transformLink;

  /// fallback chrome 坐标中对应正文 leader 原点的位置。
  final Offset chromeCoordinateOrigin;

  /// Flutter View 全局坐标到 overlay host 本地坐标的实时换算。
  final Offset? Function(Offset global) hostGlobalToLocal;

  /// 把 fallback chrome 本地坐标还原为正文 leader 本地坐标。
  Offset leaderLocalFromChromeLocal(Offset chromeLocal) => chromeLocal - chromeCoordinateOrigin;

  /// 把全局矩形换算成 overlay host 本地 AABB。
  Rect hostRectFromGlobal(Rect globalRect) {
    final points = <Offset>[
      hostGlobalToLocal(globalRect.topLeft) ?? globalRect.topLeft,
      hostGlobalToLocal(globalRect.topRight) ?? globalRect.topRight,
      hostGlobalToLocal(globalRect.bottomLeft) ?? globalRect.bottomLeft,
      hostGlobalToLocal(globalRect.bottomRight) ?? globalRect.bottomRight,
    ];
    return Rect.fromLTRB(
      points.map((point) => point.dx).reduce((a, b) => a < b ? a : b),
      points.map((point) => point.dy).reduce((a, b) => a < b ? a : b),
      points.map((point) => point.dx).reduce((a, b) => a > b ? a : b),
      points.map((point) => point.dy).reduce((a, b) => a > b ? a : b),
    );
  }
}

/// 向 chrome 子树发布当前 overlay 合成投影。
class SelectionChromeProjectionScope extends InheritedWidget {
  /// 创建投影 scope。
  const SelectionChromeProjectionScope({super.key, required this.projection, required super.child});

  /// 当前投影。
  final SelectionChromeProjection projection;

  /// 查找最近的投影；树内 fallback 路径返回 null。
  static SelectionChromeProjection? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SelectionChromeProjectionScope>()?.projection;
  }

  @override
  bool updateShouldNotify(SelectionChromeProjectionScope oldWidget) => projection != oldWidget.projection;
}

/// 把一个固定尺寸 child 锚到 chrome 本地点，并在合成期保持 unit-space。
class SelectionChromeUnitPositioner extends SingleChildRenderObjectWidget {
  /// 创建 unit-space 定位器。
  const SelectionChromeUnitPositioner({
    super.key,
    required this.projection,
    required this.anchor,
    required this.childSize,
    required super.child,
  });

  /// 当前 portal 投影。
  final SelectionChromeProjection projection;

  /// chrome 本地 child 左上角。
  final Offset anchor;

  /// child 的屏幕逻辑尺寸。
  final Size childSize;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSelectionChromeUnitPositioner(projection, anchor, childSize);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderSelectionChromeUnitPositioner)
      ..projection = projection
      ..anchor = anchor
      ..childSize = childSize;
  }
}

class _RenderSelectionChromeUnitPositioner extends RenderShiftedBox {
  _RenderSelectionChromeUnitPositioner(this._projection, this._anchor, this._childSize) : super(null);

  SelectionChromeProjection _projection;

  set projection(SelectionChromeProjection value) {
    if (identical(_projection, value)) return;
    _projection = value;
    layer = null;
    markNeedsPaint();
  }

  Offset _anchor;

  set anchor(Offset value) {
    if (_anchor == value) return;
    _anchor = value;
    markNeedsLayout();
  }

  Size _childSize;

  set childSize(Size value) {
    if (_childSize == value) return;
    _childSize = value;
    markNeedsLayout();
  }

  @override
  bool get alwaysNeedsCompositing => true;

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
    child.layout(BoxConstraints.tight(_childSize), parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = _anchor;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    var unitLayer = layer;
    if (unitLayer is! SelectionChromeUnitLayer) {
      unitLayer = SelectionChromeUnitLayer(
        transformLink: _projection.transformLink,
        anchor: _anchor,
        screenOffset: Offset.zero,
        screenRectFromAnchor: Offset.zero & _childSize,
      );
      layer = unitLayer;
    } else {
      unitLayer
        ..transformLink = _projection.transformLink
        ..anchor = _anchor
        ..screenOffset = Offset.zero
        ..screenRectFromAnchor = Offset.zero & _childSize;
    }
    context.pushLayer(
      unitLayer,
      (paintingContext, layerOffset) => paintingContext.paintChild(child, layerOffset + _anchor),
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
    final unitLayer = layer;
    if (child == null || unitLayer is! SelectionChromeUnitLayer || !unitLayer.lastVisible) return false;
    return result.addWithPaintTransform(
      transform: unitLayer.getLastTransform(),
      position: position,
      hitTest: (result, transformed) => result.addWithPaintOffset(
        offset: _anchor,
        position: transformed,
        hitTest: (result, transformed) => child.hitTest(result, position: transformed),
      ),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final unitLayer = layer;
    if (unitLayer is SelectionChromeUnitLayer) {
      final unitTransform = unitLayer.getLastTransform();
      if (unitTransform != null) transform.multiply(unitTransform);
    }
    transform.translateByDouble(_anchor.dx, _anchor.dy, 0.0, 1.0);
  }
}

/// 仅抵消 follower 线性 scale/rotation、保留锚点完整投影的 unit-space layer。
class SelectionChromeUnitLayer extends ContainerLayer {
  /// 创建固定屏幕尺寸 layer。
  SelectionChromeUnitLayer({
    required this.transformLink,
    required this.anchor,
    required this.screenOffset,
    this.screenRectFromAnchor,
  });

  /// 外层 follower 变换句柄。
  SelectionChromeTransformLink transformLink;

  /// chrome 本地锚点；完整 follower 仍负责把它投到屏幕。
  Offset anchor;

  /// 锚点投影后追加的屏幕空间偏移。
  Offset screenOffset;

  /// 用于 retained clip 可见性判定的屏幕空间矩形（相对 [anchor]）。
  Rect? screenRectFromAnchor;

  Matrix4? _lastTransform;
  bool _lastVisible = true;

  /// 最近一次合成使用的 unit-space 变换。
  Matrix4? getLastTransform() => _lastTransform == null ? null : Matrix4.copy(_lastTransform!);

  /// 最近一次合成是否仍与正文祖先 clip 相交。
  bool get lastVisible => _lastVisible;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    final follower = transformLink.followerLayer?.getLastTransform();
    final transform = follower == null ? Matrix4.identity() : _unitTransform(follower, anchor, screenOffset);
    _lastTransform = transform;
    final relativeRect = screenRectFromAnchor;
    final clip = transformLink.currentLeaderClipRect();
    if (follower != null && relativeRect != null && clip != null) {
      final screenAnchor = MatrixUtils.transformPoint(follower, anchor);
      _lastVisible = clip.overlaps(relativeRect.shift(screenAnchor));
      if (!_lastVisible) {
        engineLayer = null;
        return;
      }
    } else {
      _lastVisible = true;
    }
    final oldLayer = engineLayer;
    engineLayer = builder.pushTransform(
      transform.storage,
      oldLayer: oldLayer is ui.TransformEngineLayer ? oldLayer : null,
    );
    addChildrenToScene(builder);
    builder.pop();
  }

  @override
  void applyTransform(Layer? child, Matrix4 transform) {
    final current = _lastTransform;
    if (current != null) transform.multiply(current);
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, {required bool onlyFirst}) {
    final transform = _lastTransform;
    if (transform == null) return false;
    final inverse = Matrix4.tryInvert(transform);
    if (inverse == null) return false;
    return super.findAnnotations(result, MatrixUtils.transformPoint(inverse, localPosition), onlyFirst: onlyFirst);
  }
}

/// 合成期按实时 top/bottom 锚点翻转并钳制工具条的 unit-space layer。
class SelectionChromeToolbarUnitLayer extends ContainerLayer {
  /// 创建工具条 unit-space layer。
  SelectionChromeToolbarUnitLayer({
    required this.transformLink,
    required this.paintAnchor,
    required this.topAnchor,
    required this.bottomAnchor,
    required this.childSize,
    required this.viewport,
    required this.gapAbove,
    required this.gapBelow,
  });

  /// 外层 follower 变换句柄。
  SelectionChromeTransformLink transformLink;

  /// child 在 chrome 本地实际绘制的源锚点。
  Offset paintAnchor;

  /// 选区上边缘的 chrome 本地锚点。
  Offset topAnchor;

  /// 选区下边缘的 chrome 本地锚点。
  Offset bottomAnchor;

  /// 工具条屏幕逻辑尺寸。
  Size childSize;

  /// overlay host 本地安全视口。
  Rect viewport;

  /// 上方形态间距。
  double gapAbove;

  /// 下方形态间距。
  double gapBelow;

  Matrix4? _lastTransform;
  bool _lastVisible = true;

  /// 最近一次合成使用的 unit-space 变换。
  Matrix4? getLastTransform() => _lastTransform == null ? null : Matrix4.copy(_lastTransform!);

  /// 最近一次合成时选区锚点是否仍与正文祖先 clip 相交。
  bool get lastVisible => _lastVisible;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    final follower = transformLink.followerLayer?.getLastTransform();
    final clip = transformLink.currentLeaderClipRect();
    if (follower != null && clip != null) {
      final top = MatrixUtils.transformPoint(follower, topAnchor);
      final bottom = MatrixUtils.transformPoint(follower, bottomAnchor);
      _lastVisible = clip.overlaps(Rect.fromPoints(top, bottom).inflate(1.0));
      if (!_lastVisible) {
        _lastTransform = null;
        engineLayer = null;
        return;
      }
    } else {
      _lastVisible = true;
    }
    final transform = follower == null ? Matrix4.identity() : _resolveTransform(follower);
    _lastTransform = transform;
    final oldLayer = engineLayer;
    engineLayer = builder.pushTransform(
      transform.storage,
      oldLayer: oldLayer is ui.TransformEngineLayer ? oldLayer : null,
    );
    addChildrenToScene(builder);
    builder.pop();
  }

  Matrix4 _resolveTransform(Matrix4 follower) {
    final top = MatrixUtils.transformPoint(follower, topAnchor);
    final bottom = MatrixUtils.transformPoint(follower, bottomAnchor);
    final above = top.dy - gapAbove - childSize.height >= viewport.top;
    final anchor = above ? top : bottom;
    final desired = Offset(
      anchor.dx - childSize.width / 2,
      above ? anchor.dy - gapAbove - childSize.height : anchor.dy + gapBelow,
    );
    final maxX = viewport.right - childSize.width;
    final maxY = viewport.bottom - childSize.height;
    final topLeft = Offset(
      desired.dx.clamp(viewport.left, maxX < viewport.left ? viewport.left : maxX).toDouble(),
      desired.dy.clamp(viewport.top, maxY < viewport.top ? viewport.top : maxY).toDouble(),
    );
    final painted = MatrixUtils.transformPoint(follower, paintAnchor);
    return _unitTransform(follower, paintAnchor, topLeft - painted);
  }

  @override
  void applyTransform(Layer? child, Matrix4 transform) {
    final current = _lastTransform;
    if (current != null) transform.multiply(current);
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, {required bool onlyFirst}) {
    final transform = _lastTransform;
    if (transform == null) return false;
    final inverse = Matrix4.tryInvert(transform);
    if (inverse == null) return false;
    return super.findAnnotations(result, MatrixUtils.transformPoint(inverse, localPosition), onlyFirst: onlyFirst);
  }
}

Matrix4 _unitTransform(Matrix4 follower, Offset anchor, Offset screenOffset) {
  final linear = Matrix4.identity()
    ..setEntry(0, 0, follower.entry(0, 0))
    ..setEntry(0, 1, follower.entry(0, 1))
    ..setEntry(1, 0, follower.entry(1, 0))
    ..setEntry(1, 1, follower.entry(1, 1));
  final inverseLinear = Matrix4.tryInvert(linear);
  if (inverseLinear == null) return Matrix4.identity();
  return Matrix4.identity()
    ..translateByDouble(anchor.dx, anchor.dy, 0.0, 1.0)
    ..multiply(inverseLinear)
    ..translateByDouble(screenOffset.dx, screenOffset.dy, 0.0, 1.0)
    ..translateByDouble(-anchor.dx, -anchor.dy, 0.0, 1.0);
}

Matrix4? _layerToLayerTransform(ContainerLayer source, ContainerLayer target) {
  final forwardLayers = <ContainerLayer?>[source];
  final inverseLayers = <ContainerLayer?>[target];
  final ancestor = _pathsToCommonAncestor(source, target, forwardLayers, inverseLayers);
  if (ancestor == null) return null;
  final forward = _collectTransformForLayerChain(forwardLayers);
  final inverse = _collectTransformForLayerChain(inverseLayers);
  if (inverse.invert() == 0.0) return null;
  inverse.multiply(forward);
  return inverse;
}

Matrix4 _collectTransformForLayerChain(List<ContainerLayer?> layers) {
  final result = Matrix4.identity();
  for (var index = layers.length - 1; index > 0; index--) {
    layers[index]?.applyTransform(layers[index - 1], result);
  }
  return result;
}

Layer? _pathsToCommonAncestor(Layer? a, Layer? b, List<ContainerLayer?> ancestorsA, List<ContainerLayer?> ancestorsB) {
  if (a == null || b == null) return null;
  if (identical(a, b)) return a;
  if (a.depth < b.depth) {
    ancestorsB.add(b.parent);
    return _pathsToCommonAncestor(a, b.parent, ancestorsA, ancestorsB);
  }
  if (a.depth > b.depth) {
    ancestorsA.add(a.parent);
    return _pathsToCommonAncestor(a.parent, b, ancestorsA, ancestorsB);
  }
  ancestorsA.add(a.parent);
  ancestorsB.add(b.parent);
  return _pathsToCommonAncestor(a.parent, b.parent, ancestorsA, ancestorsB);
}
