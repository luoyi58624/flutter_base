import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

import 'navbar.dart';
import 'sidebar.dart';

/// 桌面布局，侧边菜单与正文由当前路由连接。
class DesktopLayout extends StatelessWidget {
  /// 创建桌面布局。
  const DesktopLayout({super.key, required this.title, required this.child});

  /// 由页面声明生成的导航标题。
  final String title;

  /// 当前路由页面。
  final Widget child;

  @override
  Widget build(BuildContext context) => ElComponentProvider(
    components: el.desktopComponents,
    child: Scaffold(
      appBar: DesktopNavbar(title: title),
      body: ElView(
        style: ElStyle(backgroundColor: context.elTheme.bgColor),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            crossAxisAlignment: .stretch,
            children: [
              // 退出中的旧壳也会收到窄屏约束，直接按本帧宽度收起侧栏。
              if (constraints.maxWidth > ElBreakpoint.defaultSm) const DesktopSidebar(),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    ),
  );
}
