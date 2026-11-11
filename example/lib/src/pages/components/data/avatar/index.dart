import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Avatar 头像的交互文档。
class AvatarPage extends StatelessWidget {
  /// 创建Avatar 头像文档页。
  AvatarPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).avatar == null) return ExamplePage(title: 'Avatar 头像');
    return ComponentDocPage(
      title: 'Avatar 头像',
      description: '已有头像接口支持圆形、方形和自定义内容。',
      sections: [
        ComponentDocSection(
          title: '尺寸与形状',
          description: '按 size 和 shape 展示文字头像。',
          example: Example1(),
          source: 'lib/src/pages/components/data/avatar/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '自定义内容',
          description: '内容可为图标或原始 Widget，semanticLabel 提供辅助名称。',
          example: Example2(),
          source: 'lib/src/pages/components/data/avatar/examples/example2.dart',
        ),
      ],
    );
  }
}
