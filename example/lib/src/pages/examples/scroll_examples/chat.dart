import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../layout/example_page.dart';
import 'scroll_mode.dart';
import '../../../widgets/example_scrollbar.dart';
import '../../../widgets/panel.dart';

/// 用一千条变高消息演示历史插入、底部跟随与未读消息提示。
class RecyclerChatPage extends StatefulWidget {
  /// 创建聊天长列表示例。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerChatPage({super.key}) : _live = false;
  // ignore: prefer_const_constructors_in_immutables
  RecyclerChatPage._realtime({super.key}) : _live = true;

  final bool _live;

  @override
  State<RecyclerChatPage> createState() => _RecyclerChatPageState();
}

/// 在相同聊天列表上对照同时前插、收消息和流式变高。
class RecyclerLiveChatPage extends RecyclerChatPage {
  /// 创建可播放、单步和复位的实时聊天示例。
  RecyclerLiveChatPage({super.key}) : super._realtime();
}

enum _ChatAction { earlier, receive, latest }

typedef _ChatAnchor = ({int id, double top});

class _RecyclerChatPageState extends State<RecyclerChatPage> {
  static final _liveParts = [
    '小林的滚动记录正在整理。',
    '第 1 段：在同一条消息里追加正文，气泡会随文字重新排版。',
    '第 2 段：与此同时，另一个人发来一条普通消息。',
    '第 3 段：阅读旧消息时，先记住当前可见消息在屏幕上的位置。',
    '第 4 段：第二批历史记录插入，时间线仍按原来的方向排列。',
    '第 5 段：又收到一条新消息，未读数只增加收到的消息数。',
    '第 6 段：回到末尾后，再继续追加正文，列表跟随新内容。',
    '记录结束。',
  ];

  final _composer = TextEditingController();
  final _count = ValueNotifier<int>(1000);
  final _unread = ValueNotifier<int>(0);
  final _messages = List.generate(1000, _ChatMessage.generated);
  final _official = ScrollController(keepScrollOffset: false);
  final _officialListKey = GlobalKey();
  // 仅登记已绑定槽位，正文通知与阅读锚点共用这些行，不为历史数据预建通知器。
  final _messageRows = <int, _OfficialChatRowState>{};
  late final _liveProgress = ValueNotifier<(int, bool)>((0, false));
  SliverExampleMode _mode = .official;
  bool _nearBottom = true;
  // 历史消息使用负业务 ID，与已存在的消息区分。
  int _oldestId = -1;
  int _nextId = 1000;
  int? _streamId;
  Timer? _liveTimer;

