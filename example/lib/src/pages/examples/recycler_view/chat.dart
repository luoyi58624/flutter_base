import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/recycler_view.dart' as rv;

import '../../example_page.dart';
import 'scroll_mode.dart';
import '../../../widgets/example_scrollbar.dart';

/// 用一万条变高消息演示历史插入、底部跟随与未读消息提示。
class RecyclerChatPage extends StatefulWidget {
  /// 创建聊天长列表示例。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerChatPage({super.key});
  @override
  State<RecyclerChatPage> createState() => _RecyclerChatPageState();
}

enum _ChatAction { earlier, receive, latest }

typedef _ChatAnchor = ({int id, double top});

class _RecyclerChatPageState extends State<RecyclerChatPage> {
  final _composer = TextEditingController();
  final _count = ValueNotifier<int>(10000);
  final _unread = ValueNotifier<int>(0);
  final _messages = List.generate(10000, _ChatMessage.generated);
  final _official = ScrollController(keepScrollOffset: false);
  // 切换帧中旧容器尚未卸载，El 的布局期不能与它共用单位置控制器。
  final _el = ScrollController(keepScrollOffset: false);
  final _officialListKey = GlobalKey();
  final _officialKeys = <int, GlobalKey>{};
  RecyclerExampleScrollMode _mode = .recyclerView;
  late final _adapter = _ChatAdapter(_messages);
  late final _list = rv.RecyclerView(key: ValueKey('recycler-chat-list'), controller: _official)
    ..setLayoutManager(rv.LinearLayoutManager()..setStackFromEnd(true))
    ..setAdapter(_adapter);
  bool _nearBottom = true;
  // -1 是 RecyclerView.NO_ID，历史消息从更小的稳定 ID 开始。
  int _oldestId = -1;
  int _nextId = 10000;

  ScrollController get _messageController => _mode == .elScrollView ? _el : _official;

  int _indexOf(int id) {
    var low = 0;
    var high = _messages.length - 1;
    while (low <= high) {
      final middle = (low + high) ~/ 2;
      final value = _messages[middle].id;
      if (value == id) return middle;
      if (value < id) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return -1;
  }

  _ChatAnchor? _captureMessageAnchor() {
    final viewport = _officialListKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return null;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewport.size.height;
    _ChatAnchor? anchor;
    for (final entry in _officialKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top + box.size.height <= viewportTop || top >= viewportBottom) continue;
      if (anchor == null || top < anchor.top) anchor = (id: entry.key, top: top);
    }
    return anchor;
  }

