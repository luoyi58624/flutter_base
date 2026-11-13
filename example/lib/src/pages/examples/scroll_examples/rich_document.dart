import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../widgets/code_preview/index.dart';
import '../../../widgets/example_image.dart';
import '../../../layout/example_page.dart';
import '../../../widgets/example_scrollbar.dart';
import 'scroll_mode.dart';
import '../../../widgets/panel.dart';

/// 让各滚动容器共用带长文、表格、插图和可展开源码的文档。
class RecyclerRichDocumentPage extends StatefulWidget {
  /// 创建带小节目录的富文本文档对照页。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerRichDocumentPage({super.key});

  @override
  State<RecyclerRichDocumentPage> createState() => _RecyclerRichDocumentPageState();
}

const _sectionCount = 1000;
const _titles = ['更新策略', '兼容性表格', '现场图解', '验收清单'];

String _title(int index) => '${(index + 1).toString().padLeft(3, '0')} · ${_titles[index % _titles.length]}';

typedef _Section = ({int index, bool expanded, bool checked});

class _RecyclerRichDocumentPageState extends State<RecyclerRichDocumentPage> {
  final _official = ScrollController(keepScrollOffset: false);
  final _officialKeys = List.generate(_sectionCount, (_) => GlobalKey());
  final _sections = List.generate(
    _sectionCount,
    (index) => ValueNotifier<_Section>((index: index, expanded: false, checked: false)),
  );
  final _expanded = <int>{};
  final _checked = <int>{};
  var _mode = SliverExampleMode.initial;
  var _locateGeneration = 0;

  _Section _section(int index) =>
      (index: index, expanded: _expanded.contains(index), checked: _checked.contains(index));

  void _toggleCode(int index) {
    if (!_expanded.remove(index)) _expanded.add(index);
    _updateSection(index);
  }

  void _checkSection(int index, bool checked) {
    if (checked ? _checked.add(index) : _checked.remove(index)) _updateSection(index);
  }

  void _updateSection(int index) {
    // 常驻文档也只通知当前小节，不能让一次勾选重新配置整份文档。
    _sections[index].value = _section(index);
  }

  void _changeMode(SliverExampleMode mode) {
    if (_mode == mode) return;
    _locateGeneration++;
    setState(() => _mode = mode);
  }

