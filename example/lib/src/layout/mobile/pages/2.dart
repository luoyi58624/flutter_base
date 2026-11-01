// ignore_for_file: file_names

import 'package:flutter/widgets.dart';
import 'package:flutter_base/mobile.dart';

/// 移动端第二页，按类型展示组件目录。
class ElComponentCatalogPage extends StatelessWidget {
  /// 创建组件目录。
  const ElComponentCatalogPage({super.key});

  static final _groups = [
    (
      '基础组件',
      [
        ('button', 'Button 按钮'),
        ('button-group', 'ButtonGroup 按钮组'),
        ('icon', 'Icon 图标'),
        ('text', 'Text 文本'),
        ('tag', 'Tag 标签'),
      ],
    ),
    (
      '表单组件',
      [
        ('input', 'Input 输入框'),
        ('input-number', 'InputNumber 数字输入框'),
        ('input-otp', 'InputOtp 验证码输入'),
        ('input-tag', 'InputTag 标签输入'),
        ('autocomplete', 'Autocomplete 自动补全'),
        ('mention', 'Mention 提及'),
        ('select', 'Select 选择器'),
        ('switch', 'Switch 开关'),
        ('radio', 'Radio 单选框'),
        ('checkbox', 'Checkbox 多选框'),
        ('segmented', 'Segmented 分段选择'),
        ('slider', 'Slider 滑块'),
        ('calendar', 'Calendar 日历'),
        ('form', 'Form 表单'),
      ],
    ),
    ('布局与容器', [('card', 'Card 卡片'), ('divider', 'Divider 分割线'), ('collapse', 'Collapse 折叠面板'), ('tabs', 'Tabs 标签页')]),
    ('列表组件', [('list-tile', 'ListTile 列表行'), ('list-group', 'ListTileGroup 列表组')]),
    (
      '数据展示',
      [
        ('avatar', 'Avatar 头像'),
        ('badge', 'Badge 徽标'),
        ('progress', 'Progress 进度'),
        ('skeleton', 'Skeleton 骨架屏'),
        ('empty', 'Empty 空态'),
        ('steps', 'Steps 步骤条'),
      ],
    ),
    ('反馈组件', [('alert', 'Alert 提示'), ('loading', 'LoadingIndicator 加载指示')]),
  ];

  @override
  Widget build(BuildContext context) => ElScrollView(
    key: PageStorageKey('component-catalog'),
    padding: .fromLTRB(16, 8, 16, 24),
    children: [
      Column(
        spacing: 16,
        children: [
          for (final (title, items) in _groups)
            ElListTileGroup(
              title: title,
              children: [
                for (final (id, label) in items)
                  ElListTile(key: ValueKey('component-$id'), title: label, trailing: null),
              ],
            ),
        ],
      ),
    ],
  );
}
