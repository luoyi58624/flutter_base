import 'package:example/src/layout/index.dart';
import 'package:example/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

part 'sidebar.dart';

/// 桌面布局，通过侧边菜单切换并保留各示例页面的状态。
class DesktopLayout extends StatefulWidget {
  /// 创建桌面布局。
  const DesktopLayout({super.key});

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  String _selected = 'home';
  final _visited = <String, Widget>{};

  @override
  Widget build(BuildContext context) {
    return ObsBuilder(
      builder: (context) {
        final tabIndex = GlobalState.boottomTabbarIndex.value;
        // 叶子属于当前 tab 时保留选择，外部切换 tab 则使用首个真实叶子。
        final selected = AppLayout.menuTabs[_selected] == tabIndex ? _selected : AppLayout.tabKeyOf(tabIndex);
        final page = AppLayout.pages.firstWhere((page) => page.key == selected);
        // 只挂载访问过的页面，复用原实例保留状态，避免提前运行全部示例。
        _visited.putIfAbsent(
          selected,
          () => Builder(
            key: ValueKey('example-page-$selected'),
            builder: page.data ?? (_) => Scaffold(appBar: AppBar(title: Text(page.title))),
          ),
        );

        return Scaffold(
          body: ElView(
            style: .new(backgroundColor: context.elTheme.bgColor),
            child: Row(
              crossAxisAlignment: .stretch,
              children: [
                _Sidebar(
                  current: selected,
                  onChanged: (key) => setState(() {
                    _selected = key;
                    GlobalState.boottomTabbarIndex.value = AppLayout.menuTabs[key] ?? 0;
                  }),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _visited.keys.toList().indexOf(selected),
                    children: [
                      for (final entry in _visited.entries)
                        TickerMode(enabled: entry.key == selected, child: entry.value),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
