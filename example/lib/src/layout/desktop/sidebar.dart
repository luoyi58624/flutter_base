import 'package:flutter/widgets.dart';
import 'package:flutter_base/desktop.dart';
import 'package:go_router/go_router.dart';

import '../../utils/router.dart';

/// 桌面导航头下方的路由菜单，分组只负责展示。
class DesktopSidebar extends StatelessWidget {
  /// 创建桌面侧栏。
  const DesktopSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: .new(
        width: 260,
        height: '100%',
        backgroundColor: context.elTheme.cardColor,
        border: ElBorder.only(borderRight: ElBorderSide(borderColor: context.elTheme.dividerColor, borderWidth: .5)),
      ),
      child: ElNavMenu<WidgetBuilder>.router(
        router: GoRouter.of(context),
        onChanged: (path) => context.go(path),
        children: RouterUtil.desktopMenus,
      ),
    );
  }
}
