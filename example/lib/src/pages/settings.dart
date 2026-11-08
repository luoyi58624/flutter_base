import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

import '../state/index.dart';
import 'example_page.dart';
import 'frame_recording.dart';
import 'setting/create_vs_update.dart';
import 'setting/scroll_test.dart';
import 'setting/scroll_test2.dart';

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
              ElListTile(
                key: ValueKey('settings-frame-recording'),
                title: '帧耗时记录',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FrameRecordingPage())),
              ),
              ElListTile.switcher(modelValue: GlobalState.debugShowCheckedModeBanner, title: '显示 Debug 横幅'),
              ElListTile<bool>.switcher(
                key: ValueKey('settings-exclude-semantics'),
                title: '屏蔽语义',
                modelValue: GlobalState.excludeSemantics,
              ),
              ElListTile<DocScrollMode>.popup(
                key: ValueKey('settings-doc-scroll-mode'),
                title: '文档滚动',
                modelValue: GlobalState.docScrollMode,
                options: [for (final mode in DocScrollMode.values) ElLabelModel(mode.label, mode)],
              ),
              ElListTile<int>.popup(
                key: ValueKey('settings-doc-repeat-count'),
                title: '性能压力',
                modelValue: GlobalState.docRepeatCount,
                options: [
                  for (final count in [1, 2, 5, 10, 20]) ElLabelModel('$count 倍', count),
                ],
              ),
              ElListTile<bool>.switcher(
                key: ValueKey('settings-resampling-enabled'),
                title: '触摸重采样',
                modelValue: GlobalState.resamplingEnabled,
              ),
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
              ElListTile(
                onTap: () {
                  el.router.pushPage(ScrollTestPage());
                },
                title: '滚动测试',
              ),
              ElListTile(
                onTap: () {
                  el.router.pushPage(ScrollTest2());
                },
                title: 'RecyclerView 色块',
              ),
              ElListTile(
                onTap: () {
                  el.router.pushPage(CreateVsUpdatePage());
                },
                title: '创建与更新',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
