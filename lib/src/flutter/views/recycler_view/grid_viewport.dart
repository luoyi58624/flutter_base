part of 'index.dart';

extension _MatrixViewport on _RecyclerViewportElement {
  void _matrixDataChanged(int start, int count, {bool full = false, bool structural = false}) {
    if (full) {
      _gridRows = null;
      _staggeredSpans = null;
      return;
    }
    final manager = _state._manager;
    if (structural || manager is GridLayoutManager && manager._spanSizeLookup is! _DefaultSpanSizeLookup) {
      _gridRows = null;
    } else {
      _gridRows?.invalidate(start, count);
    }
    if (_staggeredSpans?.hasExactExtents == true) {
      _staggeredSpans = null;
    } else {
      _staggeredSpans?.invalidateFrom(start, discardAssignments: structural);
    }
  }

  void _ensureMatrix() {
    final manager = _state._manager;
    if (manager is GridLayoutManager) {
      if (_gridRows == null || _gridRows!.count != _extents.length || _gridRows!.spanCount != manager._spanCount) {
        _gridRows = _GridRows(_extents, manager._spanCount, manager._spanSizeLookup);
      }
    } else if (manager is StaggeredGridLayoutManager) {
      final geometry = _staggeredSpans;
      final builder = manager._itemExtentBuilder;
      final cross = builder != null && renderObject.hasSize ? _matrixCrossExtent / manager._spanCount : null;
      if (geometry == null ||
          !identical(geometry.extents, _extents) ||
          geometry.spanCount != manager._spanCount ||
          geometry.itemCrossExtent != cross) {
        if (geometry != null && geometry.itemCrossExtent != cross) _captureAnchor();
        _staggeredSpans = _StaggeredSpans(
          _extents,
          manager._spanCount,
          itemCrossExtent: cross,
          itemExtentBuilder: cross == null ? null : builder,
        );
      }
    }
  }

  double _matrixStart(int position) {
    _ensureMatrix();
    return _state._manager is GridLayoutManager ? _gridRows!.startAt(position) : _staggeredSpans!.startAt(position);
  }

  double get _matrixCrossExtent {
    final render = renderObject;
    final available = render.childConstraints;
    return render.vertical ? available.maxWidth : available.maxHeight;
  }

  BoxConstraints _matrixChildConstraints(int position, {double? mainExtent}) {
    final manager = _state._manager;
    if (manager is! GridLayoutManager && manager is! StaggeredGridLayoutManager) return renderObject.childConstraints;
    _ensureMatrix();
    final spans = manager is GridLayoutManager
        ? manager._spanCount
        : (manager as StaggeredGridLayoutManager)._spanCount;
    final size = manager is GridLayoutManager ? _gridRows!.sizeFor(position) : 1;
    final cross = _matrixCrossExtent * size / spans;
    final extent =
        mainExtent ?? (manager is StaggeredGridLayoutManager ? _staggeredSpans!.exactExtentAt(position) : null);
    return renderObject.vertical
        ? BoxConstraints.tightFor(width: cross, height: extent)
        : BoxConstraints.tightFor(width: extent, height: cross);
  }

  void _matrixParentData(ViewHolder holder, double start, double extent, int span, int spanSize, int spanCount) {
    final render = renderObject;
    final cross = render.vertical ? render.childConstraints.maxWidth : render.childConstraints.maxHeight;
    final reversed = (widget as _RecyclerViewport).crossAxisReversed;
    (_box(holder).parentData! as _RecyclerParentData)
      ..logicalStart = start + render.leadingPadding
      ..extent = extent
      ..visible = true
      ..spanIndex = span
      ..spanSize = spanSize
      ..crossStart = cross * (reversed ? spanCount - span - spanSize : span) / spanCount;
  }

