import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'navbar_menu.dart';
import 'desktop/navbar.dart';
import 'page_scope.dart';

/// 示例页面共用的标题栏与内容区域。
class ExamplePage extends StatelessWidget {
  /// 创建示例页，未提供内容时显示空白区域。
  const ExamplePage({
    super.key,
    required this.title,
    this.child,
    this.actions = const [],
    this.backgroundColor,
    this.showThemeToggle = false,
    this.navigationBar,
  });

  /// 导航栏标题。
  final String title;

  /// 页面正文。
  final Widget? child;

  /// 页面专用操作，独立页面放在导航头，桌面公共壳中放在正文工具区。
  final List<Widget> actions;

  /// 页面正文的背景色。
  final Color? backgroundColor;

  /// 首页显式开启的主题切换，其它页面默认不显示。
  final bool showThemeToggle;

  /// 独立导航头的局部替换，桌面公共壳仍由外层管理。
  final PreferredSizeWidget? navigationBar;

  @override
  Widget build(BuildContext context) {
    // 按应用视口切换导航；桌面侧栏压窄正文时仍沿用桌面公共头。
    final mobile = MediaQuery.sizeOf(context).width <= ElBreakpoint.defaultSm;
    final ownNavbar = mobile || !DesktopPageScope.exists(context);
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: ownNavbar && navigationBar != null
          ? navigationBar
          : mobile
          ? AppBar(title: Text(title), actions: [...actions, if (showThemeToggle) NavbarMenu()])
          : ownNavbar
          ? DesktopNavbar(
              title: title,
              leading: Navigator.of(context).canPop() ? BackButton() : null,
              showThemeToggle: showThemeToggle,
              actions: actions,
            )
          : null,
      body: ownNavbar || actions.isEmpty
          ? child
          : Column(
              crossAxisAlignment: .stretch,
              children: [
                Padding(
                  padding: .symmetric(horizontal: 16, vertical: 4),
                  child: Align(
                    alignment: .centerRight,
                    child: Wrap(crossAxisAlignment: .center, children: actions),
                  ),
                ),
                Expanded(child: child ?? SizedBox.shrink()),
              ],
            ),
    );
  }
}
