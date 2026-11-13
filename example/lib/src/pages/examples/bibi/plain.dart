part of 'index.dart';

const _plainInitialCards = 20;
const _plainPageCards = 10;
const _plainLoadDistance = 200.0;
const _plainLoadDelay = Duration(milliseconds: 100);

/// 非虚拟滚动的 Bibi 首页。卡片按页留在树上，距底部 200px 再追加。
class BibiPlainPage extends StatefulWidget {
  /// 创建非虚拟首页。
  const BibiPlainPage({super.key});

  @override
  State<BibiPlainPage> createState() => _BibiPlainPageState();
}

class _BibiPlainPageState extends State<BibiPlainPage> with TickerProviderStateMixin {
  final _pager = ElTabController(length: _channels.length, initialIndex: _recommended);
  late final _header = BibiHeaderMotion(this, extent: _searchHeight);
  late final List<_FeedController> _feeds;
  int _active = _recommended;
  int _generation = 0;
  Timer? _refreshTimer;
  Completer<void>? _refreshRequest;
  bool _refreshReady = false;
  bool _applyQueued = false;

  @override
  void initState() {
    super.initState();
    _feeds = List.generate(_channels.length, (_) {
      return _FeedController(onAttach: _attachPosition, onDetach: _detachPosition)..addListener(_queueRefreshApply);
    });
    _header.setActivePage(_active);
    _header.offset.addListener(_queueRefreshApply);
    _pager.addListener(_queueRefreshApply);
  }

  void _attachPosition(ScrollPosition position) => position.isScrollingNotifier.addListener(_queueRefreshApply);
  void _detachPosition(ScrollPosition position) => position.isScrollingNotifier.removeListener(_queueRefreshApply);

  void _moveFeedsTo(double offset) {
    for (final controller in _feeds) {
      controller.restoreOffset = offset;
      if (!controller.hasClients || !controller.position.hasContentDimensions) continue;
      final position = controller.position;
      final target = offset.clamp(position.minScrollExtent, position.maxScrollExtent);
      if (position.pixels != target || position.isScrollingNotifier.value) controller.jumpTo(target);
    }
  }

  void _syncFeeds() {
    final current = _feeds[_active];
    _moveFeedsTo(current.hasClients ? current.offset : current.restoreOffset);
  }

  void _selectChannel(int index) {
    if (index == _active && !_pager.isAnimating && !_pager.isDragging) return;
    _syncFeeds();
    if ((index - _active).abs() > 1) {
      _pager.jumpTo(index);
      _pageChanged(index);
    } else {
      unawaited(_pager.animateTo(index));
    }
  }

  void _pageChanged(int index) {
    if (_active == index) return;
    _active = index;
    _header.setActivePage(index);
    _queueRefreshApply();
  }

  void _returnToTop() {
    _moveFeedsTo(0);
    _header.reset();
    _queueRefreshApply();
  }

  Future<void> _refresh() {
    final running = _refreshRequest;
    if (running != null) return running.future;
    if (_refreshReady) {
      _queueRefreshApply();
      return Future.value();
    }
    final request = _refreshRequest = Completer<void>();
    _refreshTimer = Timer(Duration(milliseconds: 500), () {
      _refreshTimer = null;
      _refreshRequest = null;
      _refreshReady = true;
      _queueRefreshApply();
      request.complete();
    });
    return request.future;
  }

  bool get _canReplaceFeed {
    final feed = _feeds[_active];
    if (_header.offset.value != 0 || _pager.isAnimating || _pager.isDragging || !feed.hasClients) return false;
    final position = feed.position;
    return position.hasContentDimensions &&
        position.pixels <= position.minScrollExtent &&
        !position.isScrollingNotifier.value;
  }

