import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/recycler_view.dart' as rv;

import '../../example_page.dart';

/// 用一万条变高消息演示历史插入、底部跟随与未读消息提示。
class RecyclerChatPage extends StatefulWidget {
  /// 创建聊天长列表示例。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerChatPage({super.key});

  @override
  State<RecyclerChatPage> createState() => _RecyclerChatPageState();
}

class _RecyclerChatPageState extends State<RecyclerChatPage> {
  final _composer = TextEditingController();
  final _count = ValueNotifier<int>(10000);
  final _unread = ValueNotifier<int>(0);
  final _messages = List.generate(10000, _ChatMessage.generated);
  late final _adapter = _ChatAdapter(_messages);
  late final _list = rv.RecyclerView(key: ValueKey('recycler-chat-list'))
    ..setLayoutManager(rv.LinearLayoutManager()..setStackFromEnd(true))
    ..setAdapter(_adapter);
  bool _nearBottom = true;
  // -1 是 RecyclerView.NO_ID，历史消息从更小的稳定 ID 开始。
  int _oldestId = -1;
  int _nextId = 10000;

  void _loadEarlier() {
    _oldestId -= 50;
    _messages.insertAll(0, List.generate(50, (index) => _ChatMessage.generated(_oldestId + index)));
    // 稳定 ID 和范围插入让内核保留正在阅读的既有消息，不手算高度补偿。
    _adapter.notifyItemRangeInserted(0, 50);
    _count.value = _messages.length;
  }

  void _append({required bool mine, String? text}) {
    final layout = _list.getLayoutManager()! as rv.LinearLayoutManager;
    final follow = _nearBottom && layout.findLastVisibleItemPosition() == _messages.length - 1;
    _messages.add(_ChatMessage.generated(_nextId++, mine: mine, text: text));
    _adapter.notifyItemInserted(_messages.length - 1);
    _count.value = _messages.length;
    if (follow) {
      _showLatest();
    } else {
      _unread.value++;
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
    _list.scrollToPosition(_messages.length - 1);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    _nearBottom = notification.metrics.extentAfter <= 48;
    if (_nearBottom && _unread.value != 0) _unread.value = 0;
    return false;
  }

  @override
  void dispose() {
    _composer.dispose();
    _count.dispose();
    _unread.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExamplePage(
    title: '聊天长列表',
    child: SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          ElCardView(
            style: ElStyle(padding: .all(12), margin: .all(12), borderRadius: .circular(12)),
            child: Column(
              crossAxisAlignment: .start,
              spacing: 8,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: _count,
                  builder: (context, count, child) => Text('$count 条消息 · 长短气泡混排', key: ValueKey('chat-count')),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElButton(key: ValueKey('chat-load-earlier'), onPressed: _loadEarlier, child: '更早 50 条'),
                    ElButton(key: ValueKey('chat-receive'), onPressed: () => _append(mine: false), child: '模拟收到'),
                    ValueListenableBuilder<int>(
                      valueListenable: _unread,
                      builder: (context, count, child) => ElButton(
                        key: ValueKey('chat-latest'),
                        onPressed: _showLatest,
                        // 未读文案不能撑高工具栏，否则正在阅读的消息会随整个视口下移。
                        style: ElStyle(width: 136),
                        child: count == 0 ? '最新消息' : '${count > 99 ? '99+' : count} 条新消息',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: _list),
          ),
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
  _ChatMessage({required this.id, required this.mine, required this.text, required this.time});

  factory _ChatMessage.generated(int id, {bool? mine, String? text}) {
    final samples = [
      '收到，稍后见。',
      '今天的列表已经接好，试试快速滑动，再回来看看消息的位置。',
      '这里是一条稍长的消息。气泡会根据实际宽度换行，高度由内容决定。\n加载更早的记录时，正在阅读的消息应该留在原来的位置。',
      '这条消息包含三行：\n一、结构按方向复用。\n二、内容与时间按消息 ID 重新绑定。',
      '好！',
    ];
    return _ChatMessage(
      id: id,
      mine: mine ?? id % 3 == 0,
      text: text ?? '${id >= 0 ? '消息 #${id + 1}' : '历史消息 ${-id}'}：${samples[id.abs() % samples.length]}',
      time: DateTime(2026, 1, 1, 9).add(Duration(minutes: id)),
    );
  }

  final int id;
  final bool mine;
  final String text;
  final DateTime time;
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
  _ChatHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) => _ChatHolder();

  @override
  void onBindViewHolder(_ChatHolder holder, int position, [List<Object> payloads = const []]) {
    holder.message.value = messages[position];
  }
}

class _ChatHolder extends rv.ViewHolder {
  _ChatHolder() : this._(ValueNotifier<_ChatMessage?>(null));

  _ChatHolder._(this.message)
    : super(
        ValueListenableBuilder<_ChatMessage?>(
          valueListenable: message,
          builder: (context, data, child) {
            if (data == null) return SizedBox.shrink();
            final colors = Theme.of(context).colorScheme;
            final time = '${data.time.hour.toString().padLeft(2, '0')}:${data.time.minute.toString().padLeft(2, '0')}';
            return Padding(
              key: ValueKey('chat-message-${data.id}'),
              padding: .symmetric(horizontal: 16, vertical: 6),
              child: LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: data.mine ? .centerRight : .centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth * .8),
                    child: ElCardView(
                      style: ElStyle(
                        padding: .all(12),
                        borderRadius: .circular(16),
                        backgroundColor: data.mine
                            ? colors.primary.withValues(alpha: .12)
                            : colors.surfaceContainerHighest,
                      ),
                      child: Column(
                        crossAxisAlignment: .start,
                        mainAxisSize: .min,
                        spacing: 5,
                        children: [
                          Text(data.mine ? '我' : '小林', style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
                          Text(data.text, style: TextStyle(height: 1.5)),
                          Text(time, style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

  final ValueNotifier<_ChatMessage?> message;
}
