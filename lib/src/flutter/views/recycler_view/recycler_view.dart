// 官方常量名称保持与 AndroidX 一致。
// ignore_for_file: constant_identifier_names
part of 'index.dart';

/// 通过 Adapter 创建和绑定条目、由 LayoutManager 安排布局的滚动容器。
class RecyclerView extends StatefulWidget {
  /// 创建容器，随后可按 AndroidX 的调用顺序设置布局管理器和适配器。
  RecyclerView({super.key, this.controller});

  /// 连接外部滚动控制器以联动滚动条，由调用方负责释放；未传入时由容器自行管理。
  final ScrollController? controller;

  /// 横向布局方向。
  static const int HORIZONTAL = 0;

  /// 纵向布局方向。
  static const int VERTICAL = 1;

  /// 条目当前没有有效适配器位置。
  static const int NO_POSITION = -1;

  /// 条目没有稳定标识。
  static const int NO_ID = -1;

  /// 容器当前没有滚动。
  static const int SCROLL_STATE_IDLE = 0;

  /// 用户正在拖动容器。
  static const int SCROLL_STATE_DRAGGING = 1;

  /// 容器正在执行惯性或程序滚动。
  static const int SCROLL_STATE_SETTLING = 2;

  final _RecyclerConfiguration _configuration = _RecyclerConfiguration();

  /// 设置适配器并释放旧适配器的绑定与回收结构。
  void setAdapter(Adapter? adapter) {
    if (identical(_configuration.adapter, adapter)) return;
    _configuration.adapter = adapter;
    _configuration.changed();
  }

  /// 返回当前适配器。
  Adapter? getAdapter() => _configuration.adapter;

  /// 更换兼容适配器，可选择是否同时回收现有条目。
  void swapAdapter(Adapter? adapter, bool removeAndRecycleExistingViews) {
    if (identical(_configuration.adapter, adapter)) return;
    _configuration.keepPoolOnAdapterChange = !removeAndRecycleExistingViews;
    setAdapter(adapter);
  }

  /// 设置条目布局管理器，同一管理器只能连接一个容器。
  void setLayoutManager(LayoutManager? layout) {
    if (identical(_configuration.layout, layout)) return;
    if (layout != null && layout is! LinearLayoutManager) {
      throw ArgumentError('当前内核支持 LinearLayoutManager。');
    }
    _configuration.layout = layout;
    _configuration.changed();
  }

  /// 返回当前布局管理器。
  LayoutManager? getLayoutManager() => _configuration.layout;

  /// 设置可在兼容容器之间共享的类型回收池。
  void setRecycledViewPool(RecycledViewPool pool) {
    if (identical(_configuration.pool, pool)) return;
    _configuration.pool = pool;
    _configuration.changed();
  }

  /// 返回当前类型回收池。
  RecycledViewPool getRecycledViewPool() => _configuration.pool;

  /// 设置离屏绑定缓存容量，预取启用时额外保留观测到的预取数量，0 同时关闭预取缓存。
  void setItemViewCacheSize(int size) {
    if (size < 0) throw ArgumentError.value(size, 'size');
    if (_configuration.cacheSize == size) return;
    _configuration.cacheSize = size;
    _configuration.changed();
  }

  /// 声明容器自身尺寸是否独立于适配器内容。
  void setHasFixedSize(bool hasFixedSize) => _configuration.hasFixedSize = hasFixedSize;

  /// 返回容器自身尺寸是否独立于适配器内容。
  bool hasFixedSize() => _configuration.hasFixedSize;

  /// 设置容器内边距，数值使用 Flutter 逻辑像素。
  void setPadding(double left, double top, double right, double bottom) {
    final padding = EdgeInsets.fromLTRB(left, top, right, bottom);
    if (!padding.isNonNegative || ![left, top, right, bottom].every((value) => value.isFinite)) {
      throw ArgumentError('内边距必须是有限的非负数。');
    }
    if (_configuration.padding == padding) return;
    _configuration.padding = padding;
    _configuration.changed();
  }

