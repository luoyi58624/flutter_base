import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../layout/example_page.dart';
import '../../../widgets/example_scrollbar.dart';
import 'scroll_mode.dart';

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

enum _ChatAction { earlier, receive, latest, locate }

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

  final _chat = ElChatScrollController();
  final _unread = ValueNotifier<int>(0);
  final _messageController = ScrollController(keepScrollOffset: false);
  var _messages = _initialMessages();
  late final _liveProgress = ValueNotifier<(int, bool)>((0, false));
  var _mode = SliverExampleMode.initial;
  // 历史消息使用负业务 ID，与已存在的消息区分。
  int _oldestId = -1;
  int _nextId = 1000;
  _StreamingMessage? _stream;
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    _chat.atLatest.addListener(_clearReadMessages);
  }

  void _clearReadMessages() {
    if (_chat.atLatest.value) _unread.value = 0;
  }

  List<ElChatMessage> _earlierMessages() {
    _oldestId -= 50;
    return List.generate(50, (index) => _message(_oldestId + index));
  }

  Future<void> _loadEarlier() async {
    setState(() => _messages = [..._earlierMessages(), ..._messages]);
  }

  void _append(ElChatMessage message) {
    if (!message.isMine && !_chat.atLatest.value) _unread.value++;
    setState(() => _messages = [..._messages, message]);
  }

  void _liveStep() {
    final (step, _) = _liveProgress.value;
    if (step == _liveParts.length) return;
    final earlier = step == 0 || step == 4 ? _earlierMessages() : const <ElChatMessage>[];
    final text = _liveParts.take(step + 1).join('\n');
    final arrivals = <ElChatMessage>[];
    if (_stream case final stream?) {
      stream.text.value = text;
    } else {
      final stream = _StreamingMessage(_nextId++, text);
      _stream = stream;
      arrivals.add(stream);
    }
    if (step == 2 || step == 5) {
      arrivals.add(_message(_nextId++, mine: false, text: step == 2 ? '我在这边也看到最新进度了。' : '等记录发完我们再一起核对。'));
    }
    if (earlier.isNotEmpty || arrivals.isNotEmpty) {
      setState(() => _messages = [...earlier, ..._messages, ...arrivals]);
      if (!_chat.atLatest.value) _unread.value += arrivals.length;
    }
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
    _releaseStream();
    _oldestId = -1;
    _nextId = 1000;
    _liveProgress.value = (0, false);
    setState(() => _messages = _initialMessages());
    _showLatest();
  }

  void _releaseStream() {
    final stream = _stream;
    if (stream == null) return;
    _stream = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => stream.text.dispose());
  }

  bool _send(String text) {
    _append(_message(_nextId++, mine: true, text: text));
    return true;
  }

  void _showLatest() {
    _unread.value = 0;
    unawaited(_chat.jumpToLatest());
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
        unawaited(_loadEarlier());
      case .receive:
        _append(_message(_nextId++, mine: false));
      case .latest:
        _showLatest();
      case .locate:
        unawaited(_chat.jumpToMessage(949));
    }
  }

  Widget _messagesViewport() => RecyclerExampleScrollbar(
    controller: _messageController,
    child: ElChatScroll(
      messages: _messages,
      controller: _chat,
      scrollController: _messageController,
      sliverBuilder: switch (_mode) {
        .recycler => null,
        .official => _officialSliver,
        .builder => _builderSliver,
        .children => _childrenSliver,
      },
      messageBuilder: _messageContent,
      onOpenFile: (file) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(file.name))),
    ),
  );

  @override
  void dispose() {
    _liveTimer?.cancel();
    if (widget._live) _liveProgress.dispose();
    _releaseStream();
    _chat.atLatest.removeListener(_clearReadMessages);
    _chat.dispose();
    _unread.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExamplePage(
    title: widget._live ? '实时群聊' : '聊天长列表',
    actions: [
      Text('${_messages.length} 条', key: ValueKey('chat-count'), style: TextStyle(fontSize: 12)),
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
            ..._mode.menuItems(keyPrefix: 'chat-mode'),
            PopupMenuDivider(),
            PopupMenuItem(key: ValueKey('chat-load-earlier'), value: _ChatAction.earlier, child: Text('更早 50 条')),
            PopupMenuItem(key: ValueKey('chat-receive'), value: _ChatAction.receive, child: Text('模拟收到')),
            PopupMenuItem(key: ValueKey('chat-locate'), value: _ChatAction.locate, child: Text('定位消息 #950')),
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
          ElChatComposer(
            key: ValueKey('chat-composer'),
            onSend: _send,
            actions: [
              ElButton(
                child: Icons.image_outlined,
                semanticLabel: '发送示例图片',
                onPressed: () => _append(_sampleImage(_nextId++, mine: true)),
              ),
              ElButton(
                child: Icons.attach_file,
                semanticLabel: '发送示例文件',
                onPressed: () => _append(_sampleFile(_nextId++, mine: true)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _officialSliver(BuildContext context, SliverChildBuilderDelegate delegate) => SliverList(delegate: delegate);

Widget _builderSliver(BuildContext context, SliverChildBuilderDelegate delegate) => ElSliverList.builder(
  itemCount: delegate.childCount!,
  itemBuilder: (context, index) => delegate.builder(context, index)!,
  findChildIndexCallback: delegate.findChildIndexCallback,
  addAutomaticKeepAlives: false,
);

Widget _childrenSliver(BuildContext context, SliverChildBuilderDelegate delegate) => ElSliverList(
  stretch: true,
  children: List.generate(delegate.childCount!, (index) => delegate.builder(context, index)!),
);

Widget? _messageContent(BuildContext context, ElChatMessage message) => switch (message) {
  _StreamingMessage(:final text) => ValueListenableBuilder<String>(
    valueListenable: text,
    builder: (_, value, _) => Text(value, style: TextStyle(height: 1.5)),
  ),
  ElChatTextMessage(:final text) => Text(text, style: TextStyle(height: 1.5)),
  _ => null,
};

final _samples = [
  '收到，稍后见。',
  '今天的列表已经接好，试试快速滑动，再回来看看消息的位置。',
  '这里是一条稍长的消息。气泡会根据实际宽度换行，高度由内容决定。\n加载更早的记录时，正在阅读的消息应该留在原来的位置。',
  '这条消息包含三行：\n一、结构按方向复用。\n二、内容与时间按消息 ID 重新绑定。',
  '好！',
];

DateTime _sentAt(int id) => DateTime(2026, 1, 1, 9).add(Duration(minutes: id));
String _sender(bool mine) => mine ? '我' : '小林';

List<ElChatMessage> _initialMessages() => List.generate(1000, (id) {
  if (id == 990) return _sampleImage(id, mine: false);
  if (id == 991) return _sampleFile(id, mine: true);
  return _message(id);
});

ElChatTextMessage _message(int id, {bool? mine, String? text}) {
  final isMine = mine ?? id % 3 == 0;
  final label = id >= 0 ? '消息 #${id + 1}' : '历史消息 ${-id}';
  return ElChatTextMessage(
    id: id,
    isMine: isMine,
    senderName: _sender(isMine),
    sentAt: _sentAt(id),
    text: text ?? '$label：${_samples[id.abs() % _samples.length]}',
  );
}

ElChatImageMessage _sampleImage(int id, {required bool mine}) => ElChatImageMessage(
  id: id,
  isMine: mine,
  senderName: _sender(mine),
  sentAt: _sentAt(id),
  src: 'assets/showcase/lake.png',
  aspectRatio: 1.7,
  alt: '湖边照片',
);

ElChatFileMessage _sampleFile(int id, {required bool mine}) => ElChatFileMessage(
  id: id,
  isMine: mine,
  senderName: _sender(mine),
  sentAt: _sentAt(id),
  name: '群聊记录.txt',
  size: 2560,
);

class _StreamingMessage extends ElChatMessage {
  _StreamingMessage(int id, String text)
    : text = ValueNotifier(text),
      super(id: id, isMine: false, senderName: _sender(false), sentAt: _sentAt(id));

  final ValueNotifier<String> text;
}
