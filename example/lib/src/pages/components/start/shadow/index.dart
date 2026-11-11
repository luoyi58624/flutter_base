import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

import '../../../../layout/example_page.dart';
import '../../../../widgets/doc_scroll_view.dart';
import '../../../../widgets/panel.dart';

/// 对照五级阴影，并通过导航栏切换视觉风格。
class ShadowPage extends HookWidget {
  /// 创建阴影示例页。
  const ShadowPage({super.key});

  @override
  Widget build(BuildContext context) {
    final type = useState(ElShadowType.material);
    final surface = context.elTheme.cardColor;
    return ExamplePage(
      title: '阴影',
      actions: [
        Padding(
          padding: .symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ElShadowType>(
              key: ValueKey('shadow-type'),
              value: type.value,
              hint: Text('阴影风格'),
              items: [
                for (final value in ElShadowType.values) DropdownMenuItem(value: value, child: Text(_labels[value]!)),
              ],
              onChanged: (value) {
                if (value != null) type.value = value;
              },
            ),
          ),
        ),
      ],
      child: DocScrollView(
        padding: .all(40),
        itemCount: 1,
        itemBuilder: (context, index) => Wrap(
          alignment: .center,
          spacing: 48,
          runSpacing: 48,
          children: [
            for (final level in ElLevelType.values)
              ExamplePanel(
                key: ValueKey('shadow-${level.name}'),
                style: ElStyle(
                  width: 180,
                  height: 120,
                  backgroundColor: surface,
                  borderRadius: .circular(16),
                ).withShadow(type: type.value, level: level),
                child: Center(child: Text(level.name)),
              ),
          ],
        ),
      ),
    );
  }
}

const _labels = {
  ElShadowType.material: 'Material 投影',
  ElShadowType.uniform: '四周均匀',
  ElShadowType.floating: '轻盈悬浮',
  ElShadowType.contact: '贴边短影',
  ElShadowType.glow: '彩色光晕',
  ElShadowType.inset: '内凹阴影',
};
