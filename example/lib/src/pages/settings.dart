import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

import '../state/index.dart';
import 'example_page.dart';

/// 两端共用的主题、系统和工具设置正文。
class SettingPage extends StatelessWidget {
  /// 创建设置页。
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: '设置',
      child: ElScrollView(
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
          ElListGroup(
            title: '工具设置',
            children: [
              ElListTile(
                onTap: () {
                  // el.popup
                },
                title: '无线调试',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
