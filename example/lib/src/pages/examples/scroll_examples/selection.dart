import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../example_page.dart';
import 'scroll_mode.dart';
import 'comparison_list.dart';

/// 用一万条独立记录演示回收复用与数据驱动的复选状态。
class RecyclerSelectionPage extends StatefulWidget {
  /// 创建万条复选列表示例。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerSelectionPage({super.key});

  @override
  State<RecyclerSelectionPage> createState() => _RecyclerSelectionPageState();
}

enum _SelectionAction { first, last, locate, clear }

class _RecyclerSelectionPageState extends State<RecyclerSelectionPage> {
  final _selectedCount = ValueNotifier<int>(0);
  final _indexInput = TextEditingController(text: '5000');
  final _official = ScrollController(keepScrollOffset: false);
  SliverExampleMode _mode = .recycler;
  ScrollController get _currentController => _official;
  late final _adapter = _SelectionRecords(_selectionChanged);

  void _selectionChanged(int count) {
    _selectedCount.value = count;
    if (_mode == .official) setState(() {});
  }

  void _scrollTo(int index) {
    if (_currentController.hasClients) {
      _currentController.jumpTo((index * _selectionExtent).clamp(0, _currentController.position.maxScrollExtent));
    }
  }

  Future<void> _locate() async {
    final index = await showDialog<int>(
      context: context,
      builder: (context) {
        void submit() {
          final input = int.tryParse(_indexInput.text.trim());
          if (input != null) Navigator.of(context).pop((input - 1).clamp(0, _adapter.getItemCount() - 1));
        }

        return AlertDialog(
          title: Text('定位条目'),
          content: TextField(
            key: ValueKey('selection-index-input'),
            controller: _indexInput,
            autofocus: true,
            keyboardType: .number,
            decoration: InputDecoration(labelText: '第几项（1–10000）', border: OutlineInputBorder()),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('取消')),
            FilledButton(key: ValueKey('selection-locate'), onPressed: submit, child: Text('定位')),
          ],
        );
      },
    );
    if (mounted && index != null) _scrollTo(index);
  }

  void _choose(Object option) {
    if (option case final SliverExampleMode mode) {
      if (_mode == mode) return;
      setState(() => _mode = mode);
      // 各容器从同一首项开始比较；数据和选择集合不随容器替换。
      if (_official.hasClients) _official.jumpTo(0);
      return;
    }
    switch (option as _SelectionAction) {
      case .first:
        _scrollTo(0);
      case .last:
        _scrollTo(_adapter.getItemCount() - 1);
      case .locate:
        _locate();
      case .clear:
        _adapter.clearSelection();
    }
  }

  @override
  void dispose() {
    _adapter.dispose();
    _selectedCount.dispose();
    _indexInput.dispose();
    _official.dispose();
    super.dispose();
  }

  Widget _row(BuildContext context, int index) {
    final item = _adapter.items[index];
    return RepaintBoundary(
      child: _OfficialSelectionRow(
        key: ValueKey(item.id),
        item: item,
        checked: _adapter.selectedIds.contains(item.id),
        onSelect: _adapter.select,
      ),
    );
  }

  Widget _scrollContent() => SliverComparisonList(
    mode: _mode,
    controller: _official,
    itemCount: _adapter.getItemCount(),
    itemBuilder: _row,
    recycledItemBuilder: (context, index) => HookBuilder(
      builder: (context) {
        final model = useMemoized(_SelectionModel.new);
        useEffect(() {
          void bind() {
            final item = _adapter.items[index.value];
            model.bind(item, _adapter.selectedIds.contains(item.id));
          }

          bind();
          index.addListener(bind);
          _adapter.addListener(bind);
          return () {
            index.removeListener(bind);
            _adapter.removeListener(bind);
            model.dispose();
          };
        }, [index]);
        return useMemoized(() => _SelectionRow(model, _adapter.select), [model]);
      },
    ),
  );

  @override
  Widget build(BuildContext context) => ExamplePage(
    title: '万条复选列表',
    actions: [
      ValueListenableBuilder<int>(
        valueListenable: _selectedCount,
        builder: (context, count, child) => Padding(
          padding: .symmetric(horizontal: 4),
          child: Text('$count / 10000', key: ValueKey('selection-count'), style: TextStyle(fontSize: 12)),
        ),
      ),
      PopupMenuButton<Object>(
        key: ValueKey('selection-menu'),
        tooltip: '列表选项',
        icon: Icon(Icons.more_vert),
        onSelected: _choose,
        itemBuilder: (context) => [
          for (final mode in SliverExampleMode.values)
            CheckedPopupMenuItem(
              key: ValueKey('selection-mode-${mode.name}'),
              value: mode,
              checked: _mode == mode,
              child: Text(mode.label),
            ),
          PopupMenuDivider(),
          PopupMenuItem(key: ValueKey('selection-first'), value: _SelectionAction.first, child: Text('首项')),
          PopupMenuItem(key: ValueKey('selection-last'), value: _SelectionAction.last, child: Text('末项')),
          PopupMenuItem(key: ValueKey('selection-locate-menu'), value: _SelectionAction.locate, child: Text('定位条目…')),
          PopupMenuItem(key: ValueKey('selection-clear'), value: _SelectionAction.clear, child: Text('清空选择')),
        ],
      ),
    ],
    child: SafeArea(top: false, child: _scrollContent()),
  );
}