  Future<void> _showContents() async {
    final target = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: .only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: FractionallySizedBox(heightFactor: .66, child: _ContentsSheet()),
      ),
    );
    if (!mounted || target == null) return;
    final generation = ++_locateGeneration;
    await _locateOfficial(target, generation);
  }

  Future<void> _locateOfficial(int index, int generation) async {
    // 官方列表的条目高度由实测决定，先估计位置，再按实际挂载范围逼近。
    for (var attempt = 0; attempt <= _sectionCount; attempt++) {
      if (!mounted || generation != _locateGeneration || !_official.hasClients) return;
      final target = _officialKeys[index].currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(target);
        return;
      }
      final position = _official.position;
      final first = _officialKeys.indexWhere((key) => key.currentContext != null);
      final direction = first > index ? -1 : 1;
      final next = attempt == 0
          ? position.maxScrollExtent * index / (_sectionCount - 1)
          : position.pixels + direction * position.viewportDimension * .8;
      final offset = next.clamp(0.0, position.maxScrollExtent);
      if (attempt > 0 && (position.pixels - offset).abs() < .01) return;
      _official.jumpTo(offset);
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Widget _sectionItem(BuildContext context, int index) => _SectionCard(
    key: _officialKeys[index],
    section: _sections[index],
    onToggleCode: _toggleCode,
    onCheck: _checkSection,
  );

  @override
  void dispose() {
    _official.dispose();
    for (final section in _sections) {
      section.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExamplePage(
    title: '富文本文档',
    actions: [
      IconButton(
        key: ValueKey('rich-document-contents'),
        tooltip: '小节目录',
        onPressed: _showContents,
        icon: Icon(Icons.format_list_numbered_rounded),
      ),
      PopupMenuButton<SliverExampleMode>(
        key: ValueKey('comparison-mode-menu'),
        onSelected: _changeMode,
        itemBuilder: (_) => [..._mode.menuItems(keyPrefix: 'comparison-mode')],
      ),
    ],
    child: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 880),
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (notification) {
              if (notification.depth == 0 && notification.dragDetails != null) _locateGeneration++;
              return false;
            },
            child: RecyclerExampleScrollbar(
              controller: _official,
              child: _mode.scrollView(
                controller: _official,
                slivers: [_mode.list(context, itemCount: _sectionCount, itemBuilder: _sectionItem)],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ContentsSheet extends StatefulWidget {
  @override
  State<_ContentsSheet> createState() => _ContentsSheetState();
}

class _ContentsSheetState extends State<_ContentsSheet> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final indices = [
      for (var index = 0; index < _sectionCount; index++)
        if (_title(index).contains(_query) || '${index + 1}'.startsWith(_query)) index,
    ];
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: .fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: ValueKey('rich-document-search'),
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                labelText: '在 $_sectionCount 节中搜索',
                hintText: '输入节号或主题',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: indices.isEmpty
                ? Center(child: Text('没有匹配的小节'))
                : ListView.builder(
                    keyboardDismissBehavior: .onDrag,
                    itemCount: indices.length,
                    itemBuilder: (context, position) {
                      final index = indices[position];
                      return ListTile(
                        key: ValueKey('rich-document-directory-$index'),
                        title: Text(_title(index)),
                        trailing: Icon(Icons.arrow_forward_rounded, size: 18),
                        onTap: () => Navigator.pop(context, index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _SectionCard({super.key, required this.section, required this.onToggleCode, required this.onCheck});

  final ValueListenable<_Section> section;
  final ValueChanged<int> onToggleCode;
  final void Function(int, bool) onCheck;

  @override
  Widget build(BuildContext context) {
    final index = section.value.index;
    final type = index % _titles.length;
    final theme = Theme.of(context);
    return Padding(
      padding: .fromLTRB(14, 8, 14, 8),
      child: ExamplePanel(
        style: ElStyle(
          padding: .all(16),
          borderRadius: .circular(16),
          backgroundColor: theme.colorScheme.surfaceContainerLow,
        ),
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: 12,
          children: [
            Text(_title(index), key: ValueKey('rich-document-title-$index'), style: theme.textTheme.titleLarge),
            switch (type) {
              0 => Text(
                '第 ${index + 1} 节记录了一次滚动回归。先固定相同的视口、字号、缓存和输入速度，分别记录首次进入与预热后的区间。'
                '\n\n换绑会更新内容实际使用的数据，长文换行会改变小节高度。开启源码后可以边滚动边观察阅读位置。',
              ),
              1 => _CompatibilityTable(),
              2 => Column(
                crossAxisAlignment: .stretch,
                spacing: 6,
                children: [
                  ClipRRect(
                    borderRadius: .circular(10),
                    child: Image.asset(
                      'assets/recycler_cards/${(index ~/ _titles.length).isEven ? 'owl.jpg' : 'owl-2.jpg'}',
                      height: 156,
                      fit: .cover,
                      semanticLabel: '样本插图 ${index + 1}',
                      frameBuilder: exampleImageFrame,
                      errorBuilder: (_, _, _) => SizedBox(height: 156),
                    ),
                  ),
                  Text('图 ${index + 1}　同一张离线图片用于对比解码后的滚动。', style: theme.textTheme.bodySmall),
                ],
              ),
              _ => Row(
                children: [
                  Expanded(child: Text('核对同一条记录的滚动位置与展开状态')),
                  ElListenableBuilder<ValueListenable<_Section>, bool>(
                    listenable: section,
                    select: (source) => source.value.checked,
                    builder: (_, _) => Switch(
                      key: ValueKey('rich-document-check-$index'),
                      value: section.value.checked,
                      onChanged: (value) => onCheck(index, value),
                    ),
                  ),
                ],
              ),
            },
            ElListenableBuilder<ValueListenable<_Section>, bool>(
              listenable: section,
              select: (source) => source.value.expanded,
              builder: (_, _) {
                final expanded = section.value.expanded;
                return Column(
                  crossAxisAlignment: .stretch,
                  spacing: 12,
                  children: [
                    Align(
                      alignment: .centerLeft,
                      child: TextButton.icon(
                        key: ValueKey('rich-document-code-toggle-$index'),
                        onPressed: () => onToggleCode(index),
                        icon: Icon(expanded ? Icons.expand_less : Icons.code_rounded, size: 18),
                        label: Text(expanded ? '收起源码' : '展开源码'),
                      ),
                    ),
                    if (expanded) ElCodePreview(key: ValueKey('rich-document-code-$index'), code: _source(type)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CompatibilityTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Table(
    border: TableBorder.symmetric(inside: BorderSide(color: Theme.of(context).dividerColor)),
    children: [
      for (final (stage, sample, observation) in [
        ('阶段', '条件', '观察'),
        ('首次', '离线图片', '首屏解码'),
        ('预热', '同一滚动轨迹', '帧间隔'),
        ('折叠', '改变一节高度', '阅读位置'),
      ])
        TableRow(
          children: [
            for (final cell in [stage, sample, observation]) Padding(padding: .all(8), child: Text(cell)),
          ],
        ),
    ],
  );
}

String _source(int type) => switch (type) {
  0 =>
    '''void replaceRecord(int index, Record next) {
  final previous = records[index];
  if (previous == next) return;
  records[index] = next;
  adapter.notifyItemChanged(index);
}
''',
  1 =>
    '''final rows = [
  ('首次', '离线图片', '首屏解码'),
  ('预热', '同一滚动轨迹', '帧间隔'),
  ('折叠', '改变一节高度', '阅读位置'),
];

for (final (stage, input, metric) in rows) {
  record(stage, input, metric);
}
''',
  2 =>
    '''Image.asset(
  'assets/recycler_cards/owl.jpg',
  height: 156,
  fit: BoxFit.cover,
  semanticLabel: '样本插图',
);
''',
  _ =>
    '''final checked = <int>{};

void markSection(int index, bool done) {
  if (done) {
    checked.add(index);
  } else {
    checked.remove(index);
  }
  adapter.notifyItemChanged(index);
}
''',
};
