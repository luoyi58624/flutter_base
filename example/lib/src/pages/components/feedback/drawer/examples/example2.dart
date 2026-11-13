import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// size 设置抽屉宽度或高度，footer 放置操作；内容里用 Navigator.pop(context, value) 返回结果。
class Example2 extends HookWidget {
  /// 创建尺寸、页脚与返回值示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final status = useState('全部');
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: .center,
      children: [
        ElButton(
          onPressed: () async {
            final value = await el.drawer.show<String>(
              context,
              title: '筛选状态',
              size: 360,
              child: Builder(
                builder: (context) => Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    for (final item in ['全部', '进行中', '已完成', '已归档'])
                      ElListTile(
                        title: item,
                        trailingText: item == status.value ? '当前' : null,
                        onTap: () => Navigator.pop(context, item),
                      ),
                  ],
                ),
              ),
              footer: Builder(
                builder: (context) => ElButton(onPressed: () => Navigator.pop(context, '全部'), child: '重置筛选'),
              ),
            );
            if (value != null) status.value = value;
          },
          child: '打开筛选',
        ),
        ElView(child: '当前筛选：${status.value}'),
      ],
    );
  }
}