  /// 将指定数据位置移入可见区域。
  void scrollToPosition(int position) => _configuration.scrollTo(position);

  /// 通过动画将指定数据位置移入可见区域。
  void smoothScrollToPosition(int position) => _configuration.scrollTo(position, smooth: true);

  /// 按屏幕坐标方向滚动指定距离。
  void scrollBy(double dx, double dy) => _configuration.state?._scrollBy(dx, dy);

  /// 按屏幕坐标方向平滑滚动指定距离。
  void smoothScrollBy(double dx, double dy) => _configuration.state?._scrollBy(dx, dy, smooth: true);

  /// 以屏幕坐标方向的速度开始惯性滚动，返回是否接受了该速度。
  bool fling(double velocityX, double velocityY) => _configuration.state?._fling(velocityX, velocityY) ?? false;

  /// 停止当前拖动之外的惯性或程序滚动。
  void stopScroll() => _configuration.state?._stopScroll();

  /// 返回空闲、拖动或惯性滚动状态。
  int getScrollState() => _configuration.state?._scrollState ?? SCROLL_STATE_IDLE;

  /// 注册滚动状态与位移监听器。
  void addOnScrollListener(OnScrollListener listener) {
    if (!_configuration.listeners.contains(listener)) _configuration.listeners.add(listener);
  }

  /// 移除已经注册的滚动监听器。
  void removeOnScrollListener(OnScrollListener listener) => _configuration.listeners.remove(listener);

  /// 移除全部滚动监听器。
  void clearOnScrollListeners() => _configuration.listeners.clear();

  /// 查找当前可见布局中指定适配器位置的条目。
  ViewHolder? findViewHolderForAdapterPosition(int position) =>
      _configuration.state?._element?._holderForAdapterPosition(position);

  /// 查找最近布局中指定位置的可见条目。
  ViewHolder? findViewHolderForLayoutPosition(int position) =>
      _configuration.state?._element?._findHolder((holder) => holder.getLayoutPosition() == position);

  /// 查找当前可见布局中具有指定稳定标识的条目。
  ViewHolder? findViewHolderForItemId(int id) => getAdapter()?.hasStableIds() == true
      ? _configuration.state?._element?._findHolder((holder) => holder.getItemId() == id)
      : null;

  /// 返回条目视图所属的可见 ViewHolder。
  ViewHolder? getChildViewHolder(Widget child) =>
      _configuration.state?._element?._findHolder((holder) => identical(holder.itemView, child));

  /// 返回条目视图在适配器中的最新位置。
  int getChildAdapterPosition(Widget child) => getChildViewHolder(child)?.getBindingAdapterPosition() ?? NO_POSITION;

  /// 返回条目视图在最近布局中的位置。
  int getChildLayoutPosition(Widget child) => getChildViewHolder(child)?.getLayoutPosition() ?? NO_POSITION;

  /// 返回是否正在计算条目布局。
  bool isComputingLayout() => _configuration.state?._element?._computingLayout ?? false;

  /// 返回适配器通知是否尚未提交到布局。
  bool hasPendingAdapterUpdates() => _configuration.state?._element?._pendingUpdates ?? false;

  @override
  State<RecyclerView> createState() => _RecyclerViewState();
}

/// 观察 RecyclerView 的滚动状态与屏幕坐标位移。
abstract class OnScrollListener {
  /// 在滚动状态发生变化时接收通知。
  void onScrollStateChanged(RecyclerView recyclerView, int newState) {}

  /// 在已经消费滚动位移后接收通知。
  void onScrolled(RecyclerView recyclerView, double dx, double dy) {}
}

