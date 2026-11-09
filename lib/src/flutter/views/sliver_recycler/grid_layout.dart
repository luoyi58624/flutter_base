part of 'sliver_recycler.dart';

extension _RecyclerGridLayout on ElRenderSliverRecycler {
  void _layoutGrid(ElSliverRecyclerGrid widget, _RecyclerAnchor? anchor) {
    final extents = _extents!;
    final count = widget.itemCount;
    final rows = _gridRows;
    final masonry = _masonry;
    final crossExtent = math.max(
      0.0,
      (constraints.crossAxisExtent - widget.crossAxisSpacing * (widget.crossAxisCount - 1)) / widget.crossAxisCount,
    );
    final childConstraints = constraints.asBoxConstraints(crossAxisExtent: crossExtent);
    var pixels = constraints.scrollOffset;
    // 仍在内容起点时保留起点，零高首项展开应自然露出，而非被锚点修正滚走。
    if (pixels <= precisionErrorTolerance) anchor = _RecyclerAnchor(0, 0);
    final measuredRows = <int, double>{};
    final visited = <int>{};

    double total() => rows?.total ?? masonry!.total;
    double startAt(int index) => rows?.startAt(index) ?? masonry!.startAt(index);
    double cacheStart() => math.max(0.0, pixels + constraints.cacheOrigin);
    double cacheEnd() => cacheStart() + constraints.remainingCacheExtent;

    void keepAnchor() {
      if (anchor != null) pixels = math.max(0.0, startAt(anchor.index) - anchor.relativeStart);
    }

    RenderBox layoutChild(int index) {
      final child = _element._layoutItem(index, childConstraints);
      (child.parentData! as _RecyclerParentData).extent = constraints.axis == Axis.vertical
          ? child.size.height
          : child.size.width;
      return child;
    }

    void layoutRow(int row) {
      final grid = rows!;
      final first = grid.firstInRow(row);
      final end = grid.endInRow(row);
      if (measuredRows.containsKey(row) &&
          Iterable<int>.generate(end - first, (offset) => first + offset).every(_element._active.containsKey)) {
        return;
      }
      var maximum = 0.0;
      for (var index = first; index < end; index++) {
        final child = layoutChild(index);
        final extent = (child.parentData! as _RecyclerParentData).extent;
        extents.measure(index, extent);
        maximum = math.max(maximum, extent);
      }
      measuredRows[row] = maximum;
      if (grid.measureRow(row, maximum)) keepAnchor();
    }

    bool layoutMasonryItem(int index) {
      final child = layoutChild(index);
      final changed = masonry!.measure(index, (child.parentData! as _RecyclerParentData).extent);
      visited.add(index);
      if (changed) keepAnchor();
      return changed;
    }

    _element.owner!.buildScope(_element, () {
      _element._recycleOutside(0, count - 1);
      _element._discardInvalidSpares();
    });

    if (_needsFirstMeasurement) {
      if (rows != null) {
        layoutRow(rows.rowFor(anchor?.index ?? 0));
      } else {
        layoutMasonryItem(anchor?.index ?? 0);
      }
      _needsFirstMeasurement = false;
      keepAnchor();
    }

    // 远跳后没有真实可见旧条目时，保持输入像素；未知尺寸推算出的条目不能充当锚点。
    final wanted = <int>{};
    if (constraints.remainingCacheExtent > 0 && (cacheStart() < total() || total() == 0)) {
      if (rows != null) {
        var first = rows.total == 0 ? 0 : rows.rowAt(cacheStart());
        final last = rows.rowAt(cacheEnd() - precisionErrorTolerance);
        _element.owner!.buildScope(
          _element,
          () => _element._recycleOutside(rows.firstInRow(first), rows.endInRow(last) - 1),
        );
        var next = first;

        void includeRow(int row) {
          layoutRow(row);
          for (var index = rows.firstInRow(row); index < rows.endInRow(row); index++) {
            wanted.add(index);
          }
        }

        // 每次推进一行，实际行高变化后重新检查前后边界，不依赖固定重试次数。
        while (true) {
          if (first > 0 && rows.rowStart(first) > cacheStart() + precisionErrorTolerance) {
            includeRow(--first);
            continue;
          }
          if (next >= rows.rowCount ||
              (wanted.isNotEmpty && rows.rowStart(next) >= cacheEnd() - precisionErrorTolerance)) {
            break;
          }
          includeRow(next++);
        }
        wanted.removeWhere((index) {
          final start = rows.startAt(index);
          final extent = measuredRows[rows.rowFor(index)]!;
          return start >= cacheEnd() - precisionErrorTolerance ||
              (extent > 0 ? start + extent <= cacheStart() + precisionErrorTolerance : start < cacheStart());
        });
      } else {
        // 各列独立查询；尺寸改变时重新取候选集合，过期估值不能积累成离屏挂载。
        while (true) {
          final candidates = masonry!.visible(cacheStart(), cacheEnd()).toSet();
          _element.owner!.buildScope(_element, () => _element._recycleExcept(candidates));
          final pending = candidates
              .where((index) => !visited.contains(index) || !_element._active.containsKey(index))
              .toList(growable: false);
          if (pending.isEmpty) {
            wanted.addAll(candidates);
            break;
          }
          var changed = false;
          for (final index in pending) {
            if (layoutMasonryItem(index)) {
              changed = true;
              break;
            }
          }
          if (!changed) {
            wanted.addAll(candidates);
            break;
          }
        }
      }
    }
    _element.owner!.buildScope(_element, () => _element._finishLayout(wanted));

    final crossReversed = axisDirectionIsReversed(constraints.crossAxisDirection);
    for (final index in _element._visibleIndices) {
      final child = _element._active[index]!.box!;
      final data = child.parentData! as _RecyclerParentData;
      final lane = rows != null ? index % widget.crossAxisCount : masonry!.laneAt(index);
      final cross = lane * (crossExtent + widget.crossAxisSpacing);
      data
        ..layoutOffset = startAt(index)
        ..crossAxisOffset = crossReversed ? constraints.crossAxisExtent - cross - crossExtent : cross;
    }
    _completeGeometry(total(), pixels);
    if (masonry != null && geometry!.visible) {
      for (final index in _element._visibleIndices) {
        final child = _element._active[index]!.box!;
        if (paintsChild(child)) masonry.retainLane(index, masonry.laneAt(index));
      }
    }
  }
}
