import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons, SelectableText, Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../../dart/utils/index.dart' show ElDartUtil;
import '../../../../flutter/components/avatar/index.dart';
import '../../../../flutter/components/button/index.dart';
import '../../../../flutter/components/index.dart' show ElComponentProvider;
import '../../../../flutter/components/tokens.dart';
import '../../../../flutter/views/image/index.dart';
import '../../../../flutter/views/scroll/scroll.dart';
import '../../../../flutter/views/scroll/sliver/list/index.dart';
import '../../../../flutter/views/view/event/event.dart';
import '../../../../flutter/views/view/style/style.dart';
import '../../../../flutter/views/view/view.dart';
import '../../../../flutter/widgets/image_preview/index.dart';
import 'message.dart';

part 'controller.dart';
part 'layout.dart';
part 'row.dart';

const double _latestThreshold = 48;
const double _historyThreshold = 160;

/// 反向展示聊天消息，并在消息增删和尺寸变化时保留阅读位置。
class ElChatScroll extends StatefulWidget {
  /// 创建聊天列表，默认以可复用的 Sliver 按需构建消息行。
  const ElChatScroll({
    super.key,
    required this.messages,
    this.controller,
    this.avatarBuilder,
    this.messageBuilder,
    this.sliverBuilder,
    this.scrollController,
    this.onOpenFile,
    this.onLoadEarlier,
    this.style,
    this.event,
  });

  /// 按最旧到最新排列的消息快照，更新时传入新列表，同一会话内 ID 唯一。
  final List<ElChatMessage> messages;

  /// 按消息 ID 定位和监听末尾位置的控制器，传入时由调用方释放。
  final ElChatScrollController? controller;

  /// 自定义当前消息的头像，返回 `null` 时使用默认头像。
  final Widget? Function(BuildContext context, ElChatMessage message)? avatarBuilder;

  /// 自定义当前消息的气泡内容，返回 `null` 时按消息类型使用默认内容。
  final Widget? Function(BuildContext context, ElChatMessage message)? messageBuilder;

  /// 用给定的消息委托构建自定义 Sliver，委托的序号从最新消息开始。
  ///
  /// 可直接用 `SliverList(delegate: delegate)`，或把委托的 builder、childCount
  /// 和 findChildIndexCallback 交给其他列表。定位和锚定要求保留委托构建的消息行。
  /// 列表沿滚动轴按委托序号排列时，尚未挂载的目标会通过滚动逐段查找。
  final Widget Function(BuildContext context, SliverChildBuilderDelegate delegate)? sliverBuilder;

  /// 供滚动条等外部部件共享的像素控制器，由调用方释放。
  final ScrollController? scrollController;

  /// 文件消息被激活时通知调用方打开或下载。
  final ValueChanged<ElChatFileMessage>? onOpenFile;

  /// 靠近最旧消息时请求历史，加载完毕后由调用方提交新快照。
  ///
  /// 已经没有更早的消息时传入 `null`。
  final Future<void> Function()? onLoadEarlier;

  /// 滚动区域根节点的样式。
  final ElStyle? style;

  /// 滚动区域根节点的交互事件。
  final ElEvent? event;

  @override
  State<ElChatScroll> createState() => _ChatScrollState();
}

class _ChatScrollState extends State<ElChatScroll> {
  final _localScroll = ScrollController(keepScrollOffset: false);
  final _recycler = ElSliverRecyclerController();
  final _layoutKey = GlobalKey();
  final _rows = <_RenderChatMessage>{};
  late ElChatScrollController _controller;
  late Map<Object, int> _indices;
  var _command = 0;
  var _navigating = false;
  var _metricsScheduled = false;
  var _historyEntered = false;
  var _historyLoading = false;
  var _historyFailed = false;
  final _pointers = <int>{};

  ScrollController get _scroll => widget.scrollController ?? _localScroll;
  _RenderChatSliver? get _layout => _layoutKey.currentContext?.findRenderObject() as _RenderChatSliver?;
  ScrollPosition? get _position =>
      _scroll.hasClients && _scroll.position.hasContentDimensions ? _scroll.position : null;

  bool _shouldFollow() => (_position?.extentBefore ?? double.infinity) <= _latestThreshold && _isIdle();

  bool _isIdle() {
    final position = _position;
    return position != null && _pointers.isEmpty && !position.isScrollingNotifier.value;
  }

  @override
  void initState() {
    super.initState();
    _indexMessages();
    _attachController();
    _scheduleMetrics();
  }

  void _indexMessages() {
    final messages = widget.messages;
    _indices = {for (var i = 0; i < messages.length; i++) messages[i].id: messages.length - 1 - i};
    assert(_indices.length == messages.length, '同一会话内的消息 ID 必须唯一。');
  }

  void _attachController() {
    _controller = widget.controller ?? ElChatScrollController();
    _controller._attach(this);
  }

