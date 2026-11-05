import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 对照纯图标、前置图标和后置图标按钮。
class Example5 extends StatelessWidget {
  const Example5({super.key});

  @override
  Widget build(BuildContext context) {
    final icons = <(ElThemeType?, IconData, String)>[
      (null, Icons.home, '首页'),
      (.primary, Icons.edit, '编辑'),
      (.success, Icons.share, '分享'),
      (.info, Icons.search, '搜索'),
      (.warning, Icons.lock_open, '解锁'),
      (.error, Icons.delete, '删除'),
    ];
    final variants = <(ElButtonVariant, ElStyle?)>[
      (.solid, null),
      (.outline, null),
      (.outline, ElStyle(backgroundColor: Colors.transparent)),
      (.text, null),
    ];

    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 8,
      children: [
        for (final (variant, style) in variants)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: .center,
            children: [
              for (final (type, icon, label) in icons)
                ElButton(
                  type: type,
                  variant: variant,
                  style: style,
                  semanticLabel: label,
                  onPressed: () {},
                  child: icon,
                ),
              ElView(
                style: ElStyle(vars: {ElTokens.$primary: Colors.teal}),
                child: ElButton(
                  type: .primary,
                  variant: variant,
                  style: style,
                  icon: Icons.search,
                  onPressed: () {},
                  child: 'Search',
                ),
              ),
              ElView(
                style: ElStyle(vars: {ElTokens.$primary: Colors.purple}),
                child: ElButton(
                  type: .primary,
                  variant: variant,
                  style: style,
                  onPressed: () {},
                  child: Row(
                    mainAxisSize: .min,
                    spacing: 6,
                    children: [
                      ElView(child: '上传'),
                      ElIcon(Icons.upload),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
