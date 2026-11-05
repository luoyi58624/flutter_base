import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:go_router/go_router.dart';

import '../state/index.dart';
import '../utils/router.dart';

/// 所有页面导航头共用的主题切换与设置入口。
class NavbarMenu extends StatelessWidget {
  /// 创建公共导航菜单。
  const NavbarMenu({super.key});

  @override
  Widget build(BuildContext context) => Row(
    key: ValueKey('navbar-menu'),
    mainAxisSize: .min,
    children: [
      ObsBuilder(
        builder: (context) => IconButton(
          tooltip: GlobalState.isDark.value ? '切换到浅色模式' : '切换到暗黑模式',
          icon: Icon(GlobalState.isDark.value ? Icons.light_mode : Icons.dark_mode),
          onPressed: () => GlobalState.isDark.value = !GlobalState.isDark.value,
        ),
      ),
      IconButton(tooltip: '全局设置', icon: Icon(Icons.settings_outlined), onPressed: () => context.go(RouterUtil.setting)),
    ],
  );
}
