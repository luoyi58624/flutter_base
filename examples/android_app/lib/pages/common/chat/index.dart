import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.id});

  final String id;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {

  @override
  void initState() {
    super.initState();
    logger.i('进入聊天室 - ${widget.id}');
  }

  @override
  void dispose() {
    super.dispose();
    logger.i('退出聊天室 - ${widget.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('聊天室 - ${widget.id}'),
        actions: [
          IconButton(
            onPressed: () {
              context.go('/chat/${widget.id}/info');
            },
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: buildListViewDemo(),
          ),
          Container(
            height: 50,
            decoration: const BoxDecoration(
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}
