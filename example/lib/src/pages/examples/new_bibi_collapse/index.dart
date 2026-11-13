import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter_base.dart';

import '../bibi/chrome.dart';
import '../bibi/feed.dart';

/// 用 ElSliverCollapse.priority 直接承载原 Bibi 的搜索、频道与双列视频流。
///
/// 原版 SliverBibiPage 保留作为对照；此页用现有官方 Scrollable + Sliver 实现，
/// 不再为页面额外定义 ScrollPhysics 或 ScrollPosition。
class NewBibiCollapsePage extends StatefulWidget {
  const NewBibiCollapsePage({super.key});

  @override
  State<NewBibiCollapsePage> createState() => _NewBibiCollapsePageState();
}

class _NewBibiCollapsePageState extends State<NewBibiCollapsePage> {
  static const channels = ['直播', '推荐', '热门', '动画', '影视', 'S16', '知识', '游戏', '音乐', '生活'];
  final scrollControllers = List.generate(channels.length, (_) => ScrollController());
  final progress = ValueNotifier<double>(0);
  var selected = 1;
  var generation = 0;

  @override
  void dispose() {
    for (final controller in scrollControllers) {
      controller.dispose();
    }
    progress.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(Duration(milliseconds: 500));
    if (mounted) setState(() => generation++);
  }

  void _goTop() {
    final controller = scrollControllers[selected];
    if (controller.hasClients) controller.animateTo(0, duration: Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _select(int index) {
    if (selected == index) {
      _goTop();
      return;
    }
    setState(() => selected = index);
    progress.value = 0;
  }

  Widget _search(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: Padding(
      padding: EdgeInsetsDirectional.only(start: 18, end: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: Color(0xffe9ebef), shape: BoxShape.circle),
            child: Icon(Icons.tv, color: Color(0xff9ca3ad)),
          ),
          SizedBox(width: 14),
          Expanded(
            child: InkWell(
              onTap: () => showBibiSearch(context, generation),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                height: 38,
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Color(0xffa2a7ae)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 21, color: Color(0xff5d6269)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '发现好看的视频',
                        style: TextStyle(fontSize: 15, color: Color(0xff5d6269), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          CircleAvatar(
            backgroundColor: Color(0xffffe2ed),
            child: Text('哔', style: TextStyle(color: Color(0xffe75886))),
          ),
          SizedBox(width: 8),
          IconButton(
            tooltip: '消息',
            icon: Icon(Icons.mail_outline),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('暂无新消息'))),
          ),
        ],
      ),
    ),
  );

  Widget _tabs(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: progress,
    builder: (context, value, _) => ColoredBox(
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              key: ValueKey('bibi-collapse-channels'),
              scrollDirection: Axis.horizontal,
              itemCount: channels.length,
              itemBuilder: (context, index) => InkWell(
                onTap: () => _select(index),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: Text(
                      channels[index],
                      style: TextStyle(
                        color: index == selected ? Color(0xfffb7299) : Color(0xff5d6269),
                        fontWeight: index == selected ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (value > .7)
            IconButton(
              tooltip: '折叠后搜索',
              onPressed: () => showBibiSearch(context, generation),
              icon: Icon(Icons.search, color: Color(0xfffb7299)),
            ),
          IconButton(
            tooltip: '更多频道',
            onPressed: () {},
            icon: Icon(Icons.menu, color: Color(0xff5d6269)),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: Color(0xfff1f2f4),
        bottomNavigationBar: SizedBox(
          height: 56 + bottomSafe,
          child: BibiBottomBar(
            bottomInset: bottomSafe,
            onHome: _goTop,
            onFollowing: () => _select(2),
            onBack: () => Navigator.maybePop(context),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: ElScrollView.sliver(
            key: ValueKey('new-bibi-channel-$selected'),
            controller: scrollControllers[selected],
            physics: ClampingScrollPhysics(),
            slivers: [
              ElSliverCollapse.priority(
                compactExtent: 43,
                contentExtent: 58,
                compact: _tabs(context),
                content: _search(context),
                backgroundColor: Colors.white,
                onProgressChanged: (v) {
                  if ((progress.value - v).abs() > .001) progress.value = v;
                },
              ),
              ElSliverRefresh(
                onRefresh: _refresh,
                refresher: ElAndroidRefresher(color: Color(0xfffb7299), bgColor: Colors.white),
              ),
              SliverToBoxAdapter(child: buildBibiBanner(context, generation)),
              SliverList.builder(
                key: ValueKey('new-bibi-rows-$selected-$generation'),
                itemCount: bibiVideoRowCount,
                itemBuilder: (context, row) => buildBibiVideoRow(context, row, generation),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
