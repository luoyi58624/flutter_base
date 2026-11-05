part of 'index.dart';

/// 管理 RecyclerView 中条目的布局、滚动定位与预取策略。
abstract class LayoutManager {
  _RecyclerViewState? _state;
  bool _itemPrefetchEnabled = true;

  /// 返回当前适配器中的条目数量。
  int getItemCount() => _state?._adapter?.getItemCount() ?? 0;

  /// 返回当前参与可见布局的条目数量，不包含回收池中的条目。
  int getChildCount() => _state?._element?._active.length ?? 0;

  /// 查找当前布局中指定位置的条目视图，未挂载时返回 null。
  Widget? findViewByPosition(int position) {
    final active = _state?._element?._active;
    if (active == null) return null;
    for (final holder in active.values) {
      if (holder.getLayoutPosition() == position) return holder.itemView;
    }
    return null;
  }

  /// 返回条目视图最近一次布局使用的位置，未参与当前布局时返回 -1。
  int getPosition(Widget view) {
    final active = _state?._element?._active;
    if (active == null) return RecyclerView.NO_POSITION;
    for (final holder in active.values) {
      if (identical(holder.itemView, view)) return holder.getLayoutPosition();
    }
    return RecyclerView.NO_POSITION;
  }

  /// 将指定适配器位置滚动到可见区域。
  void scrollToPosition(int position) {
    if (position < 0) {
      throw ArgumentError.value(position, 'position', '条目位置不能为负数。');
    }
    _state?._scrollToPosition(position);
  }

  /// 返回布局管理器是否允许水平方向滚动。
  bool canScrollHorizontally() => false;

  /// 返回布局管理器是否允许垂直方向滚动。
  bool canScrollVertically() => false;

  /// 设置是否允许提前准备即将进入可见区域的条目。
  void setItemPrefetchEnabled(bool enabled) {
    if (_itemPrefetchEnabled == enabled) return;
    _itemPrefetchEnabled = enabled;
    _state?._element?.renderObject.markNeedsLayout();
  }

  /// 返回是否允许条目预取。
  bool isItemPrefetchEnabled() => _itemPrefetchEnabled;
}

/// 按单一方向排列并回收复用条目的线性布局管理器。
class LinearLayoutManager extends LayoutManager {
  /// 创建线性布局，保留官方的 context、方向和反向布局参数顺序。
  LinearLayoutManager([BuildContext? context, int orientation = RecyclerView.VERTICAL, bool reverseLayout = false]) {
    setOrientation(orientation);
    _reverseLayout = reverseLayout;
  }

  int _orientation = RecyclerView.VERTICAL;
  bool _reverseLayout = false;
  bool _stackFromEnd = false;
  int _initialPrefetchItemCount = 2;

  /// 返回当前布局方向。
  int getOrientation() => _orientation;

  /// 设置布局方向，仅接受 RecyclerView.HORIZONTAL 或 RecyclerView.VERTICAL。
  void setOrientation(int orientation) {
    if (orientation != RecyclerView.HORIZONTAL && orientation != RecyclerView.VERTICAL) {
      throw ArgumentError.value(orientation, 'orientation', '布局方向必须是 HORIZONTAL 或 VERTICAL。');
    }
    if (_orientation == orientation) return;
    _orientation = orientation;
    _state?._layoutManagerChanged();
  }

  /// 返回是否沿当前方向反向排列条目。
  bool getReverseLayout() => _reverseLayout;

  /// 设置是否反向排列条目。
  void setReverseLayout(bool reverseLayout) {
    if (_reverseLayout == reverseLayout) return;
    _reverseLayout = reverseLayout;
    _state?._layoutManagerChanged();
  }

  /// 返回初始布局是否从内容末端对齐。
  bool getStackFromEnd() => _stackFromEnd;

  /// 设置初始布局是否从内容末端对齐，不改变条目的排列方向。
  void setStackFromEnd(bool stackFromEnd) {
    if (_stackFromEnd == stackFromEnd) return;
    _stackFromEnd = stackFromEnd;
    _state?._layoutManagerChanged();
  }

  /// 返回初次进入布局时计划预取的条目数量。
  int getInitialPrefetchItemCount() => _initialPrefetchItemCount;

  /// 设置初次进入布局时计划预取的条目数量，0 表示不执行初始预取。
  void setInitialPrefetchItemCount(int itemCount) {
    if (itemCount < 0) {
      throw ArgumentError.value(itemCount, 'itemCount', '初始预取数量不能为负数。');
    }
    if (_initialPrefetchItemCount == itemCount) return;
    _initialPrefetchItemCount = itemCount;
    _state?._element?.renderObject.markNeedsLayout();
  }

  /// 将指定条目定位到布局起始边缘的给定偏移。
  void scrollToPositionWithOffset(int position, double offset) {
    if (position < 0) {
      throw ArgumentError.value(position, 'position', '条目位置不能为负数。');
    }
    if (!offset.isFinite) {
      throw ArgumentError.value(offset, 'offset', '条目偏移必须是有限数值。');
    }
    _state?._scrollToPosition(position, offset: offset);
  }

  /// 返回当前布局中第一个可见条目的适配器位置。
  int findFirstVisibleItemPosition() =>
      _state?._element?._findVisiblePosition(first: true, complete: false) ?? RecyclerView.NO_POSITION;

  /// 返回当前布局中最后一个可见条目的适配器位置。
  int findLastVisibleItemPosition() =>
      _state?._element?._findVisiblePosition(first: false, complete: false) ?? RecyclerView.NO_POSITION;

  /// 返回当前布局中第一个完全可见条目的适配器位置。
  int findFirstCompletelyVisibleItemPosition() =>
      _state?._element?._findVisiblePosition(first: true, complete: true) ?? RecyclerView.NO_POSITION;

  /// 返回当前布局中最后一个完全可见条目的适配器位置。
  int findLastCompletelyVisibleItemPosition() =>
      _state?._element?._findVisiblePosition(first: false, complete: true) ?? RecyclerView.NO_POSITION;

  /// 返回当前方向是否为水平布局。
  @override
  bool canScrollHorizontally() => _orientation == RecyclerView.HORIZONTAL;

  /// 返回当前方向是否为垂直布局。
  @override
  bool canScrollVertically() => _orientation == RecyclerView.VERTICAL;
}
