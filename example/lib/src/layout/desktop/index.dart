import 'package:example/src/layout/index.dart';
import 'package:example/src/pages/custom_gestures.dart';
import 'package:example/src/pages/view.dart';
import 'package:example/src/pages/view/base.dart';
import 'package:example/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

part 'sidebar.dart';

/// 桌面布局，通过侧边菜单切换并保留各示例页面的状态。
class DesktopLayout extends StatefulWidget {
  /// 创建桌面布局。
  const DesktopLayout({super.key});

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  String _selected = 'home';

  @override
  Widget build(BuildContext context) {
    return ObsBuilder(
      builder: (context) {
        final tabIndex = GlobalState.boottomTabbarIndex.value;
        // 叶子属于当前 tab 时保留选择，外部切换 tab 则使用一级菜单 key。
        final selected = AppLayout.menuTabs[_selected] == tabIndex
            ? _selected
            : AppLayout.tabKeyOf(tabIndex);
        final pages = [
          ('home', Center(child: Text('首页'))),
          ('components', Center(child: Text('组件'))),
          ('component-overview', Center(child: Text('组件概览'))),
          ('examples', Center(child: Text('示例'))),
          ('view', ElViewPage()),
          ('gestures', CustomGesturesPage()),
          ('base', ViewBasePage()),
          ('settings', Center(child: Text('设置'))),
        ];
        final pageIndex = pages.indexWhere((page) => page.$1 == selected);

        return Scaffold(
          body: ElView(
            style: .new(backgroundColor: context.elTheme.bgColor),
            child: Row(
              crossAxisAlignment: .stretch,
              children: [
                _Sidebar(
                  current: selected,
                  onChanged: (key) => setState(() {
                    _selected = key;
                    GlobalState.boottomTabbarIndex.value =
                        AppLayout.menuTabs[key] ?? 0;
                  }),
                ),
                Expanded(
                  // 页面顺序固定，切换菜单时复用已挂载的页面状态。
                  child: IndexedStack(
                    index: pageIndex < 0 ? 0 : pageIndex,
                    children: [for (final page in pages) page.$2],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
