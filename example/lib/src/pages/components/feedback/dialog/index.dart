import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../widgets/docs_page/index.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';
import 'examples/example3.dart';
import 'examples/example4.dart';

/// Dialog 对话框的交互文档。
class DialogPage extends StatelessWidget {
  /// 创建 Dialog 对话框文档页。
  DialogPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).dialog == null) return ExamplePage(title: 'Dialog 对话框');
    return DocsPage(
      title: 'Dialog 对话框',
      description: '通过 el.dialog 在根导航器打开模态层：自定义对话框、确认框、提示框、输入框与底部面板共用同一套遮罩、返回键和进退场，关闭时 Future 立即得到结果。',
      sections: [
        DocsSection(
          title: '基础用法',
          description: 'show 打开自定义内容，内容里用 Navigator.pop(context, value) 返回结果；遮罩、Esc 和返回键关闭时得到 null。',
          source: 'lib/src/pages/components/feedback/dialog/examples/example1.dart',
          child: Example1(),
        ),
        DocsSection(
          title: '确认框与提示框',
          description: 'confirm 得到 true 或 false，危险操作把 type 设为 error；alert 只有确认按钮；dismissible 为假时只能通过按钮关闭。',
          source: 'lib/src/pages/components/feedback/dialog/examples/example2.dart',
          child: Example2(),
        ),
        DocsSection(
          title: '输入框',
          description: 'prompt 确认或回车时先经 validator 校验，错误提示留在面板内；确认得到输入值，取消得到 null。',
          source: 'lib/src/pages/components/feedback/dialog/examples/example3.dart',
          child: Example3(),
        ),
        DocsSection(
          title: '弹出位置',
          description: 'placement 为 bottom 时即底部面板，移动端可从面板或遮罩向下拖动关闭；top 停靠顶部。',
          source: 'lib/src/pages/components/feedback/dialog/examples/example4.dart',
          child: Example4(),
        ),
      ],
    );
  }
}
