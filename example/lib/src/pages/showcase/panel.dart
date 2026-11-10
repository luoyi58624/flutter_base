import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../widgets/panel.dart';

/// 综合展示中的独立演示卡片，统一标题、说明和内容留白。
class ShowcasePanel extends StatelessWidget {
  /// 创建一个演示区域。
  const ShowcasePanel({super.key, required this.title, required this.description, required this.child});

  /// 卡片标题。
  final String title;

  /// 简短的场景说明。
  final String description;

  /// 演示内容。
  final Widget child;

  @override
  Widget build(BuildContext context) => ExamplePanel(
    style: ElStyle(
      width: '100%',
      minHeight: 272,
      padding: .all(24),
      borderRadius: .circular(20),
      backgroundColor: context.elTheme.cardColor,
      border: .all(borderColor: context.elTheme.dividerColor),
    ),
    child: Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 24,
      children: [
        Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          spacing: 8,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 20, fontWeight: .w600, color: context.elTheme.textColor),
            ),
            Text(description, style: TextStyle(fontSize: 13, height: 1.6, color: context.elTheme.textSecondary)),
          ],
        ),
        child,
      ],
    ),
  );
}
