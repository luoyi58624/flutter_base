import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter_base.dart';

import 'chrome.dart';
import 'feed.dart';
import 'header_motion.dart';

part 'plain.dart';

const _pink = Color(0xfffb7299);
const _background = Color(0xfff1f2f4);
const _searchHeight = 58.0;
const _tabsHeight = 43.0;
const _bottomHeight = 56.0;
const _channels = ['直播', '推荐', '热门', '动画', '影视', 'S16', '知识', '游戏', '音乐', '生活'];
const _recommended = 1;
const _physics = ClampingScrollPhysics();

/// 独立的 Bibi 首页，复现原生样板的折叠、翻页和刷新交互。
class BibiPage extends StatefulWidget {
  /// 创建首页示例。
  const BibiPage({super.key});

  @override
  State<BibiPage> createState() => _BibiPageState();
}

class _BibiPageState extends State<BibiPage> with TickerProviderStateMixin {
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
      // 等用户回到顶部并停稳才更新推荐，保住正在浏览的卡片位置。
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
                    // 只平移正文视口，页头跟手时保持列表的布局尺寸与惯性活动。
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
                          _BibiFeed(
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
                  pager: _pager,
                  channels: _channels,
                  onSelect: _selectChannel,
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

class _FeedController extends ScrollController {
  _FeedController({super.onAttach, super.onDetach}) : super(keepScrollOffset: false);

  double restoreOffset = 0;

  @override
  double get initialScrollOffset => restoreOffset;
}

class _BibiFeed extends StatefulWidget {
  const _BibiFeed({
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
  State<_BibiFeed> createState() => _BibiFeedState();
}

class _BibiFeedState extends State<_BibiFeed> {
  final _showRefresh = ValueNotifier(true);
  late final _refresher = _BibiRefresher(_showRefresh);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateRefreshVisibility);
    widget.header.offset.addListener(_updateRefreshVisibility);
    widget.pager.addListener(_updateRefreshVisibility);
    _updateRefreshVisibility();
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

  @override
  void dispose() {
    widget.controller.removeListener(_updateRefreshVisibility);
    widget.header.offset.removeListener(_updateRefreshVisibility);
    widget.pager.removeListener(_updateRefreshVisibility);
    _showRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.header.bindPage(
    widget.index,
    child: ElRefresh(
      refresher: _refresher,
      onRefresh: widget.onRefresh,
      child: ElScroll.sliver(
        controller: widget.controller,
        physics: _physics,
        slivers: [
          SliverToBoxAdapter(child: buildBibiBanner(context, widget.generation)),
          SliverPadding(
            padding: EdgeInsets.only(bottom: 4),
            sliver: SliverList.builder(
              key: ValueKey('bibi-rows-${widget.generation}'),
              itemCount: bibiVideoRowCount,
              // 每行自带重绘边界，不再叠加官方列表的默认边界。
              addRepaintBoundaries: false,
              itemBuilder: (context, index) => buildBibiVideoRow(context, index, widget.generation),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BibiRefresher extends ElAndroidRefresher {
  _BibiRefresher(this.atTop) : super(color: _pink, bgColor: Colors.white);

  final ValueListenable<bool> atTop;

  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) =>
      _BibiRefreshIndicator(atTop: atTop, snapshot: details.snapshot, child: super.buildIndicator(context, details));
}

class _BibiRefreshIndicator extends StatefulWidget {
  const _BibiRefreshIndicator({required this.atTop, required this.snapshot, required this.child});

  final ValueListenable<bool> atTop;
  final ValueListenable<ElRefreshSnapshot> snapshot;
  final Widget child;

  @override
  State<_BibiRefreshIndicator> createState() => _BibiRefreshIndicatorState();
}

class _BibiRefreshIndicatorState extends State<_BibiRefreshIndicator> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.atTop, widget.snapshot]),
    child: widget.child,
    builder: (context, child) {
      final status = widget.snapshot.value.status;
      if (status == RefreshIndicatorStatus.refresh || status == RefreshIndicatorStatus.done) {
        if (!widget.atTop.value) _dismissed = true;
      } else {
        _dismissed = false;
      }
      return IgnorePointer(
        child: AnimatedOpacity(
          key: ValueKey('bibi-refresh-indicator'),
          opacity: widget.atTop.value && !_dismissed ? 1 : 0,
          duration: Duration(milliseconds: 150),
          child: child,
        ),
      );
    },
  );
}
