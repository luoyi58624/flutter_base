import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:go_router/go_router.dart';

import '../../../router.dart';

part 'sidebar.dart';

/// 桌面布局，侧边菜单与正文由当前路由连接。
class DesktopLayout extends StatelessWidget {
  /// 创建桌面布局。
  const DesktopLayout({super.key, required this.child});

  /// 当前路由页面。
  final Widget child;

  @override
  Widget build(BuildContext context) => ElComponentProvider(
    components: el.desktopComponents,
    child: Scaffold(
      body: ElView(
        style: ElStyle(backgroundColor: context.elTheme.bgColor),
        child: Row(
          crossAxisAlignment: .stretch,
          children: [
            _Sidebar(),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}
