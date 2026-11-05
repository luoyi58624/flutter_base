import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'example_page.dart';
import 'showcase/buttons.dart';
import 'showcase/hero.dart';

/// 组件综合展示首页，首批展示响应式布局与按钮交互。
class HomePage extends HookWidget {
  /// 创建综合展示页。
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scroll = useMemoized(ElScrollController.new);
    useEffect(() => scroll.dispose, [scroll]);
    return ExamplePage(
      title: '首页',
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
                  itemCount: 2,
                  itemBuilder: (context, index) =>
                      index == 0 ? ShowcaseHero(onExplore: () => scroll.scrollToIndex(1)) : ButtonShowcase(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
