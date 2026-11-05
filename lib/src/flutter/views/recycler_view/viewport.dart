part of 'index.dart';

class _RecyclerViewport extends RenderObjectWidget {
  const _RecyclerViewport({
    required this.state,
    required this.offset,
    required this.axisDirection,
    required this.refreshRate,
  });
  final _RecyclerViewState state;
  final ViewportOffset offset;
  final AxisDirection axisDirection;
  final double refreshRate;

  @override
  _RecyclerViewportElement createElement() => _RecyclerViewportElement(this);

  @override
  _RecyclerViewportRenderBox createRenderObject(BuildContext context) =>
      _RecyclerViewportRenderBox(context as _RecyclerViewportElement, offset, axisDirection, refreshRate);

  @override
  void updateRenderObject(BuildContext context, _RecyclerViewportRenderBox renderObject) {
    renderObject
      ..offset = offset
      ..axisDirection = axisDirection
      ..refreshRate = refreshRate;
  }
}

class _RecyclerParentData extends ContainerBoxParentData<RenderBox> {
  ViewHolder? holder;
  double logicalStart = 0;
  double extent = 0;
  bool visible = false;
}

class _Anchor {
  _Anchor(this.holder, this.relativeStart);
  final ViewHolder holder;
  final double relativeStart;
}

class _RecyclerViewportElement extends RenderObjectElement {
  _RecyclerViewportElement(_RecyclerViewport super.widget);

  final Map<ViewHolder, Element> _children = {};
  final Map<int, ViewHolder> _active = {};
  final List<ViewHolder> _cached = [];
  final Set<ViewHolder> _retained = {};
  late _ExtentIndex _extents;
  _Anchor? _anchor;
  bool _computingLayout = false;
  bool _pendingUpdates = false;
  bool _fullChange = false;
  bool _prefetchScheduled = false;
  bool _alive = true;
  double _scrollDelta = 0;
  int _generation = 0;

  _RecyclerViewState get _state => (widget as _RecyclerViewport).state;
  Adapter? get _adapter => _state._adapter;
  RecycledViewPool get _pool => _state._pool;

