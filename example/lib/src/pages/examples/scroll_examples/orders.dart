import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../example_page.dart';
import 'comparison_list.dart';
import 'scroll_mode.dart';
import '../../../widgets/panel.dart';

/// 用万条订单对比滚动中的批量状态更新、结构变动和多选状态。
class RecyclerOrdersPage extends StatefulWidget {
  /// 创建订单管理台对照页。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerOrdersPage({super.key});

  @override
  State<RecyclerOrdersPage> createState() => _RecyclerOrdersPageState();
}

class _RecyclerOrdersPageState extends State<RecyclerOrdersPage> {
  final _controller = ScrollController(keepScrollOffset: false);

  final _adapter = _OrderRecords();
  final _rounds = ValueNotifier<int>(0);
  SliverExampleMode _mode = .recycler;
  Timer? _updates;
  int _anchorGeneration = 0;
  double _extent = 128;

  ScrollController get _currentController => _controller;

  void _changeMode(SliverExampleMode mode) {
    if (_mode == mode) return;
    _anchorGeneration++;
    setState(() => _mode = mode);
    if (_controller.hasClients) _controller.jumpTo(0);
  }

  void _advance() {
    final count = _adapter.getItemCount();
    if (count == 0) return;
    final offset = _currentController.hasClients ? _currentController.offset : 0.0;
    final start = (offset / _extent).floor().clamp(0, math.max(0, count - _orderBatchSize)).toInt();
    _adapter.advance(start);
    _rounds.value++;
  }

  void _toggleUpdates() {
    if (_updates != null) {
      _stopUpdates();
      return;
    }
    setState(() {
      _updates = Timer.periodic(Duration(milliseconds: 250), (timer) {
        _advance();
        if (timer.tick >= 32) _stopUpdates();
      });
    });
  }

  void _stopUpdates() {
    _updates?.cancel();
    setState(() => _updates = null);
  }

