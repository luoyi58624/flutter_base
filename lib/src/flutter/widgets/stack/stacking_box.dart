part of 'index.dart';

/// Stack、滚动视口与弹层共用的 child 层序及溢出命中基座，不规定布局算法。
///
/// 默认 sibling 链已按层序排列时不分配排序列表；滚动宿主提供稳定 source
/// order 后，插入、删除和单项层级更新只维护相邻关系，不扫描整个挂载窗口。
abstract class RenderStackingBox<P extends ElStackParentData> extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, P>, RenderBoxContainerDefaultsMixin<RenderBox, P>, ElOverflowHitBounds
    implements OverflowHitTestHost {
  late final _LayerOrderCache<RenderBox> _layerOrder = _LayerOrderCache<RenderBox>(
    nextSiblingOf: (child) => (child.parentData! as ElStackParentData).nextSibling,
    nodeOf: (child) => child.parentData! as ElStackParentData,
    compare: hasCustomStackOrder ? compareStackChildren : null,
  );
  late final OverflowHitProxyRegistry _overflowHitProxies = OverflowHitProxyRegistry(this);
  int _unorderedEdges = 0;
  int _hiddenStackChildren = 0;
  bool _stackMetadataDirty = false;

  /// 虚拟挂载宿主覆写为 true，并通过 setChildStackSourceOrder 提供稳定源序。
  @protected
  bool get stackSourceOrderIsExternal => false;

  /// 宿主需要 owner 路径等复合层序时覆写，普通 Stack/Scroll 不创建比较闭包。
  @protected
  bool get hasCustomStackOrder => false;

  /// 比较同一宿主中的两个子节点；增量邻居检查与最终排序共用此规则。
  @protected
  int compareStackChildren(RenderBox a, RenderBox b) =>
      _compareLayerOrderNodes(a.parentData! as ElStackParentData, b.parentData! as ElStackParentData);

  /// 负层级统一隐藏，宿主可进一步过滤显式 hidden 或隐藏 owner 的后代。
  @protected
  bool isStackChildVisible(RenderBox child) => (child.parentData! as ElStackParentData).zIndex >= 0;

  /// 当前是否存在负层级 child；默认命中快路径据此避免误命中隐藏成员。
  bool get hasHiddenStackChildren {
    _ensureStackMetadata();
    return _hiddenStackChildren != 0;
  }

  int _edge(RenderBox? left, RenderBox? right) {
    if (left == null || right == null) return 0;
    return compareStackChildren(left, right) > 0 ? 1 : 0;
  }

  void _ensureStackMetadata() {
    if (!_stackMetadataDirty) return;
    _stackMetadataDirty = false;
    _unorderedEdges = 0;
    _hiddenStackChildren = 0;
    var index = 0;
    RenderBox? previous;
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as ElStackParentData;
      if (!stackSourceOrderIsExternal) data.mountOrder = index++;
      _unorderedEdges += _edge(previous, child);
      if (data.zIndex < 0) _hiddenStackChildren++;
      previous = child;
      child = data.nextSibling;
    }
  }

  @override
  void insert(RenderBox child, {RenderBox? after}) {
    final incremental = stackSourceOrderIsExternal && !_stackMetadataDirty;
    final next = after == null ? firstChild : (after.parentData! as ElStackParentData).nextSibling;
    final removedEdge = incremental ? _edge(after, next) : 0;
    super.insert(child, after: after);
    if (incremental) {
      _unorderedEdges += _edge(after, child) + _edge(child, next) - removedEdge;
      if ((child.parentData! as ElStackParentData).zIndex < 0) _hiddenStackChildren++;
    } else {
      _stackMetadataDirty = true;
    }
    _layerOrder.invalidate();
  }

  @override
  void remove(RenderBox child) {
    final data = child.parentData! as ElStackParentData;
    final previous = data.previousSibling;
    final next = data.nextSibling;
    if (stackSourceOrderIsExternal && !_stackMetadataDirty) {
      _unorderedEdges += _edge(previous, next) - _edge(previous, child) - _edge(child, next);
      if (data.zIndex < 0) _hiddenStackChildren--;
    } else {
      _stackMetadataDirty = true;
    }
    super.remove(child);
    _layerOrder.invalidate();
  }

  @override
  void move(RenderBox child, {RenderBox? after}) {
    final data = child.parentData! as ElStackParentData;
    if (identical(data.previousSibling, after)) return;
    final previous = data.previousSibling;
    final next = data.nextSibling;
    final incremental = stackSourceOrderIsExternal && !_stackMetadataDirty;
    if (incremental) _unorderedEdges += _edge(previous, next) - _edge(previous, child) - _edge(child, next);
    final newNext = after == null ? firstChild : (after.parentData! as ElStackParentData).nextSibling;
    final removedEdge = incremental ? _edge(after, newNext) : 0;
    super.move(child, after: after);
    if (incremental) {
      _unorderedEdges += _edge(after, child) + _edge(child, newNext) - removedEdge;
    } else {
      _stackMetadataDirty = true;
    }
    _layerOrder.invalidate();
  }

  @override
  void removeAll() {
    // ContainerRenderObjectMixin.removeAll 不经过逐项 remove，必须在断开
    // ParentData 前撤销缓存，避免后续遍历仍访问已经离树的 child。
    _layerOrder.invalidate();
    _unorderedEdges = 0;
    _hiddenStackChildren = 0;
    _stackMetadataDirty = false;
    super.removeAll();
  }

  /// ParentData 已写入新 zIndex 后调用；只刷新必要的 paint/hit/semantics。
  void markChildStackOrderChanged(RenderBox child, {required int oldZIndex}) {
    final data = child.parentData! as ElStackParentData;
    if (data.zIndex == oldZIndex) return;
    if (_stackMetadataDirty) return;
    final wasOrdered = _unorderedEdges == 0;
    final newZIndex = data.zIndex;
    final newEdges = _edge(data.previousSibling, child) + _edge(child, data.nextSibling);
    data.zIndex = oldZIndex;
    final oldEdges = _edge(data.previousSibling, child) + _edge(child, data.nextSibling);
    data.zIndex = newZIndex;
    _unorderedEdges += newEdges - oldEdges;
    final visibilityChanged = (oldZIndex < 0) != (newZIndex < 0);
    if (visibilityChanged) _hiddenStackChildren += newZIndex < 0 ? 1 : -1;
    // 默认序检查 sibling 邻居；已有显式序检查缓存里的邻居。只换数值而
    // 没有越过任何成员，不得让连续阈值更新退化成逐帧全窗口 sort。
    if (_canRetainStackOrder(child, wasOrdered: wasOrdered)) {
      if (visibilityChanged) _markStackPresentationNeedsUpdate();
      return;
    }
    _invalidateStackPresentation(child: child);
  }

  /// 为真实 child 原位更新 source order；不改其 Element/State/布局几何。
  void setChildStackSourceOrder(RenderBox child, int sourceOrder) {
    final data = child.parentData! as ElStackParentData;
    if (data.mountOrder == sourceOrder) return;
    if (_stackMetadataDirty) {
      data.mountOrder = sourceOrder;
      return;
    }
    final wasOrdered = _unorderedEdges == 0;
    final oldEdges = _edge(data.previousSibling, child) + _edge(child, data.nextSibling);
    data.mountOrder = sourceOrder;
    _unorderedEdges += _edge(data.previousSibling, child) + _edge(child, data.nextSibling) - oldEdges;
    if (_canRetainStackOrder(child, wasOrdered: wasOrdered)) return;
    _invalidateStackPresentation(child: child);
  }

  /// 原位更新同层内的激活序，供 sticky 接力使用；不请求布局。
  void setChildStackActivationOrder(RenderBox child, int activationOrder) {
    final data = child.parentData! as ElStackParentData;
    if (data.activationOrder == activationOrder) return;
    if (_stackMetadataDirty) {
      data.activationOrder = activationOrder;
      return;
    }
    final wasOrdered = _unorderedEdges == 0;
    final oldEdges = _edge(data.previousSibling, child) + _edge(child, data.nextSibling);
    data.activationOrder = activationOrder;
    _unorderedEdges += _edge(data.previousSibling, child) + _edge(child, data.nextSibling) - oldEdges;
    if (_canRetainStackOrder(child, wasOrdered: wasOrdered)) return;
    _invalidateStackPresentation(child: child);
  }

  bool _canRetainStackOrder(RenderBox child, {required bool wasOrdered}) {
    if (wasOrdered) return _unorderedEdges == 0;
    // 从显式序回到 sibling 序时撤销显式快照，恢复零分配默认路径。
    return _unorderedEdges != 0 && _layerOrder.canRetainOrderFor(child);
  }

  void _invalidateStackPresentation({RenderBox? child}) {
    if (child != null && _unorderedEdges != 0) {
      _layerOrder.invalidateChild(child);
    } else {
      _layerOrder.invalidate();
    }
    _markStackPresentationNeedsUpdate();
  }

  void _markStackPresentationNeedsUpdate() {
    didChangeStackPresentation();
    markNeedsPaint();
    markHitBoundsDirty();
    markNeedsSemanticsUpdate();
  }

  /// 层序或隐藏资格变化时通知宿主撤销派生呈现缓存，不请求布局。
  @protected
  void didChangeStackPresentation() {}

  /// 标记整组层序失效，首次呈现读取才扫描，合并同帧重复变更。
  void markNeedsPaintOrder() {
    if (_stackMetadataDirty) return;
    _stackMetadataDirty = true;
    _invalidateStackPresentation();
  }

  List<RenderBox>? get _explicitPaintOrder {
    _ensureStackMetadata();
    return _unorderedEdges == 0 ? null : _layerOrder.resolve(firstChild, structurallyOrdered: false);
  }

  /// 同一 stacking context 的唯一显式层序；null 表示直接遍历 sibling 链。
  List<RenderBox>? get explicitStackPaintOrder => _explicitPaintOrder;

  /// 顺序解析次数；默认有序路径不创建列表，也不执行 sort。
  int get debugLayerOrderRebuildCount => _layerOrder.debugRebuildCount;

  /// 当前是否直接使用 child 结构顺序。
  bool get debugUsesDefaultLayerOrder {
    _ensureStackMetadata();
    if (_unorderedEdges == 0) return true;
    _explicitPaintOrder;
    return _layerOrder.usesDefaultOrder;
  }

  /// 测试读取最终可见绘制序，不得用于滚动热路径。
  List<RenderBox> get debugChildrenInPaintOrder {
    final ordered = _explicitPaintOrder;
    if (ordered != null) return List<RenderBox>.unmodifiable(ordered.where(isStackChildVisible));
    final result = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      if (isStackChildVisible(child)) result.add(child);
      child = (child.parentData! as ElStackParentData).nextSibling;
    }
    return List<RenderBox>.unmodifiable(result);
  }

  /// 遍历完整绘制序，保留隐藏成员供宿主执行自己的遮挡与语义过滤。
  @protected
  Iterable<RenderBox> get stackChildrenInPaintOrder sync* {
    final ordered = explicitStackPaintOrder;
    if (ordered != null) {
      yield* ordered;
      return;
    }
    var child = firstChild;
    while (child != null) {
      yield child;
      child = (child.parentData! as ElStackParentData).nextSibling;
    }
  }

  /// 反向遍历同一绘制序，供最上层命中和遮挡判定使用。
  @protected
  Iterable<RenderBox> get stackChildrenInReversePaintOrder sync* {
    final ordered = explicitStackPaintOrder;
    if (ordered != null) {
      yield* ordered.reversed;
      return;
    }
    var child = lastChild;
    while (child != null) {
      yield child;
      child = (child.parentData! as ElStackParentData).previousSibling;
    }
  }

  /// 正序遍历共享层序；布局专属的可见窗口由子类在 visitor 内过滤。
  void visitStackChildrenInPaintOrder(RenderObjectVisitor visitor) {
    final ordered = _explicitPaintOrder;
    if (ordered != null) {
      for (final child in ordered) {
        if (isStackChildVisible(child)) visitor(child);
      }
      return;
    }
    var child = firstChild;
    while (child != null) {
      if (isStackChildVisible(child)) visitor(child);
      child = (child.parentData! as ElStackParentData).nextSibling;
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ElStackParentData) child.parentData = ElStackParentData();
  }

  @override
  void registerOverflowHitTestProxy(RenderBox candidate) {
    _overflowHitProxies.register(candidate);
    markHitBoundsDirty();
  }

  @override
  void unregisterOverflowHitTestProxy(RenderBox candidate) {
    _overflowHitProxies.unregister(candidate);
    markHitBoundsDirty();
  }

  @override
  void markOverflowHitTestProxyDirty(RenderBox candidate) {
    _overflowHitProxies.markDirty(candidate);
    markHitBoundsDirty();
  }

  @override
  void visitOverflowHitTestProxyBounds(void Function(Rect bounds) visitor) => _overflowHitProxies.visitBounds(visitor);

  /// 已登记的跨中间 RenderBox 溢出命中代理数量。
  int get debugOverflowHitProxyCount => _overflowHitProxies.candidateCount;

  /// 溢出命中几何快照版本。
  int get debugOverflowHitGeometryVersion => _overflowHitProxies.geometryVersion;

  /// 绘制前使溢出几何就绪；裁剪视口可延迟到实际命中查询。
  void syncStackOverflowForPaint({bool deferGeometry = false}) {
    if (_overflowHitProxies.syncForPaint(deferGeometry: deferGeometry)) markHitBoundsDirty();
  }

  /// 普通 child 未命中时补测其已登记的溢出子树。
  bool hitTestStackOverflowForChild(BoxHitTestResult result, {required Offset position, required RenderBox child}) =>
      _overflowHitProxies.hitTestForChild(result, position: position, directChild: child);
}
