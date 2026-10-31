import 'package:example/src/pages/custom_gestures.dart';
import 'package:example/src/pages/view.dart';
import 'package:example/src/pages/view/base.dart';
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
  String _current = 'home';

  @override
  Widget build(BuildContext context) {
    final pages = [
      ('home', Center(child: Text('首页'))),
      ('components', Center(child: Text('组件'))),
      ('component-overview', Center(child: Text('组件概览'))),
      ('view', ElViewPage()),
      ('gestures', CustomGesturesPage()),
      ('base', ViewBasePage()),
      ('settings', Center(child: Text('设置'))),
    ];

    return Scaffold(
      body: ElView(
        style: .new(backgroundColor: ElThemeData.of(context).bgColor),
        child: Row(
          crossAxisAlignment: .stretch,
          children: [
            _Sidebar(
              current: _current,
              onChanged: (value) => setState(() => _current = value),
            ),
            Expanded(
              // 页面顺序固定，切换菜单时复用已挂载的页面状态。
              child: IndexedStack(
                index: pages.indexWhere((page) => page.$1 == _current),
                children: [for (final page in pages) page.$2],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
