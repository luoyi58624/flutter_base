import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Switch 开关的交互文档。
class SwitchPage extends StatelessWidget {
  /// 创建Switch 开关文档页。
  SwitchPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).switcher == null) return ExamplePage(title: 'Switch 开关');
    return ComponentDocPage(
      title: 'Switch 开关',
      description: '布尔开关支持双向绑定、禁用和加载状态。',
      sections: [
        ComponentDocSection(
          title: '布尔值绑定',
          description: '开关状态与外部模型同步。',
          example: Example1(),
          source: 'lib/src/pages/components/form/switch/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '禁用与加载',
          description: '禁用和加载期间不会重复切换。',
          example: Example2(),
          source: 'lib/src/pages/components/form/switch/examples/example2.dart',
        ),
      ],
    );
  }
}
