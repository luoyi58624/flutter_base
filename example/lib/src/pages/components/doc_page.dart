import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/recycler_view.dart' as rv;

import '../../widgets/code_preview/index.dart';
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
  const ComponentDocPage({
    super.key,
    required this.title,
    required this.description,
    required this.sections,
    this.useRecyclerView = false,
    this.repeatCount = 1,
  }) : assert(repeatCount > 0);

  /// 正文一级标题。
  final String title;

  /// 标题下方的简述。
  final String description;

  /// 按阅读顺序展示的小节。
  final List<ComponentDocSection> sections;

  /// 使用 RecyclerView 的模板创建、绑定与回收管线展示相同内容。
  final bool useRecyclerView;

  /// 重复正文小节的次数，两条滚动管线使用相同的条目数量。
  final int repeatCount;

  @override
  Widget build(BuildContext context) {
    final scroll = useMemoized(ElScrollController.new);
    useEffect(() => scroll.dispose, [scroll]);
    final recyclerView = useMemoized(
      () => useRecyclerView
          ? (rv.RecyclerView()
              ..setLayoutManager(rv.LinearLayoutManager(context))
              ..setItemViewCacheSize(2))
          : null,
      [useRecyclerView],
    );
    final adapter = useMemoized(
      () => useRecyclerView
          ? _DocAdapter(title: title, description: description, sections: sections, repeatCount: repeatCount)
          : null,
      [useRecyclerView, title, description, repeatCount, ...sections],
    );
    useEffect(() {
      if (recyclerView != null && adapter != null) recyclerView.setAdapter(adapter);
      return null;
    }, [recyclerView, adapter]);

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
              recyclerView?.setPadding(padding, 24, padding, 32);
              return Row(
                crossAxisAlignment: .start,
                children: [
                  Expanded(
                    child:
                        recyclerView ??
                        ElScrollView(
                          controller: scroll,
                          padding: .fromLTRB(padding, 24, padding, 32),
                          children: [
                            ElListView.builder(
                              keepAlive: false,
                              gap: 32,
                              itemCount: sections.length * repeatCount + 1,
                              itemBuilder: (context, index) => index == 0
                                  ? _DocHeading(title: title, description: description, level: 1)
                                  : KeyedSubtree(
                                      key: ValueKey((index, sections[(index - 1) % sections.length].source)),
                                      child: _ExampleSection(
                                        key: ValueKey(sections[(index - 1) % sections.length].source),
                                        section: sections[(index - 1) % sections.length],
                                      ),
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
                                onPressed: () {
                                  if (recyclerView != null) {
                                    recyclerView.scrollToPosition(index + 1);
                                  } else {
                                    scroll.scrollToIndex(index + 1);
                                  }
                                },
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

class _DocAdapter extends rv.Adapter<_DocViewHolder> {
  _DocAdapter({required this.title, required this.description, required this.sections, required this.repeatCount});

  final String title;
  final String description;
  final List<ComponentDocSection> sections;
  final int repeatCount;

  @override
  int getItemCount() => sections.length * repeatCount + 1;

  @override
  int getItemViewType(int position) => position == 0 ? 0 : (position - 1) % sections.length + 1;

  @override
  _DocViewHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) => _DocViewHolder(
    viewType == 0
        ? _DocHeading(title: title, description: description, level: 1)
        : _ExampleSection(section: sections[viewType - 1]),
  );

  @override
  void onBindViewHolder(_DocViewHolder holder, int position, [List<Object> payloads = const []]) {
    // 只更新位置决定的间隔，固定模板子树不随绑定重新创建。
    holder.gap.value = position == getItemCount() - 1 ? 0 : 32;
  }
}

class _DocViewHolder extends rv.ViewHolder {
  _DocViewHolder(Widget template) : this._(template, ValueNotifier<double>(32));

  _DocViewHolder._(Widget template, this.gap)
    : super(
        ValueListenableBuilder<double>(
          valueListenable: gap,
          child: template,
          builder: (context, value, child) => Padding(
            padding: .only(bottom: value),
            child: child,
          ),
        ),
      );

  final ValueNotifier<double> gap;
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
    final bundle = DefaultAssetBundle.of(context);
    final source = useMemoized(() => bundle.loadString(section.source), [bundle, section.source]);
    final snapshot = useFuture(source, preserveState: false);
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      children: [
        _DocHeading(title: section.title, description: section.description, level: 2),
        ElCodeExample(code: snapshot.data ?? '', children: [section.example, if (snapshot.hasError) Text('无法读取示例源码')]),
      ],
    );
  }
}
