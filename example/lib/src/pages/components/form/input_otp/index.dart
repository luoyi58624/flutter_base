import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import '../../../../layout/example_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';

/// InputOtp 验证码输入的交互文档。
class InputOtpPage extends StatelessWidget {
  /// 创建InputOtp 验证码输入文档页。
  InputOtpPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ElComponentProvider.of(context).inputOtp == null) return ExamplePage(title: 'InputOtp 验证码输入');
    return ComponentDocPage(
      title: 'InputOtp 验证码输入',
      description: '定长验证码输入支持完成通知、掩码和多种单元格外观。',
      sections: [
        ComponentDocSection(
          title: '输入与完成通知',
          description: '输入四位验证码，完成后显示回调收到的值。',
          example: Example1(),
          source: 'lib/src/pages/components/form/input_otp/examples/example1.dart',
        ),
        ComponentDocSection(
          title: '外观与掩码',
          description: '对照三种已定义的外观，以及禁用的掩码输入。',
          example: Example2(),
          source: 'lib/src/pages/components/form/input_otp/examples/example2.dart',
        ),
      ],
    );
  }
}
