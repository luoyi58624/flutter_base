import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter_base.dart';

import '../bibi/navigation_header/index.dart';
import '../bibi/cards/feed.dart';
import '../bibi/tab_bar/index.dart';

part 'refresh.dart';

const _pink = Color(0xfffb7299);
const _background = Color(0xfff1f2f4);
const _searchHeight = 58.0;
const _tabsHeight = 43.0;
const _bottomHeight = 56.0;
const _channels = ['直播', '推荐', '热门', '动画', '影视', 'S16', '知识', '游戏', '音乐', '生活'];
const _recommended = 1;

/// 使用官方 CustomScrollView / SliverList 复刻 Bibi 首页，不依赖 ElScrollView。
///
/// 每个频道只有一份正文 ScrollPosition；页头是独立的有限行程，
/// 先消费拖拽与惯性，再将剩余量交给正文，Viewport 始终保持原有布局尺寸。
class SliverBibiPage extends StatefulWidget {
  const SliverBibiPage({super.key});

  @override
  SliverBibiPageState createState() => SliverBibiPageState();
}

/// Bibi 对照页的状态；测试入口暴露真实 Sliver 位置与刷新行程。
class SliverBibiPageState extends State<SliverBibiPage> with SingleTickerProviderStateMixin {
  final _pager = ElTabController(length: _channels.length, initialIndex: _recommended);
  late final _headerOffset = AnimationController(vsync: this, upperBound: _searchHeight);
  late final List<_SliverFeedController> _feeds;
  final _velocities = List<double>.filled(_channels.length, 0);
  final _refreshMotions = <int, _SliverPullMotion>{};
  int _active = _recommended;
  int _generation = 0;
  Timer? _refreshTimer;
  Completer<void>? _refreshRequest;
  bool _refreshReady = false;
  bool _applyQueued = false;
  bool _snapScheduled = false;
  double? _snapTarget;
  int _snapGeneration = 0;
  int _downPointers = 0;

  /// 当前频道的真实正文像素偏移，不包含搜索栏的独立行程。
  @visibleForTesting
  double get debugScrollPixels => _feedPixels(_active);

  /// 当前搜索栏的折叠距离。
  @visibleForTesting
  double get debugHeaderOffset => _headerOffset.value;

  /// 指定频道的刷新过程快照（频道尚未挂载时返回 null）。
  @visibleForTesting
  ElRefreshSnapshot? debugRefreshSnapshot(int index) => _refreshMotions[index]?.snapshot.value;

  double _feedPixels(int index) {
    final controller = _feeds[index];
    if (controller.hasClients && controller.position.hasPixels) return controller.position.pixels;
    return controller.restoreOffset;
  }

  @override
  void initState() {
    super.initState();
    _feeds = List.generate(_channels.length, (index) {
      final controller = _SliverFeedController(
        onBallistic: (velocity) {
          // 弹道自然结束时框架会再调用 goBallistic(0)，不能抹掉真实甩动方向。
          if (velocity != 0) _velocities[index] = velocity;
        },
        readMotion: () => _refreshMotions[index],
        onAttach: (position) => position.isScrollingNotifier.addListener(_checkRefreshApply),
        onDetach: (position) => position.isScrollingNotifier.removeListener(_checkRefreshApply),
      );
      controller.addListener(() => _onFeedMoved(index));
      return controller;
    });
    _pager.addListener(_checkRefreshApply);
    _headerOffset.addListener(_checkRefreshApply);
  }

  void _onFeedMoved(int index) {
    if (index != _active) return;
    // 正文像素不再决定页头折叠量；深处拖拽也必须能够单独推动搜索栏。
    _checkRefreshApply();
  }

  void _moveFeedsTo(double pixels) {
    for (final feed in _feeds) {
      feed.restoreOffset = pixels;
      if (!feed.hasClients || !feed.position.hasContentDimensions) continue;
      final position = feed.position;
      final target = pixels.clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
      if ((position.pixels - target).abs() > 0.001 || position.isScrollingNotifier.value) feed.jumpTo(target);
    }
  }

