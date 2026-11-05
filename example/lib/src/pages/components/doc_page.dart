import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter_base.dart';

import '../example_page.dart';

/// 文档页中的一个可操作示例及其源码。
class ComponentDocSection {
  /// 创建包含标题、简述、示例和源码资源路径的小节。
  ComponentDocSection({required this.title, required this.description, required this.example, required this.source});

  /// 正文和本页目录共用的小节标题。
  final String title;

  /// 小节的行为说明。
  final String description;

  /// 示例舞台中的实际组件。
  final Widget example;

  /// 该示例的 Dart 资源路径。
  final String source;
}

/// 桌面和移动目录共用的组件文档布局。
class ComponentDocPage extends HookWidget {
  /// 创建组件文档页，由外层应用提供组件预设。
  const ComponentDocPage({super.key, required this.title, required this.description, required this.sections});

  /// 正文一级标题。
  final String title;

  /// 标题下方的简述。
  final String description;

  /// 按阅读顺序展示的小节。
  final List<ComponentDocSection> sections;

  @override
  Widget build(BuildContext context) {
    final scroll = useMemoized(ElScrollController.new);
    useEffect(() => scroll.dispose, [scroll]);

    return ExamplePage(
      title: '组件文档',
      child: Align(
        alignment: .topCenter,
        child: ConstrainedBox(
          constraints: .new(maxWidth: 1080),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showContents = constraints.maxWidth >= 880;
              final padding = showContents ? 32.0 : 16.0;
              return Row(
                crossAxisAlignment: .start,
                children: [
                  Expanded(
                    child: ElScrollView(
                      controller: scroll,
                      padding: .fromLTRB(padding, 24, padding, 32),
                      children: [
                        ElListView.builder(
                          keepAlive: true,
                          gap: 32,
                          itemCount: sections.length + 1,
                          itemBuilder: (context, index) => index == 0
                              ? _DocHeading(title: title, description: description, level: 1)
                              : _ExampleSection(
                                  key: ValueKey(sections[index - 1].source),
                                  section: sections[index - 1],
                                ),
                        ),
                      ],
                    ),
                  ),
                  if (showContents)
                    SizedBox(
                      width: 168,
                      child: SingleChildScrollView(
                        primary: false,
                        padding: .fromLTRB(0, 24, 16, 16),
                        child: Column(
                          mainAxisSize: .min,
                          crossAxisAlignment: .stretch,
                          children: [
                            Padding(
                              padding: .only(left: 12, bottom: 6),
                              child: Text('本页目录', style: Theme.of(context).textTheme.labelLarge),
                            ),
                            for (final (index, section) in sections.indexed)
                              TextButton(
                                style: TextButton.styleFrom(alignment: .centerLeft),
                                onPressed: () => scroll.scrollToIndex(index + 1),
                                child: Text(section.title),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DocHeading extends StatelessWidget {
  const _DocHeading({required this.title, required this.description, required this.level});

  final String title;
  final String description;
  final int level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 8,
      children: [
        Semantics(
          headingLevel: level,
          child: Text(
            title,
            style: (level == 1 ? theme.textTheme.headlineMedium : theme.textTheme.titleLarge)?.copyWith(
              fontWeight: .w700,
            ),
          ),
        ),
        Text(description, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _ExampleSection extends HookWidget {
  const _ExampleSection({super.key, required this.section});

  final ComponentDocSection section;

  @override
  Widget build(BuildContext context) {
    final expanded = useState(false);
    final theme = context.elTheme;
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        _DocHeading(title: section.title, description: section.description, level: 2),
        ElCardView(
          style: ElStyle(
            backgroundColor: theme.cardColor,
            border: ElBorder.all(borderWidth: 1, borderColor: theme.borderColorLighter),
            borderRadius: .circular(12),
          ),
          child: Column(
            crossAxisAlignment: .stretch,
            mainAxisSize: .min,
            children: [
              Padding(padding: .all(16), child: section.example),
              Divider(height: 1),
              Align(
                alignment: .centerRight,
                child: TextButton.icon(
                  onPressed: () => expanded.value = !expanded.value,
                  icon: Icon(Icons.code, size: 18),
                  label: Text(expanded.value ? '收起源码' : '查看源码'),
                ),
              ),
              if (expanded.value) _SourceCode(path: section.source),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceCode extends HookWidget {
  const _SourceCode({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final bundle = DefaultAssetBundle.of(context);
    final source = useMemoized(() => bundle.loadString(path), [bundle, path]);
    final copied = useState(false);
    return FutureBuilder<String>(
      future: source,
      builder: (context, snapshot) {
        final code = snapshot.data;
        if (code == null) {
          return Padding(padding: .all(16), child: Text(snapshot.hasError ? '无法读取示例源码' : '正在读取源码…'));
        }
        return ColoredBox(
          color: context.elTheme.fill,
          child: Column(
            crossAxisAlignment: .stretch,
            mainAxisSize: .min,
            children: [
              Padding(
                padding: .symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    Text('Dart', style: Theme.of(context).textTheme.labelMedium),
                    TextButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (context.mounted) copied.value = true;
                      },
                      child: Text(copied.value ? '已复制' : '复制源码'),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: .horizontal,
                padding: .fromLTRB(16, 0, 16, 16),
                child: SelectionArea(
                  child: Text(code.trimRight(), style: TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
