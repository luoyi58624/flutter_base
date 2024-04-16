import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class ChatInfoPage extends StatefulWidget {
  const ChatInfoPage({super.key, required this.id});

  final String id;

  @override
  State<ChatInfoPage> createState() => _ChatInfoPageState();
}

class _ChatInfoPageState extends State<ChatInfoPage> {
  int newId = Random().nextInt(50);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('聊天信息 - ${widget.id}'),
        actions: [
          IconButton(
            onPressed: () {
              context.go('/chat/${widget.id}/info/user');
            },
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            context.push('/chat/$newId');
          },
          child: Text('跳转到新的聊天室 - $newId'),
        ),
      ),
    );
  }
}

class ChatUserInfoPage extends StatelessWidget {
  const ChatUserInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天用户信息'),
      ),
      body: Container(),
    );
  }
}
