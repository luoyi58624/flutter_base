import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../layout/example_page.dart';
import '../../../widgets/panel.dart';

/// 展示全量常驻文档的自然布局与跨段落文本选择。
class ElSliverListExamplePage extends HookWidget {
  /// 创建文档滚动示例。
  // ignore: prefer_const_constructors_in_immutables
  ElSliverListExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = useState(false);
    final expanded = useState(false);
    final controller = useScrollController();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ExamplePage(
      title: '文档滚动（全量常驻）',
      backgroundColor: colors.surface,
      actions: [
        IconButton(
          key: ValueKey('document-width-toggle'),
          tooltip: narrow.value ? '恢复完整宽度' : '切换窄版阅读',
          onPressed: () => narrow.value = !narrow.value,
          icon: Icon(narrow.value ? Icons.view_stream_outlined : Icons.view_column_outlined),
        ),
        IconButton(
          key: ValueKey('document-expand-toggle'),
          tooltip: expanded.value ? '收起第一段' : '展开第一段',
          onPressed: () => expanded.value = !expanded.value,
          icon: Icon(expanded.value ? Icons.unfold_less : Icons.unfold_more),
        ),
      ],
      child: Align(
        alignment: .topCenter,
        child: ConstrainedBox(
          constraints: .new(maxWidth: 840),
          child: FractionallySizedBox(
            widthFactor: narrow.value ? .72 : 1,
            child: ElSelectionView(
              child: ElScrollView(
                key: ValueKey('document-scroll'),
                controller: controller,
                gap: 24,
                padding: .fromLTRB(20, 20, 20, 32),
                children: [
                  ExamplePanel(
                    style: ElStyle(
                      padding: .all(20),
                      backgroundColor: colors.surfaceContainerLow,
                      borderRadius: .circular(16),
                    ),
                    child: Column(
                      mainAxisSize: .min,
                      crossAxisAlignment: .start,
                      children: [
                        Text('一页连续的阅读笔记', style: theme.textTheme.headlineSmall),
                        SizedBox(height: 12),
                        Text(
                          '80 段内容一次挂载并保留。长按或拖动文字，可以跨段落连续选择。',
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '右上角可切换阅读宽度，或展开第一段，观察文字自然换行后的排版。',
                          style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                  for (var index = 0; index < 80; index++)
                    _DocumentParagraph(
                      key: ValueKey('document-paragraph-$index'),
                      index: index,
                      expanded: index == 0 && expanded.value,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentParagraph extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _DocumentParagraph({super.key, required this.index, required this.expanded});

  final int index;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = _readingNotes[index % _readingNotes.length];
    final extra = expanded
        ? '\n\n补充记录：同一段文字可以继续变长，后面的段落会按照新的实际高度自然向下排列。'
              '试着先选中几个句子，再改变阅读宽度，体会一页文档中内容与位置的联系。'
              '这里不需要为段落指定高度，也不必把一整页内容合成一个巨大文本块。'
        : '';
    final content = Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        Text('第 ${index + 1} 段 · ${note.title}', style: theme.textTheme.titleMedium),
        SizedBox(height: 8),
        Text('${note.body}$extra', style: theme.textTheme.bodyLarge?.copyWith(height: 1.7)),
      ],
    );

    if (index % 16 != 7) return content;
    return ExamplePanel(
      style: ElStyle(
        padding: .all(16),
        backgroundColor: theme.colorScheme.surfaceContainerLow,
        border: .all(borderColor: theme.colorScheme.outlineVariant),
        borderRadius: .circular(12),
      ),
      child: content,
    );
  }
}

final _readingNotes = [
  (
    title: '清晨的街道',
    body:
        '清晨的街道还很安静，树影沿着人行道慢慢移动。早餐店刚刚开门，热气从门口飘出来。'
        '在开始忙碌之前，留一点时间看看周围，往往能发现平时匆匆经过时没有注意到的小事。',
  ),
  (title: '一扇开着的窗', body: '风从窗边经过，书页轻轻翻动。把视线从屏幕上移开片刻，让眼睛停在远处的树梢。'),
  (
    title: '沿着河岸慢慢走',
    body:
        '河岸两边有不同的声音：一边是经过的自行车，一边是水面上的鸟。'
        '走到旧桥下时，脚步和说话声都会带一点回响。没有急着抵达的地方，散步就成了一段可以自由安排的时间。',
  ),
  (
    title: '把想法写下来',
    body:
        '有些想法在脑海中显得完整，写到纸上才发现还缺少几个连接。'
        '先把观察写清楚，再补上原因和例子。文字不必一次完成，允许它随着理解一点点变得准确。',
  ),
  (
    title: '午后的一点停顿',
    body:
        '午后的光线落在桌面上，杯子的影子比早晨短了一些。'
        '读完一段，停下来想想刚才那句话与自己的经验有什么关系。有时真正留下来的，是阅读间隙出现的一个小问题。',
  ),
  (
    title: '从一段接到下一段',
    body:
        '长文由许多有各自节奏的段落组成。短段落让人停顿，长段落容纳更多解释，偶尔出现的卡片则留下一条值得记住的笔记。'
        '无论内容长短，它们都属于同一页，可以顺着阅读，也可以回到前面重新比较。',
  ),
];
