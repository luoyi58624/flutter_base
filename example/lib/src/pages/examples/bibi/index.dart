import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter_base.dart';

import 'cards/feed.dart';
import 'cards/index.dart';
import 'navigation_header/index.dart';
import 'navigation_header/motion.dart';
import 'state/index.dart';
import 'tab_bar/index.dart';

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
class BibiPage extends HookWidget {
  /// 创建首页示例。
  const BibiPage({super.key});

  @override
  Widget build(BuildContext context) {
    final collapse = useAnimationController();
    final state = useHookState(
      () => BibiState(channelCount: _channels.length, initialIndex: _recommended, collapse: collapse),
      ignoreListener: true,
    );
    final headerOffset = useMemoized(() => collapse.drive(Tween<double>(begin: 0, end: _searchHeight)), [collapse]);
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
          child: Column(
            children: [
              Expanded(
                child: MediaQuery.fromView(
                  view: View.of(context),
                  child: Builder(
                    builder: (context) {
                      final statusInset = MediaQuery.viewPaddingOf(context).top;
                      void search() => showBibiSearch(
                        context,
                        _channelSeed(state.active, state.channel(state.active).data.generation),
                      );

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ElTabView(
                            key: ValueKey('bibi-pager'),
                            controller: state.pager,
                            physics: _physics,
                            lazy: true,
                            maxCacheCount: 3,
                            onDragStateChanged: (dragging) {
                              if (dragging) state.stopScrolling();
                            },
                            children: [
                              for (var index = 0; index < _channels.length; index++)
                                _BibiFeed(
                                  key: ValueKey('bibi-feed-$index'),
                                  index: index,
                                  state: state,
                                  statusInset: statusInset,
                                ),
                            ],
                          ),
                          // 页头独立于横向视口，只有频道内容随手势横移。
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: statusInset + _searchHeight + _tabsHeight,
                            child: BibiHeader(
                              offset: headerOffset,
                              statusInset: statusInset,
                              channelBarBuilder: (progress) => BibiChannelBar(
                                progress: progress,
                                pager: state.pager,
                                channels: _channels,
                                onSelect: state.selectChannel,
                                onSearch: search,
                              ),
                              onSearch: search,
                              onBack: navigator.maybePop,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              SizedBox(
                height: insets.bottom + _bottomHeight,
                child: BibiBottomBar(
                  bottomInset: insets.bottom,
                  onHome: state.returnToTop,
                  onFollowing: () => state.selectChannel(2),
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

int _channelSeed(int index, int generation) =>
    generation * _channels.length + (index - _recommended) % _channels.length;

class _FeedController extends ScrollController {
  _FeedController({super.onAttach, super.onDetach}) : super(keepScrollOffset: false);

  double restoreOffset = 0;

  @override
  double get initialScrollOffset => restoreOffset;
}

class _BibiFeed extends HookWidget {
  const _BibiFeed({super.key, required this.index, required this.state, required this.statusInset});

  final int index;
  final BibiState state;
  final double statusInset;

  @override
  Widget build(BuildContext context) {
    final channel = useMemoized(() => state.channel(index), [state, index]);
    final active = useListenableSelector(state, () => state.active == index);
    final atTop = useMemoized(() => ValueNotifier(false));
    final refresher = useMemoized(() => _BibiRefresher(atTop));
    final refreshController = useMemoized(ElRefreshController.new);
    useDispose(atTop.dispose);

    void updateRefreshVisibility() {
      final controller = channel.controller;
      final pager = state.pager;
      atTop.value =
          state.active == index &&
          !pager.isDragging &&
          !pager.isAnimating &&
          (channel.data.count == 0 || state.collapse.value == 0) &&
          (!controller.hasClients ||
              !controller.position.hasContentDimensions ||
              controller.position.extentBefore == 0);
    }

    useEffect(() {
      state.pager.addListener(updateRefreshVisibility);
      channel.controller.addListener(updateRefreshVisibility);
      state.collapse.addListener(updateRefreshVisibility);
      return () {
        state.pager.removeListener(updateRefreshVisibility);
        channel.controller.removeListener(updateRefreshVisibility);
        state.collapse.removeListener(updateRefreshVisibility);
      };
    }, [state, channel]);

    useEffect(() {
      nextTick(() {
        if (!context.mounted) return;
        updateRefreshVisibility();
        if (state.active == index) {
          channel.applyPendingRefresh();
          if (channel.data.count == 0) refreshController.show();
        }
      });
      return null;
    }, [active, channel]);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 &&
            notification.metrics.axis == .vertical &&
            (switch (notification) {
              ScrollUpdateNotification(:final scrollDelta) => (scrollDelta ?? 0) > 0,
              OverscrollNotification(:final overscroll) => overscroll > 0,
              _ => false,
            }) &&
            notification.metrics.extentAfter == 0 &&
            state.active == index &&
            !state.pager.isDragging &&
            !state.pager.isAnimating) {
          channel.loadMore();
        }
        return false;
      },
      child: ElScrollView.sliver(
        key: PageStorageKey(index),
        controller: channel.controller,
        physics: _physics,
        slivers: [
          // Sliver 消费纵向位移并为共享页头保留与折叠进度一致的空间。
          ElSliverCollapse.priority(
            controller: state.collapse,
            compactExtent: _tabsHeight,
            contentExtent: _searchHeight,
            topInset: statusInset,
            backgroundColor: Colors.white,
            content: SizedBox.shrink(),
            compact: SizedBox.shrink(),
          ),
          ElSliverRefresh(controller: refreshController, refresher: refresher, onRefresh: channel.refresh),
          ElListenableBuilder(
            listenable: channel,
            select: (state) => state.data,
            builder: (context, _) {
              final (:count, :generation) = channel.data;
              return SliverPadding(
                padding: EdgeInsets.only(bottom: 4),
                sliver: BibiCards(count: count, generation: generation, seed: _channelSeed(index, generation)),
              );
            },
          ),
          SliverToBoxAdapter(
            child: ElListenableBuilder(
              listenable: channel,
              select: (state) => state.isLoading,
              builder: (context, _) => SizedBox(
                height: 44,
                child: channel.isLoading
                    ? Center(
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(color: _pink, strokeWidth: 2.5, semanticsLabel: '加载更多'),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BibiRefresher extends ElAndroidRefresher {
  _BibiRefresher(this.atTop) : super(color: _pink, bgColor: Colors.white);

  final ValueListenable<bool> atTop;

  @override
  Widget buildIndicator(BuildContext context, ValueListenable<ElRefreshSnapshot> snapshot) {
    return _BibiRefreshIndicator(atTop: atTop, snapshot: snapshot, child: super.buildIndicator(context, snapshot));
  }
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
