import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

import '../../layout/example_page.dart';
import '../code_preview/index.dart';
import 'scroll_view.dart';

part 'section.dart';

/// 统一文档的页首、滚动正文与宽屏目录。
class DocsPage extends HookWidget {
  /// 从有序小节生成正文和目录。
  const DocsPage({super.key, required this.title, this.description, required this.sections, this.navTitle = '组件文档'});

  /// 正文的一级标题。
  final String title;

  /// 正文标题下方的简介。
  final String? description;

  /// 按阅读顺序声明的正文小节。
  final List<DocsSection> sections;

  /// 独立页面导航栏的标题。
  final String navTitle;

  @override
  Widget build(BuildContext context) {
    final scroll = useMemoized(DocScrollController.new);
    useEffect(() => scroll.dispose, [scroll]);
    return ExamplePage(
      title: navTitle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showContents = constraints.maxWidth >= 880 && sections.isNotEmpty;
          final padding = showContents ? 32.0 : 16.0;
          return DocScrollView(
            controller: showContents ? scroll : null,
            padding: .fromLTRB(padding, 24, padding, 32),
            gap: 32,
            headerCount: 1,
            itemCount: sections.length + 1,
            itemBuilder: (context, index) =>
                index == 0 ? _Heading(title: title, description: description, level: 1) : sections[index - 1],
            outline: showContents
                ? Padding(
                    padding: .fromLTRB(0, 24, 16, 16),
                    child: Column(
                      mainAxisSize: .min,
                      crossAxisAlignment: .stretch,
                      children: [
                        Padding(
                          padding: .only(left: 12, bottom: 6),
                          child: Text('目录', style: Theme.of(context).textTheme.labelLarge),
                        ),
                        ElAnchor(
                          links: [for (final section in sections) section.title],
                          modelValue: scroll.activeSection,
                        ),
                      ],
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}
