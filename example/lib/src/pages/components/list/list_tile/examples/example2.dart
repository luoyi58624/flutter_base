import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

/// 用图标、副标题和自定义内容补充列表信息。
class Example2 extends StatelessWidget {
  /// 创建图标与副标题示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return ElListGroup(
      children: [
        ElListTile(title: '个人资料', subtitle: '头像、昵称与联系方式', leading: Icons.person_outline),
        ElListTile(title: '隐私保护', subtitle: '管理个人信息的使用范围，也可以随时调整各项权限。较长的说明会随可用宽度自动换行。', leading: Icons.shield_outlined),
        ElListTile(
          title: Text('我的账户'),
          subtitle: Text('已完成身份验证'),
          leading: CircleAvatar(radius: 16, child: Text('鱼')),
          trailing: null,
        ),
      ],
    );
  }
}
