part of 'scroll.dart';

typedef _ChatAnchor = ({Object id, double offset});

class _ChatMessageBoundary extends SingleChildRenderObjectWidget {
  const _ChatMessageBoundary({super.key, required this.id, required this.rows, required super.child});

  final Object id;
  final Set<_RenderChatMessage> rows;

  @override
  _RenderChatMessage createRenderObject(BuildContext context) => _RenderChatMessage(id, rows);

  @override
  void updateRenderObject(BuildContext context, _RenderChatMessage renderObject) {
    renderObject.id = id;
  }
}

class _RenderChatMessage extends RenderProxyBox {
  _RenderChatMessage(this.id, this.rows);

  Object id;
  final Set<_RenderChatMessage> rows;
  double extent = 0;

  _RenderChatSliver? get _chatSliver {
    RenderObject? current = parent;
    while (current != null && current is! _RenderChatSliver) {
      current = current.parent;
    }
    return current as _RenderChatSliver?;
  }

  @override
  void performLayout() {
    super.performLayout();
    extent = size.height;
  }

  @override
  void markNeedsLayout() {
    final sliver = _chatSliver;
    if (sliver != null && !sliver._layingOut && sliver.visibleIds.contains(id)) {
      sliver.preservePosition();
    }
    super.markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    rows.add(this);
  }

  @override
  void detach() {
    rows.remove(this);
    super.detach();
  }

  double? offsetIn(RenderSliver ancestor) {
    if (!attached || !hasSize) return null;
    RenderObject item = this;
    var offset = 0.0;
    for (var parent = item.parent; parent != null; parent = item.parent) {
      if (parent is RenderSliver) {
        if (item.parentData case SliverMultiBoxAdaptorParentData(keptAlive: true)) return null;
        final distance = parent.childScrollOffset(item);
        if (distance == null || !distance.isFinite) return null;
        offset += distance;
      }
      if (identical(parent, ancestor)) return offset;
      item = parent;
    }
    return null;
  }
}

class _ChatSliver extends SingleChildRenderObjectWidget {
  const _ChatSliver({
    super.key,
    required this.rows,
    required this.shouldFollow,
    required this.isIdle,
    required this.navigating,
    required this.metricsChanged,
    required super.child,
  });

  final Set<_RenderChatMessage> rows;
  final bool Function() shouldFollow;
  final bool Function() isIdle;
  final bool Function() navigating;
  final VoidCallback metricsChanged;

  @override
  _RenderChatSliver createRenderObject(BuildContext context) =>
      _RenderChatSliver(rows, shouldFollow, isIdle, navigating, metricsChanged);
}

class _RenderChatSliver extends RenderProxySliver {
  _RenderChatSliver(this._rows, this._shouldFollow, this._isIdle, this._navigating, this._metricsChanged);

  final Set<_RenderChatMessage> _rows;
  final bool Function() _shouldFollow;
  final bool Function() _isIdle;
  final bool Function() _navigating;
  final VoidCallback _metricsChanged;
  final _visible = <_ChatAnchor>[];
  bool _anchorPending = false;
  bool _follow = false;
  bool _latestChanged = false;
  bool _layingOut = false;
  double? _initialOffset;
  double? _viewportExtent;

  Iterable<Object> get visibleIds => _visible.map((anchor) => anchor.id);

  void preservePosition({bool followLatest = false}) {
    if (!_anchorPending) {
      _follow = _shouldFollow();
      _anchorPending = true;
    }
    _latestChanged |= followLatest;
    markNeedsLayout();
  }

  ({int oldest, int newest})? _visibleRange(Map<Object, int> indices) {
    int? oldest;
    int? newest;
    for (final anchor in _visible) {
      final index = indices[anchor.id];
      if (index == null) continue;
      oldest = oldest == null ? index : math.max(oldest, index);
      newest = newest == null ? index : math.min(newest, index);
    }
    return oldest == null ? null : (oldest: oldest, newest: newest!);
  }

  _RenderChatMessage? _rowFor(Object id) {
    for (final row in _rows) {
      if (row.id == id && row.offsetIn(this) != null) return row;
    }
    return null;
  }

  void _rememberVisible() {
    _visible.clear();
    final start = constraints.scrollOffset;
    final end = start + geometry!.paintExtent;
    if (end <= start) return;
    for (final row in _rows) {
      final offset = row.offsetIn(this);
      if (offset == null || offset >= end || offset + row.extent <= start) continue;
      _visible.add((id: row.id, offset: offset));
    }
    // 优先选择视口中间的消息，为两端滚出的条目留出余量。
    final center = (start + end) / 2;
    _visible.sort((a, b) => (a.offset - center).abs().compareTo((b.offset - center).abs()));
  }

  @override
  void performLayout() {
    final navigating = _navigating();
    final extent = constraints.viewportMainAxisExtent;
    final viewportChange = extent - (_viewportExtent ?? extent);
    final follow = _anchorPending ? _follow && _isIdle() : _shouldFollow();
    _initialOffset ??= constraints.scrollOffset;
    _layingOut = true;
    try {
      super.performLayout();
    } finally {
      _layingOut = false;
    }
    if (geometry!.scrollOffsetCorrection != null) return;

    var correction = 0.0;
    if (!navigating && (_anchorPending || viewportChange != 0)) {
      // 使用同一消息在 Sliver 内的坐标差，并扣除子 Sliver 已完成的修正。
      // 第一轮输入已包含当帧拖动或惯性的位移。
      final applied = constraints.scrollOffset - _initialOffset!;
      for (final anchor in _visible) {
        final offset = _rowFor(anchor.id)?.offsetIn(this);
        if (offset == null) continue;
        final change = offset - anchor.offset;
        // 反向视口从底部排布，输入区改变高度时补上底边的位移。
        correction = change - applied - viewportChange;
        if (follow && change.abs() > precisionErrorTolerance) correction = -constraints.scrollOffset;
        break;
      }
      if (follow && (_latestChanged || viewportChange != 0)) correction = -constraints.scrollOffset;
    }

    _viewportExtent = extent;
    _initialOffset = null;
    _anchorPending = false;
    _latestChanged = false;
    correction = math.max(-constraints.scrollOffset, correction);
    if (correction.abs() > precisionErrorTolerance) {
      _visible.clear();
      geometry = SliverGeometry(scrollOffsetCorrection: correction);
      return;
    }
    _rememberVisible();
    _metricsChanged();
  }
}
