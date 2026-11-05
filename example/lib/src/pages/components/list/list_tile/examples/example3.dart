import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

/// 对照默认箭头、右侧文字和自定义后缀。
class Example3 extends StatelessWidget {
  /// 创建右侧内容与后缀示例。
  Example3({super.key});

  @override
  Widget build(BuildContext context) {
    return ElListGroup(
      children: [
        ElListTile(title: '默认后缀', trailingText: '查看'),
        ElListTile(title: '当前版本', trailingText: '1.0.0', trailing: null),
        ElListTile(title: '已验证', trailing: Icons.verified_outlined),
        ElListTile(
          title: '账户状态',
          trailing: ElView(
            style: ElStyle(
              padding: .symmetric(horizontal: 8, vertical: 3),
              borderRadius: .circular(6),
              backgroundColor: context.elTheme.selectedBackground,
              color: context.elTheme.primary,
              fontSize: 12,
            ),
            child: '正常',
          ),
        ),
      ],
    );
  }
}