  void _layoutMatrix(_LayoutScrap scrap) {
    assert(() {
      RecyclerWorkProbe.fullLayouts++;
      return true;
    }());
    final render = renderObject;
    final manager = _state._manager!;
    final count = _adapter?.getItemCount() ?? 0;
    _firstVisible = _lastVisible = null;
    if (count != _extents.length) {
      if (_extents.length != 0) throw StateError('适配器数量改变后必须调用对应的 notify 方法。');
      _extents = _ExtentIndex(_adapter);
    }
    for (final holder in _pendingRetire.toList()) {
      _retire(holder, allowCache: false);
    }
    if (count == 0) {
      for (final holder in {..._active.values, ..._cached}) {
        _retire(holder, allowCache: false);
      }
      _matrixDataChanged(0, 0, full: true);
      render._correctOffset(0);
      render.offset.applyContentDimensions(0, 0);
      _pendingUpdates = false;
      render.markNeedsSemanticsUpdate();
      return;
    }
    _ensureMatrix();
    _resolveFullChange();
    _trimCache();
    for (final holder in _retained.toList()) {
      if (holder.isRecyclable()) {
        _retained.remove(holder);
        _putInPool(holder);
      }
    }
    final request = _state._config.pendingScroll;
    _state._config.pendingScroll = null;
    var anchor = _anchor;
    _anchor = null;
    final target = request?.position.clamp(0, count - 1);
    final preserveOverscroll =
        request == null &&
        anchor == null &&
        !_pendingUpdates &&
        render.offset is ScrollPosition &&
        (render.offset as ScrollPosition).hasContentDimensions &&
        (render.offset as ScrollPosition).outOfRange;
    if (target != null) {
      render._correctOffset(math.max(0, _matrixStart(target) - (request!.offset ?? 0)));
    } else if (anchor != null && anchor.holder._bound && !anchor.holder._removed) {
      render._correctOffset(
        math.max(0, _matrixStart(anchor.holder._position) + render.leadingPadding - anchor.relativeStart),
      );
    } else {
      anchor = null;
    }
    if (anchor == null && target == null && !preserveOverscroll) {
      // 远跳后旧条目已经离开视口，补测高度不能借它改写输入给出的像素位置。
      final pixels = render.offset.pixels;
      for (final holder in _active.values) {
        if (holder._removed || holder._invalid || !holder._bound) continue;
        final data = _box(holder).parentData! as _RecyclerParentData;
        final relative = data.logicalStart - pixels;
        if (relative + data.extent <= 0 || relative >= render.mainExtent - render.trailingPadding) continue;
        if (anchor == null || holder._position < anchor.holder._position) anchor = _Anchor(holder, relative);
      }
    }
    // 同轮布局会把锚点 holder 换绑给别的位置，几何校正只读取回收前的位置快照。
    final anchorPosition = anchor?.holder._position;
    final anchorRelative = anchor?.relativeStart;
    _state._initialLayout = false;
    final focused = _focusedHolder();
    void retire(ViewHolder holder) => _retire(holder, scrap: identical(holder, focused) ? null : scrap);
    double total() => manager is GridLayoutManager ? _gridRows!.rows.total : _staggeredSpans!.total;
    void keepAnchor() {
      if (target != null) {
        render._correctOffset(math.max(0, _matrixStart(target) - (request!.offset ?? 0)));
      } else if (anchorPosition != null) {
        render._correctOffset(math.max(0, _matrixStart(anchorPosition) + render.leadingPadding - anchorRelative!));
      }
    }

    for (var attempt = 0; attempt < 8; attempt++) {
      final begin = math.max(0.0, render.offset.pixels - render.leadingPadding);
      final end = render.offset.pixels + render.mainExtent - render.leadingPadding - render.trailingPadding;
      final wanted = <ViewHolder>{};
      var changed = false;
      if (manager is GridLayoutManager) {
        final geometry = _gridRows!;
        final first = geometry.rows.indexAt(begin);
        var last = first;
        while (last < geometry.rowCount && (last == first || geometry.rows.prefix(last) < end)) {
          last++;
        }
        for (final holder in _active.values.toList()) {
          final row = geometry.rowFor(holder._position);
          if (holder._removed || row < first || row >= last) retire(holder);
        }
        for (var row = first; row < geometry.rowCount; row++) {
          final currentEnd = render.offset.pixels + render.mainExtent - render.leadingPadding - render.trailingPadding;
          if (row != first && geometry.rows.prefix(row) >= currentEnd) break;
          final holders = <ViewHolder>[];
          var maximum = 0.0;
          for (var position = geometry.firstInRow(row); position < geometry.endInRow(row); position++) {
            final holder = _obtainAndLayout(position, _matrixChildConstraints(position), visible: true, scrap: scrap)!;
            final box = _box(holder);
            final extent = render.vertical ? box.size.height : box.size.width;
            _extents.measure(position, extent);
            maximum = math.max(maximum, extent);
            holders.add(holder);
          }
          final rowChanged = geometry.rows.measure(row, maximum);
          changed |= rowChanged;
          if (rowChanged) keepAnchor();
          for (final holder in holders) {
            final box = _box(holder);
            final extent = render.vertical ? box.size.height : box.size.width;
            if ((extent - maximum).abs() > precisionErrorTolerance) {
              box.layout(_matrixChildConstraints(holder._position, mainExtent: maximum), parentUsesSize: true);
            }
            wanted.add(holder);
            _matrixParentData(
              holder,
              geometry.rows.prefix(row),
              maximum,
              geometry.spanFor(holder._position),
              geometry.sizeFor(holder._position),
              manager._spanCount,
            );
          }
        }
      } else {
        final geometry = _staggeredSpans!;
        final positions = geometry.visible(begin, end).toSet();
        for (final holder in _active.values.toList()) {
          if (holder._removed || !positions.contains(holder._position)) retire(holder);
        }
        final visited = <int>{};
        while (true) {
          final currentBegin = math.max(0.0, render.offset.pixels - render.leadingPadding);
          final currentEnd = render.offset.pixels + render.mainExtent - render.leadingPadding - render.trailingPadding;
          final candidates = geometry
              .visible(currentBegin, currentEnd)
              .where((position) => !visited.contains(position))
              .toList();
          if (candidates.isEmpty) break;
          for (final position in candidates) {
            visited.add(position);
            geometry.ensurePosition(position);
            final holder = _obtainAndLayout(position, _matrixChildConstraints(position), visible: true, scrap: scrap)!;
            final box = _box(holder);
            final extent = render.vertical ? box.size.height : box.size.width;
            final itemChanged = geometry.measure(position, extent);
            changed |= itemChanged;
            if (itemChanged) keepAnchor();
            wanted.add(holder);
            _matrixParentData(
              holder,
              geometry.startAt(position),
              extent,
              geometry.spanFor(position),
              1,
              geometry.spanCount,
            );
          }
          if (geometry.hasExactExtents) break;
        }
      }
      for (final holder in _active.values.toList()) {
        if (!wanted.contains(holder)) retire(holder);
      }
      final maxScroll = math.max(0.0, total() + render.leadingPadding + render.trailingPadding - render.mainExtent);
      final pixels = render.offset.pixels;
      if (!preserveOverscroll) render._correctOffset(pixels.clamp(0.0, maxScroll));
      final adjusted = (pixels - render.offset.pixels).abs() > precisionErrorTolerance;
      final accepted = render.offset.applyContentDimensions(0, maxScroll);
      if (accepted && !adjusted && !changed) break;
    }
    for (final holder in _active.values.toList()) {
      final position = holder._position;
      final box = _box(holder);
      if (manager is GridLayoutManager) {
        final geometry = _gridRows!;
        _matrixParentData(
          holder,
          geometry.startAt(position),
          geometry.rows._values[geometry.rowFor(position)],
          geometry.spanFor(position),
          geometry.sizeFor(position),
          manager._spanCount,
        );
      } else {
        final geometry = _staggeredSpans!;
        _matrixParentData(
          holder,
          geometry.startAt(position),
          render.vertical ? box.size.height : box.size.width,
          geometry.spanFor(position),
          1,
          geometry.spanCount,
        );
      }
      final data = box.parentData! as _RecyclerParentData;
      final relative = data.logicalStart - render.offset.pixels;
      if (relative + data.extent <= 0 || relative >= render.mainExtent) {
        retire(holder);
        continue;
      }
      _staggeredSpans?.retainSpan(position, data.spanIndex);
      if (_firstVisible == null || position < _firstVisible!._position) _firstVisible = holder;
      if (_lastVisible == null || position > _lastVisible!._position) _lastVisible = holder;
    }
    _pendingUpdates = false;
    render.markNeedsSemanticsUpdate();
    _flushScrap(scrap);
    _prefetch();
  }
}
