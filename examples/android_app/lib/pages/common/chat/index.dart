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
    BottomTabbarController.of.showBottomBar.value = false;
  }

  @override
  void dispose() {
    super.dispose();
    BottomTabbarController.of.showBottomBar.value = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('聊天室 - ${widget.id}'),
      ),
      body: buildListViewDemo(),
    );
  }
}