class _RecyclerConfiguration {
  Adapter? adapter;
  LayoutManager? layout;
  RecycledViewPool pool = RecycledViewPool();
  EdgeInsets padding = EdgeInsets.zero;
  int cacheSize = 2;
  bool hasFixedSize = false;
  bool keepPoolOnAdapterChange = false;
  final List<OnScrollListener> listeners = [];
  _RecyclerViewState? state;
  _ScrollRequest? pendingScroll;

  void changed() => state?._configurationChanged();

  void scrollTo(int position, {bool smooth = false}) {
    if (position < 0) throw ArgumentError.value(position, 'position');
    if (state == null) {
      pendingScroll = _ScrollRequest(position, null);
    } else {
      state!._scrollToPosition(position, smooth: smooth);
    }
  }
}

class _ScrollRequest {
  _ScrollRequest(this.position, this.offset);
  final int position;
  final double? offset;
}

class _RecyclerViewState extends State<RecyclerView> {
  final _pointerScroll = _RecyclerPointerScroll();
  ScrollController? _internalScrollController;
  ScrollController get _scrollController => widget.controller ?? (_internalScrollController ??= ScrollController());
  late final _RecyclerObserver _observer = _RecyclerObserver(this);
  _RecyclerViewportElement? _element;
  Adapter? _appliedAdapter;
  LayoutManager? _appliedManager;
  RecycledViewPool? _appliedPool;
  int _scrollState = RecyclerView.SCROLL_STATE_IDLE;
  double _lastPixels = 0;
  bool _initialLayout = true;
  int _scrollGeneration = 0;
  bool _configurationScheduled = false;
  bool _contextActive = true;

  _RecyclerConfiguration get _config => widget._configuration;
  Adapter? get _adapter => _appliedAdapter;
  LinearLayoutManager? get _manager => _appliedManager as LinearLayoutManager?;
  RecycledViewPool get _pool => _appliedPool ?? _config.pool;

  @override
  void initState() {
    super.initState();
    if (_config.state != null) throw StateError('同一个 RecyclerView 实例不能同时挂载两次。');
    _config.state = this;
    _syncConfiguration();
    _scrollController.addListener(_didScroll);
  }

