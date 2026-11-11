import 'package:flutter/widgets.dart';
import 'package:flutter_base/desktop.dart';

import '../../../../../widgets/doc_scroll_view.dart';

/// 目录和正文共享小节下标的示例。
class AnchorExample extends HookWidget {
  /// 创建双向绑定示例。
  const AnchorExample({super.key});

  @override
  Widget build(BuildContext context) {
    final scroll = useMemoized(DocScrollController.new);
    useEffect(() => scroll.dispose, [scroll]);
    final sections = ['简介', '使用方法', '常见问题'];

    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: .start,
        spacing: 16,
        children: [
          Expanded(
            child: DocScrollView(
              controller: scroll,
              itemCount: sections.length,
              itemBuilder: (context, index) => ElView(
                style: ElStyle(
                  height: 180,
                  padding: .all(16),
                  backgroundColor: context.elTheme.fill,
                  borderRadius: .circular(8),
                ),
                child: sections[index],
              ),
              gap: 12,
            ),
          ),
          SizedBox(
            width: 106,
            child: ElAnchor(links: sections, modelValue: scroll.activeSection),
          ),
        ],
      ),
    );
  }
}
