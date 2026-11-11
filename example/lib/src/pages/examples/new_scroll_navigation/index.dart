import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 对比两种导航组件和三个折叠命名构造的真实手感。
class NewScrollNavigationPage extends StatefulWidget {
  /// 创建导航特效审核页。
  const NewScrollNavigationPage({super.key});

  @override
  State<NewScrollNavigationPage> createState() => _NavigationState();
}

enum _Mode { largeTitle, scroll, floating, bibi }

class _NavigationState extends State<NewScrollNavigationPage> {
  _Mode _mode = _Mode.largeTitle;
  final _bibiProgress = ValueNotifier<double>(0);

  @override
  void dispose() {
    _bibiProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('新版导航特效')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (mode, label) in [
                  (_Mode.largeTitle, 'LargeTitle'),
                  (_Mode.scroll, '位置折叠'),
                  (_Mode.floating, '方向浮现'),
                  (_Mode.bibi, 'Bibi 吸收'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _mode == mode,
                    onSelected: (_) {
                      _bibiProgress.value = 0;
                      setState(() => _mode = mode);
                    },
                  ),
              ],
            ),
          ),
          if (_mode == _Mode.bibi)
            ValueListenableBuilder<double>(
              valueListenable: _bibiProgress,
              builder: (context, value, _) => Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  '折叠进度 ${(value * 100).round()}% · 正文任意位置先收起搜索栏；'
                  '拖到一半附近，保持手指不动试试自动吸附。',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(switch (_mode) {
                _Mode.largeTitle => '官方自然高度 ResizingHeader：向上滚动缩小标题。',
                _Mode.scroll => '官方 PersistentHeader：滚动偏移决定高度和封面透明度。',
                _Mode.floating => '官方 FloatingHeader：上滑隐藏，回拉即浮现。',
                _Mode.bibi => '',
              }, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
          Expanded(
            child: ElScroll.sliver(
              key: ValueKey('navigation-${_mode.name}'),
              physics: ClampingScrollPhysics(),
              slivers: [
                switch (_mode) {
                  _Mode.largeTitle => ElSliverLargeTitle(
                    title: '我的收藏',
                    leading: Icon(Icons.bookmark_outline),
                    actions: [IconButton(onPressed: () {}, icon: Icon(Icons.more_horiz))],
                    backgroundColor: scheme.surface,
                    bottom: TextField(
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: '搜索收藏',
                        filled: true,
                        fillColor: scheme.surfaceContainerLow,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                  ),
                  _Mode.scroll => ElSliverCollapse.scroll(
                    minExtent: 56,
                    maxExtent: 182,
                    pinned: true,
                    builder: (context, progress) => Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: scheme.surfaceContainerHighest),
                        Opacity(
                          opacity: 1 - progress,
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('远山来信', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          top: 14,
                          child: Opacity(
                            opacity: progress,
                            child: Text('远山来信', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Mode.floating => ElSliverCollapse.floating(
                    child: Material(
                      color: scheme.primaryContainer,
                      child: SizedBox(
                        height: 56,
                        child: Row(
                          children: [
                            SizedBox(width: 16),
                            Icon(Icons.menu_open),
                            SizedBox(width: 12),
                            Text('反向滚动即浮现', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _Mode.bibi => ElSliverCollapse.bibi(
                    compactExtent: 48,
                    contentExtent: 58,
                    backgroundColor: Colors.white,
                    compact: Container(
                      color: Colors.white,
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('首页    关注    推荐    热门', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    content: Container(
                      color: Colors.white,
                      padding: EdgeInsets.fromLTRB(16, 5, 16, 9),
                      child: Container(
                        decoration: BoxDecoration(color: Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text('搜索视频、话题与用户', style: TextStyle(color: Colors.black54)),
                      ),
                    ),
                    onProgressChanged: (value) {
                      if ((_bibiProgress.value - value).abs() > .01) _bibiProgress.value = value;
                    },
                  ),
                },
                SliverPadding(
                  padding: EdgeInsets.all(12),
                  sliver: SliverList.builder(
                    itemCount: 60,
                    itemBuilder: (context, index) => Card(
                      margin: EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text('第 ${index + 1} 条内容'),
                        subtitle: Text('保持停留在列表中间，再向上 / 向下拖拽导航'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