  @override
  void didUpdateWidget(RecyclerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      (oldWidget.controller ?? _internalScrollController)?.removeListener(_didScroll);
      _scrollController.addListener(_didScroll);
    }
    if (!identical(oldWidget, widget)) {
      oldWidget._configuration.state = null;
      if (_config.state != null) throw StateError('同一个 RecyclerView 实例不能同时挂载两次。');
      _config.state = this;
      _configurationChanged();
    }
  }

  void _syncConfiguration() {
    if (!identical(_appliedAdapter, _config.adapter)) {
      final old = _appliedAdapter;
      _appliedAdapter = _config.adapter;
      _element?._replaceAdapter(old, keepPool: _config.keepPoolOnAdapterChange);
      _config.keepPoolOnAdapterChange = false;
      old?.unregisterAdapterDataObserver(_observer);
      old?.onDetachedFromRecyclerView(widget);
      _adapter?.registerAdapterDataObserver(_observer);
      _adapter?.onAttachedToRecyclerView(widget);
      _initialLayout = true;
    }
    if (!identical(_appliedPool, _config.pool)) {
      if (_appliedPool != null) _element?._replacePool(_appliedPool!);
      _appliedPool = _config.pool;
    }
    if (!identical(_appliedManager, _config.layout)) {
      _appliedManager?._state = null;
      final next = _config.layout;
      if (next?._state != null && !identical(next!._state, this)) {
        throw StateError('同一个 LayoutManager 不能连接两个 RecyclerView。');
      }
      _appliedManager = next;
      _manager?._state = this;
      _layoutManagerChanged();
    }
  }

  void _configurationChanged() {
    // 父级 build/useEffect 期间不能嵌套 buildScope；本帧沿用已提交配置，再安全切换。
    if (_element != null && SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (!_configurationScheduled) {
        _configurationScheduled = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _configurationScheduled = false;
          if (mounted) _configurationChanged();
        });
      }
      return;
    }
    _syncConfiguration();
    _element?.renderObject.markNeedsLayout();
    if (mounted) setState(() {});
  }

  void _layoutManagerChanged() {
    _element?._resetGeometry();
    _initialLayout = true;
    if (mounted) setState(() {});
  }

  AxisDirection _axisDirection(BuildContext context) {
    final manager = _manager;
    if (manager == null || manager._orientation == RecyclerView.VERTICAL) {
      return manager?._reverseLayout == true ? AxisDirection.up : AxisDirection.down;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return (manager._reverseLayout != rtl) ? AxisDirection.left : AxisDirection.right;
  }

  void _didScroll() {
    if (!_contextActive) return;
    if (!_scrollController.hasClients) return;
    final pixels = _scrollController.position.pixels;
    final delta = pixels - _lastPixels;
    _lastPixels = pixels;
    if (delta == 0) return;
    _element?._scrollDelta = delta;
    final direction = _axisDirection(context);
    final physical = axisDirectionIsReversed(direction) ? -delta : delta;
    for (final listener in List<OnScrollListener>.of(_config.listeners)) {
      listener.onScrolled(
        widget,
        axisDirectionToAxis(direction) == Axis.horizontal ? physical : 0,
        axisDirectionToAxis(direction) == Axis.vertical ? physical : 0,
      );
    }
  }

  void _setScrollState(int value) {
    if (_scrollState == value) return;
    _scrollState = value;
    for (final listener in List<OnScrollListener>.of(_config.listeners)) {
      listener.onScrollStateChanged(widget, value);
    }
  }

  bool _notification(ScrollNotification notification) {
    // 退出树时仍需同步结束 Activity，但终态不能冒泡到已经停用的 Material 等祖先。
    if (!_contextActive) return true;
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _scrollGeneration++;
        _config.pendingScroll = null;
      }
      _setScrollState(
        notification.dragDetails == null ? RecyclerView.SCROLL_STATE_SETTLING : RecyclerView.SCROLL_STATE_DRAGGING,
      );
    } else if (notification is ScrollEndNotification) {
      _setScrollState(RecyclerView.SCROLL_STATE_IDLE);
    } else if (notification is ScrollUpdateNotification && notification.dragDetails == null) {
      _setScrollState(RecyclerView.SCROLL_STATE_SETTLING);
    }
    return false;
  }

  void _scrollToPosition(int position, {double? offset, bool smooth = false}) {
    if (position < 0) throw ArgumentError.value(position, 'position');
    final count = _adapter?.getItemCount() ?? 0;
    if (count == 0) {
      _config.pendingScroll = _ScrollRequest(position, offset);
      return;
    }
    final target = math.min(position, count - 1);
    final element = _element;
    final generation = ++_scrollGeneration;
    if (smooth && element != null && _scrollController.hasClients) {
      final destination = element
          ._offsetForPosition(target, element.renderObject.leadingPadding + (offset ?? 0))
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      unawaited(
        _scrollController
            .animateTo(destination, duration: const Duration(milliseconds: 250), curve: Curves.easeOut)
            .then((_) {
              if (!mounted || generation != _scrollGeneration) return;
              _config.pendingScroll = _ScrollRequest(target, offset);
              _element?.renderObject.markNeedsLayout();
            }),
      );
    } else {
      _stopScroll();
      _config.pendingScroll = _ScrollRequest(target, offset);
      element?.renderObject.markNeedsLayout();
    }
  }

  void _scrollBy(double dx, double dy, {bool smooth = false}) {
    if (!_scrollController.hasClients) return;
    _scrollGeneration++;
    _config.pendingScroll = null;
    final direction = _axisDirection(context);
    var delta = axisDirectionToAxis(direction) == Axis.vertical ? dy : dx;
    if (axisDirectionIsReversed(direction)) delta = -delta;
    final position = _scrollController.position;
    final target = (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (smooth) {
      unawaited(
        _scrollController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  bool _fling(double velocityX, double velocityY) {
    if (!_scrollController.hasClients) return false;
    final position = _scrollController.position;
    if (position is! ScrollPositionWithSingleContext) return false;
    final direction = _axisDirection(context);
    var velocity = axisDirectionToAxis(direction) == Axis.vertical ? velocityY : velocityX;
    if (!velocity.isFinite || velocity.abs() < position.physics.minFlingVelocity) return false;
    if (axisDirectionIsReversed(direction)) velocity = -velocity;
    _scrollGeneration++;
    _config.pendingScroll = null;
    _setScrollState(RecyclerView.SCROLL_STATE_SETTLING);
    final maximum = position.physics.maxFlingVelocity;
    position.goBallistic(velocity.clamp(-maximum, maximum));
    return true;
  }

  void _stopScroll() {
    _scrollGeneration++;
    _config.pendingScroll = null;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.pixels);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configuredSmoothScroll = ElViewProvider.smoothScrollOf(context);
    final smoothScroll = configuredSmoothScroll is ElNoSmoothScroll ? null : configuredSmoothScroll;
    return Listener(
      onPointerDown: (_) => _cancelPositionRequest(),
      onPointerSignal: (_) => _cancelPositionRequest(),
      onPointerPanZoomStart: (_) => _cancelPositionRequest(),
      child: NotificationListener<ScrollNotification>(
        onNotification: _notification,
        child: Scrollable(
          controller: _scrollController,
          axisDirection: _axisDirection(context),
          viewportBuilder: (context, offset) {
            final direction = _axisDirection(context);
            final configuration = ScrollConfiguration.of(context);
            _pointerScroll.bind(offset as ScrollPosition, smoothScroll);
            // 比本 Scrollable 更早仲裁滚轮，同时让真正嵌套的子列表保持优先权。
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _pointerScroll.reset(),
              onPointerPanZoomStart: (_) => _pointerScroll.reset(),
              onPointerSignal: (event) => _pointerScroll.handle(event, direction, configuration.pointerAxisModifiers),
              child: _RecyclerViewport(
                state: this,
                offset: offset,
                axisDirection: direction,
                refreshRate: View.of(context).display.refreshRate,
              ),
            );
          },
        ),
      ),
    );
  }

  void _cancelPositionRequest() {
    _scrollGeneration++;
    _config.pendingScroll = null;
  }

  @override
  void deactivate() {
    _contextActive = false;
    _scrollState = RecyclerView.SCROLL_STATE_IDLE;
    // 子 Scrollable 尚可保存位置，祖先终态通知则由本层截断。
    _pointerScroll.suspend();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _contextActive = true;
    _pointerScroll.resume();
  }

  @override
  void dispose() {
    _pointerScroll.dispose();
    _appliedAdapter?.unregisterAdapterDataObserver(_observer);
    _appliedAdapter?.onDetachedFromRecyclerView(widget);
    _appliedManager?._state = null;
    _config.state = null;
    _scrollController.removeListener(_didScroll);
    _internalScrollController?.dispose();
    super.dispose();
  }
}

class _RecyclerObserver extends AdapterDataObserver {
  _RecyclerObserver(this.state);
  final _RecyclerViewState state;

  @override
  void onChanged() => state._element?._dataChanged();

  @override
  void onItemRangeChanged(int positionStart, int itemCount, [Object? payload]) =>
      state._element?._itemsChanged(positionStart, itemCount, payload);

  @override
  void onItemRangeInserted(int positionStart, int itemCount) =>
      state._element?._itemsInserted(positionStart, itemCount);

  @override
  void onItemRangeRemoved(int positionStart, int itemCount) => state._element?._itemsRemoved(positionStart, itemCount);

  @override
  void onItemRangeMoved(int fromPosition, int toPosition, int itemCount) =>
      state._element?._itemMoved(fromPosition, toPosition);
}
