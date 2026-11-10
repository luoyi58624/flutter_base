import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

import '../utils/router.dart';
import 'example_page.dart';
import 'examples/index.dart';

/// 两端共用的高级示例目录，列表统一使用移动端预设。
class ExamplesPage extends StatelessWidget {
  /// 创建示例一级页。
  const ExamplesPage({super.key});

  @override
  Widget build(BuildContext context) => ExamplePage(
    title: '示例',
    child: ElComponentProvider(
      components: el.mobileComponents,
      child: Builder(
        builder: (context) => ElView(
          style: ElStyle(backgroundColor: context.elTheme.bgColor),
          child: Align(
            alignment: .topCenter,
            child: ConstrainedBox(
              constraints: .new(maxWidth: 880),
              child: ElScrollView(
                key: PageStorageKey('advanced-examples'),
                padding: .all(24),
                gap: 24,
                children: [
                  Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    spacing: 8,
                    children: [
                      Text('高级示例', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: .w700)),
                      Text('独立体验视图、手势与交互细节。', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  ElListGroup(
                    title: '交互与视图',
                    children: [
                      for (final page in advancedExamples)
                        ElListTile(
                          key: ValueKey('advanced-${page.key}'),
                          title: page.title,
                          leading: page.icon,
                          onTap: () => RouterUtil.push(page.data!),
                        ),
                    ],
                  ),
                  ElListGroup(
                    title: 'Sliver 业务示例',
                    children: [
                      for (final page in scrollBusinessExamples)
                        ElListTile(
                          key: ValueKey('advanced-${page.key}'),
                          title: page.title,
                          leading: page.icon,
                          onTap: () => RouterUtil.push(page.data!),
                        ),
                    ],
                  ),
                  ElListGroup(
                    title: '新版滚动',
                    children: [
                      for (final page in sliverScrollExamples)
                        ElListTile(
                          key: ValueKey('advanced-${page.key}'),
                          title: page.title,
                          leading: page.icon,
                          onTap: () => RouterUtil.push(page.data!),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
