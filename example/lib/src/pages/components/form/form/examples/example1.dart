import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// prop 从表单 Map 读写字段，点击校验显示必填错误。
class Example1 extends HookWidget {
  /// 创建字段绑定与校验示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final data = useState<Map<String, dynamic>>({'name': ''});
    final result = useState('尚未校验');
    return ElForm(
      modelValue: data,
      labelPosition: .top,
      rules: {
        'name': [ElRequiredFormRule(message: '请输入姓名')],
      },
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: .stretch,
          mainAxisSize: .min,
          spacing: 12,
          children: [
            ElFormItem(
              prop: 'name',
              label: '姓名',
              child: ElInput(placeholder: '请输入姓名'),
            ),
            Wrap(
              spacing: 8,
              children: [
                ElButton(onPressed: () => result.value = ElForm.of(context).validate() ? '校验通过' : '校验失败', child: '校验'),
                ElButton(
                  onPressed: () {
                    ElForm.of(context).reset();
                    result.value = '已重置';
                  },
                  child: '重置',
                ),
              ],
            ),
            Text(result.value),
            Text('表单：${data.value}'),
          ],
        ),
      ),
    );
  }
}