  @override
  _RecyclerViewportRenderBox get renderObject => super.renderObject as _RecyclerViewportRenderBox;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _state._element = this;
    _extents = _ExtentIndex(_adapter);
  }

  @override
  void update(covariant _RecyclerViewport newWidget) {
    final oldState = _state;
    super.update(newWidget);
    if (!identical(oldState, _state)) {
      oldState._element = null;
      _state._element = this;
    }
    renderObject.markNeedsLayout();
  }

  @override
  void performRebuild() {
    super.performRebuild();
    renderObject.markNeedsLayout();
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    for (final child in _children.values.toList(growable: false)) {
      visitor(child);
    }
  }

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    for (final entry in _children.entries) {
      if (entry.key._attached) visitor(entry.value);
    }
  }

  @override
  void insertRenderObjectChild(RenderBox child, ViewHolder slot) {
    renderObject.insert(child, after: renderObject.lastChild);
    (child.parentData! as _RecyclerParentData).holder = slot;
  }

  @override
  void moveRenderObjectChild(RenderBox child, Object? oldSlot, Object? newSlot) {}

  @override
  void removeRenderObjectChild(RenderBox child, Object? slot) => renderObject.remove(child);

  @override
  void forgetChild(Element child) {
    final holder = child.slot! as ViewHolder;
    _children.remove(holder);
    _active.removeWhere((_, value) => identical(value, holder));
    _cached.remove(holder);
    _retained.remove(holder);
    if (identical(holder._owner, this)) holder._owner = null;
    super.forgetChild(child);
  }

  Widget _host(ViewHolder holder, bool visible) => TickerMode(
    key: holder._key,
    enabled: visible,
    child: ExcludeFocus(
      excluding: !visible,
      child: RepaintBoundary(child: holder.itemView),
    ),
  );

  void _updateHolder(ViewHolder holder, {required bool visible, int? bindPosition}) {
    owner!.buildScope(this, () {
      if (bindPosition != null) _adapter!.bindViewHolder(holder, bindPosition);
      final child = updateChild(_children[holder], _host(holder, visible), holder);
      if (child != null) _children[holder] = child;
    });
  }

  RenderBox _box(ViewHolder holder) => _children[holder]!.renderObject! as RenderBox;

  void _detachForTransfer(ViewHolder holder) {
    renderObject.markNeedsLayout();
    _active.removeWhere((_, value) => identical(value, holder));
    _cached.remove(holder);
    _retained.remove(holder);
    owner!.buildScope(this, () {
      final child = _children.remove(holder);
      if (child != null) updateChild(child, null, holder);
    });
    holder._owner = null;
  }

  void _discardHolder(ViewHolder holder) {
    if (!_alive || !identical(holder._owner, this)) return;
    if (holder._attached) {
      holder._bindingAdapter?.onViewDetachedFromWindow(holder);
      holder._attached = false;
    }
    _pool._remove(holder);
    _detachForTransfer(holder);
    holder._resetInternal();
  }

  void _putInPool(ViewHolder holder) {
    holder._bindingAdapter?.onViewRecycled(holder);
    _pool.putRecycledView(holder);
  }

  void _retire(ViewHolder holder, {bool allowCache = true}) {
    _active.removeWhere((_, value) => identical(value, holder));
    if (holder._attached) {
      holder._bindingAdapter?.onViewDetachedFromWindow(holder);
      holder._attached = false;
    }
    if (_children.containsKey(holder)) {
      (_box(holder).parentData! as _RecyclerParentData).visible = false;
      _updateHolder(holder, visible: false);
    }
    if (!holder.isRecyclable()) {
      _retained.add(holder);
      return;
    }
    if (allowCache &&
        holder._bound &&
        !holder._invalid &&
        !holder._removed &&
        !holder._needsBind &&
        _state._config.cacheSize > 0) {
      if (!_cached.contains(holder)) _cached.add(holder);
      _trimCache();
    } else {
      _cached.remove(holder);
      _putInPool(holder);
    }
  }

  void _trimCache() {
    while (_cached.length > _state._config.cacheSize) {
      _putInPool(_cached.removeAt(0));
    }
  }

  ViewHolder? _obtainAndLayout(int position, BoxConstraints constraints, {required bool visible, int? deadline}) {
    final adapter = _adapter!;
    final type = adapter.getItemViewType(position);
    var holder = _active[position];
    if (holder != null && (holder._itemViewType != type || holder._removed || holder._invalid)) {
      _retire(holder, allowCache: false);
      holder = null;
    }
    if (holder == null) {
      final index = _cached.indexWhere(
        (candidate) =>
            candidate._position == position &&
            candidate._itemViewType == type &&
            !candidate._invalid &&
            !candidate._removed,
      );
      if (index >= 0) holder = _cached.removeAt(index);
    }
    final needsBinding = holder == null || holder._needsBind || !holder._bound;
    if (deadline != null && needsBinding && !_pool._willBindInTime(type, _clock.elapsedMicroseconds, deadline)) {
      if (holder != null && !_cached.contains(holder)) _cached.add(holder);
      return null;
    }
    var created = false;
    var createCallbackUs = 0;
    if (holder == null) {
      holder = _pool.getRecycledView(type);
      if (holder == null) {
        if (deadline != null && !_pool._willCreateInTime(type, _clock.elapsedMicroseconds, deadline)) return null;
        final costs = _pool._dataForType(type);
        if (deadline != null &&
            _clock.elapsedMicroseconds + costs.createRunningAverageUs + costs.bindRunningAverageUs >= deadline) {
          return null;
        }
        final start = _clock.elapsedMicroseconds;
        holder = developer.Timeline.timeSync(
          'RecyclerView.create',
          () => adapter.createViewHolder(_state.widget, type),
        );
        createCallbackUs = _clock.elapsedMicroseconds - start;
        created = true;
      }
      final available = holder!;
      if (available._owner != null && !identical(available._owner, this)) {
        available._owner!._detachForTransfer(available);
      }
      available._owner = this;
    }
    final target = holder;
    final start = _clock.elapsedMicroseconds;
    final bind = target._needsBind || !target._bound || target._position != position;
    var bindCallbackUs = 0;
    developer.Timeline.timeSync(created ? 'RecyclerView.mount' : 'RecyclerView.bind', () {
      // bind 与真正的 Element 构建在同一 buildScope 中完成，成本包含延迟发生的 Widget 工作。
      owner!.buildScope(this, () {
        if (bind) {
          final bindStart = _clock.elapsedMicroseconds;
          adapter.bindViewHolder(target, position);
          bindCallbackUs = _clock.elapsedMicroseconds - bindStart;
        }
        final child = updateChild(_children[target], _host(target, visible), target);
        if (child != null) _children[target] = child;
      });
      _box(target).layout(constraints, parentUsesSize: true);
    });
    final elapsed = _clock.elapsedMicroseconds - start;
    if (created) _pool._factorInCreateTime(type, createCallbackUs + elapsed - bindCallbackUs);
    if (bind) _pool._factorInBindTime(type, created ? bindCallbackUs : elapsed);
    if (visible) {
      _active[position] = target;
      if (!target._attached) {
        target._attached = true;
        adapter.onViewAttachedToWindow(target);
      }
      target
        .._layoutPosition = position
        .._oldPosition = RecyclerView.NO_POSITION;
    }
    return target;
  }

  void _captureAnchor() {
    if (_anchor != null || _active.isEmpty) return;
    final candidates = _active.values.where((holder) => !holder._removed).toList()
      ..sort((a, b) => a._position.compareTo(b._position));
    if (candidates.isNotEmpty) {
      final holder = candidates.first;
      final data = _box(holder).parentData! as _RecyclerParentData;
      _anchor = _Anchor(holder, data.logicalStart - renderObject.offset.pixels);
    }
  }

  void _beforeUpdate() {
    if (_computingLayout) throw StateError('不能在 RecyclerView 计算布局期间发送适配器通知。');
    _captureAnchor();
    _pendingUpdates = true;
    _generation++;
  }

  Iterable<ViewHolder> get _boundHolders => _children.keys.where((holder) => holder._bound);

  void _dataChanged() {
    _beforeUpdate();
    _fullChange = true;
    for (final holder in _boundHolders) {
      holder
        .._invalid = true
        .._needsBind = true
        .._fullUpdate = true;
    }
    _extents = _ExtentIndex(_adapter);
    renderObject.markNeedsLayout();
  }

  void _itemsChanged(int start, int count, Object? payload) {
    RangeError.checkValidRange(start, start + count, _extents.length);
    _beforeUpdate();
    for (final holder in _boundHolders) {
      if (holder._position >= start && holder._position < start + count) holder._addChangePayload(payload);
    }
    _extents.invalidate(start, count, _adapter!);
    renderObject.markNeedsLayout();
  }

  void _itemsInserted(int start, int count) {
    RangeError.checkValueInInterval(start, 0, _extents.length);
    if (count < 0) throw ArgumentError.value(count, 'count');
    _beforeUpdate();
    for (final holder in _boundHolders) {
      if (holder._position >= start) {
        if (holder._oldPosition == -1) holder._oldPosition = holder._layoutPosition;
        holder._position += count;
      }
    }
    _extents.insert(start, count, _adapter!);
    _rekeyActive();
    renderObject.markNeedsLayout();
  }

  void _itemsRemoved(int start, int count) {
    RangeError.checkValidRange(start, start + count, _extents.length);
    _beforeUpdate();
    for (final holder in _boundHolders) {
      if (holder._position >= start && holder._position < start + count) {
        holder._removed = true;
      } else if (holder._position >= start + count) {
        if (holder._oldPosition == -1) holder._oldPosition = holder._layoutPosition;
        holder._position -= count;
      }
    }
    _extents.remove(start, count, _adapter!);
    _rekeyActive();
    renderObject.markNeedsLayout();
  }

  void _itemMoved(int from, int to) {
    RangeError.checkValidIndex(from, List.filled(_extents.length, null));
    RangeError.checkValidIndex(to, List.filled(_extents.length, null));
    _beforeUpdate();
    for (final holder in _boundHolders) {
      final old = holder._position;
      if (old == from) {
        holder._position = to;
      } else if (from < to && old > from && old <= to) {
        holder._position--;
      } else if (to < from && old >= to && old < from) {
        holder._position++;
      }
      if (old != holder._position && holder._oldPosition == -1) holder._oldPosition = holder._layoutPosition;
    }
    _extents.move(from, to, _adapter!);
    _rekeyActive();
    renderObject.markNeedsLayout();
  }

  void _rekeyActive() {
    final holders = _active.values.toList(growable: false);
    _active.clear();
    for (final holder in holders) {
      if (!holder._removed) _active[holder._position] = holder;
    }
  }

  void _resolveFullChange() {
    if (!_fullChange) return;
    _fullChange = false;
    final adapter = _adapter!;
    final positions = <int, int>{};
    if (adapter.hasStableIds()) {
      for (var i = 0; i < adapter.getItemCount(); i++) {
        final id = adapter.getItemId(i);
        if (positions.containsKey(id)) throw StateError('稳定标识必须在适配器中唯一：$id');
        positions[id] = i;
      }
    }
    for (final holder in _boundHolders.toList(growable: false)) {
      final position = positions[holder._itemId];
      if (position == null || adapter.getItemViewType(position) != holder._itemViewType) {
        _cached.remove(holder);
        _retire(holder, allowCache: false);
      } else {
        holder
          .._position = position
          .._invalid = false;
      }
    }
    _rekeyActive();
  }

  void _replaceAdapter(Adapter? old, {required bool keepPool}) {
    _generation++;
    for (final holder in _children.keys.toList(growable: false)) {
      if (keepPool) {
        if (!_pool._contains(holder)) _retire(holder, allowCache: false);
      } else if (!keepPool) {
        if (holder._attached) holder._bindingAdapter?.onViewDetachedFromWindow(holder);
        holder._bindingAdapter?.onViewRecycled(holder);
        holder._attached = false;
        _pool._remove(holder);
        _discardHolder(holder);
      }
    }
    _active.clear();
    _cached.clear();
    if (!keepPool) _retained.clear();
    _anchor = null;
    _fullChange = false;
    _pendingUpdates = false;
    _extents = _ExtentIndex(_adapter);
    renderObject.markNeedsLayout();
  }

  void _replacePool(RecycledViewPool old) {
    for (final holder in old._holders.where((holder) => identical(holder._owner, this)).toList()) {
      old._remove(holder);
      _discardHolder(holder);
    }
  }

  void _resetGeometry() {
    if (!_alive) return;
    _captureAnchor();
    _extents = _ExtentIndex(_adapter);
    renderObject.markNeedsLayout();
  }

  double _offsetForPosition(int position, double relative) =>
      _extents.prefix(position.clamp(0, _extents.length)) + renderObject.leadingPadding - relative;

  ViewHolder? _holderForAdapterPosition(int position) =>
      _findHolder((holder) => holder.getBindingAdapterPosition() == position);

  ViewHolder? _findHolder(bool Function(ViewHolder) test) {
    for (final holder in _active.values) {
      if (holder._attached && !holder._removed && test(holder)) return holder;
    }
    return null;
  }

  int _findVisiblePosition({required bool first, required bool complete}) {
    final positions = <int>[];
    final pixels = renderObject.offset.pixels;
    for (final holder in _active.values) {
      if (holder._removed) continue;
      final data = _box(holder).parentData! as _RecyclerParentData;
      final start = data.logicalStart - pixels;
      if (!complete ||
          (start >= renderObject.leadingPadding - .01 &&
              start + data.extent <= renderObject.mainExtent - renderObject.trailingPadding + .01)) {
        positions.add(holder._layoutPosition);
      }
    }
    if (positions.isEmpty) return RecyclerView.NO_POSITION;
    return first ? positions.reduce(math.min) : positions.reduce(math.max);
  }

  void _layoutContents() {
    _computingLayout = true;
    try {
      developer.Timeline.timeSync('RecyclerView.layout', _layoutLinear);
    } finally {
      _computingLayout = false;
    }
  }

  void _layoutLinear() {
    final render = renderObject;
    final adapter = _adapter;
    final manager = _state._manager;
    final count = adapter?.getItemCount() ?? 0;
    if (count != _extents.length) {
      // 数据变更必须通知；首次挂载或尚未连接适配器时允许建立初始索引。
      if (_extents.length != 0) throw StateError('适配器数量改变后必须调用对应的 notify 方法。');
      _extents = _ExtentIndex(adapter);
    }
    if (count == 0 || manager == null) {
      for (final holder in _children.keys.where((holder) => holder._attached).toList()) {
        _retire(holder, allowCache: false);
      }
      for (final holder in _cached.toList()) {
        _retire(holder, allowCache: false);
      }
      render._correctOffset(0);
      render.offset.applyContentDimensions(0, 0);
      _pendingUpdates = false;
      return;
    }
    _resolveFullChange();
    _trimCache();
    for (final holder in _retained.toList()) {
      if (holder.isRecyclable()) {
        _retained.remove(holder);
        _putInPool(holder);
      }
    }
    final constraints = render.childConstraints;
    final request = _state._config.pendingScroll;
    final stackToEnd = _state._initialLayout && manager._stackFromEnd && request == null && _anchor == null;
    _state._config.pendingScroll = null;
    var pixels = render.offset.pixels;
    if (request != null) {
      final position = request.position.clamp(0, count - 1);
      pixels = _offsetForPosition(position, render.leadingPadding + (request.offset ?? 0));
      _anchor = null;
    } else if (_anchor case final anchor?) {
      if (anchor.holder._bound && !anchor.holder._removed && anchor.holder._position >= 0) {
        pixels = _offsetForPosition(anchor.holder._position, anchor.relativeStart);
      }
      _anchor = null;
    } else if (_state._initialLayout && manager._stackFromEnd) {
      pixels = math.max(0, _extents.total + render.leadingPadding + render.trailingPadding - render.mainExtent);
    }
    _state._initialLayout = false;
    pixels = math.max(0, pixels);
    render._correctOffset(pixels);

    for (var attempt = 0; attempt < 4; attempt++) {
      pixels = render.offset.pixels;
      final first = _extents.indexAt(math.max(0, pixels - render.leadingPadding));
      final relative = _extents.prefix(first) + render.leadingPadding - pixels;
      final oldAttached = _children.keys.where((holder) => holder._attached).toList(growable: false);
      for (final holder in oldAttached) {
        final position = holder._position;
        if (holder._removed ||
            position < first ||
            position >= count ||
            _extents.prefix(position) + render.leadingPadding >= pixels + render.mainExtent) {
          _retire(holder, allowCache: !holder._removed && !holder._invalid);
        }
      }
      final wanted = <ViewHolder>{};
      for (var position = first; position < count; position++) {
        var start = _extents.prefix(position) + render.leadingPadding;
        if (position != first && start >= render.offset.pixels + render.mainExtent - render.trailingPadding) break;
        final holder = _obtainAndLayout(position, constraints, visible: true)!;
        final box = _box(holder);
        final extent = render.vertical ? box.size.height : box.size.width;
        _extents.measure(position, extent);
        // 新测量可修正同模板的估算高度，但首个可见条目必须留在同一屏幕位置。
        final anchoredPixels = math.max(0.0, _extents.prefix(first) + render.leadingPadding - relative);
        render._correctOffset(anchoredPixels);
        start = _extents.prefix(position) + render.leadingPadding;
        final data = box.parentData! as _RecyclerParentData;
        data
          ..logicalStart = start
          ..extent = extent
          ..visible = true;
        wanted.add(holder);
      }
      for (final holder in _children.keys.where((holder) => holder._attached).toList()) {
        if (!wanted.contains(holder)) _retire(holder);
      }
      final maxScroll = math.max(
        0.0,
        _extents.total + render.leadingPadding + render.trailingPadding - render.mainExtent,
      );
      var targetPixels = render.offset.pixels.clamp(0.0, maxScroll);
      if (request != null) {
        // 未知高度在本轮测量后可能改变末端，重新解析定位目标并先夹紧，避免触发越界弹簧。
        targetPixels = _offsetForPosition(
          request.position.clamp(0, count - 1),
          render.leadingPadding + (request.offset ?? 0),
        ).clamp(0.0, maxScroll);
      } else if (stackToEnd) {
        targetPixels = maxScroll;
      }
      final adjusted = (targetPixels - render.offset.pixels).abs() > .01;
      if (adjusted) render._correctOffset(targetPixels);
      final accepted = render.offset.applyContentDimensions(0, maxScroll);
      if (accepted && !adjusted) break;
    }
    for (final holder in _active.values) {
      final data = _box(holder).parentData! as _RecyclerParentData;
      final shift = manager._stackFromEnd
          ? math.max(0.0, render.mainExtent - render.leadingPadding - render.trailingPadding - _extents.total)
          : 0.0;
      data.logicalStart = _extents.prefix(holder._position) + render.leadingPadding + shift;
      final logical = data.logicalStart - render.offset.pixels;
      final main = render.reversed ? render.mainExtent - logical - data.extent : logical;
      data.offset = render.vertical ? Offset(render.crossPadding, main) : Offset(main, render.crossPadding);
    }
    _pendingUpdates = false;
    render.markNeedsSemanticsUpdate();
    _schedulePrefetch();
  }

  void _schedulePrefetch() {
    final manager = _state._manager;
    if (_prefetchScheduled ||
        manager == null ||
        !manager.isItemPrefetchEnabled() ||
        manager._initialPrefetchItemCount == 0 ||
        _state._config.cacheSize == 0 ||
        _active.isEmpty) {
      return;
    }
    _prefetchScheduled = true;
    final generation = _generation;
    final rate = renderObject.refreshRate > 0 ? renderObject.refreshRate : 60.0;
    final intervalUs = (1000000 / rate).round();
    // 引擎原始帧时间和 Timeline 使用单调时钟；不匹配时只给保守的 1ms 预算。
    final age = developer.Timeline.now - SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
    final remaining = age >= 0 && age < 1000000 ? intervalUs - age - 2000 : 1000;
    final deadline = _clock.elapsedMicroseconds + math.max(0, remaining).toInt();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _prefetchScheduled = false;
      if (!_alive ||
          generation != _generation ||
          !identical(manager, _state._manager) ||
          !manager.isItemPrefetchEnabled() ||
          _clock.elapsedMicroseconds >= deadline ||
          _active.isEmpty) {
        return;
      }
      final direction = _scrollDelta < 0 ? -1 : 1;
      final edge = direction > 0 ? _active.keys.reduce(math.max) : _active.keys.reduce(math.min);
      final count = math.min(manager._initialPrefetchItemCount, _state._config.cacheSize);
      for (var distance = 1; distance <= count; distance++) {
        final position = edge + direction * distance;
        if (position < 0 || position >= _extents.length || _clock.elapsedMicroseconds >= deadline) break;
        if (_active.containsKey(position) || _cached.any((holder) => holder._position == position)) continue;
        _computingLayout = true;
        try {
          developer.Timeline.timeSync('RecyclerView.prefetch', () {
            final holder = _obtainAndLayout(
              position,
              renderObject.childConstraints,
              visible: false,
              deadline: deadline,
            );
            if (holder != null) {
              // 预取也完成 mount/build/layout，随后保留绑定，下一帧直接接入可见布局。
              if (!_cached.contains(holder)) _cached.add(holder);
              _trimCache();
            }
          });
        } finally {
          _computingLayout = false;
        }
      }
    });
  }

  @override
  void unmount() {
    _alive = false;
    _generation++;
    for (final holder in _children.keys) {
      _pool._remove(holder);
      if (holder._attached) holder._bindingAdapter?.onViewDetachedFromWindow(holder);
      holder._bindingAdapter?.onViewRecycled(holder);
      holder
        .._owner = null
        .._attached = false;
      holder._resetInternal();
    }
    _state._element = null;
    super.unmount();
  }
}

