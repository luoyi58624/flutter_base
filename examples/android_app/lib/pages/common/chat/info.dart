import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class ChatInfoPage extends StatelessWidget {
  const ChatInfoPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('聊天信息 - $id'),
        actions: [
          IconButton(
            onPressed: () {
              context.go('/chat/$id/info/user');
            },
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Container(),
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
