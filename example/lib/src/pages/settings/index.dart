import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

import '../../state/index.dart';
import '../../layout/example_page.dart';
import 'frame_recording/index.dart';
import 'create_vs_update/index.dart';
import 'el_scroll/index.dart';
import 'grid_scroll/index.dart';
import 'scroll_test/index.dart';

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
        spacing: 20,
        children: [
          ElListGroup(
            title: '主题与外观',
            children: [
              ElListTile.switcher(modelValue: GlobalState.isDark, title: '暗色模式'),
              _colorRow('浅色主题主色', GlobalState.primaryColor),
              _colorRow('暗色主题主色', GlobalState.darkPrimaryColor),
              ElListTile<bool>.popup(
                title: '组件尺寸（预留）',
                modelValue: GlobalState.compact,
                options: [ElLabelModel('标准', false), ElLabelModel('紧凑', true)],
              ),
            ],
          ),
          ElListGroup(
            title: '文字与缩放',
            children: [
              ElListTile<int?>.popup(
                title: '正文字重',
                modelValue: GlobalState.globalFontWeight,
                options: [
                  ElLabelModel('跟随系统', null),
                  for (final weight in [300, 400, 500, 600, 700]) ElLabelModel('$weight', weight),
                ],
              ),
              ElListTile<double>.popup(
                title: '文字缩放',
                modelValue: GlobalState.globalScale,
                options: [
                  for (final scale in [.8, 1.0, 1.2, 1.5])
                    ElLabelModel(scale == 1 ? '跟随系统' : '${(scale * 100).round()}%', scale),
                ],
              ),
            ],
          ),
          ElListGroup(
            title: '语言与方向',
            children: [
              ElListTile<Locale?>.popup(
                title: '控件语言',
                modelValue: GlobalState.locale,
                options: [
                  ElLabelModel('跟随系统', null),
                  for (final entry in GlobalState.supportedLocales.entries) ElLabelModel(entry.key, entry.value),
                ],
              ),
              ElListTile.switcher(modelValue: GlobalState.rtl, title: '从右向左排版'),
            ],
          ),
          ElListGroup(
            title: '动画',
            children: [
              ElListTile.switcher(modelValue: GlobalState.closeAnimation, title: '减少动画'),
              ElListTile.switcher(modelValue: GlobalState.slowAnimation, title: '慢动画（2 倍时长）'),
            ],
          ),
          ElListGroup(
            title: '性能与调试',
            children: [
              ElListTile.switcher(modelValue: GlobalState.showFps, title: '实时帧率'),
              ElListTile.switcher(modelValue: GlobalState.showPerformanceOverlay, title: '性能监控'),
              ElListTile(
                key: ValueKey('settings-frame-recording'),
                title: '帧耗时记录',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FrameRecordingPage())),
              ),
              ElListTile.switcher(modelValue: GlobalState.debugShowCheckedModeBanner, title: '显示 Debug 横幅'),
              ElListTile.switcher(modelValue: GlobalState.enabledRepaintRainbow, title: '重绘彩虹（Debug）'),
              ElListTile.switcher(modelValue: GlobalState.showSemanticsDebugger, title: '语义调试器'),
              ElListTile<bool>.switcher(
                key: ValueKey('settings-exclude-semantics'),
                title: '屏蔽语义',
                modelValue: GlobalState.excludeSemantics,
              ),
            ],
          ),
          ElListGroup(
            title: '文档与滚动',
            children: [
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
                  el.router.pushPage(ElScrollPage());
                },
                title: 'ElScrollView 测试',
              ),
              ElListTile(
                onTap: () {
                  el.router.pushPage(CreateVsUpdatePage());
                },
                title: '创建与更新',
              ),
              ElListTile(
                onTap: () {
                  el.router.pushPage(GridScrollPage());
                },
                title: '网格滚动',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

ElListTile<Color?> _colorRow(String title, Obs<Color?> model) => ElListTile<Color?>.popup(
  title: title,
  modelValue: model,
  options: [
    ElLabelModel('品牌默认', null),
    ElLabelModel('蓝色', Color(0xff409eff)),
    ElLabelModel('绿色', Color(0xff16a34a)),
    ElLabelModel('紫色', Color(0xff8b5cf6)),
    ElLabelModel('橙色', Color(0xffea580c)),
    ElLabelModel('红色', Color(0xffdc2626)),
  ],
);
