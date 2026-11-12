import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../state/index.dart';
import '../../../widgets/icons/settings_icons.dart';
import '../../components/basic/button/index.dart';
import '../view/index.dart';
import '../view_base/index.dart';

/// 移动应用「我的 → 组件示例」进入的演示列表。
class DemoListPage extends StatelessWidget {
  const DemoListPage({super.key});

  ElListTile _tile(BuildContext context, ElSettingIcons icon, [Widget? page]) => ElListTile(
    title: icon.label,
    onTap: () {
      if (page != null) {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => page));
      }
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('首页'),
        actions: [
          ObsBuilder(
            builder: (context) {
              return Switch(
                value: GlobalState.showPerformanceOverlay.value,
                onChanged: (v) => GlobalState.showPerformanceOverlay.value = v,
              );
            },
          ),
        ],
      ),
      body: ElScrollView(
        children: [
          Padding(
            padding: .all(16),
            child: Column(
              spacing: 16,
              children: [
                ElListGroup(
                  children: [
                    _tile(context, .airplane, ElViewPage()),
                    _tile(context, .bluetooth, ViewBasePage()),
                    _tile(context, .mobile),
                    _tile(context, .connect),
                    _tile(context, .user, ButtonPage()),
                  ],
                ),
                ElListGroup(
                  children: [
                    _tile(context, .personalize),
                    _tile(context, .display),
                    _tile(context, .sound),
                    _tile(context, .notifications),
                  ],
                ),
                ElListGroup(children: [_tile(context, .password), _tile(context, .privacy), _tile(context, .location)]),
                ElListGroup(
                  children: [
                    _tile(context, .apps),
                    _tile(context, .battery),
                    _tile(context, .accessibility),
                    _tile(context, .cloud),
                  ],
                ),
                ElListGroup(
                  children: [
                    _tile(context, .system),
                    _tile(context, .about),
                    _tile(context, .account),
                    _tile(context, .help),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
