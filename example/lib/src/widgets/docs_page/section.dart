part of 'index.dart';

/// 带二级标题的文档小节，可直接展示内容或关联源码预览。
class DocsSection extends StatelessWidget {
  /// 创建小节，提供源码资源路径时将内容放进示例卡。
  DocsSection({Key? key, required this.title, this.description, this.source, required this.child})
    : super(key: key ?? (source == null ? null : ValueKey(source)));

  /// 正文与目录共用的小节标题。
  final String title;

  /// 标题下方的小节说明。
  final String? description;

  /// 正文内容或示例舞台里的组件。
  final Widget child;

  /// 用于高亮和复制的 Dart 源码资源路径。
  final String? source;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    mainAxisSize: .min,
    children: [
      _Heading(title: title, description: description, level: 2),
      if (source case final path?) _SourceExample(source: path, child: child) else child,
    ],
  );
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.description, required this.level});

  final String title;
  final String? description;
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
        if (description case final text?)
          Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _SourceExample extends HookWidget {
  const _SourceExample({required this.source, required this.child});

  final String source;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bundle = DefaultAssetBundle.of(context);
    final contents = useMemoized(() => bundle.loadString(source), [bundle, source]);
    final snapshot = useFuture(contents, preserveState: false);
    return ElCodeExample(code: snapshot.data ?? '', children: [child, if (snapshot.hasError) Text('无法读取示例源码')]);
  }
}
