part of 'index.dart';

/// 提供每个条目占用的跨度，规则与 AndroidX GridLayoutManager.SpanSizeLookup 一致。
abstract class SpanSizeLookup {
  /// 返回指定位置占用的跨度，必须在 1 到当前 spanCount 之间。
  int getSpanSize(int position);

  /// 返回条目在所在行或列中的起始跨度。
  int getSpanIndex(int position, int spanCount) => _spanInfo(position, spanCount).$1;

  /// 返回条目所在的跨度分组，垂直布局时为行号。
  int getSpanGroupIndex(int position, int spanCount) => _spanInfo(position, spanCount).$2;

  (int, int) _spanInfo(int position, int spanCount) {
    RangeError.checkNotNegative(position, 'position');
    if (spanCount < 1) throw ArgumentError.value(spanCount, 'spanCount');
    var span = 0, group = 0;
    for (var index = 0; index <= position; index++) {
      final size = _checkedSpanSize(index, spanCount);
      if (span + size > spanCount) {
        span = 0;
        group++;
      }
      if (index == position) return (span, group);
      span += size;
      if (span == spanCount) {
        span = 0;
        group++;
      }
    }
    throw StateError('无法解析跨度。');
  }

  int _checkedSpanSize(int position, int spanCount) {
    final size = getSpanSize(position);
    if (size < 1 || size > spanCount) {
      throw StateError('位置 $position 请求 $size 个跨度，spanCount 为 $spanCount。');
    }
    return size;
  }
}

class _DefaultSpanSizeLookup extends SpanSizeLookup {
  @override
  int getSpanSize(int position) => 1;
  @override
  int getSpanIndex(int position, int spanCount) => position % spanCount;
  @override
  int getSpanGroupIndex(int position, int spanCount) => position ~/ spanCount;
}

/// 按跨度分组排列条目，同一行或列以组内最大主轴尺寸对齐。
class GridLayoutManager extends LinearLayoutManager {
  /// 创建 AndroidX 风格网格，垂直时 spanCount 表示列数，水平时表示行数。
  GridLayoutManager(
    BuildContext? context,
    int spanCount, [
    int orientation = RecyclerView.VERTICAL,
    bool reverseLayout = false,
  ]) : super(context, orientation, reverseLayout) {
    setSpanCount(spanCount);
  }

  int _spanCount = 1;
  SpanSizeLookup _spanSizeLookup = _DefaultSpanSizeLookup();

  /// 返回垂直布局的列数或水平布局的行数。
  int getSpanCount() => _spanCount;

  /// 修改跨度数并重新测量当前可见条目。
  void setSpanCount(int spanCount) {
    if (spanCount < 1) throw ArgumentError.value(spanCount, 'spanCount', '跨度数至少为 1。');
    if (_spanCount == spanCount) return;
    _spanCount = spanCount;
    _state?._layoutManagerChanged();
  }

  /// 返回当前条目跨度规则。
  SpanSizeLookup getSpanSizeLookup() => _spanSizeLookup;

  /// 设置条目跨度规则，允许标题等条目横跨多列。
  void setSpanSizeLookup(SpanSizeLookup lookup) {
    if (identical(_spanSizeLookup, lookup)) return;
    _spanSizeLookup = lookup;
    _state?._layoutManagerChanged();
  }

  /// 网格沿用 AndroidX 的限制，不支持 stackFromEnd，请使用 reverseLayout。
  @override
  void setStackFromEnd(bool stackFromEnd) {
    if (stackFromEnd) throw UnsupportedError('GridLayoutManager 不支持 stackFromEnd。');
    super.setStackFromEnd(false);
  }
}

/// 将变高条目依次放入当前最短跨度的瀑布流布局管理器。
class StaggeredGridLayoutManager extends _AxisLayoutManager {
  /// 创建 AndroidX 风格瀑布流，垂直时 spanCount 表示列数，水平时表示行数。
  StaggeredGridLayoutManager(int spanCount, int orientation) : super(orientation, false) {
    setSpanCount(spanCount);
  }

  int _spanCount = 1;
  double Function(int position, double crossAxisExtent)? _itemExtentBuilder;

  /// 返回垂直布局的列数或水平布局的行数。
  int getSpanCount() => _spanCount;

  /// 修改跨度数并重新计算列分配。
  void setSpanCount(int spanCount) {
    if (spanCount < 1) throw ArgumentError.value(spanCount, 'spanCount', '跨度数至少为 1。');
    if (_spanCount == spanCount) return;
    _spanCount = spanCount;
    _state?._layoutManagerChanged();
  }

  /// 提供条目含内外边距的精确主轴尺寸，传入 null 恢复按可见条目实测。
  ///
  /// 回调接收适配器位置和单个跨度的实际交叉轴尺寸，返回有限非负值。
  /// 布局会约束条目使用返回的尺寸。回调应只计算尺寸，条目变更后通过适配器通知更新。
  void setItemExtentBuilder(double Function(int position, double crossAxisExtent)? builder) {
    if (identical(_itemExtentBuilder, builder)) return;
    _itemExtentBuilder = builder;
    _state?._layoutManagerChanged();
  }

  /// 清除列分配，让后续布局按当前内容重新填充。
  void invalidateSpanAssignments() => _state?._layoutManagerChanged();

  /// 将指定条目定位到布局起始边缘的给定偏移。
  void scrollToPositionWithOffset(int position, double offset) {
    RangeError.checkNotNegative(position, 'position');
    if (!offset.isFinite) throw ArgumentError.value(offset, 'offset');
    _state?._scrollToPosition(position, offset: offset);
  }

  /// 返回每个跨度中第一个可见条目的位置，空跨度为 NO_POSITION。
  List<int> findFirstVisibleItemPositions([List<int>? into]) => _positions(into, first: true, complete: false);

  /// 返回每个跨度中最后一个可见条目的位置，空跨度为 NO_POSITION。
  List<int> findLastVisibleItemPositions([List<int>? into]) => _positions(into, first: false, complete: false);

  /// 返回每个跨度中第一个完全可见条目的位置，空跨度为 NO_POSITION。
  List<int> findFirstCompletelyVisibleItemPositions([List<int>? into]) => _positions(into, first: true, complete: true);

  /// 返回每个跨度中最后一个完全可见条目的位置，空跨度为 NO_POSITION。
  List<int> findLastCompletelyVisibleItemPositions([List<int>? into]) => _positions(into, first: false, complete: true);

  List<int> _positions(List<int>? into, {required bool first, required bool complete}) {
    final result = into ?? List.filled(_spanCount, RecyclerView.NO_POSITION);
    if (result.length < _spanCount) throw ArgumentError('结果数组长度不能小于 spanCount。');
    result.fillRange(0, _spanCount, RecyclerView.NO_POSITION);
    final element = _state?._element;
    if (element == null) return result;
    final render = element.renderObject;
    for (final holder in element._active.values) {
      final data = element._box(holder).parentData! as _RecyclerParentData;
      final start = data.logicalStart - render.offset.pixels;
      if (complete &&
          (start < render.leadingPadding - .01 ||
              start + data.extent > render.mainExtent - render.trailingPadding + .01)) {
        continue;
      }
      final lane = data.spanIndex;
      final position = holder.getLayoutPosition();
      if (result[lane] == RecyclerView.NO_POSITION || (first ? position < result[lane] : position > result[lane])) {
        result[lane] = position;
      }
    }
    return result;
  }
}