final double _selectionExtent = 88;

class _SelectionItem {
  _SelectionItem(this.id)
    : title = '条目 ${(id + 1).toString().padLeft(5, '0')}',
      description = '记录 ${id + 1} · 分组 ${id % 37 + 1} · 独立业务编号 RV-${100000 + id}';

  final int id;
  final String title;
  final String description;
}

class _SelectionRecords extends ChangeNotifier {
  _SelectionRecords(this.onCountChanged);

  final ValueChanged<int> onCountChanged;
  final items = List.generate(10000, _SelectionItem.new);
  // 状态归业务 ID，holder 的叶子模型只保存当前记录的显示快照。
  final selectedIds = <int>{};

  int getItemCount() => items.length;

  void select(int id, bool selected) {
    final changed = selected ? selectedIds.add(id) : selectedIds.remove(id);
    if (!changed) return;
    notifyListeners();
    onCountChanged(selectedIds.length);
  }

  void clearSelection() {
    selectedIds.clear();
    notifyListeners();
    onCountChanged(0);
  }
}

class _SelectionModel {
  final item = ValueNotifier<_SelectionItem?>(null);
  final checked = ValueNotifier<bool>(false);
  bool receiving = false;

  void bind(_SelectionItem value, bool selected) {
    receiving = true;
    try {
      item.value = value;
      checked.value = selected;
    } finally {
      receiving = false;
    }
  }

  void dispose() {
    item.dispose();
    checked.dispose();
  }
}

class _OfficialSelectionRow extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _OfficialSelectionRow({super.key, required this.item, required this.checked, required this.onSelect});
  final _SelectionItem item;
  final bool checked;
  final void Function(int, bool) onSelect;
  @override
  State<_OfficialSelectionRow> createState() => _OfficialSelectionRowState();
}

class _OfficialSelectionRowState extends State<_OfficialSelectionRow> {
  final _model = _SelectionModel();
  late final _row = _SelectionRow(_model, (id, checked) => widget.onSelect(id, checked));
  @override
  void initState() {
    super.initState();
    _model.bind(widget.item, widget.checked);
  }

  @override
  void didUpdateWidget(_OfficialSelectionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _model.bind(widget.item, widget.checked);
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _row;
}

class _SelectionRow extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _SelectionRow(this.model, this.onSelect);
  final _SelectionModel model;
  final void Function(int, bool) onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rowEvent = ElEvent(onTap: (_) => model.checked.value = !model.checked.value);
    // 固定结构只在挂载或主题变化时建立，绑定只通知真正消费数据的叶子。
    final content = Row(
      spacing: 14,
      children: [
        // 阻止冒泡的包装与记录无关，只有语义文案随绑定更新。
        ElView(
          event: ElEvent(onTap: (event) => event.stopPropagation()),
          child: ValueListenableBuilder<_SelectionItem?>(
            valueListenable: model.item,
            child: ElCheckbox.toggle(
              modelValue: model.checked,
              onChanged: (checked) {
                final item = model.item.value;
                if (!model.receiving && item != null) onSelect(item.id, checked);
              },
            ),
            builder: (context, item, child) => Semantics(label: '选择${item?.title ?? ''}', child: child),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            mainAxisAlignment: .center,
            spacing: 4,
            children: [
              ValueListenableBuilder<_SelectionItem?>(
                valueListenable: model.item,
                builder: (context, item, child) => Text(item?.title ?? '', style: TextStyle(fontWeight: .w600)),
              ),
              ValueListenableBuilder<_SelectionItem?>(
                valueListenable: model.item,
                builder: (context, item, child) => Text(
                  item?.description ?? '',
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return ValueListenableBuilder<bool>(
      valueListenable: model.checked,
      child: content,
      builder: (context, checked, child) => ElCardView(
        event: rowEvent,
        style: ElStyle(
          height: _selectionExtent,
          padding: .symmetric(horizontal: 16, vertical: 10),
          backgroundColor: checked ? colors.primary.withValues(alpha: .06) : colors.surface,
          border: .only(borderBottom: .new(borderColor: colors.outlineVariant.withValues(alpha: .5))),
        ),
        child: child,
      ),
    );
  }
}
