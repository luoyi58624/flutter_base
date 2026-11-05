import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../layout/navbar_menu.dart';

/// 示例页面共用的标题栏与内容区域。
class ExamplePage extends StatelessWidget {
  /// 创建示例页，未提供内容时显示空白区域。
  const ExamplePage({super.key, required this.title, this.child, this.actions = const [], this.backgroundColor});

  /// 导航栏标题。
  final String title;

  /// 页面正文。
  final Widget? child;

  /// 页面专用操作，移动端放在导航头，桌面端放在正文工具区。
  final List<Widget> actions;

  /// 页面正文的背景色。
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    // 按应用视口切换导航；桌面侧栏压窄正文时仍沿用桌面公共头。
    final mobile = MediaQuery.sizeOf(context).width <= ElBreakpoint.defaultSm;
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: mobile ? AppBar(title: Text(title), actions: [...actions, NavbarMenu()]) : null,
      body: mobile || actions.isEmpty
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
