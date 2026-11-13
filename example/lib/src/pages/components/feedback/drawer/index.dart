import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../widgets/docs_page/index.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Drawer 抽屉的交互文档。
class DrawerPage extends StatelessWidget {
  /// 创建 Drawer 抽屉文档页。
  DrawerPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).drawer == null) return ExamplePage(title: 'Drawer 抽屉');
    return DocsPage(
      title: 'Drawer 抽屉',
      description: '通过 el.drawer.show 从屏幕边缘打开抽屉，正文超出时独立滚动；遮罩、Esc、返回键与移动端拖动都可关闭。',
      sections: [
        DocsSection(
          title: '停靠方向',
          description: 'placement 选择从哪条边缘滑入，默认右侧。',
          source: 'lib/src/pages/components/feedback/drawer/examples/example1.dart',
          child: Example1(),
        ),
        DocsSection(
          title: '尺寸、页脚与返回值',
          description: 'size 设置抽屉宽度或高度，footer 放置操作；内容里用 Navigator.pop(context, value) 返回结果。',
          source: 'lib/src/pages/components/feedback/drawer/examples/example2.dart',
          child: Example2(),
        ),
      ],
    );
  }
}
