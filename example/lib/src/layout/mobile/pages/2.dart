import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

import '../../../pages/components/start/shadow/index.dart';

class ComponentPage extends StatelessWidget {
  const ComponentPage({super.key});

  static final List<(String, List<(String, String, Widget?)>)> _groups = [
    ('开始使用', [('quick-start', '快速开始', null), ('theme-design', '主题设计', null), ('shadow-design', '阴影设计', ShadowPage())]),
    (
      '基础组件',
      [
        ('button', 'Button 按钮', null),
        ('button-group', 'ButtonGroup 按钮组', null),
        ('icon', 'Icon 图标', null),
        ('text', 'Text 文本', null),
        ('tag', 'Tag 标签', null),
      ],
    ),
    (
      '表单组件',
      [
        ('input', 'Input 输入框', null),
        ('input-number', 'InputNumber 数字输入框', null),
        ('input-otp', 'InputOtp 验证码输入', null),
        ('input-tag', 'InputTag 标签输入', null),
        ('autocomplete', 'Autocomplete 自动补全', null),
        ('mention', 'Mention 提及', null),
        ('select', 'Select 选择器', null),
        ('switch', 'Switch 开关', null),
        ('radio', 'Radio 单选框', null),
        ('checkbox', 'Checkbox 多选框', null),
        ('segmented', 'Segmented 分段选择', null),
        ('slider', 'Slider 滑块', null),
        ('calendar', 'Calendar 日历', null),
        ('form', 'Form 表单', null),
      ],
    ),
    (
      '布局与容器',
      [
        ('card', 'Card 卡片', null),
        ('divider', 'Divider 分割线', null),
        ('collapse', 'Collapse 折叠面板', null),
        ('tabs', 'Tabs 标签页', null),
      ],
    ),
    ('列表组件', [('list-tile', 'ListTile 列表行', null), ('list-group', 'ListTileGroup 列表组', null)]),
    (
      '数据展示',
      [
        ('avatar', 'Avatar 头像', null),
        ('badge', 'Badge 徽标', null),
        ('progress', 'Progress 进度', null),
        ('skeleton', 'Skeleton 骨架屏', null),
        ('empty', 'Empty 空态', null),
        ('steps', 'Steps 步骤条', null),
      ],
    ),
    ('反馈组件', [('alert', 'Alert 提示', null), ('loading', 'LoadingIndicator 加载指示', null)]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('组件')),
      body: ElScrollView(
        key: PageStorageKey('component-catalog'),
        padding: .fromLTRB(16, 8, 16, 24),
        children: [
          Column(
            spacing: 16,
            children: [
              for (final (title, items) in _groups)
                ElListGroup(
                  title: title,
                  children: [
                    for (final (id, label, page) in items)
                      ElListTile(
                        key: ValueKey('component-$id'),
                        title: label,
                        onTap: () {
                          if (page != null) {
                            Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => page));
                          }
                        },
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
