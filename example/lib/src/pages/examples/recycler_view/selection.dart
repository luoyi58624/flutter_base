import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/recycler_view.dart' as rv;

import '../../example_page.dart';

/// 用一万条独立记录演示回收复用与数据驱动的复选状态。
class RecyclerSelectionPage extends StatefulWidget {
  /// 创建万条复选列表示例。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerSelectionPage({super.key});

  @override
  State<RecyclerSelectionPage> createState() => _RecyclerSelectionPageState();
}

class _RecyclerSelectionPageState extends State<RecyclerSelectionPage> {
  final _selectedCount = ValueNotifier<int>(0);
  final _indexInput = TextEditingController(text: '5000');
  late final _adapter = _SelectionAdapter((count) => _selectedCount.value = count);
  late final _list = rv.RecyclerView(key: ValueKey('recycler-selection-list'))
    ..setLayoutManager(rv.LinearLayoutManager())
    ..setHasFixedSize(true)
    ..setAdapter(_adapter);

  void _locate() {
    final index = int.tryParse(_indexInput.text.trim());
    if (index == null) return;
    _list.scrollToPosition((index - 1).clamp(0, _adapter.getItemCount() - 1));
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _selectedCount.dispose();
    _indexInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExamplePage(
    title: '万条复选列表',
    child: SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          ElCardView(
            style: ElStyle(padding: .all(12), margin: .all(12), borderRadius: .circular(12)),
            child: Column(
              crossAxisAlignment: .start,
              spacing: 10,
              children: [
                Text('10,000 条不同记录，复选状态跟随数据 ID，离屏复用后仍然保持。'),
                ValueListenableBuilder<int>(
                  valueListenable: _selectedCount,
                  builder: (context, count, child) => Text('已选 $count / 10000', key: ValueKey('selection-count')),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: .center,
                  children: [
                    ElButton(key: ValueKey('selection-first'), onPressed: () => _list.scrollToPosition(0), child: '首项'),
                    ElButton(
                      key: ValueKey('selection-last'),
                      onPressed: () => _list.scrollToPosition(_adapter.getItemCount() - 1),
                      child: '末项',
                    ),
                    ElButton(key: ValueKey('selection-clear'), onPressed: _adapter.clearSelection, child: '清空'),
                    SizedBox(
                      width: 112,
                      child: TextField(
                        key: ValueKey('selection-index-input'),
                        controller: _indexInput,
                        keyboardType: .number,
                        decoration: InputDecoration(labelText: '第几项', isDense: true, border: OutlineInputBorder()),
                        onSubmitted: (_) => _locate(),
                      ),
                    ),
                    ElButton(key: ValueKey('selection-locate'), onPressed: _locate, child: '定位'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _list),
        ],
      ),
    ),
  );
}

class _SelectionItem {
  _SelectionItem(this.id)
    : title = '条目 ${(id + 1).toString().padLeft(5, '0')}',
      description = '记录 ${id + 1} · 分组 ${id % 37 + 1} · 独立业务编号 RV-${100000 + id}';

  final int id;
  final String title;
  final String description;
}

typedef _SelectionBinding = ({_SelectionItem item, bool checked});

class _SelectionAdapter extends rv.Adapter<_SelectionHolder> {
  _SelectionAdapter(this.onCountChanged) {
    setHasStableIds(true);
  }

  final ValueChanged<int> onCountChanged;
  final _items = List.generate(10000, _SelectionItem.new);
  // 状态归业务 ID，holder 只显示本次绑定的快照，不能保存某一行的勾选状态。
  final _selectedIds = <int>{};

  @override
  int getItemCount() => _items.length;

  @override
  int getItemId(int position) => _items[position].id;

  @override
  _SelectionHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) => _SelectionHolder(_select);

  @override
  void onBindViewHolder(_SelectionHolder holder, int position, [List<Object> payloads = const []]) {
    final item = _items[position];
    holder.binding.value = (item: item, checked: _selectedIds.contains(item.id));
  }

  void _select(int id, bool selected) {
    final changed = selected ? _selectedIds.add(id) : _selectedIds.remove(id);
    if (!changed) return;
    notifyItemChanged(id, 'selection');
    onCountChanged(_selectedIds.length);
  }

  void clearSelection() {
    final changed = _selectedIds.toList(growable: false);
    _selectedIds.clear();
    for (final id in changed) {
      notifyItemChanged(id, 'selection');
    }
    onCountChanged(0);
  }
}

class _SelectionHolder extends rv.ViewHolder {
  _SelectionHolder(void Function(int, bool) onSelect) : this._(ValueNotifier<_SelectionBinding?>(null), onSelect);

  _SelectionHolder._(this.binding, void Function(int, bool) onSelect)
    : super(
        ValueListenableBuilder<_SelectionBinding?>(
          valueListenable: binding,
          builder: (context, data, child) {
            if (data == null) return SizedBox.shrink();
            final colors = Theme.of(context).colorScheme;
            return ElCardView(
              key: ValueKey('selection-row-${data.item.id}'),
              style: ElStyle(
                height: 88,
                padding: .symmetric(horizontal: 16, vertical: 10),
                backgroundColor: data.checked ? colors.primary.withValues(alpha: .06) : colors.surface,
                border: .only(borderBottom: .new(borderColor: colors.outlineVariant.withValues(alpha: .5))),
              ),
              child: Row(
                spacing: 14,
                children: [
                  Semantics(
                    label: '选择${data.item.title}',
                    child: ElCheckbox.toggle(
                      key: ValueKey('selection-check-${data.item.id}'),
                      value: data.checked,
                      onChanged: (checked) => onSelect(data.item.id, checked),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      mainAxisAlignment: .center,
                      spacing: 4,
                      children: [
                        Text(data.item.title, style: TextStyle(fontWeight: .w600)),
                        Text(
                          data.item.description,
                          maxLines: 1,
                          overflow: .ellipsis,
                          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

  final ValueNotifier<_SelectionBinding?> binding;
}