class _RecyclerViewportRenderBox extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _RecyclerParentData>
    implements RenderAbstractViewport {
  _RecyclerViewportRenderBox(this.element, this._offset, this._axisDirection, this.refreshRate);
  final _RecyclerViewportElement element;
  ViewportOffset _offset;
  AxisDirection _axisDirection;
  double refreshRate;
  double? _previousCrossExtent;

  ViewportOffset get offset => _offset;

  void _correctOffset(double pixels) {
    final correction = pixels - _offset.pixels;
    // correctBy(0) 也会触发新尺寸通知并重启惯性模拟，稳定几何不能提交空修正。
    if (correction != 0) _offset.correctBy(correction);
  }

  set offset(ViewportOffset value) {
    if (identical(value, _offset)) return;
    if (attached) _offset.removeListener(markNeedsLayout);
    _offset = value;
    if (attached) _offset.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  AxisDirection get axisDirection => _axisDirection;
  set axisDirection(AxisDirection value) {
    if (_axisDirection == value) return;
    _axisDirection = value;
    _previousCrossExtent = null;
    markNeedsLayout();
  }

  bool get vertical => axisDirectionToAxis(axisDirection) == Axis.vertical;
  bool get reversed => axisDirectionIsReversed(axisDirection);
  double get mainExtent => vertical ? size.height : size.width;
  EdgeInsets get padding => element._state._config.padding;
  double get leadingPadding =>
      vertical ? (reversed ? padding.bottom : padding.top) : (reversed ? padding.right : padding.left);
  double get trailingPadding =>
      vertical ? (reversed ? padding.top : padding.bottom) : (reversed ? padding.left : padding.right);
  double get crossPadding => vertical ? padding.left : padding.top;
  BoxConstraints get childConstraints {
    final cross = math.max(0.0, vertical ? size.width - padding.horizontal : size.height - padding.vertical);
    return vertical ? BoxConstraints.tightFor(width: cross) : BoxConstraints.tightFor(height: cross);
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RecyclerParentData) child.parentData = _RecyclerParentData();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _offset.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _offset.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void performLayout() {
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      throw FlutterError('RecyclerView 需要父级提供有限的宽度和高度。');
    }
    size = constraints.biggest;
    _offset.applyViewportDimension(mainExtent);
    final cross = vertical ? size.width : size.height;
    invokeLayoutCallback((BoxConstraints _) {
      if (_previousCrossExtent != null && _previousCrossExtent != cross) element._resetGeometry();
      _previousCrossExtent = cross;
      element._layoutContents();
    });
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushClipRect(needsCompositing, offset, Offset.zero & size, (context, offset) {
      var child = firstChild;
      while (child != null) {
        final data = child.parentData! as _RecyclerParentData;
        if (data.visible) context.paintChild(child, offset + data.offset);
        child = data.nextSibling;
      }
    });
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    while (child != null) {
      final target = child;
      final data = child.parentData! as _RecyclerParentData;
      if (data.visible &&
          result.addWithPaintOffset(
            offset: data.offset,
            position: position,
            hitTest: (result, transformed) => target.hitTest(result, position: transformed),
          )) {
        return true;
      }
      child = data.previousSibling;
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final data = child.parentData! as _RecyclerParentData;
    transform.translateByDouble(data.offset.dx, data.offset.dy, 0, 1);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _RecyclerParentData;
      if (data.visible) visitor(child);
      child = data.nextSibling;
    }
  }

  @override
  Rect? describeSemanticsClip(RenderObject? child) => Offset.zero & size;

  @override
  RevealedOffset getOffsetToReveal(RenderObject target, double alignment, {Rect? rect, Axis? axis}) {
    final transformed = MatrixUtils.transformRect(target.getTransformTo(this), rect ?? target.paintBounds);
    final start = vertical ? transformed.top : transformed.left;
    final extent = vertical ? transformed.height : transformed.width;
    final physicalDelta = start - (mainExtent - extent) * alignment;
    final delta = reversed ? -physicalDelta : physicalDelta;
    return RevealedOffset(
      offset: offset.pixels + delta,
      rect: transformed.shift(vertical ? Offset(0, -physicalDelta) : Offset(-physicalDelta, 0)),
    );
  }

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    if (descendant == null) {
      super.showOnScreen(descendant: descendant, rect: rect, duration: duration, curve: curve);
      return;
    }
    final revealed = getOffsetToReveal(descendant, 0, rect: rect);
    offset.moveTo(math.max(0, revealed.offset), duration: duration, curve: curve);
  }
}

