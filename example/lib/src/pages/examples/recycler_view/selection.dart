import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/recycler_view.dart' as rv;

import '../../example_page.dart';
import 'scroll_mode.dart';
import '../../../widgets/example_scrollbar.dart';
import '../../../widgets/plain_scroll.dart';

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
  // El 在布局期读取唯一 position，不能与切换当帧尚待卸载的官方宿主共用。
  final _elController = ScrollController(keepScrollOffset: false);
  ScrollController get _currentController => _mode == .elScrollView || _mode == .plain ? _elController : _official;
  RecyclerExampleScrollMode _mode = .recyclerView;
  var _listRevision = 0;
  final _plain = ExamplePlainHandle();
  late final _adapter = _SelectionAdapter(_selectionChanged);
  late final _list = rv.RecyclerView(key: ValueKey('recycler-selection-list'), controller: _official)
    ..setLayoutManager(rv.LinearLayoutManager())
    ..setHasFixedSize(true)
    ..setAdapter(_adapter);

  void _selectionChanged(int count) {
    _selectedCount.value = count;
    if (_mode != .recyclerView) setState(() => _listRevision++);
  }

  void _scrollTo(int index) {
    if (_mode == .recyclerView) {
      _list.scrollToPosition(index);
    } else if (_mode == .plain) {
      _plain.ensure(index);
    } else if (_currentController.hasClients) {
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
    if (option case final RecyclerExampleScrollMode mode) {
      if (_mode == mode) return;
      setState(() => _mode = mode);
      // 各容器从同一首项开始比较；数据和选择集合不随容器替换。
      _list.scrollToPosition(0);
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
    _selectedCount.dispose();
    _indexInput.dispose();
    _official.dispose();
    _elController.dispose();
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

  Widget _scrollContent() {
    if (_mode == .plain) {
      return ExamplePlainScroll(
        key: ValueKey('selection-plain-list'),
        controller: _elController,
        maxCount: _adapter.getItemCount(),
        revision: _listRevision,
        handle: _plain,
        scrollbar: RecyclerExampleIosScrollbar(),
        itemBuilder: _row,
      );
    }
    if (_mode == .elScrollView) {
      return ElScrollView(
        key: ValueKey('el-selection-list'),
        controller: _elController,
        scrollbar: RecyclerExampleIosScrollbar(),
        children: [
          ElListView.builder(
            fixedSize: true,
            keepAlive: false,
            itemCount: _adapter.getItemCount(),
            itemBuilder: (context, index) => _row(context, index),
          ),
        ],
      );
    }
    if (_mode == .recyclerView2) {
      return RecyclerExampleScrollbar(
        controller: _official,
        child: ElRecyclerView2(
          key: ValueKey('recycler2-selection-list'),
          controller: _official,
          itemCount: _adapter.getItemCount(),
          itemBuilder: _row,
        ),
      );
    }
    return RecyclerExampleScrollbar(
      controller: _official,
      child: _mode == .recyclerView
          ? _list
          : ListView.builder(
              key: ValueKey('official-selection-list'),
              controller: _official,
              itemExtent: _selectionExtent,
              itemCount: _adapter.getItemCount(),
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
              itemBuilder: _row,
            ),
    );
  }

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
          for (final mode in RecyclerExampleScrollMode.values)
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

class _SelectionAdapter extends rv.Adapter<_SelectionHolder> {
  _SelectionAdapter(this.onCountChanged) {
    setHasStableIds(true);
  }

  final ValueChanged<int> onCountChanged;
  final items = List.generate(10000, _SelectionItem.new);
  // 状态归业务 ID，holder 的叶子模型只保存当前记录的显示快照。
  final selectedIds = <int>{};

  @override
  int getItemCount() => items.length;
  @override
  int getItemId(int position) => items[position].id;
  @override
  _SelectionHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) => _SelectionHolder(select);
  @override
  void onBindViewHolder(_SelectionHolder holder, int position, [List<Object> payloads = const []]) {
    final item = items[position];
    holder.model.bind(item, selectedIds.contains(item.id));
  }

  void select(int id, bool selected) {
    final changed = selected ? selectedIds.add(id) : selectedIds.remove(id);
    if (!changed) return;
    notifyItemChanged(id, 'selection');
    onCountChanged(selectedIds.length);
  }

  void clearSelection() {
    final changed = selectedIds.toList(growable: false);
    selectedIds.clear();
    for (final id in changed) {
      notifyItemChanged(id, 'selection');
    }
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

class _SelectionHolder extends rv.ViewHolder {
  _SelectionHolder(void Function(int, bool) onSelect) : this._(_SelectionModel(), onSelect);
  _SelectionHolder._(this.model, void Function(int, bool) onSelect) : super(_SelectionRow(model, onSelect));
  final _SelectionModel model;
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
