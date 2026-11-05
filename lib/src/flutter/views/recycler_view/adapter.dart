part of 'index.dart';

/// 持有可重复绑定的条目视图及其在适配器中的身份。
abstract class ViewHolder {
  /// 创建持有固定视图结构的条目，后续绑定只更新该结构消费的数据。
  ViewHolder(this.itemView);

  /// 创建条目时提供的视图描述，其挂载后的子树由回收容器保留。
  final Widget itemView;

  final GlobalKey _key = GlobalKey();
  int _position = -1;
  int _layoutPosition = -1;
  int _oldPosition = -1;
  int _itemId = -1;
  int _itemViewType = 0;
  int _recyclableCount = 0;
  bool _bound = false;
  bool _invalid = false;
  bool _removed = false;
  bool _needsBind = true;
  bool _fullUpdate = true;
  bool _attached = false;
  final List<Object> _payloads = [];
  Adapter? _bindingAdapter;
  _RecyclerViewportElement? _owner;
  Widget? _hostWidget;
  bool? _hostVisible;
  final _reuseAnimation = ReuseAnimationState();

  /// 返回绑定适配器中的最新位置，失效、删除或回收后返回 -1。
  int getBindingAdapterPosition() => _bound && !_invalid && !_removed && _bindingAdapter != null ? _position : -1;

  /// 返回 RecyclerView 适配器中的最新位置。
  int getAbsoluteAdapterPosition() => getBindingAdapterPosition();

  /// 返回最近一次布局使用的位置，不提前应用尚未布局的数据变更。
  int getLayoutPosition() => _bound ? _layoutPosition : -1;

  /// 返回结构变更之前的位置，没有旧布局时返回 -1。
  int getOldPosition() => _oldPosition;

  /// 返回最近一次绑定的稳定标识，未启用稳定标识时返回 -1。
  int getItemId() => _itemId;

  /// 返回创建该条目时使用的视图类型。
  int getItemViewType() => _itemViewType;

  /// 返回最近一次绑定该条目的适配器。
  Adapter? getBindingAdapter() => _bindingAdapter;

  /// 成对禁止或恢复回收，嵌套调用通过引用计数保持每一层保护。
  void setIsRecyclable(bool recyclable) {
    _recyclableCount += recyclable ? -1 : 1;
    if (_recyclableCount < 0) {
      _recyclableCount = 0;
      assert(() {
        debugPrint('ViewHolder.setIsRecyclable(true) 缺少配对的 false 调用。');
        return true;
      }());
    }
  }

  /// 返回条目是否没有尚未解除的回收保护。
  bool isRecyclable() => _recyclableCount == 0;

  void _addChangePayload(Object? payload) {
    _needsBind = true;
    if (payload == null) {
      _fullUpdate = true;
      _payloads.clear();
    } else if (!_fullUpdate) {
      _payloads.add(payload);
    }
  }

  void _resetInternal() {
    _position = -1;
    _layoutPosition = -1;
    _oldPosition = -1;
    _itemId = -1;
    _recyclableCount = 0;
    _bound = false;
    _invalid = false;
    _removed = false;
    _needsBind = true;
    _fullUpdate = true;
    _attached = false;
    _payloads.clear();
    _bindingAdapter = null;
  }
}

/// 将业务数据绑定到可按类型回收复用的条目视图。
abstract class Adapter<VH extends ViewHolder> {
  final List<AdapterDataObserver> _observers = [];
  bool _hasStableIds = false;

  /// 创建指定类型的条目结构，此时尚未绑定具体的数据位置。
  VH onCreateViewHolder(RecyclerView parent, int viewType);

  /// 绑定指定位置的数据，空载荷表示必须完整更新条目内容。
  void onBindViewHolder(VH holder, int position, [List<Object> payloads = const []]);

  /// 返回当前数据集合中的条目数量。
  int getItemCount();

  /// 返回指定位置的结构类型，默认所有条目使用类型 0。
  int getItemViewType(int position) => 0;

  /// 返回指定位置的稳定标识，默认返回 -1。
  int getItemId(int position) => -1;

  /// 创建条目并记录类型，容器通过该入口调用创建回调。
  @nonVirtual
  VH createViewHolder(RecyclerView parent, int viewType) {
    final holder = onCreateViewHolder(parent, viewType);
    if (holder._owner != null || holder._bound) {
      throw StateError('onCreateViewHolder 必须返回尚未挂载或绑定的新条目。');
    }
    holder._itemViewType = viewType;
    return holder;
  }

  /// 更新条目身份并执行绑定，容器通过该入口调用绑定回调。
  @nonVirtual
  void bindViewHolder(VH holder, int position) {
    final payloads = holder._fullUpdate ? const <Object>[] : List<Object>.unmodifiable(holder._payloads);
    holder
      .._position = position
      .._itemId = _hasStableIds ? getItemId(position) : -1
      .._bound = true
      .._invalid = false
      .._removed = false
      .._bindingAdapter = this;
    onBindViewHolder(holder, position, payloads);
    holder
      .._needsBind = false
      .._fullUpdate = false
      .._payloads.clear();
  }

