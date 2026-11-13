import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// confirm 得到 true 或 false，危险操作把 type 设为 error；alert 只有确认按钮；dismissible 为假时只能通过按钮关闭。
class Example2 extends StatelessWidget {
  /// 创建确认框与提示框示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    void report(bool accepted, String action) {
      if (context.mounted)
        el.message.show(accepted ? '已$action' : '已取消', context: context, type: accepted ? .success : .info);
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElButton(
          onPressed: () async => report(await el.dialog.confirm(context, title: '退出登录', content: '退出后需要重新验证身份。'), '退出'),
          child: '确认框',
        ),
        ElButton(
          type: .error,
          onPressed: () async => report(
            await el.dialog.confirm(context, title: '删除项目', content: '删除后项目中的文件无法恢复。', confirmText: '删除', type: .error),
            '删除',
          ),
          child: '危险操作',
        ),
        ElButton(
          onPressed: () => el.dialog.alert(context, title: '同步完成', content: '共同步 12 个文件。', confirmText: '知道了'),
          child: '提示框',
        ),
        ElButton(
          onPressed: () async => report(
            await el.dialog.confirm(
              context,
              title: '服务协议已更新',
              content: '请阅读后选择是否同意，遮罩和返回键不会关闭这个对话框。',
              confirmText: '同意',
              cancelText: '不同意',
              dismissible: false,
            ),
            '同意',
          ),
          child: '必须选择',
        ),
      ],
    );
  }
}
