import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../layout/example_page.dart';
import 'scroll_mode.dart';
import 'comparison_list.dart';
import '../../../widgets/panel.dart';

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
    final item = _adapter.itemAt(index);
    return RepaintBoundary(
      child: _OfficialSelectionRow(key: ValueKey(item.id), item: item, records: _adapter),
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
          void bind() => _adapter.bind(model, _adapter.itemAt(index.value));

          bind();
          index.addListener(bind);
          return () {
            index.removeListener(bind);
            _adapter.unbind(model);
          };
        }, [index, model]);
        useEffect(() => model.dispose, [model]);
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

class _SelectionRecords {
  _SelectionRecords(this.onCountChanged);

  final ValueChanged<int> onCountChanged;
  // 选择集合不依赖文案是否已创建，远距离定位只生成实际绑定的记录。
  final items = <int, _SelectionItem>{};
  // 状态归业务 ID，holder 的叶子模型只保存当前记录的显示快照。
  final selectedIds = <int>{};
  // 只登记已绑定的行，兼容容器切换时同一业务记录短暂对应多个模型。
  final _models = <int, Set<_SelectionModel>>{};

  int getItemCount() => 10000;

  _SelectionItem itemAt(int index) => items.putIfAbsent(index, () => _SelectionItem(index));

  void bind(_SelectionModel model, _SelectionItem item) {
    if (model.item.value?.id != item.id) unbind(model);
    (_models[item.id] ??= {}).add(model);
    model.bind(item, selectedIds.contains(item.id));
  }

  void unbind(_SelectionModel model) {
    final id = model.item.value?.id;
    final models = _models[id];
    if (models == null) return;
    models.remove(model);
    if (models.isEmpty) _models.remove(id);
  }

  void select(int id, bool selected) {
    final changed = selected ? selectedIds.add(id) : selectedIds.remove(id);
    if (!changed) return;
    final models = _models[id];
    if (models != null) {
      for (final model in models) {
        model.updateChecked(selected);
      }
    }
    onCountChanged(selectedIds.length);
  }

  void clearSelection() {
    if (selectedIds.isEmpty) return;
    final selectedModels = [
      for (final entry in _models.entries)
        if (selectedIds.contains(entry.key)) ...entry.value,
    ];
    selectedIds.clear();
    for (final model in selectedModels) {
      model.updateChecked(false);
    }
    onCountChanged(0);
  }

  void dispose() {
    _models.clear();
    items.clear();
  }
}

class _SelectionModel {
  final item = ValueNotifier<_SelectionItem?>(null);
  final checked = ValueNotifier<bool>(false);
  bool receiving = false;

  void bind(_SelectionItem value, bool selected) {
    item.value = value;
    updateChecked(selected);
  }

  void updateChecked(bool selected) {
    // 业务回灌不能经复选框的双向绑定再次修改选择集合。
    receiving = true;
    try {
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
  _OfficialSelectionRow({super.key, required this.item, required this.records});
  final _SelectionItem item;
  final _SelectionRecords records;
  @override
  State<_OfficialSelectionRow> createState() => _OfficialSelectionRowState();
}

class _OfficialSelectionRowState extends State<_OfficialSelectionRow> {
  final _model = _SelectionModel();
  late final _row = _SelectionRow(_model, (id, checked) => widget.records.select(id, checked));
  @override
  void initState() {
    super.initState();
    widget.records.bind(_model, widget.item);
  }

  @override
  void didUpdateWidget(_OfficialSelectionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.records, widget.records)) oldWidget.records.unbind(_model);
    widget.records.bind(_model, widget.item);
  }

  @override
  void dispose() {
    widget.records.unbind(_model);
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
      builder: (context, checked, child) => ExamplePanel(
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
