import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// InputTag 标签输入的交互文档。
class InputTagPage extends StatelessWidget {
  /// 创建InputTag 标签输入文档页。
  InputTagPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).inputTag == null) return ExamplePage(title: 'InputTag 标签输入');
    return ComponentDocPage(
      title: 'InputTag 标签输入',
      description: '通过已有标签输入接口维护字符串列表。',
      sections: [
        ComponentDocSection(
          title: '新增与移除',
          description: '输入内容后按 Enter 或逗号提交，通过关闭按钮删除条目。',
          example: Example1(),
          source: 'lib/src/pages/components/form/input_tag/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '折叠与数量限制',
          description: '设置标签上限并折叠较多条目，开关控制禁用。',
          example: Example2(),
          source: 'lib/src/pages/components/form/input_tag/examples/example2.dart',
        ),
      ],
    );
  }
}
