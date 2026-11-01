import 'package:example/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ElScrollView(
        padding: .all(20),
        gap: 20,
        children: [
          ElListGroup(
            title: '主题设置',
            children: [ElListTile.switcher(modelValue: GlobalState.isDark, title: '主题模式')],
          ),
          ElListGroup(
            title: '系统设置',
            children: [
              ElListTile.switcher(modelValue: GlobalState.showPerformanceOverlay, title: '性能监控'),
              ElListTile.switcher(modelValue: GlobalState.debugShowCheckedModeBanner, title: '显示 Debug 横幅'),
            ],
          ),
        ],
      ),
    );
  }
}
