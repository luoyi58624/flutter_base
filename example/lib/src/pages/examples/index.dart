import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

import '../../layout/example_page.dart';
import '../../utils/router.dart';
import 'bibi/index.dart';
import 'new_bibi_collapse/index.dart';
import 'new_scroll_navigation/index.dart';
import 'new_scroll_nested/index.dart';
import 'new_scroll_refresh/index.dart';
import 'official_gesture/index.dart';
import 'press_feedback/index.dart';
import 'scroll_examples/index.dart';
import 'sliver_bibi/index.dart';
import 'sliver_list/index.dart';
import 'sliver_recycler/index.dart';
import 'sliver_recycler_grid/index.dart';
import 'sliver_takeaway/index.dart';
import 'view/index.dart';
import 'view_base/index.dart';

import 'navigation_effects/index.dart';

export 'navigation_effects/index.dart' show navigationEffectExamples;
export 'scroll_examples/index.dart' show scrollBusinessExamples;

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
              child: ElScroll(
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
                  ElListGroup(
                    title: '导航特效 · 旧版 15 个示例迁移',
                    children: [
                      for (final page in navigationEffectExamples)
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

/// 独立高级示例的统一目录，同时供目录点击与深度路由读取页面工厂。
final advancedExamples = <ElMenuModel<WidgetBuilder>>[
  ElMenuModel(key: 'bibi-home', title: 'Bibi 首页', icon: ElIcon(Icons.video_library_outlined), data: (_) => BibiPage()),
  ElMenuModel(
    key: 'sliver-bibi',
    title: 'Bibi Sliver 对照',
    icon: ElIcon(Icons.view_day_outlined),
    data: (_) => SliverBibiPage(),
  ),
  ElMenuModel(
    key: 'bibi-plain',
    title: 'Bibi 非虚拟',
    icon: ElIcon(Icons.view_stream_outlined),
    data: (_) => BibiPlainPage(),
  ),
  ElMenuModel(
    key: 'sliver-recycler',
    title: 'SliverRecycler 性能对照',
    icon: ElIcon(Icons.view_list_outlined),
    data: (_) => ElSliverRecyclerExamplePage(),
  ),
  ElMenuModel(
    key: 'sliver-recycler-grid',
    title: 'Sliver 网格示例',
    icon: ElIcon(Icons.grid_view_outlined),
    data: (_) => ElSliverRecyclerGridExamplePage(),
  ),
  ElMenuModel(
    key: 'sliver-recycler-masonry',
    title: 'Sliver 瀑布流示例',
    icon: ElIcon(Icons.view_quilt_outlined),
    data: (_) => ElSliverRecyclerGridExamplePage.masonry(),
  ),
  ElMenuModel(
    key: 'sliver-list',
    title: '文档滚动（全量常驻）',
    icon: ElIcon(Icons.description_outlined),
    data: (_) => ElSliverListExamplePage(),
  ),
  ElMenuModel(key: 'view', title: 'ElView 测试', icon: ElIcon(Icons.web_outlined), data: (_) => ElViewPage()),
  ElMenuModel(key: 'base', title: 'ElView 基础使用', icon: ElIcon(Icons.layers_outlined), data: (_) => ViewBasePage()),
  ElMenuModel(
    key: 'press-feedback',
    title: '按压反馈',
    icon: ElIcon(Icons.ads_click_outlined),
    data: (_) => PressFeedbackPage(),
  ),
  ElMenuModel(
    key: 'official-zoom-pager',
    title: '官方手势 · 缩放翻页交接',
    icon: ElIcon(Icons.zoom_out_map_outlined),
    data: (_) => OfficialZoomPagerPage(),
  ),
];

/// 新版滚动示例，两端共用相同分组和页面工厂。
final sliverScrollExamples = <ElMenuModel<WidgetBuilder>>[
  ElMenuModel(
    key: 'new-bibi-collapse',
    title: 'Bibi · 新版折叠导航与真实视频流',
    icon: ElIcon(Icons.video_library_outlined),
    data: (_) => NewBibiCollapsePage(),
  ),
  ElMenuModel(
    key: 'new-scroll-navigation',
    title: '导航特效（LargeTitle / Collapse）',
    icon: ElIcon(Icons.auto_awesome_outlined),
    data: (_) => NewScrollNavigationPage(),
  ),
  ElMenuModel(
    key: 'new-scroll-nested',
    title: '嵌套滚动与 shrinkWrap',
    icon: ElIcon(Icons.swap_vert_outlined),
    data: (_) => NewScrollNestedPage(),
  ),
  ElMenuModel(
    key: 'new-scroll-refresh',
    title: '下拉刷新（Widget / Sliver）',
    icon: ElIcon(Icons.refresh_outlined),
    data: (_) => NewScrollRefreshPage(),
  ),
  ElMenuModel(
    key: 'sliver-takeaway',
    title: '外卖商家列表',
    icon: ElIcon(Icons.delivery_dining_outlined),
    data: (_) => TakeawaySliverPage(),
  ),
];
