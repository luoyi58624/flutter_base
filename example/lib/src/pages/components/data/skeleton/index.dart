import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Skeleton 骨架屏的交互文档。
class SkeletonPage extends StatelessWidget {
  /// 创建Skeleton 骨架屏文档页。
  SkeletonPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).skeleton == null) return ExamplePage(title: 'Skeleton 骨架屏');
    return ComponentDocPage(
      title: 'Skeleton 骨架屏',
      description: '切换加载状态，保留内容组件的实例与状态。',
      sections: [
        ComponentDocSection(
          title: '加载与正文',
          description: '开关控制 loading，标题和正文行使用现有骨架实现。',
          example: Example1(),
          source: 'lib/src/pages/components/data/skeleton/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '头像与行数',
          description: '可选择头像占位并调整正文行数。',
          example: Example2(),
          source: 'lib/src/pages/components/data/skeleton/examples/example2.dart',
        ),
      ],
    );
  }
}
