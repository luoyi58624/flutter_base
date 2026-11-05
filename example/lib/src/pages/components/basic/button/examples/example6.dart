import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 在不同外观下把方形图标按钮设为圆形。
class Example6 extends StatelessWidget {
  const Example6({super.key});

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
    final circle = ElStyle(borderRadius: .circular(999));
    final variants = <(ElButtonVariant, ElStyle)>[
      (.solid, circle),
      (.outline, circle),
      (.outline, circle.merge(ElStyle(backgroundColor: Colors.transparent))),
      (.text, circle),
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
            ],
          ),
      ],
    );
  }
}