  void _syncFeeds() => _moveFeedsTo(_feedPixels(_active));

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
    _refreshMotions[_active]?.onPageDeactivated();
    final previous = _feeds[_active];
    if (previous.hasClients && previous.position is ScrollPositionWithSingleContext) {
      (previous.position as ScrollPositionWithSingleContext).goIdle();
    }
    _snapGeneration++;
    _snapTarget = null;
    _active = index;
    _onFeedMoved(index);
    _checkRefreshApply();
  }

  void _returnToTop() {
    _snapGeneration++;
    _snapTarget = null;
    _headerOffset.stop();
    _moveFeedsTo(0);
    _headerOffset.value = 0;
    _checkRefreshApply();
  }

  Future<void> _refresh() {
    final running = _refreshRequest;
    if (running != null) return running.future;
    if (_refreshReady) {
      _checkRefreshApply();
      return Future<void>.value();
    }
    final request = _refreshRequest = Completer<void>();
    _refreshTimer = Timer(Duration(milliseconds: 500), () {
      _refreshTimer = null;
      _refreshRequest = null;
      _refreshReady = true;
      _checkRefreshApply();
      request.complete();
    });
    return request.future;
  }

  bool get _canReplaceFeed {
    final feed = _feeds[_active];
    if (_headerOffset.value != 0 || _pager.isDragging || _pager.isAnimating || !feed.hasClients) return false;
    final position = feed.position;
    return position.hasContentDimensions &&
        position.pixels <= position.minScrollExtent &&
        !position.isScrollingNotifier.value;
  }

  void _checkRefreshApply() {
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

  void _onPointerDown(int index) {
    if (index == _active) _downPointers++;
  }

  void _onPointerUp(int index) {
    if (index != _active) return;
    _downPointers = math.max(0, _downPointers - 1);
    _scheduleHeaderSnap(index);
  }

  void _onPointerCancel(int index) => _onPointerUp(index);

  bool _onScrollNotification(int index, ScrollNotification notification) {
    if (index != _active || notification.depth != 0 || notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollStartNotification && notification.dragDetails != null) {
      // 只有正式开始拖拽才取消吸附，轻点不会打断动画。
      _snapGeneration++;
      _snapTarget = null;
      _headerOffset.stop();
      _velocities[index] = 0;
    } else if (notification is ScrollEndNotification) {
      _scheduleHeaderSnap(index);
    }
    return false;
  }

  void _scheduleHeaderSnap(int index) {
    if (_snapScheduled) return;
    _snapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snapScheduled = false;
      if (!mounted || _active != index || _downPointers > 0 || _pager.isDragging || _pager.isAnimating) return;
      final feed = _feeds[index];
      if (!feed.hasClients || !feed.position.hasContentDimensions || feed.position.isScrollingNotifier.value) return;
      final pixels = _headerOffset.value;
      if (pixels <= 0 || pixels >= _searchHeight) {
        _snapTarget = null;
        return;
      }
      final velocity = _velocities[index];
      final target =
          _snapTarget ??
          (velocity.abs() >= 50
              ? (velocity > 0 ? _searchHeight : 0.0)
              : (pixels >= _searchHeight / 2 ? _searchHeight : 0.0));
      if ((pixels - target).abs() < 0.01) {
        _snapTarget = null;
        return;
      }
      _snapTarget = target;
      final generation = ++_snapGeneration;
      unawaited(_animateHeaderSnap(target, generation));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _animateHeaderSnap(double target, int generation) async {
    try {
      await _headerOffset
          .animateTo(target, duration: Duration(milliseconds: 180), curve: Curves.easeInOutSine)
          .orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted && generation == _snapGeneration) _snapTarget = null;
  }

  void _onWheelSettled(int index, double direction) {
    if (index != _active) return;
    _velocities[index] = direction * 100;
    _scheduleHeaderSnap(index);
  }

  void _registerMotion(int index, _SliverPullMotion motion) => _refreshMotions[index] = motion;

  void _unregisterMotion(int index, _SliverPullMotion motion) {
    if (identical(_refreshMotions[index], motion)) _refreshMotions.remove(index);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshRequest?.complete();
    _pager.removeListener(_checkRefreshApply);
    _headerOffset.removeListener(_checkRefreshApply);
    _pager.dispose();
    _headerOffset.dispose();
    for (final feed in _feeds) {
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
                    valueListenable: _headerOffset,
                    // 只平移完整视口，不改变布局尺寸或正文像素；保留原版 Bibi 的几何行为。
                    builder: (context, offset, child) =>
                        Transform.translate(offset: Offset(0, _searchHeight - offset), child: child),
                    child: ElTabView(
                      key: ValueKey('sliver-bibi-pager'),
                      controller: _pager,
                      physics: ClampingScrollPhysics(),
                      lazy: true,
                      maxCacheCount: 3,
                      onIndexChanged: _pageChanged,
                      onDragStateChanged: (dragging) {
                        if (dragging) _syncFeeds();
                      },
                      children: [
                        for (var index = 0; index < _channels.length; index++)
                          _SliverBibiFeed(
                            key: ValueKey('sliver-bibi-feed-$index'),
                            index: index,
                            generation: _generation,
                            controller: _feeds[index],
                            activeIndex: () => _active,
                            headerOffset: _headerOffset,
                            pager: _pager,
                            onRefresh: _refresh,
                            onScrollNotification: (notification) => _onScrollNotification(index, notification),
                            onPointerDown: () => _onPointerDown(index),
                            onPointerUp: () => _onPointerUp(index),
                            onPointerCancel: () => _onPointerCancel(index),
                            onWheelSettled: (direction) => _onWheelSettled(index, direction),
                            registerMotion: (motion) => _registerMotion(index, motion),
                            unregisterMotion: (motion) => _unregisterMotion(index, motion),
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
                  offset: _headerOffset,
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

class _SliverFeedController extends ScrollController {
  _SliverFeedController({required this.onBallistic, required this.readMotion, super.onAttach, super.onDetach})
    : super(keepScrollOffset: false);

  final ValueChanged<double> onBallistic;
  final _SliverPullMotion? Function() readMotion;
  double restoreOffset = 0;

  @override
  double get initialScrollOffset => restoreOffset;

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) =>
      _SliverFeedPosition(
        physics: physics,
        context: context,
        oldPosition: oldPosition,
        initialPixels: initialScrollOffset,
        onBallistic: onBallistic,
        readMotion: readMotion,
      );
}

class _SliverFeedPosition extends ScrollPositionWithSingleContext {
  _SliverFeedPosition({
    required super.physics,
    required super.context,
    required super.oldPosition,
    required super.initialPixels,
    required this.onBallistic,
    required this.readMotion,
  }) : super(keepScrollOffset: false);

  final ValueChanged<double> onBallistic;
  final _SliverPullMotion? Function() readMotion;
  double? _lastBallisticSample;

  @override
  void goBallistic(double velocity) {
    _lastBallisticSample = pixels;
    onBallistic(velocity);
    super.goBallistic(velocity);
  }

  @override
  double setPixels(double newPixels) {
    if (activity is BallisticScrollActivity) {
      // 官方仿真仍提供完整位移曲线，但先让页头消费每帧增量。
      // 仿真采样值与真实正文 pixels 不相等，因此必须单独保存上次采样。
      final previousSample = _lastBallisticSample ?? pixels;
      _lastBallisticSample = newPixels;
      final remaining = readMotion()?.consumeHeaderDelta(newPixels - previousSample) ?? (newPixels - previousSample);
      return super.setPixels(pixels + remaining);
    }
    return super.setPixels(newPixels);
  }

  @override
  void pointerScroll(double delta) {
    final remaining = readMotion()?.consumeWheelDelta(delta) ?? delta;
    if (remaining != 0) super.pointerScroll(remaining);
  }
}

class _SliverBibiFeed extends StatefulWidget {
  const _SliverBibiFeed({
    super.key,
    required this.index,
    required this.generation,
    required this.controller,
    required this.activeIndex,
    required this.headerOffset,
    required this.pager,
    required this.onRefresh,
    required this.onScrollNotification,
    required this.onPointerDown,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.onWheelSettled,
    required this.registerMotion,
    required this.unregisterMotion,
  });

  final int index;
  final int generation;
  final ScrollController controller;
  final int Function() activeIndex;
  final AnimationController headerOffset;
  final ElTabController pager;
  final Future<void> Function() onRefresh;
  final bool Function(ScrollNotification) onScrollNotification;
  final VoidCallback onPointerDown;
  final VoidCallback onPointerUp;
  final VoidCallback onPointerCancel;
  final ValueChanged<double> onWheelSettled;
  final ValueChanged<_SliverPullMotion> registerMotion;
  final ValueChanged<_SliverPullMotion> unregisterMotion;

  @override
  State<_SliverBibiFeed> createState() => _SliverBibiFeedState();
}

class _SliverBibiFeedState extends State<_SliverBibiFeed> with SingleTickerProviderStateMixin {
  late final _motion = _SliverPullMotion(
    vsync: this,
    header: widget.headerOffset,
    canStart: _canReceivePull,
    onWheelSettled: widget.onWheelSettled,
    onRefresh: () => widget.onRefresh(),
  );
  late final _physics = _SliverPullPhysics(_motion);
  final _indicatorVisible = ValueNotifier<bool>(false);
  final _refresher = ElAndroidRefresher(color: _pink, bgColor: Colors.white);

  bool _canReceivePull() =>
      mounted && widget.activeIndex() == widget.index && !widget.pager.isAnimating && !widget.pager.isDragging;

  bool _canPull() {
    final controller = widget.controller;
    return _canReceivePull() &&
        widget.headerOffset.value == 0 &&
        controller.hasClients &&
        controller.position.hasContentDimensions &&
        controller.position.pixels <= controller.position.minScrollExtent + 0.01;
  }

  void _updateIndicatorVisibility() {
    final next = _canPull();
    if (_indicatorVisible.value != next) _indicatorVisible.value = next;
  }

  @override
  void initState() {
    super.initState();
    widget.registerMotion(_motion);
    widget.controller.addListener(_updateIndicatorVisibility);
    widget.headerOffset.addListener(_updateIndicatorVisibility);
    widget.pager.addListener(_updateIndicatorVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateIndicatorVisibility();
    });
  }

  @override
  void dispose() {
    widget.unregisterMotion(_motion);
    widget.controller.removeListener(_updateIndicatorVisibility);
    widget.headerOffset.removeListener(_updateIndicatorVisibility);
    widget.pager.removeListener(_updateIndicatorVisibility);
    _indicatorVisible.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _updateIndicatorVisibility();
          return widget.onScrollNotification(notification);
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {
            _motion.pointerDown();
            widget.onPointerDown();
          },
          onPointerUp: (_) {
            _motion.pointerUp();
            widget.onPointerUp();
          },
          onPointerCancel: (_) {
            _motion.pointerCancel();
            widget.onPointerCancel();
          },
          child: CustomScrollView(
            key: ValueKey('sliver-bibi-scroll-${widget.index}'),
            controller: widget.controller,
            physics: _physics,
            slivers: [
              // 正文依然是标准 Sliver；搜索栏通过统一输入分账，不占据正文的滚动区间。
              SliverToBoxAdapter(child: buildBibiBanner(context, widget.generation)),
              SliverPadding(
                padding: EdgeInsets.only(bottom: 4),
                sliver: SliverList.builder(
                  key: ValueKey('sliver-bibi-rows-${widget.generation}'),
                  itemCount: bibiVideoRowCount,
                  itemBuilder: (context, row) => buildBibiVideoRow(context, row, widget.generation),
                ),
              ),
            ],
          ),
        ),
      ),
      Positioned.fill(
        // 外层已经按搜索栏行程平移整个正文视口；刷新层与视口共用顶部坐标。
        child: ValueListenableBuilder<bool>(
          valueListenable: _indicatorVisible,
          builder: (context, visible, _) => AnimatedOpacity(
            key: ValueKey('sliver-bibi-refresh-indicator'),
            duration: Duration(milliseconds: 150),
            opacity: visible ? 1 : 0,
            child: IgnorePointer(child: _refresher.buildIndicator(context, _motion.snapshot)),
          ),
        ),
      ),
    ],
  );
}
