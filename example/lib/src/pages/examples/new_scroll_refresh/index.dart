import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// Sliver 下拉刷新的交互审核页面。
class NewScrollRefreshPage extends StatefulWidget {
  /// 创建新版刷新示例。
  const NewScrollRefreshPage({super.key});

  @override
  State<NewScrollRefreshPage> createState() => _RefreshPageState();
}

class _RefreshPageState extends State<NewScrollRefreshPage> {
  bool _reverse = false;
  bool _ios = false;
  int _refreshes = 0;

  Future<void> _refresh() async {
    await Future<void>.delayed(Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _refreshes++);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final refresher = _ios ? ElIosRefresher() : ElAndroidRefresher();
    final slivers = <Widget>[
      ElSliverRefresh(onRefresh: _refresh, refresher: refresher),
      SliverPadding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        sliver: SliverList.builder(
          itemCount: 42,
          itemBuilder: (context, index) => Card(
            margin: EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: colors.primaryContainer, child: Text('${index + 1}')),
              title: Text('第 ${index + 1} 条动态'),
              subtitle: Text('已刷新 $_refreshes 次 · 拖动边缘，松手后触发刷新'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
        ),
      ),
    ];
    final scroll = ElScroll.sliver(key: ValueKey('refresh-scroll-$_reverse'), reverse: _reverse, slivers: slivers);

    return Scaffold(
      appBar: AppBar(title: Text('新版滚动 · 下拉刷新（$_refreshes）')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('刷新器外观', style: Theme.of(context).textTheme.titleSmall),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('Android · 悬浮'),
                      selected: !_ios,
                      onSelected: (_) => setState(() => _ios = false),
                    ),
                    ChoiceChip(
                      label: Text('iOS · 内容让位'),
                      selected: _ios,
                      onSelected: (_) => setState(() => _ios = true),
                    ),
                    FilterChip(
                      label: Text('反向列表'),
                      selected: _reverse,
                      onSelected: (value) => setState(() => _reverse = value),
                    ),
                  ],
                ),
                Text(
                  'Sliver 放在正文之前，iOS 形态用真实布局占位，Android 形态悬浮。',
                  style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Expanded(child: scroll),
        ],
      ),
    );
  }
}
