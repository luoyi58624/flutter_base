import 'package:flutter/widgets.dart';

import '../../doc_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';
import 'examples/example3.dart';

/// Icon 图标的交互文档。
class IconPage extends StatelessWidget {
  /// 创建Icon 图标文档页。
  IconPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ComponentDocPage(
      title: 'Icon 图标',
      description: '展示桌面字体图标和移动 SVG 图标，支持尺寸、颜色与样式继承。',
      sections: [
        ComponentDocSection(
          title: '尺寸与颜色',
          description: 'size 和 color 可直接指定图标外观。',
          example: Example1(),
          source: 'lib/src/pages/components/basic/icon/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '样式继承',
          description: '父级样式统一设置图标通道，局部图标可单独覆写。',
          example: Example2(),
          source: 'lib/src/pages/components/basic/icon/examples/example2.dart',
        ),
        ComponentDocSection(
          title: '全部图标',
          description: '按钮组切换两端完整图标库，首次显示按当前布局初始化；移动 SVG 继承祖先字重。',
          example: Example3(),
          source: 'lib/src/pages/components/basic/icon/examples/example3.dart',
        ),
      ],
    );
  }
}