  ScrollController get _messageController => _official;

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
    for (final entry in _messageRows.entries) {
      final box = _messageBox(entry.key);
      if (box == null) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top + box.size.height <= viewportTop || top >= viewportBottom) continue;
      if (anchor == null || top < anchor.top) anchor = (id: entry.key, top: top);
    }
    return anchor;
  }

  RenderBox? _messageBox(int id) {
    final row = _messageRows[id];
    if (row == null || !row.mounted) return null;
    final box = row.context.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize ? box : null;
  }

  void _restoreMessageAnchor(_ChatAnchor? anchor) {
    if (anchor == null) return;
    final mode = _mode;
    final controller = _messageController;
    void correct() {
      if (!mounted || _mode != mode || !controller.hasClients) return;
      final box = _messageBox(anchor.id);
      if (box == null) return;
      // 反向容器的像素增大时内容向下平移，只补容器还没保住的几何差。
      final correction = anchor.top - box.localToGlobal(Offset.zero).dy;
      if (correction.abs() <= .01) return;
      controller.jumpTo((controller.offset + correction).clamp(0, controller.position.maxScrollExtent));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => correct());
  }

  void _loadEarlier() {
    final anchor = _captureMessageAnchor();
    _insertEarlier();
    _count.value = _messages.length;
    setState(() {});
    _restoreMessageAnchor(anchor);
  }

  void _insertEarlier() {
    _oldestId -= 50;
    _messages.insertAll(0, List.generate(50, (index) => _ChatMessage.generated(_oldestId + index)));
  }

  bool _shouldFollow() => _nearBottom && _official.hasClients && _official.offset <= 48;

  void _append({required bool mine, String? text}) {
    final follow = _shouldFollow();
    final anchor = !follow ? _captureMessageAnchor() : null;
    _insertMessage(mine: mine, text: text);
    _finishIncoming(follow, anchor, 1);
  }

  void _insertMessage({required bool mine, String? text}) {
    _messages.add(_ChatMessage.generated(_nextId++, mine: mine, text: text));
  }

  void _finishIncoming(bool follow, _ChatAnchor? anchor, int arrivals) {
    if (_count.value != _messages.length) {
      _count.value = _messages.length;
      setState(() {});
    }
    if (follow) {
      _showLatest();
    } else {
      _unread.value += arrivals;
      _restoreMessageAnchor(anchor);
    }
  }

  void _liveStep() {
    final (step, _) = _liveProgress.value;
    if (step == _liveParts.length) return;
    final follow = _shouldFollow();
    final anchor = !follow ? _captureMessageAnchor() : null;
    // 同一拍的前插、增长和新消息共用一次阅读锚点，避免分次恢复位置。
    if (step == 0 || step == 4) _insertEarlier();
    final text = _liveParts.take(step + 1).join('\n');
    var arrivals = 0;
    if (_streamId case final id?) {
      final index = _indexOf(id);
      final message = _ChatMessage.generated(id, mine: false, text: text);
      _messages[index] = message;
      _messageRows[id]?._updateMessage(message);
    } else {
      _streamId = _nextId;
      _insertMessage(mine: false, text: text);
      arrivals++;
    }
    if (step == 2 || step == 5) {
      _insertMessage(mine: false, text: step == 2 ? '我在这边也看到最新进度了。' : '等记录发完我们再一起核对。');
      arrivals++;
    }
    _finishIncoming(follow, anchor, arrivals);
    if (step + 1 == _liveParts.length) {
      _liveTimer?.cancel();
      _liveTimer = null;
    }
    _liveProgress.value = (step + 1, _liveTimer != null);
  }

  void _toggleLive() {
    final (step, running) = _liveProgress.value;
    if (step == _liveParts.length) return;
    if (running) {
      _liveTimer?.cancel();
      _liveTimer = null;
    } else {
      _liveTimer = Timer.periodic(Duration(milliseconds: 450), (_) => _liveStep());
    }
    _liveProgress.value = (step, !running);
  }

  void _resetLive() {
    _liveTimer?.cancel();
    _liveTimer = null;
    _streamId = null;
    _oldestId = -1;
    _nextId = 1000;
    _messages
      ..clear()
      ..addAll(List.generate(1000, _ChatMessage.generated));
    _count.value = _messages.length;
    _liveProgress.value = (0, false);
    setState(() {});
    _showLatest();
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
    final mode = _mode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _mode == mode && _official.hasClients) _official.jumpTo(0);
    });
  }

  void _choose(Object option) {
    if (option case final SliverExampleMode mode) {
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
    _nearBottom = notification.metrics.extentBefore <= 48;
    if (_nearBottom && _unread.value != 0) _unread.value = 0;
    return false;
  }

  int? _messageIndexForKey(Key key) {
    if (key is! ValueKey<int>) return null;
    final index = _indexOf(key.value);
    return index < 0 ? null : _messages.length - 1 - index;
  }

  Widget _messageRow(int index, {bool trackedKey = true}) => _OfficialChatRow(
    key: trackedKey ? ValueKey(_messages[index].id) : null,
    message: _messages[index],
    rows: _messageRows,
  );

  Widget _messagesViewport() => NotificationListener<ScrollNotification>(
    onNotification: _onScroll,
    child: RecyclerExampleScrollbar(
      controller: _official,
      child: _mode.scrollView(
        key: _officialListKey,
        controller: _official,
        reverse: true,
        semanticChildCount: _messages.length,
        slivers: [
          _mode.list(
            context,
            itemCount: _messages.length,
            itemBuilder: (_, index) => _messageRow(_messages.length - 1 - index),
            findChildIndexCallback: _messageIndexForKey,
            itemType: (index) => _messages[_messages.length - 1 - index].mine,
            recycledItemBuilder: (_, index) => ValueListenableBuilder<int>(
              valueListenable: index,
              builder: (_, value, _) => _messageRow(_messages.length - 1 - value, trackedKey: false),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    _liveTimer?.cancel();
    if (widget._live) _liveProgress.dispose();
    _composer.dispose();
    _count.dispose();
    _unread.dispose();
    _official.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExamplePage(
    title: widget._live ? '实时群聊' : '聊天长列表',
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
            for (final mode in SliverExampleMode.values)
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
          if (widget._live)
            Padding(
              padding: .symmetric(horizontal: 12, vertical: 4),
              child: Wrap(
                crossAxisAlignment: .center,
                spacing: 8,
                children: [
                  ElListenableBuilder<ValueNotifier<(int, bool)>, int>(
                    listenable: _liveProgress,
                    select: (source) => source.value.$1,
                    builder: (context, child) => Text(
                      '并发脚本 ${_liveProgress.value.$1} / ${_liveParts.length}',
                      key: ValueKey('chat-live-progress'),
                    ),
                  ),
                  // 正文每拍增长只更新进度文字，按钮仅在播放或完成状态改变时更新。
                  ElListenableBuilder<ValueNotifier<(int, bool)>, (bool, bool)>(
                    listenable: _liveProgress,
                    select: (source) => (source.value.$2, source.value.$1 == _liveParts.length),
                    builder: (context, child) {
                      final (step, running) = _liveProgress.value;
                      return IconButton(
                        key: ValueKey('chat-live-play'),
                        tooltip: running ? '暂停' : '播放',
                        onPressed: step == _liveParts.length ? null : _toggleLive,
                        icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      );
                    },
                  ),
                  ElListenableBuilder<ValueNotifier<(int, bool)>, bool>(
                    listenable: _liveProgress,
                    select: (source) => source.value.$2 || source.value.$1 == _liveParts.length,
                    builder: (context, child) => TextButton(
                      key: ValueKey('chat-live-step'),
                      onPressed: _liveProgress.value.$2 || _liveProgress.value.$1 == _liveParts.length
                          ? null
                          : _liveStep,
                      child: Text('单步'),
                    ),
                  ),
                  TextButton(key: ValueKey('chat-live-reset'), onPressed: _resetLive, child: Text('复位')),
                ],
              ),
            ),
          Expanded(child: _messagesViewport()),
          ExamplePanel(
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

class _OfficialChatRow extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _OfficialChatRow({super.key, required this.message, required this.rows});
  final _ChatMessage message;
  final Map<int, _OfficialChatRowState> rows;
  @override
  State<_OfficialChatRow> createState() => _OfficialChatRowState();
}

class _OfficialChatRowState extends State<_OfficialChatRow> {
  late final _message = ValueNotifier<_ChatMessage?>(widget.message);
  late final _row = _ChatRow(_message, widget.message.mine);
  @override
  void initState() {
    super.initState();
    widget.rows[widget.message.id] = this;
  }

  @override
  void didUpdateWidget(_OfficialChatRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.message.id != widget.message.id || !identical(oldWidget.rows, widget.rows)) &&
        identical(oldWidget.rows[oldWidget.message.id], this)) {
      oldWidget.rows.remove(oldWidget.message.id);
    }
    widget.rows[widget.message.id] = this;
    _message.value = widget.message;
  }

  void _updateMessage(_ChatMessage message) {
    if (!mounted || widget.message.id != message.id) return;
    _message.value = message;
  }

  @override
  void dispose() {
    if (identical(widget.rows[widget.message.id], this)) widget.rows.remove(widget.message.id);
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
    final bubble = ExamplePanel(
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
          ElListenableBuilder<ValueNotifier<_ChatMessage?>, String>(
            listenable: message,
            select: (value) => value.value?.text ?? '',
            builder: (context, child) => Text(message.value?.text ?? '', style: TextStyle(height: 1.5)),
          ),
          ElListenableBuilder<ValueNotifier<_ChatMessage?>, String>(
            listenable: message,
            select: (value) => value.value?.timeLabel ?? '',
            builder: (context, child) =>
                Text(message.value?.timeLabel ?? '', style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant)),
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