  /// 设置是否提供随数据移动保持不变的稳定标识，注册观察者后不可切换。
  @nonVirtual
  void setHasStableIds(bool hasStableIds) {
    if (hasObservers()) {
      throw StateError('适配器已经注册观察者，不能更改稳定标识配置。');
    }
    _hasStableIds = hasStableIds;
  }

  /// 返回是否启用了稳定标识。
  @nonVirtual
  bool hasStableIds() => _hasStableIds;

  /// 返回是否有容器或其他对象正在观察适配器。
  @nonVirtual
  bool hasObservers() => _observers.isNotEmpty;

  /// 注册数据变化观察者，同一观察者不能重复注册。
  @nonVirtual
  void registerAdapterDataObserver(AdapterDataObserver observer) {
    if (_observers.contains(observer)) {
      throw StateError('该适配器观察者已经注册。');
    }
    _observers.add(observer);
  }

  /// 移除已经注册的数据变化观察者。
  @nonVirtual
  void unregisterAdapterDataObserver(AdapterDataObserver observer) {
    if (!_observers.remove(observer)) {
      throw StateError('该适配器观察者尚未注册。');
    }
  }

  /// 在条目离开同位置缓存并即将进入回收池时释放绑定数据。
  void onViewRecycled(VH holder) {}

  /// 在条目的临时状态阻止回收时决定是否允许继续回收。
  bool onFailedToRecycleView(VH holder) => false;

  /// 在条目进入可见布局时接收通知。
  void onViewAttachedToWindow(VH holder) {}

  /// 在条目离开可见布局时接收通知，此时不一定已经进入回收池。
  void onViewDetachedFromWindow(VH holder) {}

  /// 在 RecyclerView 开始观察此适配器时接收通知。
  void onAttachedToRecyclerView(RecyclerView recyclerView) {}

  /// 在 RecyclerView 停止观察此适配器时接收通知。
  void onDetachedFromRecyclerView(RecyclerView recyclerView) {}

  /// 通知整个数据集合已经改变，现有条目需要重新确认身份和绑定。
  @nonVirtual
  void notifyDataSetChanged() => _dispatch((observer) => observer.onChanged());

  /// 通知一个条目的内容改变，可选载荷用于合并局部绑定。
  @nonVirtual
  void notifyItemChanged(int position, [Object? payload]) => notifyItemRangeChanged(position, 1, payload);

  /// 通知连续条目的内容改变，null 载荷会清除已经累积的局部载荷。
  @nonVirtual
  void notifyItemRangeChanged(int positionStart, int itemCount, [Object? payload]) =>
      _dispatch((observer) => observer.onItemRangeChanged(positionStart, itemCount, payload));

  /// 通知在指定位置插入了一个条目。
  @nonVirtual
  void notifyItemInserted(int position) => notifyItemRangeInserted(position, 1);

  /// 通知从指定位置开始插入了连续条目。
  @nonVirtual
  void notifyItemRangeInserted(int positionStart, int itemCount) =>
      _dispatch((observer) => observer.onItemRangeInserted(positionStart, itemCount));

  /// 通知指定位置的条目已移除。
  @nonVirtual
  void notifyItemRemoved(int position) => notifyItemRangeRemoved(position, 1);

  /// 通知从指定位置开始的连续条目已移除。
  @nonVirtual
  void notifyItemRangeRemoved(int positionStart, int itemCount) =>
      _dispatch((observer) => observer.onItemRangeRemoved(positionStart, itemCount));

  /// 通知一个条目从原位置移动到了目标位置。
  @nonVirtual
  void notifyItemMoved(int fromPosition, int toPosition) =>
      _dispatch((observer) => observer.onItemRangeMoved(fromPosition, toPosition, 1));

  void _dispatch(void Function(AdapterDataObserver observer) notify) {
    for (final observer in List<AdapterDataObserver>.of(_observers.reversed)) {
      notify(observer);
    }
  }
}

/// 观察适配器的内容变化和结构变化。
abstract class AdapterDataObserver {
  /// 在整个数据集合改变时接收通知。
  void onChanged() {}

  /// 在连续条目的内容改变时接收可选局部载荷。
  void onItemRangeChanged(int positionStart, int itemCount, [Object? payload]) {}

  /// 在连续条目插入后接收通知。
  void onItemRangeInserted(int positionStart, int itemCount) {}

  /// 在连续条目移除后接收通知。
  void onItemRangeRemoved(int positionStart, int itemCount) {}

  /// 在条目移动后接收通知，单项移动的数量为 1。
  void onItemRangeMoved(int fromPosition, int toPosition, int itemCount) {}
}
