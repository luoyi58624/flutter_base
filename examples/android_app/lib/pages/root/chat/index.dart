import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class ChatRootPage extends StatefulWidget {
  const ChatRootPage({super.key});

  @override
  State<ChatRootPage> createState() => _ChatRootPageState();
}

class _ChatRootPageState extends State<ChatRootPage> {
  final ScrollController scrollController = ScrollController();
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天列表'),
        actions: [
          IconButton(
            onPressed: () {
              DrawerUtil.show(
                width: 200,
                child: buildListViewDemo(),
              );
            },
            icon: const Icon(Icons.menu),
          ),
        ],
      ),
      body: Scrollbar(
        controller: scrollController,
        child: SuperListView.separated(
          controller: scrollController,
          itemCount: 50,
          itemBuilder: (context, index) => _ChatItem(index),
          separatorBuilder: buildSeparatorWidget(context, indent: 80),
        ),
      ),
    );
  }
}

class _ChatItem extends StatefulWidget {
  const _ChatItem(this.index);

  final int index;

  @override
  State<_ChatItem> createState() => _ChatItemState();
}

class _ChatItemState extends State<_ChatItem> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.go('/chat/${widget.index}');
        // context.push(context, ChatPage(id: widget.index.toString()), rootNavigator: true);
      },
      child: Container(
        height: 72,
        padding: const EdgeInsets.only(left: 12, top: 4),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.person, size: 36, color: Colors.grey),
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '聊天会话 - ${widget.index}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '同样ssr框架，就React有问题',
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
