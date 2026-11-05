import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../doc_page.dart';
import 'examples/example1.dart';
import 'examples/example2.dart';
import 'examples/example3.dart';
import 'examples/example4.dart';
import 'examples/example5.dart';
import 'examples/example6.dart';
import 'examples/example7.dart';
import 'examples/example8.dart';

/// 桌面与移动目录共用的 ButtonGroup 文档页。
class ButtonGroupPage extends StatelessWidget {
  /// 创建 ButtonGroup 文档页。
  ButtonGroupPage({super.key});

  static final _examples = 'lib/src/pages/components/basic/button_group/examples';

  @override
  Widget build(BuildContext context) {
    final supported = ElComponentProvider.of(context).buttonGroup != null;

    // 按实际注入的能力显示演示，避免缺少品牌实现时整页构建失败。
    Widget preview(Widget example) => supported ? example : Text('当前品牌暂未支持按钮组，可展开源码查看用法。');

    return ComponentDocPage(
      title: 'ButtonGroup 按钮组',
      description: '将相关操作组合展示，支持普通操作、单选和多选。当前默认预设提供桌面端实现。',
      sections: [
        ComponentDocSection(
          title: '基础使用',
          description: '普通按钮组不绑定选中值，每个条目通过 onPressed 响应操作。',
          example: preview(Example1()),
          source: '$_examples/example1.dart',
        ),
        ComponentDocSection(
          title: '主题配色',
          description: '通过 type 设置整组语义色，或通过 bgColor 使用自定义颜色。',
          example: preview(Example2()),
          source: '$_examples/example2.dart',
        ),
        ComponentDocSection(
          title: '单选按钮组',
          description: '使用 .single 绑定单值模型；模型可空时，再次点击选中项可取消选择。',
          example: preview(Example3()),
          source: '$_examples/example3.dart',
        ),
        ComponentDocSection(
          title: '多选按钮组',
          description: '使用 .multi 绑定 List 或 Set。泛型表示完整集合类型，条目 value 对应集合中的元素。',
          example: preview(Example4()),
          source: '$_examples/example4.dart',
        ),
        ComponentDocSection(
          title: '保留选中项',
          description: '设置 mandatory: true 阻止清空最后一个选中项，初始选择由调用方提供。',
          example: preview(Example5()),
          source: '$_examples/example5.dart',
        ),
        ComponentDocSection(
          title: '禁用状态',
          description: '拨动开关切换整组禁用；删除条目始终单独禁用，禁用不会清除已有选择。',
          example: preview(Example6()),
          source: '$_examples/example6.dart',
        ),
        ComponentDocSection(
          title: '图标按钮组',
          description: 'child 可直接传入图标，纯图标条目通过 semanticLabel 提供辅助名称，value 也可使用枚举。',
          example: preview(Example7()),
          source: '$_examples/example7.dart',
        ),
        ComponentDocSection(
          title: '方向与通栏布局',
          description: 'block 沿排列方向撑满，条目 flex 控制空间份额。纵向通栏需要外层提供有界高度；条目省略 value 时使用下标。',
          example: preview(Example8()),
          source: '$_examples/example8.dart',
        ),
      ],
    );
  }
}
