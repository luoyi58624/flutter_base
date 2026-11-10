import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:go_router/go_router.dart';

import '../../utils/router.dart';
import '../example_page.dart';
import 'catalog.dart';

/// 移动导航下的组件目录，叶子与桌面侧栏共用页面声明。
class ComponentPage extends StatelessWidget {
  /// 创建组件目录页。
  const ComponentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: '组件',
      child: ElScroll(
        key: PageStorageKey('component-catalog'),
        padding: .fromLTRB(16, 8, 16, 24),
        children: [
          Column(
            spacing: 16,
            children: [
              for (final group in componentCatalog)
                ElListGroup(
                  title: group.title,
                  children: [
                    for (final item in group.children)
                      ElListTile(
                        key: ValueKey('component-${item.key}'),
                        title: item.title,
                        onTap: () => context.go('${RouterUtil.component}/${item.key}'),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
