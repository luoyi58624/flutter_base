import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

/// 用带说明、图标和禁用项的菜单树组织设置选项。
class Example7 extends HookWidget {
  /// 创建多级菜单示例。
  Example7({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = useState('system');
    final labels = {'system': '跟随系统', 'light': '浅色', 'dark': '深色', 'contrast': '高对比度', 'battery': '省电模式'};

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        ElListGroup(
          children: [
            ElListTile<String>.popup(
              title: '显示设置',
              modelValue: appearance,
              popupAnchor: ElOverlayAnchor(placement: .bottomStart, offset: 4),
              options: [
                ElMenuOption(
                  '外观',
                  'appearance',
                  leading: Icons.palette_outlined,
                  description: '选择适合当前环境的显示方式',
                  children: [
                    ElMenuOption('跟随系统', 'system', leading: Icons.brightness_auto_outlined),
                    ElMenuOption('浅色', 'light', leading: Icons.light_mode_outlined),
                    ElMenuOption('深色', 'dark', leading: Icons.dark_mode_outlined, description: '适合弱光环境'),
                    ElMenuOption('高对比度', 'contrast', disabled: true, description: '暂不可用'),
                  ],
                ),
                ElMenuOption('省电模式', 'battery', leading: Icons.battery_saver_outlined),
              ],
            ),
          ],
        ),
        Text('当前显示：${labels[appearance.value]}'),
      ],
    );
  }
}
