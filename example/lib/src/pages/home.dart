import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../utils/router.dart';
import 'example_page.dart';
import 'examples/index.dart';
import 'showcase/buttons.dart';
import 'showcase/hero.dart';
import '../widgets/panel.dart';

/// 组件综合展示首页，提供滚动示例入口、响应式布局与按钮交互。
class HomePage extends HookWidget {
  /// 创建综合展示页。
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scroll = useMemoized(ElScrollController.new);
    useEffect(() => scroll.dispose, [scroll]);
    return ExamplePage(
      title: '首页',
      showThemeToggle: true,
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: .topCenter,
          child: ConstrainedBox(
            constraints: .new(maxWidth: 1200),
            child: ElScrollView(
              key: PageStorageKey('showcase-scroll'),
              controller: scroll,
              padding: .all(constraints.maxWidth < 600 ? 16 : 32),
              children: [
                ElListView.builder(
                  keepAlive: true,
                  gap: 36,
                  itemCount: 3,
                  itemBuilder: (context, index) => switch (index) {
                    0 => _ScrollEntries(),
                    1 => ShowcaseHero(onExplore: () => scroll.scrollToIndex(2)),
                    _ => ButtonShowcase(),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrollEntries extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExamplePanel(
      style: ElStyle(
        backgroundColor:
            theme.cardTheme.color ?? (theme.useMaterial3 ? theme.colorScheme.surfaceContainerLow : theme.cardColor),
        borderRadius: .circular(theme.useMaterial3 ? 12 : 4),
        clipBehavior: .antiAlias,
      ),
      // ListTile 的墨水效果绘制在卡片内，避免被外层背景遮住。
      child: Material(
        type: .transparency,
        child: Column(
          children: [
            for (final page in advancedExamples.where(
              (page) => {
                'sliver-recycler',
                'sliver-recycler-grid',
                'sliver-recycler-masonry',
                'sliver-list',
              }.contains(page.key),
            ))
              ListTile(
                key: ValueKey('home-${page.key}'),
                leading: page.icon,
                title: Text(page.title),
                trailing: Icon(Icons.chevron_right),
                onTap: () => RouterUtil.push(page.data!),
              ),
          ],
        ),
      ),
    );
  }
}
