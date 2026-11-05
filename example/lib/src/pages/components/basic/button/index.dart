import 'package:flutter/widgets.dart';

import '../../doc_page.dart';
import 'examples/appearance.dart';
import 'examples/events.dart';
import 'examples/icons.dart';
import 'examples/sizing.dart';
import 'examples/states.dart';
import 'examples/toggle.dart';

/// 桌面与移动目录共用的 Button 文档页。
class ButtonPage extends StatelessWidget {
  /// 创建 Button 文档页。
  const ButtonPage({super.key});

  static const _examples = 'lib/src/pages/components/basic/button/examples';

  @override
  Widget build(BuildContext context) => ComponentDocPage(
    title: 'Button 按钮',
    description: '按钮用于触发操作，也可以表示收藏等布尔状态。',
    sections: [
      ComponentDocSection(
        title: '基础用法',
        description: '用 type 表达操作的语义，用 variant 区分视觉层级。',
        example: ButtonAppearanceExample(),
        source: '$_examples/appearance.dart',
      ),
      ComponentDocSection(
        title: '图标按钮',
        description: '只显示图标时，用 semanticLabel 提供辅助名称。',
        example: ButtonIconsExample(),
        source: '$_examples/icons.dart',
      ),
      ComponentDocSection(
        title: '尺寸与通栏',
        description: '用 ElStyle 调整尺寸，设置 width 为 100% 可占满可用宽度。',
        example: ButtonSizingExample(),
        source: '$_examples/sizing.dart',
      ),
      ComponentDocSection(
        title: '禁用与加载',
        description: '禁用和加载都会阻止激活，加载时会保留焦点。',
        example: ButtonStatesExample(),
        source: '$_examples/states.dart',
      ),
      ComponentDocSection(
        title: '切换状态',
        description: 'ElButton.toggle 可以绑定一个布尔模型，点击后更新选中状态。',
        example: ButtonToggleExample(),
        source: '$_examples/toggle.dart',
      ),
      ComponentDocSection(
        title: '点击事件',
        description: '通过 onPressed 执行操作，event 可在默认动作前拦截点击。',
        example: ButtonEventsExample(),
        source: '$_examples/events.dart',
      ),
    ],
  );
}
