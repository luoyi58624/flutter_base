import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 打开后滚动列表，卡片在同一帧跟随目标；首选侧放不下时翻到另一侧，目标滚出列表可见区域后暂时隐藏，滚回后恢复。
class Example3 extends StatelessWidget {
  /// 创建滚动与边界示例。
  Example3({super.key});

  @override
  Widget build(BuildContext context) {
    return ElCard(
      style: ElStyle(height: 260, padding: .zero),
      child: ListView(
        padding: .all(16),
        children: [
          ElView(
            style: ElStyle(color: context.elTheme.textSecondary),
            child: '向下滚动，找到按钮并打开弹出框，然后继续滚动。',
          ),
          SizedBox(height: 240),
          Center(
            child: ElPopover(
              placement: .top,
              title: '跟随目标',
              content: '上方放不下时翻到下方。',
              child: ElButton(type: .primary, child: '打开后滚动'),
            ),
          ),
          SizedBox(height: 480),
        ],
      ),
    );
  }
}
