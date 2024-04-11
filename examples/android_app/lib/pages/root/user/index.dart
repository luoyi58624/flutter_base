import 'package:android_app/controllers/global.dart';
import 'package:android_app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class UserPage extends StatelessWidget {
  const UserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户信息'),
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: SizedBox(height: 150),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                CupertinoButton.filled(
                  onPressed: () {
                    GlobalController.of.isLogin.value = false;
                    context.go('/login');
                  },
                  child: const Text('退出登录'),
                ),
                const SizedBox(height: 8),
                CupertinoButton.filled(
                  onPressed: () {
                    GlobalController.of.isLogin.value = false;
                  },
                  child: const Text('清除登录信息'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
