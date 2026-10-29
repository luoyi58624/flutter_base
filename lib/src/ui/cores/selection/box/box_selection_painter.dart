part of 'box_selection_view.dart';

class _BoxRegionWidget extends SingleChildRenderObjectWidget {
  const _BoxRegionWidget({required this.owner, required super.child});
  final _BoxSelectionState owner;
  @override
  RenderObject createRenderObject(BuildContext context) => _BoxRegionRender(owner);
}

class _BoxRegionRender extends RenderProxyBox implements SelectionGeometryObserver {
  _BoxRegionRender(this.regionOwner);
  final _BoxSelectionState regionOwner;
  Rect? _marquee;
  set marquee(Rect? value) {
    if (_marquee == value) return;
    _marquee = value;
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;
  @override
  bool selectionLayoutChanged() => regionOwner._flushGeometry();
  @override
  void performLayout() {
    do {
      super.performLayout();
    } while (selectionLayoutChanged());
  }

  @override
  void attach(PipelineOwner owner) {
    regionOwner._region = this;
    super.attach(owner);
  }

  @override
  void detach() {
    regionOwner._finish();
    regionOwner._region = null;
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final rect = _marquee?.intersect(Offset.zero & size);
    if (rect == null || rect.isEmpty) return;
    final color = regionOwner.widget.selectionColor;
    context.canvas
      ..drawRect(rect.shift(offset), Paint()..color = color)
      ..drawRect(
        rect.shift(offset),
        Paint()
          ..color = color.withAlpha(255)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }
}

class _BoxContentBoundary extends SingleChildRenderObjectWidget {
  const _BoxContentBoundary({required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _BoxContentRender();
}

class _BoxContentRender extends RenderProxyBox {
  @override
  bool get isRepaintBoundary => true;
}

/// 矩形查询索引；布局批次建树，指针移动只遍历相交分支。
final class SelectionRectIndex<T> {
  /// 冻结本批条目几何，叶子保留少量候选做精确相交判断。
  SelectionRectIndex(Iterable<({Rect rect, T value})> entries) : _roots = [_RectNode.build(entries.toList())];

  final List<_RectNode<T>?> _roots;

  /// 虚拟新项按倍增批次合并，避免每帧重建全部已访问对象的索引。
  void add(({Rect rect, T value}) entry) {
    final entries = [entry];
    var level = 0;
    while (level < _roots.length && _roots[level] != null) {
      entries.addAll(_roots[level]!.values);
      _roots[level++] = null;
    }
    final tree = _RectNode.build(entries);
    if (level == _roots.length) {
      _roots.add(tree);
    } else {
      _roots[level] = tree;
    }
  }

  /// 上次查询实际检查的叶子条目数，供结构性性能验证。
  int debugLastCandidateCount = 0;

  /// 返回有正相交面积的对象；只接触边缘不命中。
  Set<T> query(Rect rect) {
    debugLastCandidateCount = 0;
    final result = <T>{};
    if (rect.isEmpty) return result;
    void visit(_RectNode<T>? node) {
      if (node == null || !rect.overlaps(node.bounds)) return;
      final entries = node.entries;
      if (entries != null) {
        for (final entry in entries) {
          assert(() {
            debugLastCandidateCount++;
            return true;
          }());
          if (rect.overlaps(entry.rect)) result.add(entry.value);
        }
      } else {
        visit(node.left);
        visit(node.right);
      }
    }

    for (final root in _roots) {
      visit(root);
    }
    return result;
  }
}

final class _RectNode<T> {
  _RectNode(this.bounds, this.entries, this.left, this.right);
  final Rect bounds;
  final List<({Rect rect, T value})>? entries;
  final _RectNode<T>? left;
  final _RectNode<T>? right;

  Iterable<({Rect rect, T value})> get values sync* {
    if (entries != null) {
      yield* entries!;
    } else {
      yield* left!.values;
      yield* right!.values;
    }
  }

  static _RectNode<T>? build<T>(List<({Rect rect, T value})> entries) {
    if (entries.isEmpty) return null;
    var bounds = entries.first.rect;
    for (final entry in entries.skip(1)) {
      bounds = bounds.expandToInclude(entry.rect);
    }
    if (entries.length <= 8) return _RectNode(bounds, entries, null, null);
    final horizontal = bounds.width >= bounds.height;
    entries.sort(
      (a, b) =>
          horizontal ? a.rect.center.dx.compareTo(b.rect.center.dx) : a.rect.center.dy.compareTo(b.rect.center.dy),
    );
    final middle = entries.length ~/ 2;
    return _RectNode(bounds, null, build(entries.sublist(0, middle)), build(entries.sublist(middle)));
  }
}
