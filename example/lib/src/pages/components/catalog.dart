import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import 'basic/button/index.dart';
import 'start/shadow/index.dart';

/// 两端共用的组件目录，分组仅供展示，data 只在打开已有示例时构造页面。
final componentCatalog = <ElMenuModel<WidgetBuilder>>[
  ElMenuModel(
    group: true,
    title: '开始使用',
    children: [
      ElMenuModel(key: 'quick-start', title: '快速开始'),
      ElMenuModel(key: 'theme-design', title: '主题设计'),
      ElMenuModel(key: 'shadow-design', title: '阴影设计', data: (_) => ShadowPage()),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '基础组件',
    children: [
      ElMenuModel(key: 'button', title: 'Button 按钮', data: (_) => ButtonPage()),
      ElMenuModel(key: 'button-group', title: 'ButtonGroup 按钮组'),
      ElMenuModel(key: 'icon', title: 'Icon 图标'),
      ElMenuModel(key: 'text', title: 'Text 文本'),
      ElMenuModel(key: 'tag', title: 'Tag 标签'),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '表单组件',
    children: [
      ElMenuModel(key: 'input', title: 'Input 输入框'),
      ElMenuModel(key: 'input-number', title: 'InputNumber 数字输入框'),
      ElMenuModel(key: 'input-otp', title: 'InputOtp 验证码输入'),
      ElMenuModel(key: 'input-tag', title: 'InputTag 标签输入'),
      ElMenuModel(key: 'autocomplete', title: 'Autocomplete 自动补全'),
      ElMenuModel(key: 'mention', title: 'Mention 提及'),
      ElMenuModel(key: 'select', title: 'Select 选择器'),
      ElMenuModel(key: 'switch', title: 'Switch 开关'),
      ElMenuModel(key: 'radio', title: 'Radio 单选框'),
      ElMenuModel(key: 'checkbox', title: 'Checkbox 多选框'),
      ElMenuModel(key: 'segmented', title: 'Segmented 分段选择'),
      ElMenuModel(key: 'slider', title: 'Slider 滑块'),
      ElMenuModel(key: 'calendar', title: 'Calendar 日历'),
      ElMenuModel(key: 'form', title: 'Form 表单'),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '布局与容器',
    children: [
      ElMenuModel(key: 'card', title: 'Card 卡片'),
      ElMenuModel(key: 'divider', title: 'Divider 分割线'),
      ElMenuModel(key: 'collapse', title: 'Collapse 折叠面板'),
      ElMenuModel(key: 'tabs', title: 'Tabs 标签页'),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '列表组件',
    children: [
      ElMenuModel(key: 'list-tile', title: 'ListTile 列表行'),
      ElMenuModel(key: 'list-group', title: 'ListTileGroup 列表组'),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '数据展示',
    children: [
      ElMenuModel(key: 'avatar', title: 'Avatar 头像'),
      ElMenuModel(key: 'badge', title: 'Badge 徽标'),
      ElMenuModel(key: 'progress', title: 'Progress 进度'),
      ElMenuModel(key: 'skeleton', title: 'Skeleton 骨架屏'),
      ElMenuModel(key: 'empty', title: 'Empty 空态'),
      ElMenuModel(key: 'steps', title: 'Steps 步骤条'),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '反馈组件',
    children: [
      ElMenuModel(key: 'alert', title: 'Alert 提示'),
      ElMenuModel(key: 'loading', title: 'LoadingIndicator 加载指示'),
    ],
  ),
];
