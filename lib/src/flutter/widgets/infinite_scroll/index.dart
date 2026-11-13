import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../views/button/button_view.dart' show ElButtonView;
import '../../views/scroll/refresh/index.dart' show ElRefresher, ElSliverRefresh;
import '../../views/scroll/refresh/refresher/platform.dart' show buildPlatformRefreshSpinner;
import '../../views/scroll/scroll.dart' show ElScrollView;

/// 一页分页结果，条目类型与分页键类型由调用方指定。
class ElInfiniteScrollPage<T, K extends Object> {
  /// 创建一页数据，省略 [nextPageKey] 表示已经到达末页。
  const ElInfiniteScrollPage({required this.items, this.nextPageKey});

  /// 本页条目。
  final List<T> items;

  /// 下一页的请求键，可以是页码、偏移量或游标。
  final K? nextPageKey;
}

/// 支持下拉刷新和触底分页的纵向滚动组件。
///
/// 首次挂载和下拉刷新都请求 [firstPageKey]，成功时替换当前数据。
/// 后续页面按 [ElInfiniteScrollPage.nextPageKey] 加载并追加，内容较短时会继续补页。
class ElInfiniteScroll<T, K extends Object> extends StatefulWidget {
  /// 创建分页滚动组件。
  const ElInfiniteScroll({
    super.key,
    required this.firstPageKey,
    required this.onLoadPage,
    required this.sliverBuilder,
    this.loadDistance = 200,
    this.controller,
    this.physics,
    this.refresher,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
  }) : assert(loadDistance >= 0 && loadDistance < double.infinity);

  /// 第一页请求键，变化时重新从该页加载。
  final K firstPageKey;

  /// 异步请求指定页面，异常会进入可重试的失败状态。
  ///
  /// 每轮分页的请求键须保持唯一。返回空页时，若仍有下一页键则继续分页。
  final Future<ElInfiniteScrollPage<T, K>> Function(K pageKey) onLoadPage;

  /// 根据只读条目快照构建内容 Sliver，如 [SliverList] 或 [SliverGrid]。
  final Widget Function(BuildContext context, List<T> items) sliverBuilder;

  /// 距离内容底部多少逻辑像素开始加载下一页，默认 200。
  final double loadDistance;

  /// 内部 [ElScrollView] 使用的滚动控制器。
  final ScrollController? controller;

  /// 内部 [ElScrollView] 使用的滚动物理。
  final ScrollPhysics? physics;

  /// 下拉刷新器的外观和策略，省略时使用平台默认实现。
  final ElRefresher? refresher;

  /// 数据为空且已经到达末页时构建的占位 Widget。
  final WidgetBuilder? emptyBuilder;

  /// 构建首屏或底部加载 Widget，默认显示平台自适应进度指示器。
  final WidgetBuilder? loadingBuilder;

  /// 构建失败提示并提供重试操作，默认显示重试按钮。
  final Widget Function(BuildContext context, Object error, VoidCallback retry)? errorBuilder;

  @override
  State<ElInfiniteScroll<T, K>> createState() => _InfiniteScrollState<T, K>();
}

class _LoadFailure {
  const _LoadFailure({required this.refresh, required this.error});

  final bool refresh;
  final Object error;
}

