import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 管理 Bibi 首页分页，频道数据由各频道独立保存。
class BibiState extends ElHookState {
  /// 从推荐频道进入首页，折叠进度由页头和正文共同使用。
  BibiState({required int channelCount, required int initialIndex, required this.collapse})
    : pager = ElTabController(length: channelCount, initialIndex: initialIndex),
      _active = initialIndex;

  final AnimationController collapse;
  final ElTabController pager;
  final _channels = <int, BibiChannelState>{};
  int _active;

  /// 当前已经停稳的频道。
  int get active => _active;

  /// 频道视图按需挂载，数据和位置在视图被移出缓存后仍保留。
  BibiChannelState channel(int index) => _channels.putIfAbsent(index, BibiChannelState.new);

  /// 暂停当前频道的纵向惯性，避免翻页时它继续推动共享页头。
  void stopScrolling() {
    final controller = channel(active).controller;
    if (controller.hasClients && controller.position.isScrollingNotifier.value) {
      controller.jumpTo(controller.offset);
    }
  }

  @override
  void initState() => pager.addListener(_updateActive);

  void _updateActive() {
    if (pager.isDragging || pager.isAnimating || pager.position != pager.index || _active == pager.index) return;
    _active = pager.index;
    notify();
  }

  /// 切换频道，邻页使用现有分页动画。
  void selectChannel(int index) {
    if (index == active && !pager.isDragging && !pager.isAnimating) return;
    stopScrolling();
    if ((index - active).abs() > 1) {
      pager.jumpTo(index);
    } else {
      unawaited(pager.animateTo(index));
    }
  }

  /// 回到当前频道的顶部并展开搜索栏。
  void returnToTop() {
    final controller = channel(active).controller;
    if (controller.hasClients) controller.jumpTo(0);
    collapse.value = 0;
  }

  @override
  void dispose() {
    pager.removeListener(_updateActive);
    pager.dispose();
    for (final channel in _channels.values) {
      channel.dispose();
    }
    super.dispose();
  }
}

/// 独立管理一个频道的本地请求、分页和滚动位置。
class BibiChannelState extends ElHookState {
  static const _initialBatches = 2;

  /// 保留频道自己的滚动位置。
  late final controller = ScrollController(onAttach: _attach, onDetach: _detach)..addListener(applyPendingRefresh);
  Timer? _load;
  Timer? _refreshTimer;
  Completer<void>? _refresh;
  bool _refreshReady = false;
  bool _applyQueued = false;
  bool _disposed = false;
  int _count = 0;
  int _generation = 0;

  /// 当前可渲染的数据批次和刷新代次。
  ({int count, int generation}) get data => (count: _count, generation: _generation);

  /// 是否正在等待触底追加。
  bool get isLoading => _load != null;

  void _attach(ScrollPosition position) => position.isScrollingNotifier.addListener(applyPendingRefresh);

  void _detach(ScrollPosition position) => position.isScrollingNotifier.removeListener(applyPendingRefresh);

  /// 首次请求和下拉刷新共用本地请求，刷新优先于触底追加。
  Future<void> refresh() {
    if (_refresh case final request?) return request.future;
    if (_refreshReady) {
      applyPendingRefresh();
      return Future.value();
    }
    final request = _refresh = Completer<void>();
    if (isLoading) {
      _load!.cancel();
      _load = null;
      notify();
    }
    _refreshTimer = Timer(Duration(milliseconds: 500), () {
      _refreshTimer = null;
      _refresh = null;
      _refreshReady = true;
      applyPendingRefresh();
      request.complete();
    });
    return request.future;
  }

  bool get _canApplyRefresh {
    if (_count == 0) return true;
    if (!controller.hasClients) return false;
    final position = controller.position;
    return position.hasContentDimensions && position.extentBefore == 0 && !position.isScrollingNotifier.value;
  }

  /// 刷新期间离开顶部时，等该频道回到顶部停稳再替换旧列表。
  void applyPendingRefresh() {
    if (!_refreshReady || _applyQueued || !_canApplyRefresh) return;
    _applyQueued = true;
    nextTick(() {
      _applyQueued = false;
      if (_disposed || !_refreshReady || !_canApplyRefresh) return;
      _refreshReady = false;
      if (_count != 0) _generation++;
      _count = _initialBatches;
      notify();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// 触底后追加一批，合并重复触底通知。
  void loadMore() {
    if (_count == 0 || _refresh != null || _refreshReady || isLoading) return;
    _load = Timer(Duration(milliseconds: 100), () {
      _load = null;
      _count++;
      notify();
    });
    notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _refresh?.complete();
    _load?.cancel();
    for (final position in controller.positions) {
      _detach(position);
    }
    controller.dispose();
    super.dispose();
  }
}
