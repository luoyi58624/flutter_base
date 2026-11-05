import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Form 表单的交互文档。
class FormPage extends StatelessWidget {
  /// 创建Form 表单文档页。
  FormPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).input == null) return ExamplePage(title: 'Form 表单');
    return ComponentDocPage(
      title: 'Form 表单',
      description: '使用已有 ElForm、ElFormItem 和规则对象组织表单与校验。',
      sections: [
        ComponentDocSection(
          title: '字段绑定与校验',
          description: 'prop 从表单 Map 读写字段，点击校验显示必填错误。',
          example: Example1(),
          source: 'lib/src/pages/components/form/form/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '帮助信息与显式错误',
          description: 'ElFormItem 也可单独组合标签、内容和外部错误。',
          example: Example2(),
          source: 'lib/src/pages/components/form/form/examples/example2.dart',
        ),
      ],
    );
  }
}
