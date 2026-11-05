import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// InputNumber 数字输入框的交互文档。
class InputNumberPage extends StatelessWidget {
  /// 创建InputNumber 数字输入框文档页。
  InputNumberPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).inputNumber == null) return ExamplePage(title: 'InputNumber 数字输入框');
    return ComponentDocPage(
      title: 'InputNumber 数字输入框',
      description: '通过现有数字接口演示范围、步长、精度及控制按钮。',
      sections: [
        ComponentDocSection(
          title: '步长与范围',
          description: '用可空数值模型绑定数字，并限制最小值和最大值。',
          example: Example1(),
          source: 'lib/src/pages/components/form/input_number/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '精度与控制按钮',
          description: '对照小数精度、右侧按钮、无按钮和禁用状态。',
          example: Example2(),
          source: 'lib/src/pages/components/form/input_number/examples/example2.dart',
        ),
      ],
    );
  }
}