class _InfiniteScrollState<T, K extends Object> extends State<ElInfiniteScroll<T, K>> {
  final _loadedKeys = <K>{};
  List<T> _items = const [];
  K? _nextPageKey;
  ScrollPosition? _position;
  ({bool refresh, Completer<void> completion})? _request;
  _LoadFailure? _failure;
  bool _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleLoadCheck();
  }

  @override
  void didUpdateWidget(covariant ElInfiniteScroll<T, K> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reset = oldWidget.firstPageKey != widget.firstPageKey;
    if (reset) {
      _finishRequest();
      _loadedKeys.clear();
      _items = const [];
      _nextPageKey = null;
      _failure = null;
    }
    if (reset || oldWidget.loadDistance != widget.loadDistance) _scheduleLoadCheck();
  }

  @override
  void dispose() {
    _finishRequest();
    super.dispose();
  }

  bool get _canLoad => _request == null && _failure == null && (_loadedKeys.isEmpty || _nextPageKey != null);

  void _scheduleLoadCheck() {
    if (_checkScheduled || !_canLoad) return;
    _checkScheduled = true;
    final binding = WidgetsBinding.instance;
    // 用布局完成后的最新范围判断，避免沿用上一页的滚动范围多发请求。
    binding.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted || !_canLoad) return;
      if (_loadedKeys.isEmpty) {
        unawaited(_refresh());
        return;
      }
      final position = _position;
      if (position != null &&
          position.haveDimensions &&
          position.viewportDimension > 0 &&
          position.extentAfter <= widget.loadDistance) {
        unawaited(_requestPage(_nextPageKey!, refresh: false));
      }
    });
    binding.ensureVisualUpdate();
  }

  Future<void> _refresh() {
    final request = _request;
    if (request != null && request.refresh) return request.completion.future;
    return _requestPage(widget.firstPageKey, refresh: true);
  }

  Future<void> _requestPage(K pageKey, {required bool refresh}) {
    final completion = Completer<void>();
    setState(() {
      // 刷新优先，正在执行的追加请求结束后也不能写回旧数据。
      _finishRequest();
      _request = (refresh: refresh, completion: completion);
      _failure = null;
    });
    unawaited(_loadPage(pageKey, refresh: refresh, completion: completion));
    return completion.future;
  }

  void _finishRequest() {
    _request?.completion.complete();
    _request = null;
  }

  Future<void> _loadPage(K pageKey, {required bool refresh, required Completer<void> completion}) async {
    try {
      final page = await widget.onLoadPage(pageKey);
      if (!mounted || !identical(_request?.completion, completion)) return;
      final nextPageKey = page.nextPageKey;
      if (nextPageKey != null && (nextPageKey == pageKey || (!refresh && _loadedKeys.contains(nextPageKey)))) {
        throw StateError('下一页键重复：$nextPageKey');
      }
      final items = List<T>.unmodifiable(refresh ? page.items : _items.followedBy(page.items));
      setState(() {
        if (refresh) _loadedKeys.clear();
        _loadedKeys.add(pageKey);
        _items = items;
        _nextPageKey = nextPageKey;
        _finishRequest();
      });
      _scheduleLoadCheck();
    } catch (error) {
      if (!mounted || !identical(_request?.completion, completion)) return;
      setState(() {
        _failure = _LoadFailure(refresh: refresh, error: error);
        _finishRequest();
      });
    }
  }

  void _retry(_LoadFailure failure) {
    if (!mounted || !identical(_failure, failure)) return;
    unawaited(failure.refresh ? _refresh() : _requestPage(_nextPageKey!, refresh: false));
  }

  Widget _buildError(BuildContext context, _LoadFailure failure) {
    void retry() => _retry(failure);
    return widget.errorBuilder?.call(context, failure.error, retry) ??
        Center(
          child: ElButtonView(
            onPressed: retry,
            child: const Padding(padding: EdgeInsets.all(12), child: Text('加载失败，点击重试')),
          ),
        );
  }

  Widget _buildLoading(BuildContext context) =>
      widget.loadingBuilder?.call(context) ??
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(label: '加载中', child: buildPlatformRefreshSpinner()),
        ),
      );

  Widget _buildContent(BuildContext context) {
    if (_items.isNotEmpty) return widget.sliverBuilder(context, _items);
    return SliverFillRemaining(child: Center(child: _buildPlaceholder(context)));
  }

  Widget _buildPlaceholder(BuildContext context) {
    final failure = _failure;
    if (failure != null) return _buildError(context, failure);
    if (_loadedKeys.isEmpty || _nextPageKey != null) return _buildLoading(context);
    return widget.emptyBuilder?.call(context) ?? const Text('暂无数据');
  }

  @override
  Widget build(BuildContext context) {
    final failure = _items.isEmpty ? null : _failure;
    final refreshFailure = failure?.refresh == true ? failure : null;
    final loadFailure = failure?.refresh == false ? failure : null;
    final loadingMore = _items.isNotEmpty && _request?.refresh == false;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) _scheduleLoadCheck();
        return false;
      },
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 && notification.metrics.extentAfter <= widget.loadDistance) {
            _scheduleLoadCheck();
          }
          return false;
        },
        child: ElScrollView.sliver(
          controller: widget.controller,
          physics: widget.physics,
          slivers: [
            Builder(
              builder: (context) {
                _position = Scrollable.of(context).position;
                return ElSliverRefresh(onRefresh: _refresh, refresher: widget.refresher);
              },
            ),
            SliverToBoxAdapter(
              child: refreshFailure == null
                  ? null
                  : Builder(builder: (context) => _buildError(context, refreshFailure)),
            ),
            Builder(builder: _buildContent),
            SliverToBoxAdapter(
              child: loadFailure != null
                  ? Builder(builder: (context) => _buildError(context, loadFailure))
                  : loadingMore
                  ? Builder(builder: _buildLoading)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