class _ExtentIndex {
  _ExtentIndex(Adapter? adapter) {
    _sizes = List<double?>.filled(adapter?.getItemCount() ?? 0, null, growable: true);
    _rebuild(adapter);
  }
  late List<double?> _sizes;
  List<int> _types = [];
  List<double> _values = [];
  List<double> _tree = [];
  final Map<int, double> _estimates = {};

  int get length => _sizes.length;
  double get total => prefix(length);

  void _rebuild(Adapter? adapter) {
    _types = List.generate(length, (index) => adapter!.getItemViewType(index));
    _values = List.generate(length, (index) => _sizes[index] ?? _estimates[_types[index]] ?? 100.0);
    _tree = List.filled(length + 1, 0.0);
    for (var i = 0; i < length; i++) {
      _add(i, _values[i]);
    }
  }

  void _add(int index, double delta) {
    for (var i = index + 1; i < _tree.length; i += i & -i) {
      _tree[i] += delta;
    }
  }

  double prefix(int end) {
    var sum = 0.0;
    for (var i = end; i > 0; i -= i & -i) {
      sum += _tree[i];
    }
    return sum;
  }

  int indexAt(double offset) {
    if (length == 0) return 0;
    var index = 0;
    var sum = 0.0;
    var bit = 1;
    while (bit * 2 <= length) {
      bit *= 2;
    }
    while (bit != 0) {
      final next = index + bit;
      if (next <= length && sum + _tree[next] <= offset) {
        index = next;
        sum += _tree[next];
      }
      bit ~/= 2;
    }
    return math.min(index, length - 1);
  }

  void measure(int index, double extent) {
    if (!extent.isFinite || extent < 0) throw StateError('条目布局尺寸必须是有限的非负数。');
    final type = _types[index];
    final firstOfType = !_estimates.containsKey(type);
    _estimates.putIfAbsent(type, () => extent);
    _sizes[index] = extent;
    _add(index, extent - _values[index]);
    _values[index] = extent;
    if (firstOfType) {
      for (var i = 0; i < length; i++) {
        if (_sizes[i] == null && _types[i] == type) {
          _add(i, extent - _values[i]);
          _values[i] = extent;
        }
      }
    }
  }

  void invalidate(int start, int count, Adapter adapter) {
    for (var i = start; i < start + count; i++) {
      _sizes[i] = null;
    }
    _rebuild(adapter);
  }

  void insert(int start, int count, Adapter adapter) {
    _sizes.insertAll(start, List<double?>.filled(count, null));
    _rebuild(adapter);
  }

  void remove(int start, int count, Adapter adapter) {
    _sizes.removeRange(start, start + count);
    _rebuild(adapter);
  }

  void move(int from, int to, Adapter adapter) {
    _sizes.insert(to, _sizes.removeAt(from));
    _rebuild(adapter);
  }
}
