import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../widgets/docs_page/index.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Slider 滑块的交互文档。
class SliderPage extends StatelessWidget {
  /// 创建Slider 滑块文档页。
  SliderPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).slider == null) return ExamplePage(title: 'Slider 滑块');
    return DocsPage(
      title: 'Slider 滑块',
      description: '通过现有单值和范围构造演示数值调整。',
      sections: [
        DocsSection(
          title: '单值与步长',
          description: '使用 double 模型，步长限制可选刻度。',
          source: 'lib/src/pages/components/form/slider/examples/example1.dart',
          child: Example1(),
        ),
        DocsSection(
          title: '范围与禁用',
          description: '范围模型为 List<double>，禁用后保留原值。',
          source: 'lib/src/pages/components/form/slider/examples/example2.dart',
          child: Example2(),
        ),
      ],
    );
  }
}
