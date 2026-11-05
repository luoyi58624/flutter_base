import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../state/index.dart';

/// 首页导航头使用的主题切换入口。
class NavbarMenu extends StatelessWidget {
  /// 创建首页主题切换按钮。
  const NavbarMenu({super.key});

  @override
  Widget build(BuildContext context) => ObsBuilder(
    key: ValueKey('navbar-menu'),
    builder: (context) => IconButton(
      tooltip: GlobalState.isDark.value ? '切换到浅色模式' : '切换到暗黑模式',
      icon: Icon(GlobalState.isDark.value ? Icons.light_mode : Icons.dark_mode),
      onPressed: () => GlobalState.isDark.value = !GlobalState.isDark.value,
    ),
  );
}
