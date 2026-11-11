import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// Calendar 日历的交互文档。
class CalendarPage extends StatelessWidget {
  /// 创建Calendar 日历文档页。
  CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).calendar == null) return ExamplePage(title: 'Calendar 日历');
    return ComponentDocPage(
      title: 'Calendar 日历',
      description: '选择单日或日期范围，绑定值保持现有 DateTime 接口。',
      sections: [
        ComponentDocSection(
          title: '单日选择',
          description: '限制可选日期区间，选择后显示日期。',
          example: Example1(),
          source: 'lib/src/pages/components/form/calendar/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '日期范围',
          description: '范围模型使用 List<DateTime>；Material 替代通过官方范围对话框选择。',
          example: Example2(),
          source: 'lib/src/pages/components/form/calendar/examples/example2.dart',
        ),
      ],
    );
  }
}