  void _queueRefreshApply() {
    if (!mounted || !_refreshReady || _applyQueued || !_canReplaceFeed) return;
    _applyQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyQueued = false;
      if (!mounted || !_refreshReady || !_canReplaceFeed) return;
      _refreshReady = false;
      _moveFeedsTo(0);
      setState(() => _generation++);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshRequest?.complete();
    _header.offset.removeListener(_queueRefreshApply);
    _header.dispose();
    _pager.dispose();
    for (final feed in _feeds) {
      feed.removeListener(_queueRefreshApply);
      for (final position in feed.positions) {
        _detachPosition(position);
      }
      feed.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewPaddingOf(context);
    final navigator = Navigator.of(context);
    final behavior = ScrollConfiguration.of(context);
    return Scaffold(
      backgroundColor: _background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
        child: ScrollConfiguration(
          behavior: behavior.copyWith(
            overscroll: false,
            scrollbars: false,
            dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse},
          ),
          child: Stack(
            children: [
              Positioned.fill(
                top: insets.top + _tabsHeight,
                bottom: insets.bottom + _bottomHeight,
                child: ClipRect(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _header.offset,
                    builder: (context, offset, child) =>
                        Transform.translate(offset: Offset(0, _searchHeight - offset), child: child),
                    child: ElTabView(
                      key: ValueKey('bibi-pager'),
                      controller: _pager,
                      physics: _physics,
                      lazy: true,
                      maxCacheCount: 3,
                      onDragStateChanged: (dragging) {
                        if (dragging) _syncFeeds();
                      },
                      onIndexChanged: _pageChanged,
                      children: [
                        for (var index = 0; index < _channels.length; index++)
                          _BibiPlainFeed(
                            key: ValueKey('bibi-feed-$index'),
                            index: index,
                            generation: _generation,
                            controller: _feeds[index],
                            header: _header,
                            pager: _pager,
                            onRefresh: _refresh,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: insets.top + _searchHeight + _tabsHeight,
                child: BibiHeader(
                  offset: _header.offset,
                  statusInset: insets.top,
                  channelBarBuilder: (progress) => BibiChannelBar(
                    progress: progress,
                    pager: _pager,
                    channels: _channels,
                    onSelect: _selectChannel,
                    onSearch: () => showBibiSearch(context, _generation),
                  ),
                  onSearch: () => showBibiSearch(context, _generation),
                  onBack: navigator.maybePop,
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: insets.bottom + _bottomHeight,
                child: BibiBottomBar(
                  bottomInset: insets.bottom,
                  onHome: _returnToTop,
                  onFollowing: () => _selectChannel(2),
                  onBack: navigator.maybePop,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BibiPlainFeed extends StatefulWidget {
  const _BibiPlainFeed({
    super.key,
    required this.index,
    required this.generation,
    required this.controller,
    required this.header,
    required this.pager,
    required this.onRefresh,
  });

  final int index;
  final int generation;
  final ScrollController controller;
  final BibiHeaderMotion header;
  final ElTabController pager;
  final Future<void> Function() onRefresh;

  @override
  State<_BibiPlainFeed> createState() => _BibiPlainFeedState();
}

class _BibiPlainFeedState extends State<_BibiPlainFeed> {
  final _showRefresh = ValueNotifier(true);
  late final _refresher = _BibiRefresher(_showRefresh);
  int _cards = _plainInitialCards;
  int _ticket = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
    widget.header.offset.addListener(_updateRefreshVisibility);
    widget.pager.addListener(_updateRefreshVisibility);
    _updateRefreshVisibility();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeLoad();
    });
  }

  @override
  void didUpdateWidget(_BibiPlainFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generation != widget.generation) {
      _ticket++;
      _cards = _plainInitialCards;
      _loading = false;
    }
  }

  void _onController() {
    _updateRefreshVisibility();
    _maybeLoad();
  }

  void _updateRefreshVisibility() {
    final controller = widget.controller;
    _showRefresh.value =
        widget.pager.index == widget.index &&
        !widget.pager.isDragging &&
        !widget.pager.isAnimating &&
        widget.header.offset.value == 0 &&
        (!controller.hasClients ||
            !controller.position.hasContentDimensions ||
            controller.offset <= controller.position.minScrollExtent);
  }

  /// 距底部不足 200px 时，等 100ms 再挂上下一批 10 张卡片。
  void _maybeLoad() {
    if (_loading) return;
    final controller = widget.controller;
    if (!controller.hasClients || !controller.position.hasContentDimensions) return;
    final position = controller.position;
    if (position.maxScrollExtent - position.pixels > _plainLoadDistance) return;
    _loading = true;
    final ticket = ++_ticket;
    Future<void>.delayed(_plainLoadDelay, () {
      if (!mounted || ticket != _ticket) return;
      setState(() => _cards += _plainPageCards);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _ticket++;
    widget.controller.removeListener(_onController);
    widget.header.offset.removeListener(_updateRefreshVisibility);
    widget.pager.removeListener(_updateRefreshVisibility);
    _showRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chunks = <Widget>[];
    var row = 0;
    var placed = 0;
    var chunk = 0;
    while (placed < _cards) {
      final count = chunk == 0 ? _plainInitialCards : _plainPageCards;
      final rows = count ~/ 2;
      final start = row;
      chunks.add(
        ElRebuildWidget(
          key: ValueKey('bibi-plain-${widget.generation}-$chunk'),
          child: RepaintBoundary(
            child: Column(
              mainAxisSize: .min,
              children: [
                for (var index = 0; index < rows; index++) buildBibiVideoRow(context, start + index, widget.generation),
              ],
            ),
          ),
        ),
      );
      row += rows;
      placed += count;
      chunk++;
    }
    return widget.header.bindPage(
      widget.index,
      child: ElScrollView.sliver(
        controller: widget.controller,
        physics: _physics,
        slivers: [
          ElSliverRefresh(refresher: _refresher, onRefresh: widget.onRefresh),
          SliverPadding(
            padding: EdgeInsets.only(bottom: 4),
            sliver: ElSliverList(stretch: true, children: [buildBibiBanner(context, widget.generation), ...chunks]),
          ),
        ],
      ),
    );
  }
}
