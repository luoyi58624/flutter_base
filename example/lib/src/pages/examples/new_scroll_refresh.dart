import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// Widget 与 Sliver 两种下拉刷新入口的交互审核页面。
class NewScrollRefreshPage extends StatefulWidget {
  /// 创建新版刷新示例。
  const NewScrollRefreshPage({super.key});

  @override
  State<NewScrollRefreshPage> createState() => _RefreshPageState();
}

class _RefreshPageState extends State<NewScrollRefreshPage> {
  bool _useSliver = false;
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
      if (_useSliver) ElSliverRefresh(onRefresh: _refresh, refresher: refresher),
      SliverPadding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        sliver: SliverList.builder(
          itemCount: 42,
          itemBuilder: (context, index) => Card(
            margin: EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: colors.primaryContainer,
                child: Text('${index + 1}'),
              ),
              title: Text('第 ${index + 1} 条动态'),
              subtitle: Text('已刷新 $_refreshes 次 · 拖动边缘，松手后触发刷新'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
        ),
      ),
    ];
    final scroll = ElScroll.sliver(
      key: ValueKey('refresh-scroll-$_useSliver-$_reverse'),
      reverse: _reverse,
      slivers: slivers,
    );
    final content = _useSliver
        ? scroll
        : ElRefresh(
            onRefresh: _refresh,
            refresher: refresher,
            axisDirection: _reverse ? AxisDirection.up : AxisDirection.down,
            child: scroll,
          );

    return Scaffold(
      appBar: AppBar(title: Text('新版滚动 · 下拉刷新（$_refreshes）')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('刷新入口', style: Theme.of(context).textTheme.titleSmall),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: Text('Widget · ElRefresh'),
                      selected: !_useSliver,
                      onSelected: (_) => setState(() => _useSliver = false),
                    ),
                    ChoiceChip(
                      label: Text('Sliver · ElSliverRefresh'),
                      selected: _useSliver,
                      onSelected: (_) => setState(() => _useSliver = true),
                    ),
                  ],
                ),
                SizedBox(height: 8),
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
                  _useSliver
                      ? 'Sliver 放在正文之前，iOS 形态用真实布局占位，Android 形态悬浮。'
                      : 'Widget 包裹整个 ElScroll；支持 leading / trailing 两侧刷新。',
                  style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Expanded(child: content),
        ],
      ),
    );
  }
}
