import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileIcons;

/// 枚举两端全部图标，首次显示时按当前布局初始化图标库。
class Example3 extends HookWidget {
  /// 创建完整图标库示例。
  // ignore: prefer_const_constructors_in_immutables
  Example3({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = useState(MediaQuery.sizeOf(context).width <= ElBreakpoint.defaultSm);
    final Map<String, Widget> icons = mobile.value
        ? ElMobileIcons.values
        : {for (final entry in ElDesktopIcons.values.entries) entry.key: ElIcon(entry.value)};
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 20,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: .center,
          children: [
            ElButtonGroup<bool>.single(
              modelValue: mobile,
              mandatory: true,
              type: .primary,
              semanticLabel: '图标库',
              children: [
                ElButtonGroupItem(value: false, child: '桌面端'),
                ElButtonGroupItem(value: true, child: '移动端'),
              ],
            ),
            Text('共 ${icons.length} 个图标'),
          ],
        ),
        ElView(
          style: ElStyle(iconSize: 32, iconColor: context.elTheme.textColor),
          child: Wrap(
            key: ValueKey('icon-catalog-grid'),
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final entry in icons.entries)
                Tooltip(
                  message: entry.key,
                  child: SizedBox(
                    width: 100,
                    height: 88,
                    child: Column(
                      mainAxisAlignment: .center,
                      spacing: 10,
                      children: [
                        entry.value,
                        Text(
                          entry.key,
                          textAlign: .center,
                          maxLines: 2,
                          overflow: .ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
