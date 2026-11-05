import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:go_router/go_router.dart';

import '../../../../router.dart';
import '../../../pages/components/catalog.dart';

class ComponentPage extends StatelessWidget {
  const ComponentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('组件')),
      body: ElScrollView(
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