  @override
  void didUpdateWidget(ElChatScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _controller._detach(this);
      if (oldWidget.controller == null) _controller.dispose();
      _attachController();
    }
    if (!identical(oldWidget.messages, widget.messages)) {
      final previous = _indices;
      _indexMessages();
      _layout?.preservePosition(followLatest: oldWidget.messages.lastOrNull?.id != widget.messages.lastOrNull?.id);
      if (widget.sliverBuilder == null && oldWidget.sliverBuilder == null) _updateRecyclerAnchor(previous);
    }
    if ((oldWidget.sliverBuilder == null) != (widget.sliverBuilder == null)) _cancelCommand();
    if (widget.onLoadEarlier == null || oldWidget.onLoadEarlier == null) {
      _historyEntered = false;
      _historyFailed = false;
    }
    _scheduleMetrics();
  }

  void _updateRecyclerAnchor(Map<Object, int> previous) {
    if (previous.isEmpty || _indices.isEmpty || _position == null) return;
    if (_shouldFollow()) return;
    // 首尾变动对存活消息只有一个反向序号增量，历史分页通常不影响这个增量。
    for (final id in _layout?.visibleIds ?? const <Object>[]) {
      final oldIndex = previous[id];
      final newIndex = _indices[id];
      if (oldIndex == null || newIndex == null) continue;
      final shift = newIndex - oldIndex;
      if (shift > 0) _recycler.notifyItemsInserted(0, shift);
      if (shift < 0) _recycler.notifyItemsRemoved(0, -shift);
      break;
    }
  }

  void _scheduleMetrics() {
    if (_metricsScheduled) return;
    _metricsScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _metricsScheduled = false;
      if (!mounted) return;
      final position = _position;
      if (position == null) return;
      _controller._updateAtLatest(position.extentBefore <= _latestThreshold);
      if (widget.onLoadEarlier == null || widget.messages.isEmpty || _navigating) return;
      if (position.extentAfter > _historyThreshold) {
        _historyEntered = false;
      } else if (!_historyEntered && !_historyLoading && !_historyFailed) {
        _historyEntered = true;
        unawaited(_loadEarlier());
      }
    });
  }

  Future<void> _loadEarlier() async {
    final load = widget.onLoadEarlier;
    if (load == null || _historyLoading) return;
    setState(() {
      _historyFailed = false;
      _historyLoading = true;
    });
    try {
      await load();
    } catch (_) {
      if (mounted && widget.onLoadEarlier != null) _historyFailed = true;
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  void _pointerStart(PointerEvent event) {
    _pointers.add(event.pointer);
    _cancelCommand();
  }

  void _pointerEnd(PointerEvent event) => _pointers.remove(event.pointer);

  Widget _buildMessage(BuildContext context, int index, {bool keyed = true}) {
    final message = widget.messages[widget.messages.length - 1 - index];
    return _ChatMessageBoundary(
      key: keyed ? ValueKey<Object>(message.id) : null,
      id: message.id,
      rows: _rows,
      child: _ChatMessageRow(
        message: message,
        avatarBuilder: widget.avatarBuilder,
        messageBuilder: widget.messageBuilder,
        onOpenFile: widget.onOpenFile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.messages.length;
    final builder = widget.sliverBuilder;
    final sliver = builder == null
        ? ElSliverList.recycler(
            itemCount: count,
            controller: _recycler,
            itemType: (index) {
              final message = widget.messages[count - 1 - index];
              return (message.isMine, message.runtimeType);
            },
            itemBuilder: (_, index) => ValueListenableBuilder(
              valueListenable: index,
              builder: (context, value, _) => _buildMessage(context, value, keyed: false),
            ),
          )
        : builder(
            context,
            SliverChildBuilderDelegate(
              _buildMessage,
              childCount: count,
              findChildIndexCallback: (key) => key is ValueKey<Object> ? _indices[key.value] : null,
              addAutomaticKeepAlives: false,
            ),
          );

    return ElView(
      style: const ElStyle(width: '100%', height: '100%').merge(widget.style),
      event: widget.event,
      child: Listener(
        onPointerDown: _pointerStart,
        onPointerUp: _pointerEnd,
        onPointerCancel: _pointerEnd,
        onPointerPanZoomStart: _pointerStart,
        onPointerPanZoomEnd: _pointerEnd,
        onPointerSignal: (_) => _cancelCommand(),
        child: NotificationListener<Notification>(
          onNotification: (notification) {
            if (notification case ScrollNotification(depth: 0) || ScrollMetricsNotification(depth: 0)) {
              _scheduleMetrics();
            }
            return false;
          },
          child: ElScrollView.sliver(
            controller: _scroll,
            reverse: true,
            semanticChildCount: count,
            slivers: [
              _ChatSliver(
                key: _layoutKey,
                rows: _rows,
                shouldFollow: _shouldFollow,
                isIdle: _isIdle,
                navigating: () => _navigating,
                metricsChanged: _scheduleMetrics,
                child: sliver,
              ),
              if (widget.onLoadEarlier != null && (_historyLoading || _historyFailed))
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const .all(8),
                      child: _historyFailed
                          ? _historyRetry(context)
                          : Semantics(liveRegion: true, child: const Text('正在加载历史消息')),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyRetry(BuildContext context) {
    void retry() => unawaited(_loadEarlier());
    if (ElComponentProvider.maybeOf(context)?.button != null) {
      return ElButton(variant: .text, onPressed: retry, child: const Text('重试加载历史消息'));
    }
    return Semantics(
      button: true,
      child: GestureDetector(onTap: retry, child: const Text('重试加载历史消息')),
    );
  }

  @override
  void dispose() {
    _controller._detach(this);
    if (widget.controller == null) _controller.dispose();
    _localScroll.dispose();
    super.dispose();
  }
}
