import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../example_page.dart';
import 'basic/button/index.dart';
import 'basic/button_group/index.dart';
import 'list/list_tile/index.dart';
import 'start/shadow/index.dart';

/// 两端共用的组件目录，每个叶子都提供实际演示或空白示例页。
final componentCatalog = <ElMenuModel<WidgetBuilder>>[
  ElMenuModel(
    group: true,
    title: '开始使用',
    children: [
      _page('quick-start', '快速开始'),
      _page('theme-design', '主题设计'),
      _page('shadow-design', '阴影设计', builder: (_) => ShadowPage()),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '基础组件',
    children: [
      _page('button', 'Button 按钮', builder: (_) => ButtonPage()),
      _page('button-group', 'ButtonGroup 按钮组', builder: (_) => ButtonGroupPage()),
      _page('icon', 'Icon 图标'),
      _page('text', 'Text 文本'),
      _page('tag', 'Tag 标签'),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '表单组件',
    children: [
      _page('input', 'Input 输入框'),
      _page('input-number', 'InputNumber 数字输入框'),
      _page('input-otp', 'InputOtp 验证码输入'),
      _page('input-tag', 'InputTag 标签输入'),
      _page('autocomplete', 'Autocomplete 自动补全'),
      _page('mention', 'Mention 提及'),
      _page('select', 'Select 选择器'),
      _page('switch', 'Switch 开关'),
      _page('radio', 'Radio 单选框'),
      _page('checkbox', 'Checkbox 多选框'),
      _page('segmented', 'Segmented 分段选择'),
      _page('slider', 'Slider 滑块'),
      _page('calendar', 'Calendar 日历'),
      _page('form', 'Form 表单'),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '布局与容器',
    children: [
      _page('card', 'Card 卡片'),
      _page('divider', 'Divider 分割线'),
      _page('collapse', 'Collapse 折叠面板'),
      _page('tabs', 'Tabs 标签页'),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '列表组件',
    children: [
      _page('list-tile', 'ListTile 列表行', builder: (_) => ListTilePage()),
      _page('list-group', 'ListTileGroup 列表组'),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '数据展示',
    children: [
      _page('avatar', 'Avatar 头像'),
      _page('badge', 'Badge 徽标'),
      _page('progress', 'Progress 进度'),
      _page('skeleton', 'Skeleton 骨架屏'),
      _page('empty', 'Empty 空态'),
      _page('steps', 'Steps 步骤条'),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '反馈组件',
    children: [_page('alert', 'Alert 提示'), _page('loading', 'LoadingIndicator 加载指示')],
  ),
];

ElMenuModel<WidgetBuilder> _page(String key, String title, {WidgetBuilder? builder}) => ElMenuModel(
  key: key,
  title: title,
  data: builder ?? (_) => ExamplePage(title: title),
);