  void _restoreMessageAnchor(_ChatAnchor? anchor) {
    if (anchor == null) return;
    final mode = _mode;
    final controller = _messageController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _mode != mode || _mode == .recyclerView || !controller.hasClients) return;
      final box = _officialKeys[anchor.id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return;
      // 两种反向容器的像素增大时内容都向下平移，仅补偿尚未由容器保住的几何差。
      final correction = anchor.top - box.localToGlobal(Offset.zero).dy;
      if (correction.abs() > .01) {
        controller.jumpTo((controller.offset + correction).clamp(0, controller.position.maxScrollExtent));
      }
    });
  }

  void _loadEarlier() {
    final anchor = _mode != .recyclerView ? _captureMessageAnchor() : null;
    _oldestId -= 50;
    _messages.insertAll(0, List.generate(50, (index) => _ChatMessage.generated(_oldestId + index)));
    _adapter.notifyItemRangeInserted(0, 50);
    _count.value = _messages.length;
    if (_mode != .recyclerView) {
      setState(() {});
      _restoreMessageAnchor(anchor);
    }
  }

  void _append({required bool mine, String? text}) {
    final follow =
        _nearBottom &&
        (_mode != .recyclerView
            ? _messageController.hasClients && _messageController.offset <= 48
            : (_list.getLayoutManager()! as rv.LinearLayoutManager).findLastVisibleItemPosition() ==
                  _messages.length - 1);
    final anchor = _mode != .recyclerView && !follow ? _captureMessageAnchor() : null;
    _messages.add(_ChatMessage.generated(_nextId++, mine: mine, text: text));
    _adapter.notifyItemInserted(_messages.length - 1);
    _count.value = _messages.length;
    if (_mode != .recyclerView) setState(() {});
    if (follow) {
      _showLatest();
    } else {
      _unread.value++;
      _restoreMessageAnchor(anchor);
    }
  }

  void _send() {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    _append(mine: true, text: text);
  }

  void _showLatest() {
    _unread.value = 0;
    _nearBottom = true;
    if (_mode == .recyclerView) {
      _list.scrollToPosition(_messages.length - 1);
    } else {
      final mode = _mode;
      final controller = _messageController;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mode == mode && _mode != .recyclerView && controller.hasClients) controller.jumpTo(0);
      });
    }
  }

  void _choose(Object option) {
    if (option case final RecyclerExampleScrollMode mode) {
      if (_mode == mode) return;
      setState(() => _mode = mode);
      // 切换只替换容器，同一批消息从最新位置开始比较。
      _showLatest();
      return;
    }
    switch (option as _ChatAction) {
      case .earlier:
        _loadEarlier();
      case .receive:
        _append(mine: false);
      case .latest:
        _showLatest();
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    _nearBottom = (_mode == .recyclerView ? notification.metrics.extentAfter : notification.metrics.extentBefore) <= 48;
    if (_nearBottom && _unread.value != 0) _unread.value = 0;
    return false;
  }

  int? _messageIndexForKey(Key key) {
    for (final entry in _officialKeys.entries) {
      if (entry.value != key) continue;
      final index = _indexOf(entry.key);
      return index < 0 ? null : (_mode == .listView ? _messages.length - 1 - index : index);
    }
    return null;
  }

  Widget _messageRow(int index) {
    final message = _messages[index];
    final key = _officialKeys.putIfAbsent(message.id, GlobalKey.new);
    return _OfficialChatRow(
      key: key,
      message: message,
      onDisposed: () {
        if (identical(_officialKeys[message.id], key)) _officialKeys.remove(message.id);
      },
    );
  }

  Widget _officialMessages() => KeyedSubtree(
    key: ValueKey('official-chat-list'),
    child: ListView.builder(
      key: _officialListKey,
      controller: _official,
      reverse: true,
      itemCount: _messages.length,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      findChildIndexCallback: _messageIndexForKey,
      itemBuilder: (context, index) => _messageRow(_messages.length - 1 - index),
    ),
  );

  Widget _elMessages() => KeyedSubtree(
    key: ValueKey('el-chat-list'),
    child: ElScrollView(
      key: _officialListKey,
      controller: _el,
      reverse: true,
      preserveAnchor: true,
      scrollbar: RecyclerExampleIosScrollbar(),
      children: [
        ElListView.builder(
          itemCount: _messages.length,
          keepAlive: false,
          findChildIndexCallback: _messageIndexForKey,
          // El 的 reverse 保留内容顺序，只把像素零点放到末尾。
          itemBuilder: (context, index) => _messageRow(index),
        ),
      ],
    ),
  );

  Widget _messagesViewport() => NotificationListener<ScrollNotification>(
    onNotification: _onScroll,
    child: _mode == .elScrollView
        ? _elMessages()
        : RecyclerExampleScrollbar(controller: _official, child: _mode == .recyclerView ? _list : _officialMessages()),
  );

  @override
  void dispose() {
    _composer.dispose();
    _count.dispose();
    _unread.dispose();
    _official.dispose();
    _el.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExamplePage(
    title: '聊天长列表',
    actions: [
      ValueListenableBuilder<int>(
        valueListenable: _count,
        builder: (context, count, child) =>
            Text('$count 条', key: ValueKey('chat-count'), style: TextStyle(fontSize: 12)),
      ),
      ValueListenableBuilder<int>(
        valueListenable: _unread,
        builder: (context, count, child) => PopupMenuButton<Object>(
          key: ValueKey('chat-menu'),
          tooltip: '聊天选项',
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('${count > 99 ? '99+' : count}', key: ValueKey('chat-unread-count')),
            child: Icon(Icons.more_vert),
          ),
          onSelected: _choose,
          itemBuilder: (context) => [
            for (final mode in RecyclerExampleScrollMode.values)
              CheckedPopupMenuItem(
                key: ValueKey('chat-mode-${mode.name}'),
                value: mode,
                checked: _mode == mode,
                child: Text(mode.label),
              ),
            PopupMenuDivider(),
            PopupMenuItem(key: ValueKey('chat-load-earlier'), value: _ChatAction.earlier, child: Text('更早 50 条')),
            PopupMenuItem(key: ValueKey('chat-receive'), value: _ChatAction.receive, child: Text('模拟收到')),
            PopupMenuItem(
              key: ValueKey('chat-latest'),
              value: _ChatAction.latest,
              child: Text(count == 0 ? '最新消息' : '$count 条新消息'),
            ),
          ],
        ),
      ),
    ],
    child: SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Expanded(child: _messagesViewport()),
          ElCardView(
            style: ElStyle(padding: .all(12)),
            child: Row(
              crossAxisAlignment: .end,
              spacing: 12,
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('chat-composer'),
                    controller: _composer,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(hintText: '输入消息', isDense: true, border: OutlineInputBorder()),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                ElButton(key: ValueKey('chat-send'), onPressed: _send, child: '发送'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ChatMessage {
  _ChatMessage.generated(this.id, {bool? mine, String? text}) : mine = mine ?? id % 3 == 0, _suppliedText = text;
  static final _samples = [
    '收到，稍后见。',
    '今天的列表已经接好，试试快速滑动，再回来看看消息的位置。',
    '这里是一条稍长的消息。气泡会根据实际宽度换行，高度由内容决定。\n加载更早的记录时，正在阅读的消息应该留在原来的位置。',
    '这条消息包含三行：\n一、结构按方向复用。\n二、内容与时间按消息 ID 重新绑定。',
    '好！',
  ];
  final int id;
  final bool mine;
  final String? _suppliedText;
  // 索引只需要 ID 和方向，昂贵的正文与本地时间计算留到真正显示该消息时。
  late final String text =
      _suppliedText ?? '${id >= 0 ? '消息 #${id + 1}' : '历史消息 ${-id}'}：${_samples[id.abs() % _samples.length]}';
  late final DateTime time = DateTime(2026, 1, 1, 9).add(Duration(minutes: id));
  late final String timeLabel = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class _ChatAdapter extends rv.Adapter<_ChatHolder> {
  _ChatAdapter(this.messages) {
    setHasStableIds(true);
  }
  final List<_ChatMessage> messages;
  @override
  int getItemCount() => messages.length;
  @override
  int getItemId(int position) => messages[position].id;
  @override
  int getItemViewType(int position) => messages[position].mine ? 1 : 0;
  @override
  _ChatHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) => _ChatHolder(viewType == 1);
  @override
  void onBindViewHolder(_ChatHolder holder, int position, [List<Object> payloads = const []]) {
    holder.message.value = messages[position];
  }
}

class _ChatHolder extends rv.ViewHolder {
  _ChatHolder(bool mine) : this._(ValueNotifier<_ChatMessage?>(null), mine);
  _ChatHolder._(this.message, bool mine) : super(_ChatRow(message, mine));
  final ValueNotifier<_ChatMessage?> message;
}

class _OfficialChatRow extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _OfficialChatRow({super.key, required this.message, required this.onDisposed});
  final _ChatMessage message;
  final VoidCallback onDisposed;
  @override
  State<_OfficialChatRow> createState() => _OfficialChatRowState();
}

class _OfficialChatRowState extends State<_OfficialChatRow> {
  late final _message = ValueNotifier<_ChatMessage?>(widget.message);
  late final _row = _ChatRow(_message, widget.message.mine);
  @override
  void didUpdateWidget(_OfficialChatRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _message.value = widget.message;
  }

  @override
  void dispose() {
    widget.onDisposed();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: _row);
}

class _ChatRow extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _ChatRow(this.message, this.mine);
  final ValueNotifier<_ChatMessage?> message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // 气泡的方向、布局与样式由类型固定，绑定只更新正文和时间两个叶子。
    final bubble = ElCardView(
      style: ElStyle(
        padding: .all(12),
        borderRadius: .circular(16),
        backgroundColor: mine ? colors.primary.withValues(alpha: .12) : colors.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        spacing: 5,
        children: [
          Text(mine ? '我' : '小林', style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
          ValueListenableBuilder<_ChatMessage?>(
            valueListenable: message,
            builder: (context, value, child) => Text(value?.text ?? '', style: TextStyle(height: 1.5)),
          ),
          ValueListenableBuilder<_ChatMessage?>(
            valueListenable: message,
            builder: (context, value, child) =>
                Text(value?.timeLabel ?? '', style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant)),
          ),
        ],
      ),
    );
    return Padding(
      padding: .symmetric(horizontal: 16, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: mine ? .centerRight : .centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * .8),
            child: bubble,
          ),
        ),
      ),
    );
  }
}
