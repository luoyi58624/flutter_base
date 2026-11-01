import 'package:example/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 首页内容，提供应用明暗主题切换。
class HomePage extends StatelessWidget {
  /// 创建首页。
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        actions: [
          ObsBuilder(
            builder: (context) {
              final isDark = GlobalState.isDark.value;
              return IconButton(
                tooltip: isDark ? '切换到浅色模式' : '切换到暗黑模式',
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => GlobalState.isDark.value = !isDark,
              );
            },
          ),
        ],
      ),
      body: Container(),
    );
  }
}