  void _changeHead({required bool insert}) {
    final controller = _currentController;
    final pixels = controller.hasClients ? controller.offset : 0.0;
    final previousCount = _adapter.getItemCount();
    final first = previousCount == 0 ? 0 : (pixels / _extent).floor().clamp(0, previousCount - 1);
    final anchor = first < previousCount ? _adapter.getItemId(first) : null;
    final extent = _extent;
    final generation = ++_anchorGeneration;
    setState(insert ? _adapter.insertHead : _adapter.removeHead);

    if (anchor != null && pixels > .01) {
      // 等结构提交后按稳定订单补偿官方与 El 的像素偏移，使用等高行避免额外测量。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _anchorGeneration || !controller.hasClients) return;
        final index = _adapter.indexOf(anchor);
        final position = controller.position;
        final expected = index < 0 ? 0.0 : pixels + (index - first) * extent;
        final target = expected.clamp(position.minScrollExtent, position.maxScrollExtent);
        if ((position.pixels - target).abs() > .01) controller.jumpTo(target);
      });
    }
  }

  @override
  void dispose() {
    _updates?.cancel();
    _controller.dispose();

    _adapter.disposeRecords();
    _rounds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _extent = _orderExtent(context);
    final count = _adapter.getItemCount();
    return ExamplePage(
      title: '订单管理台',
      actions: [SliverComparisonModeMenu(mode: _mode, onChanged: _changeMode)],
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                Padding(
                  padding: .fromLTRB(12, 8, 12, 10),
                  child: ExamplePanel(
                    style: ElStyle(
                      padding: .all(10),
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: .circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: .start,
                      spacing: 4,
                      children: [
                        ListenableBuilder(
                          listenable: Listenable.merge([_adapter.selectedCount, _rounds]),
                          builder: (context, child) => Text(
                            '共 $count 单 · 已选 ${_adapter.selectedCount.value} 单 · 已更新 ${_rounds.value} 批',
                            key: ValueKey('orders-summary'),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            FilledButton.tonal(
                              key: ValueKey('orders-live'),
                              onPressed: _toggleUpdates,
                              child: Text(_updates == null ? '实时更新 8 秒' : '停止更新'),
                            ),
                            TextButton(
                              key: ValueKey('orders-update'),
                              onPressed: count == 0 ? null : _advance,
                              child: Text('推进 24 单'),
                            ),
                            TextButton(
                              key: ValueKey('orders-insert'),
                              onPressed: () => _changeHead(insert: true),
                              child: Text('顶部插入'),
                            ),
                            TextButton(
                              key: ValueKey('orders-remove'),
                              onPressed: count == 0 ? null : () => _changeHead(insert: false),
                              child: Text('移除前 24 单'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SliverComparisonList(
                    mode: _mode,
                    controller: _controller,

                    itemCount: count,

                    findChildIndexCallback: _adapter.indexForKey,
                    itemBuilder: (context, index) {
                      final record = _adapter.recordAt(index);
                      return _OrderRow(key: ValueKey(record.id), record: record, onSelect: _adapter.select);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _orderBatchSize = 24;
const _orderDestinations = ['青棠路 · 前台', '北岸创意园 · A 座', '松林里 · 驿站', '晴川广场 · 2 层'];

double _orderExtent(BuildContext context) => 128 + math.max(0.0, MediaQuery.textScalerOf(context).scale(14) - 14) * 6;

class _OrderRecords {
  final _ids = List.generate(10000, (index) => 10000 - index);
  final _records = <int, _OrderRecord>{};
  final selectedCount = ValueNotifier<int>(0);
  int _latestId = 10000;

  int getItemCount() => _ids.length;

  int getItemId(int position) => _ids[position];

  int indexOf(int id) {
    var low = 0;
    var high = _ids.length - 1;
    while (low <= high) {
      final middle = (low + high) ~/ 2;
      final current = _ids[middle];
      if (current == id) return middle;
      if (current > id) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return -1;
  }

  int? indexForKey(Key key) {
    final index = key is ValueKey<int> ? indexOf(key.value) : -1;
    return index < 0 ? null : index;
  }

  _OrderRecord recordAt(int index) {
    final id = _ids[index];
    return _records.putIfAbsent(id, () => _OrderRecord(id));
  }

  void select(_OrderRecord record, bool selected) {
    if (!identical(_records[record.id], record) || record.selected.value == selected) return;
    record.selected.value = selected;
    selectedCount.value += selected ? 1 : -1;
  }

  void advance(int first) {
    final limit = math.min(first + _orderBatchSize, _ids.length);
    for (var index = first; index < limit; index++) {
      final record = recordAt(index);
      record.progress.value = (record.progress.value + 11) % 101;
    }
  }

  void insertHead() {
    _latestId += _orderBatchSize;
    _ids.insertAll(0, List.generate(_orderBatchSize, (index) => _latestId - index));
  }

  void removeHead() {
    final count = math.min(_orderBatchSize, _ids.length);
    var removedSelected = 0;
    for (var index = 0; index < count; index++) {
      final record = _records.remove(_ids[index]);
      if (record?.selected.value == true) removedSelected++;
    }
    _ids.removeRange(0, count);
    selectedCount.value -= removedSelected;
  }

  void disposeRecords() {
    for (final record in _records.values) {
      record.selected.dispose();
      record.progress.dispose();
    }
    selectedCount.dispose();
  }
}

class _OrderRecord {
  _OrderRecord(this.id) : progress = ValueNotifier((id * 7) % 101);

  final int id;
  final ValueNotifier<int> progress;
  final selected = ValueNotifier(false);

  String get title => '订单 #$id';
  String get destination => _orderDestinations[id % _orderDestinations.length];
  String get amount => '¥${38 + id % 218}.${id % 10}0';
  String get details => '${2 + id % 8} 件 · ${id.isEven ? '同城配送' : '到店自取'} · $destination';
}

class _OrderRow extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _OrderRow({super.key, required this.record, required this.onSelect});

  final _OrderRecord record;
  final void Function(_OrderRecord, bool) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      height: _orderExtent(context),
      child: Padding(
        padding: .fromLTRB(12, 3, 12, 5),
        child: ExamplePanel(
          key: ValueKey('orders-card'),
          style: ElStyle(
            padding: .fromLTRB(9, 8, 11, 8),
            backgroundColor: colors.surfaceContainerLow,
            borderRadius: .circular(13),
          ),
          child: Column(
            crossAxisAlignment: .stretch,
            mainAxisAlignment: .spaceEvenly,
            children: [
              Row(
                spacing: 6,
                children: [
                  ValueListenableBuilder(
                    valueListenable: record.selected,
                    builder: (context, checked, child) => Semantics(
                      label: '选择${record.title}',
                      child: Checkbox(
                        key: ValueKey('orders-select'),
                        value: checked,
                        onChanged: (checked) => onSelect(record, checked ?? false),
                        visualDensity: .compact,
                        materialTapTargetSize: .shrinkWrap,
                      ),
                    ),
                  ),
                  Icon(record.id.isEven ? Icons.local_shipping_outlined : Icons.storefront_outlined, size: 19),
                  Expanded(
                    child: Text(record.title, maxLines: 1, overflow: .ellipsis, style: theme.textTheme.titleSmall),
                  ),
                  Text(record.amount, style: theme.textTheme.labelLarge?.copyWith(color: colors.primary)),
                ],
              ),
              Padding(
                padding: .symmetric(horizontal: 6),
                child: Text(
                  record.details,
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
              Padding(
                padding: .symmetric(horizontal: 6),
                child: ValueListenableBuilder(
                  valueListenable: record.progress,
                  builder: (context, progress, child) => Row(
                    spacing: 9,
                    children: [
                      Text(
                        progress == 100 ? '已完成' : (progress == 0 ? '待处理' : '处理中'),
                        style: theme.textTheme.labelSmall?.copyWith(color: colors.primary),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          borderRadius: .circular(4),
                          semanticsLabel: '订单进度',
                        ),
                      ),
                      Text('$progress%', style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
