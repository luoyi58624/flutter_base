part of 'media.dart';

// 官方 SliverGrid 需要确定几何；这里只使用媒体业务已有的封面比例。
class _MediaMasonryDelegate extends SliverGridDelegate {
  _MediaMasonryDelegate(this.columns, this.count, this.footer, this.ratio, this.rtl);
  final int columns;
  final int count;
  final double footer;
  final double Function(int) ratio;
  final bool rtl;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) =>
      _MediaMasonryLayout(columns, constraints.crossAxisExtent / columns, footer, count, ratio, rtl);

  @override
  bool shouldRelayout(_MediaMasonryDelegate oldDelegate) => true;
}

class _MediaMasonryLayout extends SliverGridLayout {
  factory _MediaMasonryLayout(
    int columns,
    double slotWidth,
    double footer,
    int count,
    double Function(int) ratio,
    bool rtl,
  ) {
    final columnEnds = List.filled(columns, 0.0);
    final tiles = <SliverGridGeometry>[];
    final starts = <double>[];
    final maximumEnds = <double>[];
    for (var index = 0; index < count; index++) {
      var column = 0;
      for (var next = 1; next < columns; next++) {
        if (columnEnds[next] < columnEnds[column]) column = next;
      }
      final top = columnEnds[column];
      final height = math.max(0.0, slotWidth - _waterfallGap) / ratio(index) + footer + _waterfallGap;
      tiles.add(
        SliverGridGeometry(
          scrollOffset: top,
          crossAxisOffset: (rtl ? columns - 1 - column : column) * slotWidth,
          mainAxisExtent: height,
          crossAxisExtent: slotWidth,
        ),
      );
      columnEnds[column] += height;
      starts.add(top);
      maximumEnds.add(columnEnds.reduce(math.max));
    }
    return _MediaMasonryLayout._(tiles, starts, maximumEnds);
  }

  const _MediaMasonryLayout._(this._tiles, this._starts, this._maximumEnds);
  final List<SliverGridGeometry> _tiles;
  final List<double> _starts;
  final List<double> _maximumEnds;

  int _countThrough(List<double> values, double offset) {
    var low = 0;
    var high = values.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (values[mid] <= offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) =>
      math.min(_countThrough(_maximumEnds, scrollOffset), _tiles.length - 1);

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) =>
      (_countThrough(_starts, scrollOffset) - 1).clamp(0, _tiles.length - 1);

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) => _tiles[index];

  @override
  double computeMaxScrollOffset(int childCount) => childCount == 0 ? 0 : _maximumEnds[childCount - 1];
}
