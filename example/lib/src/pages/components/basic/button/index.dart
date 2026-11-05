import 'package:flutter/widgets.dart';

import '../../doc_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';
import 'examples/example3.dart';
import 'examples/example4.dart';
import 'examples/example5.dart';
import 'examples/example6.dart';
import 'examples/example7.dart';
import 'examples/example8.dart';
import 'examples/example9.dart';
import 'examples/example10.dart';

/// 桌面与移动目录共用的 Button 文档页。
class ButtonPage extends StatelessWidget {
  /// 创建 Button 文档页。
  const ButtonPage({super.key});

  static const _examples = 'lib/src/pages/components/basic/button/examples';

  @override
  Widget build(BuildContext context) {
    return ComponentDocPage(
      title: 'Button 按钮',
      description: '常用的操作按钮，支持实心、描边、文字、链接与图标等外观。',
      sections: [
        ComponentDocSection(
          title: '基础使用',
          description: '每行对照同一组主题色，依次展示实心、浅底描边、透明描边、文字和带底色的文字按钮。',
          example: Example1(),
          source: '$_examples/example1.dart',
        ),
        ComponentDocSection(
          title: '自定义颜色',
          description: '在按钮外层用 ElView 覆写主色 token，组件按外观使用这个颜色。',
          example: Example2(),
          source: '$_examples/example2.dart',
        ),
        ComponentDocSection(
          title: '禁用按钮',
          description: '拨动开关，比较不同外观的可用和禁用状态。',
          example: Example3(),
          source: '$_examples/example3.dart',
        ),
        ComponentDocSection(
          title: '链接按钮',
          description: '用 variant: .link 展示链接外观，两行分别是可用和禁用状态。',
          example: Example4(),
          source: '$_examples/example4.dart',
        ),
        ComponentDocSection(
          title: '图标按钮',
          description: '纯图标按钮提供辅助名称。文字按钮可以用 icon 放置前置图标，也可以自行排列文字和后置图标。',
          example: Example5(),
          source: '$_examples/example5.dart',
        ),
        ComponentDocSection(
          title: '圆形图标按钮',
          description: '给方形图标按钮设置足够大的圆角，即可得到圆形外观。',
          example: Example6(),
          source: '$_examples/example6.dart',
        ),
        ComponentDocSection(
          title: '加载状态',
          description: '各按钮点击后独立加载两秒，期间阻止重复激活。',
          example: Example7(),
          source: '$_examples/example7.dart',
        ),
        ComponentDocSection(
          title: '块级按钮',
          description: '将 ElStyle.width 设为 100% 即可撑满可用宽度。',
          example: Example8(),
          source: '$_examples/example8.dart',
        ),
        ComponentDocSection(
          title: 'Toggle 切换',
          description: '六个切换按钮共用一个布尔模型，点击任意一个都能看到它们同步变化。',
          example: Example9(),
          source: '$_examples/example9.dart',
        ),
        ComponentDocSection(
          title: 'Toggle 切换',
          description: '六个切换按钮共用一个布尔模型，点击任意一个都能看到它们同步变化。',
          example: Example9(),
          source: '$_examples/example9.dart',
        ),
        ComponentDocSection(
          title: '通用点击',
          description: 'ScaleTap、FadeTap 通用交互样式',
          example: Example10(),
          source: '$_examples/example10.dart',
        ),
      ],
    );
  }
}
