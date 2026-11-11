import 'package:flutter/widgets.dart';
import 'package:flutter_base/mobile.dart';

import '../../../../widgets/docs_page/index.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';
import 'examples/example3.dart';
import 'examples/example4.dart';
import 'examples/example5.dart';
import 'examples/example6.dart';
import 'examples/example7.dart';
import 'examples/example8.dart';

/// 桌面与移动目录共用的 ListTile 文档页。
class ListTilePage extends StatelessWidget {
  /// 创建 ListTile 文档页。
  ListTilePage({super.key});

  static final _examples = 'lib/src/pages/components/list/list_tile/examples';

  @override
  Widget build(BuildContext context) => DocsPage(
    title: 'ListTile 列表行',
    description: '用于设置入口、信息展示、开关与菜单选择，以下示例展示移动端外观。',
    sections: [
      DocsSection(
        title: '基础使用',
        description: '通过 title 和 trailingText 展示标题与当前值，onTap 处理点击动作；放入 ElListGroup 后自动添加分隔线。',
        source: '$_examples/example1.dart',
        child: _preview(Example1()),
      ),
      DocsSection(
        title: '图标与副标题',
        description: 'leading 放置前侧图标，subtitle 补充说明；内容也可以传入 Widget，长文本按可用宽度换行。',
        source: '$_examples/example2.dart',
        child: _preview(Example2()),
      ),
      DocsSection(
        title: '右侧内容与后缀',
        description: 'trailingText 显示右侧文字，trailing 替换默认箭头；显式传入 null 可移除后缀及其间距。',
        source: '$_examples/example3.dart',
        child: _preview(Example3()),
      ),
      DocsSection(
        title: '禁用状态',
        description: '拨动开关，对照普通行、开关行和菜单行的禁用状态；禁用时不会执行点击、切换或展开菜单。',
        source: '$_examples/example4.dart',
        child: _preview(Example4()),
      ),
      DocsSection(
        title: '开关列表行',
        description: '使用 ElListTile<bool>.switcher 绑定布尔模型，整行点击即可切换；loading 显示加载状态并暂时阻止切换。',
        source: '$_examples/example5.dart',
        child: _preview(Example5()),
      ),
      DocsSection(
        title: '弹出单选菜单',
        description: '使用 popup 和 ElLabelModel 声明单选菜单，选中后自动显示对应文案；可空模型表示尚未选择。',
        source: '$_examples/example6.dart',
        child: _preview(Example6()),
      ),
      DocsSection(
        title: '多级菜单',
        description: '用 ElMenuOption 声明子菜单、图标、说明和禁用项；分支只展开子菜单，选择叶子后才更新绑定值。',
        source: '$_examples/example7.dart',
        child: _preview(Example7()),
      ),
      DocsSection(
        title: '自定义样式',
        description: '通过 style 合并行的颜色、背景、内边距和圆角，保留列表行的布局与交互。',
        source: '$_examples/example8.dart',
        child: _preview(Example8()),
      ),
    ],
  );

  // 列表行目前仅有移动端实现，局部安装预设让两端文档都能预览，并保留外层文档主题。
  Widget _preview(Widget child) => ElComponentProvider(components: el.mobileComponents, child: child);
}
