import 'dart:math';

import 'package:android_app/global.dart';
import 'package:flutter/material.dart';

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
      body: buildCenterColumn(
        [
          ElevatedButton(
            onPressed: () {
              context.go('/chat/$newId');
            },
            child: Text('go - $newId'),
          ),
          ElevatedButton(
            onPressed: () {
              context.pushPath('/chat/$newId');
            },
            child: Text('push - $newId'),
          ),
          ElevatedButton(
            onPressed: () {
              context.go('/chat');
            },
            child: const Text('回到聊天列表'),
          ),
          ElevatedButton(
            onPressed: () {
              context.go(RoutePath.root);
            },
            child: const Text('跳转到首页'),
          ),
          ElevatedButton(
            onPressed: () {
              context.go('${RoutePath.root}/image');
            },
            child: const Text('跳转到首页图片测试'),
          ),
        ],
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
