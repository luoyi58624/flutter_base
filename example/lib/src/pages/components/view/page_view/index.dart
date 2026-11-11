import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../layout/example_page.dart';
import '../../../../widgets/view_card.dart';

/// 官方分页与横向滚动边缘交接示例。
class PageViewPage extends HookWidget {
  /// 创建沿用旧 Tab 示例内容的分页页。
  const PageViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pages = usePageController();
    final tabs = useTabController(initialLength: _tabs.length);
    return ExamplePage(
      title: 'PageView 分页视图',
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {...ScrollConfiguration.of(context).dragDevices, PointerDeviceKind.mouse},
          scrollbars: false,
        ),
        child: Column(
          children: [
            TabBar(
              controller: tabs,
              onTap: (index) =>
                  pages.animateToPage(index, duration: Duration(milliseconds: 300), curve: Curves.easeOut),
              tabs: [
                for (final tab in _tabs)
                  Tab(
                    child: Row(
                      mainAxisSize: .min,
                      spacing: 8,
                      children: [
                        Text(tab.title),
                        DecoratedBox(
                          decoration: BoxDecoration(color: Color(0xffe2e8f0), borderRadius: .circular(999)),
                          child: Padding(
                            padding: .symmetric(horizontal: 7, vertical: 2),
                            child: Text(tab.badge, style: TextStyle(fontSize: 11, color: Color(0xff475569))),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Expanded(
              child: ElPageView.builder(
                controller: pages,
                itemCount: _tabs.length,
                onPageChanged: (index) {
                  tabs.animateTo(index);
                },
                itemBuilder: (context, index) => _TabPane(key: ValueKey(index), tab: _tabs[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabPane extends StatefulWidget {
  const _TabPane({super.key, required this.tab});
  final _TabData tab;

  @override
  State<_TabPane> createState() => _TabPaneState();
}

class _TabPaneState extends State<_TabPane> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tab = widget.tab;
    return ColoredBox(
      color: Color(0xfff8fafc),
      child: ElScroll.sliver(
        key: PageStorageKey('page-list-${tab.title}'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: .fromLTRB(16, 16, 16, 8),
              child: Text(tab.description, style: TextStyle(fontSize: 14, height: 1.45, color: Color(0xff475569))),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: .only(bottom: 12),
              child: SizedBox(
                height: 112,
                child: ElScroll(
                  key: PageStorageKey('page-strip-${tab.title}'),
                  axis: .horizontal,
                  padding: .symmetric(horizontal: 12),
                  gap: 8,
                  children: List.generate(12, (index) => _StripCard(tab: tab, index: index)),
                ),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: tab.count,
            itemBuilder: (context, index) => ExampleViewCard(item: demoCards[index % demoCards.length]),
          ),
        ],
      ),
    );
  }
}

class _StripCard extends StatelessWidget {
  const _StripCard({required this.tab, required this.index});
  final _TabData tab;
  final int index;

  @override
  Widget build(BuildContext context) => ElCard(
    style: ElStyle(
      width: 132,
      padding: .all(12),
      backgroundColor: Colors.white,
      border: .all(borderColor: Color(0xffe2e8f0)),
      borderRadius: .circular(10),
      boxShadow: [BoxShadow(color: Color(0x0f0f172a), blurRadius: 10, offset: Offset(0, 3))],
    ),
    child: Column(
      crossAxisAlignment: .start,
      spacing: 6,
      children: [
        ElView(
          style: ElStyle(width: 10, height: 10, backgroundColor: tab.accent, borderRadius: .circular(99)),
        ),
        Text(
          '${tab.title} 精选 ${index + 1}',
          style: TextStyle(fontSize: 13, fontWeight: .w700, color: Color(0xff0f172a)),
        ),
        Text('滚到边缘继续拉 → 切页', style: TextStyle(fontSize: 11, color: Color(0xff94a3b8))),
      ],
    ),
  );
}

final _tabs = [
  _TabData('消息', '900', 900, Color(0xff2563eb), '横向拖动切换页面；顶部横向滚动带到边缘后继续拉动，即可切页。'),
  _TabData('订单', '1.2k', 1200, Color(0xff059669), '长列表按需构建，切换页面后保留滚动位置和已选中的卡片。'),
  _TabData('日志', '2k', 2000, Color(0xffdc2626), '上下滚动查看日志；左右拖动切页，横向卡片带优先响应。'),
];

class _TabData {
  const _TabData(this.title, this.badge, this.count, this.accent, this.description);
  final String title;
  final String badge;
  final int count;
  final Color accent;
  final String description;
}
