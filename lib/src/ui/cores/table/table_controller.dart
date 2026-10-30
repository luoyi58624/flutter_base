// ignore_for_file: prefer_initializing_formals

part of 'table.dart';

/// 表格数据、列配置、扩展配置、运行状态与命令式 API 的唯一宿主。
class ElTableController extends ChangeNotifier {
  static const int _indexColumnMinChars = 1;

  /// 创建控制器；所有配置都可在创建后通过 setter 或 [update] 替换。
  ElTableController({
    String? id,
    bool cacheEnabled = false,
    Iterable<ElTableRow> data = const [],
    Iterable<ElTableColumn> columns = const [],
    String? rowKey,
    Map<Object, double> columnWidths = const {},
    Map<Object, double> rowHeights = const {},
    bool showHeader = true,
    ElTableEmptyBuilder? emptyBuilder,
    Iterable<Object> pinnedRowKeys = const [],
    ElTableSummaryCellBuilder? summaryBuilder,
    ElTableRowStyleBuilder? rowStyleBuilder,
    bool rowResizable = false,
    bool localSort = true,
    bool sortRequired = false,
  }) : _id = _normalizeTableId(id),
       _cacheEnabled = cacheEnabled,
       _data = _freezeData(data),
       _columns = _copyColumns(columns),
       _rowKey = rowKey,
       _columnWidths = _copyExtents(columnWidths, 'columnWidths'),
       _rowHeights = _copyExtents(rowHeights, 'rowHeights'),
       _showHeader = showHeader,
       _emptyBuilder = emptyBuilder,
       _pinnedRowKeys = Set<Object>.of(pinnedRowKeys),
       _summaryBuilder = summaryBuilder,
       _rowStyleBuilder = rowStyleBuilder,
       _rowResizable = rowResizable,
       _localSort = localSort,
       _sortRequired = sortRequired {
    _rowKeyReader = _rowKey == null ? null : _TablePathReader(_rowKey!);
    _validateRows(_data, rowKey: _rowKey, reader: _rowKeyReader);
    _rebuildColumnPlans();
    _restoreCachedConfiguration();
    _scheduleCacheReadyRestore();
  }

  String? _id;
  bool _cacheEnabled;
  int _cacheReadyGeneration = 0;
  List<ElTableRow> _data;
  List<ElTableColumn> _columns;
  String? _rowKey;
  Object? _sortColumnKey;
  bool? _sortAscending;
  final Set<Object> _selectedRowKeys = <Object>{};
  Object? _currentRowKey;
  final Set<Object> _expandedRowKeys = <Object>{};
  Map<Object, double> _columnWidths;
  Map<Object, double> _rowHeights;
  bool _showHeader;
  ElTableEmptyBuilder? _emptyBuilder;
  final Set<Object> _pinnedRowKeys;
  ElTableSummaryCellBuilder? _summaryBuilder;
  ElTableRowStyleBuilder? _rowStyleBuilder;
  bool _rowResizable;
  bool _localSort;
  bool _sortRequired;
  late _TablePathReader? _rowKeyReader;
  Map<Object, ElTableRow>? _rowsByKey;
  List<ElTableRow>? _selectedRowsCache;
  final Map<ElTableRowPredicate?, _TableSelectionAggregate> _selectionAggregates =
      HashMap<ElTableRowPredicate?, _TableSelectionAggregate>.identity();
  late List<ElTableColumn> _visibleColumns;
  late List<List<ElTableColumn>> _visibleColumnPaths;
  int _headerDepth = 1;
  late List<_TableColumnPlan> _visibleColumnPlans;
  late Map<ElTableColumn, _TableColumnPlan> _plansByColumn;
  int _columnRevision = 0;
  int _geometryRevision = 0;
  int _projectionRevision = 0;
  bool _hasAutoIndexWidth = false;
  _TableViewState? _view;

  /// 表格稳定身份；启用配置缓存后用它隔离不同表格的持久化状态。
  String? get id => _id;

  /// 动态替换表格身份；旧身份的缓存会先被清除，再尝试恢复新身份已有配置。
  set id(String? value) {
    final next = _normalizeTableId(value);
    if (_id == next) return;
    final previous = _id;
    if (previous != null) _TableCacheBackend.remove(_cacheStorageKey(previous));
    _id = next;
    _cacheReadyGeneration++;
    final restored = _cacheEnabled && next != null && _restoreCachedConfiguration();
    if (_cacheEnabled && next != null && !restored) _persistCachedConfiguration();
    _scheduleCacheReadyRestore();
    notifyListeners();
  }

  /// 是否把列显隐、排序、显示顺序与列宽持久化；修改开关会清除当前身份的旧缓存。
  bool get cacheEnabled => _cacheEnabled;

  /// 动态开启或关闭配置缓存；切换前先删除当前身份的旧快照。
  set cacheEnabled(bool value) {
    if (_cacheEnabled == value) return;
    final currentId = _id;
    if (currentId != null) _TableCacheBackend.remove(_cacheStorageKey(currentId));
    _cacheEnabled = value;
    _cacheReadyGeneration++;
    if (value && currentId != null) _persistCachedConfiguration();
    _scheduleCacheReadyRestore();
    notifyListeners();
  }

  /// 清除当前 [id] 对应的持久化配置，不改变正在使用的表格状态。
  void clearCachedConfiguration() {
    final currentId = _id;
    if (currentId == null) return;
    _TableCacheBackend.remove(_cacheStorageKey(currentId));
  }

  /// 当前数据的不可变视图；传入的 List 只包裹不复制，调用方应把它视为只读快照。
  List<ElTableRow> get data => _data;

  /// 替换完整数据，不隐式清除排序、选择与展开状态；List 只包裹不复制。
  set data(Iterable<ElTableRow> value) {
    final next = _freezeData(value);
    if (listEquals(_data, next)) return;
    _validateRows(next, rowKey: _rowKey, reader: _rowKeyReader);
    final currentKey = _currentRowKey;
    final previousFocusOrder = currentKey == null ? const <ElTableRow>[] : _focusOrderRows(_data);
    final previousIndex = currentKey == null ? -1 : previousFocusOrder.indexWhere((row) => rowKeyOf(row) == currentKey);
    _data = next;
    _rowsByKey = null;
    _selectedRowsCache = null;
    _selectionAggregates.clear();
    _projectionRevision++;
    _refreshIndexColumnWidth();
    var repairedCurrentRow = false;
    if (currentKey != null && !next.any((row) => rowKeyOf(row) == currentKey)) {
      final nextFocusOrder = _focusOrderRows(next);
      _currentRowKey = nextFocusOrder.isEmpty
          ? null
          : rowKeyOf(nextFocusOrder[previousIndex.clamp(0, nextFocusOrder.length - 1)]);
      repairedCurrentRow = true;
    }
    notifyListeners();
    if (repairedCurrentRow) _view?._scheduleCurrentRowReveal(_currentRowKey);
  }

  /// 生成与视图一致的键盘行顺序，供数据刷新时修复已经失效的当前行。
  List<ElTableRow> _focusOrderRows(Iterable<ElTableRow> rows) {
    final source = List<ElTableRow>.of(rows);
    if (_pinnedRowKeys.isEmpty) return sortedRows(source);
    final pinned = <ElTableRow>[];
    final body = <ElTableRow>[];
    for (final row in source) {
      (_pinnedRowKeys.contains(rowKeyOf(row)) ? pinned : body).add(row);
    }
    return <ElTableRow>[...pinned, ...sortedRows(body)];
  }

  /// 当前列配置的不可变视图，声明顺序就是表格解析顺序。
  List<ElTableColumn> get columns => _columns;

  /// 替换完整列配置，controller 会冻结子列与标签选项以避免外部可变列表串改。
  set columns(Iterable<ElTableColumn> value) {
    final next = _prepareColumns(value);
    if (listEquals(_columns, next)) return;
    _columns = next;
    _commitColumnConfiguration();
  }

  /// 当前可见叶子列快照，多级表头会展开为参与数据区域布局的列。
  List<ElTableColumn> get visibleColumns => _visibleColumns;

  /// 当前顶层列或分组的显示顺序；拖拽表头与缓存都使用这组稳定身份。
  List<Object> get columnOrderKeys => List<Object>.unmodifiable([
    for (var index = 0; index < _columns.length; index++) _topLevelColumnKeyOf(_columns[index], index),
  ]);

  /// 所有已声明列的显隐状态；稳定 key 优先使用列 key，其次使用 prop。
  Map<Object, bool> get columnVisibility {
    final result = <Object, bool>{};
    for (final entry in _declaredColumnEntries()) {
      result[entry.key] = entry.column.visible;
    }
    return Map<Object, bool>.unmodifiable(result);
  }

  /// 把顶层列、分组或分组内叶子列移动到目标下标；返回 false 表示身份不存在或顺序未改变。
  ///
  /// 顶层身份取 [columnOrderKeys]（表头拖拽就走这条路径）；分组内的列另有两种写法：
  /// 嵌套身份 `父身份/本级身份`（见 [_nestedColumnIdentity]）或它自己的声明 key，
  /// 此时 [targetIndex] 是它在**父分组 children** 中的目标下标。
  bool moveColumnTo(Object columnKey, int targetIndex) {
    final keys = columnOrderKeys;
    final sourceIndex = keys.indexOf(columnKey);
    if (sourceIndex >= 0) return _moveTopLevelColumn(sourceIndex, targetIndex);
    final path = _columnPathOf(columnKey);
    if (path == null) return false;
    if (path.length == 1) return _moveTopLevelColumn(path.single, targetIndex);
    final parentPath = path.sublist(0, path.length - 1);
    final siblings = _columnAt(_columns, parentPath)!.children;
    if (siblings.length < 2) return false;
    final resolvedTarget = targetIndex.clamp(0, siblings.length - 1);
    if (path.last == resolvedTarget) return false;
    final reordered = List<ElTableColumn>.of(siblings);
    reordered.insert(resolvedTarget, reordered.removeAt(path.last));
    _columns = _replaceColumnAt(
      _columns,
      parentPath,
      (column) => _copyColumn(column, children: List<ElTableColumn>.unmodifiable(reordered)),
    );
    _commitColumnConfiguration();
    return true;
  }

  /// 顶层列 / 分组互换显示下标；表头拖拽提交时走的就是这里。
  bool _moveTopLevelColumn(int sourceIndex, int targetIndex) {
    if (_columns.length < 2) return false;
    final resolvedTarget = targetIndex.clamp(0, _columns.length - 1);
    if (sourceIndex == resolvedTarget) return false;
    final next = List<ElTableColumn>.of(_columns);
    final column = next.removeAt(sourceIndex);
    next.insert(resolvedTarget, column);
    _columns = List<ElTableColumn>.unmodifiable(next);
    _commitColumnConfiguration();
    return true;
  }

  /// 按给定稳定身份重排列；未列出的声明列保持原相对顺序并追加到末尾。
  ///
  /// 顶层身份取 [columnOrderKeys]；分组内的列用嵌套身份 `父身份/本级身份` 或它自己的
  /// 声明 key，命中的列在**它所在分组内**按请求顺序排到前面（其余保持原相对顺序）。
  bool setColumnOrder(Iterable<Object> columnKeys) {
    final requested = <Object>[];
    for (final key in columnKeys) {
      if (!requested.contains(key)) requested.add(key);
    }
    final currentKeys = columnOrderKeys;
    final byKey = <Object, ElTableColumn>{
      for (var index = 0; index < _columns.length; index++) currentKeys[index]: _columns[index],
    };
    final next = <ElTableColumn>[];
    for (final key in requested) {
      final column = byKey.remove(key);
      if (column != null) next.add(column);
    }
    for (final key in currentKeys) {
      final column = byKey.remove(key);
      if (column != null) next.add(column);
    }
    final ordered = _applyNestedColumnOrder(next, requested);
    if (listEquals(ordered, _columns)) return false;
    _columns = List<ElTableColumn>.unmodifiable(ordered);
    _commitColumnConfiguration();
    return true;
  }

  /// 更新单列或整组列的可见性；返回 false 表示身份不存在或状态未改变。
  bool setColumnVisible(Object columnKey, bool visible) {
    var found = false;
    var changed = false;
    var leafIndex = 0;

    ElTableColumn visit(ElTableColumn column) {
      final index = leafIndex;
      if (column.children.isEmpty) leafIndex++;
      final children = <ElTableColumn>[for (final child in column.children) visit(child)];
      final key = _declaredColumnKeyOf(column, index);
      if (key == columnKey) {
        found = true;
        if (column.visible != visible) changed = true;
        return _copyColumn(column, visible: visible, children: children);
      }
      if (!listEquals(children, column.children)) changed = true;
      return _copyColumn(column, children: children);
    }

    final next = <ElTableColumn>[for (final column in _columns) visit(column)];
    if (!found || !changed) return false;
    _columns = List<ElTableColumn>.unmodifiable(next);
    _commitColumnConfiguration();
    return true;
  }

  /// 翻转单列或整组列的可见性；身份不存在时返回 false。
  bool toggleColumnVisible(Object columnKey) {
    final current = columnVisibility[columnKey];
    return current == null ? false : setColumnVisible(columnKey, !current);
  }

  /// 写入单列固定方向；null 表示取消固定，返回 false 表示身份不存在或状态未变。
  ///
  /// 固定方向只按**叶子列**分带（渲染层读的就是叶子列的 `fixed`），所以分组列的身份
  /// 不算固定列身份、返回 false；分组内的叶子列支持嵌套身份 `父身份/本级身份`
  /// 与它自己的声明 key，写法与 [moveColumnTo] 一致。
  bool setColumnFixed(Object columnKey, ElTableColumnFixed? fixed) {
    final path = _columnPathOf(columnKey);
    if (path == null) return false;
    final column = _columnAt(_columns, path)!;
    if (column.children.isNotEmpty || column.fixed == fixed) return false;
    _columns = _replaceColumnAt(_columns, path, (column) => _copyColumn(column, fixed: fixed, replaceFixed: true));
    _commitColumnConfiguration();
    return true;
  }

  /// 行键字段路径；null 时优先读取 Map 的 id 字段，否则使用行对象本身。
  String? get rowKey => _rowKey;

  /// 替换行键字段路径，选择、当前行、展开、行高和滚动定位都会改用新身份。
  set rowKey(String? value) {
    if (_rowKey == value) return;
    final reader = value == null ? null : _TablePathReader(value);
    _validateRows(_data, rowKey: value, reader: reader);
    _rowKey = value;
    _rowKeyReader = reader;
    _rowsByKey = null;
    _selectedRowsCache = null;
    _selectionAggregates.clear();
    _projectionRevision++;
    notifyListeners();
  }

  /// 当前排序状态；null 表示未排序。
  ElTableSort? get sortState => _sortColumnKey == null || _sortAscending == null
      ? null
      : ElTableSort(columnKey: _sortColumnKey!, ascending: _sortAscending!);

  /// 当前排序列身份；null 表示未排序。
  Object? get sortColumnKey => _sortColumnKey;

  /// 当前排序方向；true 为升序、false 为降序、null 表示未排序。
  bool? get sortAscending => _sortAscending;

  /// 是否必须保持排序；true 时排序不可清除，表头重复点击只在升序与降序之间切换。
  ///
  /// 只约束交互与命令，不在切换时改动当前排序状态；也不负责补一个排序（内核不知道按哪列、什么方向）。
  bool get sortRequired => _sortRequired;

  /// 更新「必须排序」开关。
  set sortRequired(bool value) {
    if (_sortRequired == value) return;
    _sortRequired = value;
    notifyListeners();
  }

  /// 当前选中行 key 的不可变快照。
  Set<Object> get selectedRowKeys => UnmodifiableSetView<Object>(_selectedRowKeys);

  /// 直接替换选中行 key。
  set selectedRowKeys(Iterable<Object> keys) => _replaceSelection(Set<Object>.of(keys));

  /// 当前选中行快照。
  List<ElTableRow> get selectedRows => _selectedRowsCache ??= List<ElTableRow>.unmodifiable([
    for (final row in _data)
      if (_selectedRowKeys.contains(rowKeyOf(row))) row,
  ]);

  /// 直接替换选中行。
  set selectedRows(Iterable<ElTableRow> rows) => _setSelectedRows(rows);

  /// 当前行 key；null 表示没有当前行。
  Object? get currentRowKey => _currentRowKey;

  /// 设置当前行 key，null 用于清除。
  set currentRowKey(Object? value) {
    if (_currentRowKey == value) return;
    _currentRowKey = value;
    notifyListeners();
  }

  /// 当前行；null 表示没有当前行。
  ElTableRow? get currentRow => _currentRowKey == null ? null : rowByKey(_currentRowKey!);

  /// 设置当前行，null 用于清除。
  set currentRow(ElTableRow? row) {
    currentRowKey = row == null ? null : rowKeyOf(row);
  }

  /// 当前展开行 key 的不可变快照。
  Set<Object> get expandedRowKeys => UnmodifiableSetView<Object>(_expandedRowKeys);

  /// 直接替换展开行 key。
  set expandedRowKeys(Iterable<Object> keys) => _replaceSet(_expandedRowKeys, Set<Object>.of(keys));

  /// 当前展开行快照。
  List<ElTableRow> get expandedRows => List<ElTableRow>.unmodifiable([
    for (final row in _data)
      if (_expandedRowKeys.contains(rowKeyOf(row))) row,
  ]);

  /// 直接替换展开行。
  set expandedRows(Iterable<ElTableRow> rows) => _setExpandedRows(rows);

  /// 普通列的宽度覆盖状态，key 通常来自 [columnKeyOf]；内置列忽略对应记录。
  Map<Object, double> get columnWidths => UnmodifiableMapView<Object, double>(_columnWidths);

  /// 替换完整列宽状态。
  set columnWidths(Map<Object, double> value) {
    final next = _copyExtents(value, 'columnWidths');
    if (mapEquals(_columnWidths, next)) return;
    _columnWidths = next;
    _geometryRevision++;
    _persistCachedConfiguration();
    notifyListeners();
  }

  /// 行高状态，key 通常来自 [rowKeyOf]。
  Map<Object, double> get rowHeights => UnmodifiableMapView<Object, double>(_rowHeights);

  /// 替换完整行高状态。
  set rowHeights(Map<Object, double> value) {
    final next = _copyExtents(value, 'rowHeights');
    if (mapEquals(_rowHeights, next)) return;
    _rowHeights = next;
    notifyListeners();
  }

  /// 是否渲染表头，包括多级分组表头。
  bool get showHeader => _showHeader;

  /// 更新表头可见性。
  set showHeader(bool value) {
    if (_showHeader == value) return;
    _showHeader = value;
    notifyListeners();
  }

  /// 无数据内容构建器；适合读取 context 或 controller 的动态空状态。
  /// 空态外观（底色 / 高度 / 对齐）由 `ElTableStyle.empty` 与 `emptyHeight` 决定。
  ElTableEmptyBuilder? get emptyBuilder => _emptyBuilder;

  /// 更新无数据内容构建器，允许显式设为 null 清空。
  set emptyBuilder(ElTableEmptyBuilder? value) {
    if (identical(_emptyBuilder, value)) return;
    _emptyBuilder = value;
    notifyListeners();
  }

  /// 固定在表头下方且不参与纵向滚动和本地排序的行键快照。
  Set<Object> get pinnedRowKeys => UnmodifiableSetView<Object>(_pinnedRowKeys);

  /// 替换全部固定行键。
  set pinnedRowKeys(Iterable<Object> value) {
    final next = Set<Object>.of(value);
    if (setEquals(_pinnedRowKeys, next)) return;
    _pinnedRowKeys
      ..clear()
      ..addAll(next);
    _projectionRevision++;
    notifyListeners();
  }

  /// 固定在表格底部的合计行构建器。
  ElTableSummaryCellBuilder? get summaryBuilder => _summaryBuilder;

  /// 更新合计行构建器，允许显式设为 null 移除合计行。
  set summaryBuilder(ElTableSummaryCellBuilder? value) {
    if (identical(_summaryBuilder, value)) return;
    _summaryBuilder = value;
    notifyListeners();
  }

  /// 按展示行叠加样式的构建器，可实现斑马纹、业务状态色等策略。
  ElTableRowStyleBuilder? get rowStyleBuilder => _rowStyleBuilder;

  /// 更新展示行样式构建器。
  set rowStyleBuilder(ElTableRowStyleBuilder? value) {
    if (identical(_rowStyleBuilder, value)) return;
    _rowStyleBuilder = value;
    notifyListeners();
  }

  /// 是否允许用户拖拽数据行底缘调整单行高度。
  bool get rowResizable => _rowResizable;

  /// 更新行高拖拽开关。
  set rowResizable(bool value) {
    if (_rowResizable == value) return;
    _rowResizable = value;
    notifyListeners();
  }

  /// 是否由底层根据 sortState 对数据执行本地排序；false 只保留排序状态和事件。
  bool get localSort => _localSort;

  /// 更新本地排序开关。
  set localSort(bool value) {
    if (_localSort == value) return;
    _localSort = value;
    _projectionRevision++;
    notifyListeners();
  }

  /// 一次性替换多项表格配置并只通知一次；rowKey 传 null 表示保持现状。
  void update({
    Iterable<ElTableRow>? data,
    Iterable<ElTableColumn>? columns,
    String? rowKey,
    Map<Object, double>? columnWidths,
    Map<Object, double>? rowHeights,
    bool? showHeader,
    ElTableEmptyBuilder? emptyBuilder,
    Iterable<Object>? pinnedRowKeys,
    ElTableSummaryCellBuilder? summaryBuilder,
    ElTableRowStyleBuilder? rowStyleBuilder,
    bool? rowResizable,
    bool? localSort,
    bool? sortRequired,
  }) {
    var changed = false;
    var rebuildColumns = false;
    final nextRowKey = rowKey ?? _rowKey;
    final nextData = data == null ? _data : _freezeData(data);
    final nextRowKeyReader = nextRowKey == null ? null : _TablePathReader(nextRowKey);
    if (data != null || rowKey != null) _validateRows(nextData, rowKey: nextRowKey, reader: nextRowKeyReader);

    if (data != null && !listEquals(_data, nextData)) {
      _data = nextData;
      _rowsByKey = null;
      _selectedRowsCache = null;
      _selectionAggregates.clear();
      _projectionRevision++;
      _refreshIndexColumnWidth();
      changed = true;
    }
    if (columns != null) {
      final next = _prepareColumns(columns);
      if (!listEquals(_columns, next)) {
        _columns = next;
        changed = true;
        rebuildColumns = true;
        _columnRevision++;
        _projectionRevision++;
      }
    }
    if (rowKey != null && _rowKey != rowKey) {
      _rowKey = rowKey;
      _rowKeyReader = nextRowKeyReader;
      _rowsByKey = null;
      _selectedRowsCache = null;
      _selectionAggregates.clear();
      _projectionRevision++;
      changed = true;
    }
    if (columnWidths != null) {
      final next = _copyExtents(columnWidths, 'columnWidths');
      if (!mapEquals(_columnWidths, next)) {
        _columnWidths = next;
        _geometryRevision++;
        changed = true;
      }
    }
    if (rowHeights != null) {
      final next = _copyExtents(rowHeights, 'rowHeights');
      if (!mapEquals(_rowHeights, next)) {
        _rowHeights = next;
        changed = true;
      }
    }
    if (showHeader != null && _showHeader != showHeader) {
      _showHeader = showHeader;
      changed = true;
    }
    if (emptyBuilder != null && !identical(_emptyBuilder, emptyBuilder)) {
      _emptyBuilder = emptyBuilder;
      changed = true;
    }
    if (pinnedRowKeys != null) {
      final next = Set<Object>.of(pinnedRowKeys);
      if (!setEquals(_pinnedRowKeys, next)) {
        _pinnedRowKeys
          ..clear()
          ..addAll(next);
        _projectionRevision++;
        changed = true;
      }
    }
    if (summaryBuilder != null && !identical(_summaryBuilder, summaryBuilder)) {
      _summaryBuilder = summaryBuilder;
      changed = true;
    }
    if (rowStyleBuilder != null && !identical(_rowStyleBuilder, rowStyleBuilder)) {
      _rowStyleBuilder = rowStyleBuilder;
      changed = true;
    }
    if (rowResizable != null && _rowResizable != rowResizable) {
      _rowResizable = rowResizable;
      changed = true;
    }
    if (localSort != null && _localSort != localSort) {
      _localSort = localSort;
      _projectionRevision++;
      changed = true;
    }
    if (sortRequired != null && _sortRequired != sortRequired) {
      _sortRequired = sortRequired;
      changed = true;
    }
    if (rebuildColumns) _rebuildColumnPlans();
    if (changed) {
      _persistCachedConfiguration();
      notifyListeners();
    }
  }

  /// 解析业务行的稳定身份。
  Object rowKeyOf(ElTableRow row) => _rowKeyOf(row, _rowKey, _rowKeyReader);

  /// 按稳定身份查找当前数据行。
  ElTableRow? rowByKey(Object key) => (_rowsByKey ??= _buildRowIndex())[key];

  /// 解析列的稳定身份；显式 key 优先，其次是字段，最后才用声明位置兜底。
  Object columnKeyOf(ElTableColumn column, int index) {
    final plan = _plansByColumn[column];
    if (plan != null && plan.index == index) return plan.key;
    return _columnKeyCandidate(column, index);
  }

  Object _columnKeyCandidate(ElTableColumn column, int index) {
    final key = column.key;
    if (key != null) return key;
    final field = column.prop;
    if (field != null && field.isNotEmpty) return field;
    final title = column.title;
    if (title != null) return Object.hash(column.type, title, index);
    return Object.hash(column.type, index);
  }

  /// 读取单元格原始值，按 prop 点路径读取。
  Object? valueOf(ElTableRow row, ElTableColumn column) {
    final plan = _plansByColumn[column];
    if (plan != null) return plan.valueOf(row);
    return _TableColumnPlan.compile(this, column, -1).valueOf(row);
  }

  /// 按当前 [sortState] 对任意数据快照执行与 [ElTable] 相同的稳定排序。
  ///
  /// 未开启 [localSort]、尚未排序或排序列不可见时保持输入顺序。分页等上层组件
  /// 应先调用本方法排序完整数据，再截取当前页，避免只排序可见页。
  List<ElTableRow> sortedRows(Iterable<ElTableRow> rows) {
    final source = List<ElTableRow>.of(rows, growable: false);
    final sort = localSort ? sortState : null;
    if (sort == null || source.length < 2) return List<ElTableRow>.unmodifiable(source);

    _TableColumnPlan? plan;
    for (final candidate in _visibleColumnPlans) {
      if (candidate.key == sort.columnKey) {
        plan = candidate;
        break;
      }
    }
    if (plan == null) return List<ElTableRow>.unmodifiable(source);

    final orders = _TableViewState._sortRows(source, plan);
    return List<ElTableRow>.unmodifiable(sort.ascending ? orders.ascending : orders.descending);
  }

  /// 解析列宽；仅普通列读取 width，内置列使用组件宽度，index 至少与复选框列等宽。
  double? columnWidthOf(ElTableColumn column) =>
      _plansByColumn[column]?.width ?? (column.type == null ? column.width : _builtInWidthOf(column, column.type!));

  /// 解析普通列最小宽度；内置列忽略 minWidth 并返回 null。
  double? columnMinWidthOf(ElTableColumn column) =>
      column.type == null ? _plansByColumn[column]?.minWidth ?? column.minWidth : null;

  /// 解析数据单元格对齐方式；内置列默认居中。
  TextAlign? columnAlignOf(ElTableColumn column) => _plansByColumn[column]?.align ?? column.align;

  /// 解析列是否允许拖拽调整宽度；内置列始终不允许。
  bool? columnResizableOf(ElTableColumn column) =>
      column.type == null ? _plansByColumn[column]?.resizable ?? column.resizable : false;

  /// index 行号列自动宽度里附加的单元格左右内边距；由视图层按生效皮肤同步。
  ///
  /// 列宽是**总宽**，行号还要被单元格自己的内边距吃掉两侧。只按内容宽给列，
  /// 数字就没地方待，会顶到相邻列上（行号列看起来"挤进"了下一列）。
  double _indexColumnHorizontalPadding = 0;

  /// 同步单元格横向内边距；它参与行号列宽，变了要重编译列计划。
  void _syncIndexColumnPadding(double value) {
    if (_indexColumnHorizontalPadding == value) return;
    _indexColumnHorizontalPadding = value;
    if (!_hasAutoIndexWidth) return;
    _rebuildColumnPlans();
    _geometryRevision++;
  }

  /// 序号列实测数字宽用的**生效文字样式**；由视图层按单元格级联产物同步。
  ///
  /// 不能拿 [InheritedText.initial] 硬测：那量的是引擎默认字体 + 初值字号下的
  /// 数字宽，而单元格渲染用的是级联生效的字体族与字号。两者不一致时（站点挂了
  /// 自定义字体、或字号档位不同于初值），预留宽度就会偏窄，末位序号被挤到第二行。
  _IndexTextEnvironment? _indexTextEnvironment;

  /// 同步序号列的完整文字环境；变化后重新编译列计划。
  void _syncIndexTextEnvironment(_IndexTextEnvironment value) {
    if (_indexTextEnvironment == value) return;
    _indexTextEnvironment = value;
    if (!_hasAutoIndexWidth) return;
    _rebuildColumnPlans();
    _geometryRevision++;
  }

  /// 内置列统一定宽，index 按内容和内边距扩展，忽略列声明的宽度配置。
  double _builtInWidthOf(ElTableColumn column, ElTableColumnType type) {
    if (type != ElTableColumnType.index) return _TableColumnPlan._builtInControlWidth;
    return _autoIndexColumnWidth(column);
  }

  /// 无生效样式可读时的兜底度量：el_ui 文本初值（初值字号 + 引擎默认字体族）。
  static TextStyle _fallbackIndexMeasureStyle() {
    final fontSize = InheritedText.initial.fontSize;
    return TextStyle(fontSize: fontSize);
  }

  /// 为渲染层创建表头上下文。
  ElTableHeaderCell headerCellOf(ElTableColumn column, int columnIndex) => ElTableHeaderCell(
    controller: this,
    column: column,
    columnKey: columnKeyOf(column, columnIndex),
    columnIndex: columnIndex,
  );

  /// 解析表头展示内容，列级 headerBuilder 优先于列类型与 title/label。
  Object? headerContentOf(BuildContext context, ElTableColumn column, int columnIndex) {
    final plan = _planFor(column, columnIndex);
    return plan.headerContentOf(context, this);
  }

  /// 为渲染层创建单元格上下文。
  ElTableCell cellOf(ElTableRow row, int rowIndex, ElTableColumn column, int columnIndex) =>
      _planFor(column, columnIndex).cellOf(this, row, rowKeyOf(row), rowIndex);

  /// 解析单元格展示内容，优先级为列 slotBuilder、列类型 cellBuilder、formatter、原始值。
  Object? cellContentOf(BuildContext context, ElTableRow row, int rowIndex, ElTableColumn column, int columnIndex) {
    final plan = _planFor(column, columnIndex);
    final cell = plan.cellOf(this, row, rowKeyOf(row), rowIndex);
    return plan.contentOf(context, cell);
  }

  /// 按指定列身份排序，默认升序；这里只记录状态，不内置业务查询。
  /// [sortRequired] 为 true 时仍可用（它只挡清除，不挡设置）。
  void sort(Object columnKey, {bool ascending = true}) {
    if (_sortColumnKey == columnKey && _sortAscending == ascending) return;
    _sortColumnKey = columnKey;
    _sortAscending = ascending;
    _projectionRevision++;
    _persistCachedConfiguration();
    notifyListeners();
  }

  /// 清除排序；[sortRequired] 为 true 时整个不生效（排序状态必须保留）。
  void clearSort() {
    if (_sortRequired) return;
    if (_sortColumnKey == null && _sortAscending == null) return;
    _sortColumnKey = null;
    _sortAscending = null;
    _projectionRevision++;
    _persistCachedConfiguration();
    notifyListeners();
  }

  /// 判断指定数据行是否已选择。
  bool isSelected(ElTableRow row) => _selectedRowKeys.contains(rowKeyOf(row));

  /// 判断指定数据行在指定选择列下是否可选；列未声明规则时默认可选。
  bool isSelectable(ElTableRow row, [ElTableColumn? column]) => column?.selectable?.call(row) ?? true;

  /// 统计当前数据在指定规则下的表头三态选择状态。
  ElTableSelectionState selectionState({ElTableRowPredicate? where}) {
    final aggregate = _selectionAggregate(where);
    if (aggregate.selectableCount == 0 || aggregate.selectedCount == 0) return ElTableSelectionState.none;
    if (aggregate.selectedCount == aggregate.selectableCount) return ElTableSelectionState.all;
    return ElTableSelectionState.partial;
  }

  /// 判断当前数据是否至少包含一行符合指定选择规则的数据。
  bool hasSelectableRows({ElTableRowPredicate? where}) => _selectionAggregate(where).selectableCount > 0;

  /// 选择指定行。
  void select(ElTableRow row) {
    if (_selectedRowKeys.add(rowKeyOf(row))) {
      _selectionChanged(row, 1);
      notifyListeners();
    }
  }

  /// 取消选择指定行。
  void unselect(ElTableRow row) {
    if (_selectedRowKeys.remove(rowKeyOf(row))) {
      _selectionChanged(row, -1);
      notifyListeners();
    }
  }

  /// 切换指定行的选择状态。
  void toggleSelection(ElTableRow row) {
    final key = rowKeyOf(row);
    final removed = _selectedRowKeys.remove(key);
    if (!removed) _selectedRowKeys.add(key);
    _selectionChanged(row, removed ? -1 : 1);
    notifyListeners();
  }

  /// 选择当前数据中符合条件的全部行。
  void selectAll({ElTableRowPredicate? where}) {
    final next = <Object>{..._selectedRowKeys};
    for (final row in _data) {
      if (where?.call(row) ?? true) next.add(rowKeyOf(row));
    }
    _replaceSelection(next);
  }

  /// 取消选择当前数据中符合条件的全部行；不传 where 时等价于清空选择。
  void unselectAll({ElTableRowPredicate? where}) {
    if (where == null) {
      clearSelection();
      return;
    }
    final next = <Object>{..._selectedRowKeys};
    for (final row in _data) {
      if (where(row)) next.remove(rowKeyOf(row));
    }
    _replaceSelection(next);
  }

  /// 按表头三态切换当前数据的全选：全选态则取消，否则选中全部可选行。
  void toggleAllSelection({ElTableRowPredicate? where}) {
    if (selectionState(where: where) == ElTableSelectionState.all) {
      unselectAll(where: where);
    } else {
      selectAll(where: where);
    }
  }

  /// 清除全部选择。
  void clearSelection() => _replaceSelection(const <Object>{});

  /// 展开指定数据行。
  void expand(ElTableRow row) {
    if (_expandedRowKeys.add(rowKeyOf(row))) notifyListeners();
  }

  /// 收起指定数据行。
  void collapse(ElTableRow row) {
    if (_expandedRowKeys.remove(rowKeyOf(row))) notifyListeners();
  }

  /// 切换指定数据行的展开状态。
  void toggleExpansion(ElTableRow row) {
    final key = rowKeyOf(row);
    if (!_expandedRowKeys.remove(key)) _expandedRowKeys.add(key);
    notifyListeners();
  }

  /// 判断指定数据行是否展开。
  bool isExpanded(ElTableRow row) => _expandedRowKeys.contains(rowKeyOf(row));

  /// 收起全部展开行。
  void collapseAll() => _replaceSet(_expandedRowKeys, const <Object>{});

  /// 设置列宽覆盖，key 通常来自 [columnKeyOf]；仅普通列在布局时读取。
  void setColumnWidth(Object columnKey, double width) {
    _validateExtent(width, 'width');
    if (_columnWidths[columnKey] == width) return;
    _columnWidths[columnKey] = width;
    _geometryRevision++;
    _persistCachedConfiguration();
    notifyListeners();
  }

  /// 清除单列宽度。
  void resetColumnWidth(Object columnKey) {
    if (_columnWidths.remove(columnKey) == null) return;
    _geometryRevision++;
    _persistCachedConfiguration();
    notifyListeners();
  }

  /// 清除全部列宽状态。
  void clearColumnWidths() {
    if (_columnWidths.isEmpty) return;
    _columnWidths.clear();
    _geometryRevision++;
    _persistCachedConfiguration();
    notifyListeners();
  }

  /// 设置单行高度，key 通常来自 [rowKeyOf]。
  void setRowHeight(Object rowKey, double height) {
    _validateExtent(height, 'height');
    if (_rowHeights[rowKey] == height) return;
    _rowHeights[rowKey] = height;
    notifyListeners();
  }

  /// 清除单行高度。
  void resetRowHeight(Object rowKey) {
    if (_rowHeights.remove(rowKey) == null) return;
    notifyListeners();
  }

  /// 清除全部行高状态。
  void clearRowHeights() {
    if (_rowHeights.isEmpty) return;
    _rowHeights.clear();
    notifyListeners();
  }

  void _commitColumnConfiguration() {
    _rebuildColumnPlans();
    _columnRevision++;
    _projectionRevision++;
    _persistCachedConfiguration();
    notifyListeners();
  }

  List<({ElTableColumn column, Object key, int topLevelIndex})> _declaredColumnEntries() {
    final result = <({ElTableColumn column, Object key, int topLevelIndex})>[];
    var leafIndex = 0;

    void visit(ElTableColumn column, int topLevelIndex) {
      final index = leafIndex;
      if (column.children.isEmpty) leafIndex++;
      result.add((column: column, key: _declaredColumnKeyOf(column, index), topLevelIndex: topLevelIndex));
      for (final child in column.children) {
        visit(child, topLevelIndex);
      }
    }

    for (var index = 0; index < _columns.length; index++) {
      visit(_columns[index], index);
    }
    return result;
  }

  Object _declaredColumnKeyOf(ElTableColumn column, int index) {
    final plan = _plansByColumn[column];
    if (plan != null) return plan.key;
    return _columnKeyCandidate(column, index);
  }

  Object _topLevelColumnKeyOf(ElTableColumn column, int index) {
    final explicit = column.key;
    if (explicit != null) return explicit;
    final field = column.prop;
    if (field != null && field.isNotEmpty) return field;
    return _tableColumnToken(column) ?? _columnKeyCandidate(column, index);
  }

  int _topLevelIndexOfColumnKey(Object columnKey) {
    final direct = columnOrderKeys.indexOf(columnKey);
    if (direct >= 0) return direct;
    for (final entry in _declaredColumnEntries()) {
      if (entry.key == columnKey) return entry.topLevelIndex;
    }
    return -1;
  }

  int _topLevelIndexOfColumn(ElTableColumn column) {
    for (final entry in _declaredColumnEntries()) {
      if (identical(entry.column, column)) return entry.topLevelIndex;
    }
    return -1;
  }

  /// 分组内列的嵌套身份：父身份 + 本级身份，层级之间用 `/` 连接。
  ///
  /// 本级身份与顶层身份同源（[ElTableColumn.key] → [ElTableColumn.prop] → 稳定 token →
  /// 声明位置兜底），所以 `info/age` 这种写法在 [moveColumnTo] / [setColumnOrder] /
  /// [setColumnFixed] 里都是有效身份；带显式 key / prop 的身份不随位置变化。
  String _nestedColumnIdentity(ElTableColumn column, int index, String? parentKey) {
    final own = '${_topLevelColumnKeyOf(column, index)}';
    return parentKey == null ? own : '$parentKey/$own';
  }

  /// 把列身份解析成「从根到该列的兄弟下标路径」；null 表示身份不存在。
  ///
  /// 解析顺序固定为 顶层 key → 声明 key → 分组内嵌套身份：
  ///  · 顶层 key 取 [columnOrderKeys] 的口径，保证原有顶层语义逐字不变；
  ///  · 声明 key 与 [setColumnVisible] / [columnKeyOf] 同源（含位置兜底）；
  ///  · 嵌套身份见 [_nestedColumnIdentity]。
  List<int>? _columnPathOf(Object columnKey, [List<ElTableColumn>? columns]) {
    final root = columns ?? _columns;
    for (var index = 0; index < root.length; index++) {
      if (_topLevelColumnKeyOf(root[index], index) == columnKey) return <int>[index];
    }
    final declared = _findColumnPath(
      root,
      (column, declaredIndex, nestedKey) => _declaredColumnKeyOf(column, declaredIndex) == columnKey,
    );
    if (declared != null) return declared;
    return _findColumnPath(root, (column, declaredIndex, nestedKey) => nestedKey == columnKey);
  }

  /// 先序深度优先查找第一个满足 [matches] 的列；`declaredIndex` 是声明序叶子下标
  /// （与 [_declaredColumnEntries] 同一口径），`nestedKey` 是 [_nestedColumnIdentity]。
  List<int>? _findColumnPath(
    List<ElTableColumn> columns,
    bool Function(ElTableColumn column, int declaredIndex, String nestedKey) matches,
  ) {
    var leafIndex = 0;

    List<int>? visit(List<ElTableColumn> siblings, List<int> parentPath, String? parentKey) {
      for (var index = 0; index < siblings.length; index++) {
        final column = siblings[index];
        final declaredIndex = leafIndex;
        final nestedKey = _nestedColumnIdentity(column, index, parentKey);
        if (column.children.isEmpty) leafIndex++;
        final path = List<int>.of(parentPath)..add(index);
        if (matches(column, declaredIndex, nestedKey)) return path;
        final found = visit(column.children, path, nestedKey);
        if (found != null) return found;
      }
      return null;
    }

    return visit(columns, const <int>[], null);
  }

  /// 路径上的列；路径越界时返回 null。
  static ElTableColumn? _columnAt(List<ElTableColumn> columns, List<int> path) {
    ElTableColumn? column;
    List<ElTableColumn> siblings = columns;
    for (final index in path) {
      if (index < 0 || index >= siblings.length) return null;
      column = siblings[index];
      siblings = column.children;
    }
    return column;
  }

  /// 用 [replace] 改写路径末端那一列，沿路重建祖先并冻结新增的 children；返回新的根列表。
  static List<ElTableColumn> _replaceColumnAt(
    List<ElTableColumn> columns,
    List<int> path,
    ElTableColumn Function(ElTableColumn column) replace,
  ) {
    var updated = replace(_columnAt(columns, path)!);
    for (var depth = path.length - 2; depth >= 0; depth--) {
      final parentPath = path.sublist(0, depth + 1);
      final parent = _columnAt(columns, parentPath)!;
      final children = List<ElTableColumn>.of(parent.children);
      children[path[depth + 1]] = updated;
      updated = _copyColumn(parent, children: List<ElTableColumn>.unmodifiable(children));
    }
    final roots = List<ElTableColumn>.of(columns);
    roots[path.first] = updated;
    return List<ElTableColumn>.unmodifiable(roots);
  }

  /// 分组内换序：请求里的分组内身份在它所在的那组 children 里排到最前，其余保持原相对顺序。
  ///
  /// 顶层身份已由 [setColumnOrder] 的顶层换序处理，这里只处理 `path.length >= 2` 的身份；
  /// 同一组收到的多个身份合到一次重排里，重排只替换该分组的 children、不改变任何列表长度，
  /// 因此先算好的路径全程有效（父路径按值比较，不能用 List 当 map key）。
  List<ElTableColumn> _applyNestedColumnOrder(List<ElTableColumn> columns, List<Object> requested) {
    final parents = <List<int>>[];
    final grouped = <List<int>>[];
    for (final key in requested) {
      if (columnOrderKeys.contains(key)) continue;
      final path = _columnPathOf(key, columns);
      if (path == null || path.length < 2) continue;
      final parent = path.sublist(0, path.length - 1);
      var slot = -1;
      for (var index = 0; index < parents.length; index++) {
        if (listEquals(parents[index], parent)) {
          slot = index;
          break;
        }
      }
      if (slot < 0) {
        parents.add(parent);
        grouped.add(<int>[]);
        slot = parents.length - 1;
      }
      if (!grouped[slot].contains(path.last)) grouped[slot].add(path.last);
    }
    var result = columns;
    for (var slot = 0; slot < parents.length; slot++) {
      final indices = grouped[slot];
      final siblings = _columnAt(result, parents[slot])!.children;
      final reordered = <ElTableColumn>[
        for (final index in indices)
          if (index < siblings.length) siblings[index],
        for (var index = 0; index < siblings.length; index++)
          if (!indices.contains(index)) siblings[index],
      ];
      result = _replaceColumnAt(
        result,
        parents[slot],
        (column) => _copyColumn(column, children: List<ElTableColumn>.unmodifiable(reordered)),
      );
    }
    return result;
  }

  ElTableColumnFixed? _columnFixedOfKey(Object columnKey) {
    for (final plan in _visibleColumnPlans) {
      if (plan.key == columnKey) return plan.column.fixed;
    }
    return null;
  }

  String _cacheStorageKey(String tableId) => '$_tableStoragePrefix$tableId';

  void _scheduleCacheReadyRestore() {
    final currentId = _id;
    if (!_cacheEnabled || currentId == null) return;
    final generation = ++_cacheReadyGeneration;
    unawaited(
      _TableCacheBackend.ensureStorage().then((_) {
        if (_cacheReadyGeneration != generation || !_cacheEnabled || _id != currentId) return;
        if (_restoreCachedConfiguration()) notifyListeners();
      }),
    );
  }

  bool _restoreCachedConfiguration() {
    final currentId = _id;
    if (!_cacheEnabled || currentId == null) return false;
    final state = _TableCachedState.tryParse(_TableCacheBackend.read(_cacheStorageKey(currentId)));
    if (state == null) return false;
    var changed = false;
    final nextColumns = _applyCachedColumns(_columns, state);
    if (!listEquals(_columns, nextColumns)) {
      _columns = nextColumns;
      _rebuildColumnPlans();
      _columnRevision++;
      _projectionRevision++;
      changed = true;
    }
    final maps = _persistentColumnMaps();
    final nextWidths = <Object, double>{};
    for (final entry in state.widths.entries) {
      final key = maps.tokenToKey[entry.key];
      if (key != null) nextWidths[key] = entry.value;
    }
    if (!mapEquals(_columnWidths, nextWidths)) {
      _columnWidths = nextWidths;
      _geometryRevision++;
      changed = true;
    }
    final nextSortKey = state.sortKey == null ? null : maps.tokenToKey[state.sortKey!];
    final nextSortAscending = nextSortKey == null ? null : state.sortAscending;
    // sortRequired 下缓存里没有排序（或列身份对不上）也不能清掉当前排序，保持「必须有排序」不变式。
    final applySort = nextSortKey != null || !_sortRequired;
    if (applySort && (_sortColumnKey != nextSortKey || _sortAscending != nextSortAscending)) {
      _sortColumnKey = nextSortKey;
      _sortAscending = nextSortAscending;
      _projectionRevision++;
      changed = true;
    }
    return changed;
  }

  List<ElTableColumn> _prepareColumns(Iterable<ElTableColumn> columns) {
    final copied = _copyColumns(columns);
    final currentId = _id;
    if (!_cacheEnabled || currentId == null) return copied;
    final state = _TableCachedState.tryParse(_TableCacheBackend.read(_cacheStorageKey(currentId)));
    return state == null ? copied : _applyCachedColumns(copied, state);
  }

  /// 把缓存负载应用到列树上：显隐与固定方向按列 token 逐列覆盖，顶层顺序按 token 重排。
  ///
  /// token 是缓存的列身份（[ElTableColumn.key] → prop → title），固定方向只按叶子列分带，
  /// 所以分组列不参与；缓存里没有该列记录时保留声明值——旧负载没有 `fixed` 字段时
  /// 就是这个分支，等价于「全部未固定」，不能当成缓存损坏。
  List<ElTableColumn> _applyCachedColumns(List<ElTableColumn> columns, _TableCachedState state) {
    ElTableColumn apply(ElTableColumn column) {
      final children = <ElTableColumn>[for (final child in column.children) apply(child)];
      final token = _tableColumnToken(column);
      final cachedFixed = column.children.isEmpty && token != null ? state.fixed[token] : null;
      return _copyColumn(
        column,
        visible: token == null ? column.visible : state.visibility[token] ?? column.visible,
        fixed: cachedFixed,
        replaceFixed: cachedFixed != null,
        children: List<ElTableColumn>.unmodifiable(children),
      );
    }

    final prepared = <ElTableColumn>[for (final column in columns) apply(column)];
    final byToken = <String, ElTableColumn>{};
    for (final column in prepared) {
      final token = _tableColumnToken(column);
      if (token != null) byToken.putIfAbsent(token, () => column);
    }
    final ordered = <ElTableColumn>[];
    for (final token in state.order) {
      final column = byToken.remove(token);
      if (column != null) ordered.add(column);
    }
    for (final column in prepared) {
      final token = _tableColumnToken(column);
      if (token == null || byToken.remove(token) != null) ordered.add(column);
    }
    return List<ElTableColumn>.unmodifiable(ordered);
  }

  ({Map<String, Object> tokenToKey, Map<Object, String> keyToToken}) _persistentColumnMaps() {
    final tokenToKey = <String, Object>{};
    final keyToToken = <Object, String>{};
    for (final entry in _declaredColumnEntries()) {
      if (entry.column.children.isNotEmpty) continue;
      final token = _tableColumnToken(entry.column);
      if (token == null || tokenToKey.containsKey(token)) continue;
      tokenToKey[token] = entry.key;
      keyToToken[entry.key] = token;
    }
    return (tokenToKey: tokenToKey, keyToToken: keyToToken);
  }

  void _persistCachedConfiguration() {
    final currentId = _id;
    if (!_cacheEnabled || currentId == null) return;
    final maps = _persistentColumnMaps();
    final order = <String>[];
    for (final column in _columns) {
      final token = _tableColumnToken(column);
      if (token != null && !order.contains(token)) order.add(token);
    }
    final visibility = <String, bool>{};
    for (final entry in _declaredColumnEntries()) {
      final token = _tableColumnToken(entry.column);
      if (token != null) visibility[token] = entry.column.visible;
    }
    final widths = <String, double>{};
    for (final entry in _columnWidths.entries) {
      final token = maps.keyToToken[entry.key];
      if (token != null) widths[token] = entry.value;
    }
    // 只存已固定的叶子列：固定方向按叶子列分带，没有记录即「未固定」。
    final fixed = <String, ElTableColumnFixed>{};
    for (final entry in _declaredColumnEntries()) {
      if (entry.column.children.isNotEmpty) continue;
      final token = _tableColumnToken(entry.column);
      final direction = entry.column.fixed;
      if (token != null && direction != null) fixed[token] = direction;
    }
    final sortToken = _sortColumnKey == null ? null : maps.keyToToken[_sortColumnKey];
    _TableCacheBackend.write(
      _cacheStorageKey(currentId),
      _TableCachedState(
        order: List<String>.unmodifiable(order),
        visibility: Map<String, bool>.unmodifiable(visibility),
        widths: Map<String, double>.unmodifiable(widths),
        fixed: Map<String, ElTableColumnFixed>.unmodifiable(fixed),
        sortKey: sortToken,
        sortAscending: sortToken == null ? null : _sortAscending,
      ).toMap(),
    );
  }

  /// 滚动到指定稳定行键；算法尚未挂载或行不存在时返回 false。
  Future<bool> scrollTo(Object rowKey) async => _view?._scrollToRow(rowKey) ?? false;

  _TableColumnPlan _planFor(ElTableColumn column, int columnIndex) {
    final plan = _plansByColumn[column];
    if (plan != null && plan.index == columnIndex) return plan;
    return _TableColumnPlan.compile(this, column, columnIndex);
  }

  void _rebuildColumnPlans() {
    final grouped = _hasVisibleColumnGroup(_columns);
    final paths = <List<ElTableColumn>>[];
    final List<ElTableColumn> leaves;
    if (grouped) {
      _collectVisibleColumnPaths(_columns, const [], paths);
      leaves = [for (final path in paths) path.last];
    } else {
      leaves = [
        for (final column in _columns)
          if (column.visible) column,
      ];
    }
    final columns = List<ElTableColumn>.unmodifiable(leaves);
    final plans = <_TableColumnPlan>[];
    final byColumn = HashMap<ElTableColumn, _TableColumnPlan>.identity();
    final usedKeys = <Object>{};
    var hasAutoIndexWidth = false;
    for (var index = 0; index < columns.length; index++) {
      final column = columns[index];
      final candidate = _columnKeyCandidate(column, index);
      Object key = candidate;
      if (!usedKeys.add(key)) {
        if (column.key != null) throw ArgumentError.value(column.key, 'columns', '显式列 key 必须唯一。');
        key = (candidate, index);
        while (!usedKeys.add(key)) {
          key = (key, index);
        }
      }
      final plan = _TableColumnPlan.compile(this, column, index, resolvedKey: key);
      plans.add(plan);
      byColumn[plan.column] = plan;
      if (plan.hasAutoIndexWidth) hasAutoIndexWidth = true;
    }
    _visibleColumns = columns;
    if (grouped) {
      _visibleColumnPaths = List<List<ElTableColumn>>.unmodifiable([
        for (final path in paths) List<ElTableColumn>.unmodifiable(path),
      ]);
      _headerDepth = paths.fold<int>(1, (depth, path) => math.max(depth, path.length));
    } else {
      _visibleColumnPaths = const [];
      _headerDepth = 1;
    }
    _visibleColumnPlans = List<_TableColumnPlan>.unmodifiable(plans);
    _plansByColumn = byColumn;
    _hasAutoIndexWidth = hasAutoIndexWidth;
  }

  /// 按各列起始值检查序号宽度，数据量位数不变也可能让末尾序号跨位。
  void _refreshIndexColumnWidth() {
    if (!_hasAutoIndexWidth ||
        !_visibleColumnPlans.any(
          (plan) => plan.hasAutoIndexWidth && plan.width != _autoIndexColumnWidth(plan.column),
        )) {
      return;
    }
    _rebuildColumnPlans();
    _geometryRevision++;
  }

  /// 按完整数据集和起始序号预留字符格，虚拟视口变化不参与计算。
  double _autoIndexColumnWidth(ElTableColumn column) {
    final start = column.index is int ? column.index as int : 1;
    final environment =
        _indexTextEnvironment ??
        (style: _fallbackIndexMeasureStyle(), scaler: TextScaler.noScaling, direction: TextDirection.ltr, locale: null);
    return RenderOrdinalGutter.measureWidth(
      totalRows: _data.length,
      firstNumber: start,
      minChars: _indexColumnMinChars,
      styles: <TextStyle>[environment.style],
      textDirection: environment.direction,
      textScaler: environment.scaler,
      padding: EdgeInsets.only(right: _indexColumnHorizontalPadding),
      locale: environment.locale,
    );
  }

  void _setSelectedRows(Iterable<ElTableRow> rows) {
    _replaceSelection({for (final row in rows) rowKeyOf(row)});
  }

  void _setExpandedRows(Iterable<ElTableRow> rows) {
    _replaceSet(_expandedRowKeys, {for (final row in rows) rowKeyOf(row)});
  }

  void _replaceSet(Set<Object> target, Set<Object> next) {
    if (setEquals(target, next)) return;
    target
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  void _replaceSelection(Set<Object> next) {
    if (setEquals(_selectedRowKeys, next)) return;
    _selectedRowKeys
      ..clear()
      ..addAll(next);
    _selectedRowsCache = null;
    _selectionAggregates.clear();
    notifyListeners();
  }

  _TableSelectionAggregate _selectionAggregate(ElTableRowPredicate? where) {
    final cached = _selectionAggregates[where];
    if (cached != null) return cached;
    var selectableCount = 0;
    var selectedCount = 0;
    for (final row in _data) {
      if (!(where?.call(row) ?? true)) continue;
      selectableCount++;
      if (_selectedRowKeys.contains(rowKeyOf(row))) selectedCount++;
    }
    final aggregate = _TableSelectionAggregate(selectableCount, selectedCount);
    _selectionAggregates[where] = aggregate;
    return aggregate;
  }

  void _selectionChanged(ElTableRow row, int delta) {
    _selectedRowsCache = null;
    for (final entry in _selectionAggregates.entries) {
      if (entry.key?.call(row) ?? true) entry.value.selectedCount += delta;
    }
  }

  void _attach(_TableViewState view) {
    if (_view != null && !identical(_view, view)) {
      throw FlutterError('一个 ElTableController 不能同时挂载到多个 ElTable。');
    }
    _view = view;
  }

  void _detach(_TableViewState view) {
    if (identical(_view, view)) _view = null;
  }

  @override
  void dispose() {
    assert(_view == null, 'ElTableController.dispose 前必须先从 ElTable 卸载。');
    _cacheReadyGeneration++;
    super.dispose();
  }

  static List<ElTableColumn> _copyColumns(Iterable<ElTableColumn> columns) =>
      List<ElTableColumn>.unmodifiable(columns.map(_copyColumn));

  static String? _normalizeTableId(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static List<ElTableRow> _freezeData(Iterable<ElTableRow> data) =>
      data is List<ElTableRow> ? UnmodifiableListView<ElTableRow>(data) : List<ElTableRow>.unmodifiable(data);

  /// 复制列配置：覆盖显隐、子列与固定方向，其余字段原样保留。
  ///
  /// [replaceFixed] 为 true 时用 [fixed] 覆盖固定方向（传 null 即取消固定），
  /// 为 false 时保留列上原有的固定方向——恢复缓存时靠它区分「缓存里有值」与「缓存没提」。
  static ElTableColumn _copyColumn(
    ElTableColumn column, {
    bool? visible,
    ElTableColumnFixed? fixed,
    bool replaceFixed = false,
    List<ElTableColumn>? children,
  }) => ElTableColumn(
    key: column.key,
    type: column.type,
    prop: column.prop,
    title: column.title,
    width: column.width,
    minWidth: column.minWidth,
    flex: column.flex,
    fixed: replaceFixed ? fixed : column.fixed,
    visible: visible ?? column.visible,
    sort: column.sort,
    initialSortAscending: column.initialSortAscending,
    sortField: column.sortField,
    showOverflow: column.showOverflow,
    align: column.align,
    indexTextAlign: column.indexTextAlign,
    headerAlign: column.headerAlign,
    cellStyleBuilder: column.cellStyleBuilder,
    headerStyle: column.headerStyle,
    headerBuilder: column.headerBuilder,
    resizable: column.resizable,
    selectable: column.selectable,
    expandable: column.expandable,
    index: column.index,
    slotBuilder: column.slotBuilder,
    formatter: column.formatter,
    sorter: column.sorter,
    tagOptions: column.tagOptions == null ? null : List<ElTableTagOption>.unmodifiable(column.tagOptions!),
    children: children ?? _copyColumns(column.children),
  );

  static void _collectVisibleColumnPaths(
    List<ElTableColumn> columns,
    List<ElTableColumn> ancestors,
    List<List<ElTableColumn>> result,
  ) {
    for (final column in columns) {
      if (!column.visible) continue;
      final path = <ElTableColumn>[...ancestors, column];
      if (column.children.isEmpty) {
        result.add(path);
      } else {
        _collectVisibleColumnPaths(column.children, path, result);
      }
    }
  }

  static bool _hasVisibleColumnGroup(List<ElTableColumn> columns) {
    for (final column in columns) {
      if (!column.visible) continue;
      if (column.children.isNotEmpty) return true;
    }
    return false;
  }

  static Map<Object, double> _copyExtents(Map<Object, double> extents, String name) {
    final next = <Object, double>{};
    for (final entry in extents.entries) {
      _validateExtent(entry.value, name);
      next[entry.key] = entry.value;
    }
    return next;
  }

  static void _validateExtent(double value, String name) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, name, '尺寸必须是有限正数。');
    }
  }

  static void _validateRows(List<ElTableRow> rows, {required String? rowKey, required _TablePathReader? reader}) {
    if (rows.isNotEmpty) _rowKeyOf(rows.first, rowKey, reader);
  }

  Map<Object, ElTableRow> _buildRowIndex() {
    final result = <Object, ElTableRow>{};
    for (final row in _data) {
      final key = rowKeyOf(row);
      if (result.containsKey(key)) throw ArgumentError.value(key, 'data', '行键必须唯一。');
      result[key] = row;
    }
    return result;
  }

  static Object _rowKeyOf(ElTableRow row, String? rowKey, _TablePathReader? reader) {
    if (reader != null) {
      final key = reader.read(row);
      if (key != null) return key;
      throw ArgumentError.value(rowKey, 'rowKey', '指定的行键字段在数据行中不存在或为 null。');
    }
    final id = row['id'];
    if (id != null) return id;
    return row;
  }

  /// 内置 checkbox 列的表头三态控件内容。
  static Object _checkboxHeaderOf(ElTableHeaderCell header) {
    final controller = header.controller;
    final selectable = header.column.selectable;
    final state = controller.selectionState(where: selectable);
    return ElTableSelectionControl(
      state: state,
      disabled: !controller.hasSelectableRows(where: selectable),
    );
  }

  /// 内置 checkbox 列的行选择控件内容。
  static Object _checkboxControlOf(ElTableCell cell) {
    final disabled = !cell.controller.isSelectable(cell.row, cell.column);
    return ElTableSelectionControl(
      state: cell.controller.isSelected(cell.row) ? ElTableSelectionState.all : ElTableSelectionState.none,
      disabled: disabled,
      row: cell.row,
      rowKey: cell.rowKey,
      rowIndex: cell.rowIndex,
    );
  }

  /// 内置 index 列的表头内容；未声明 title 时展示 `#`。
  static Object _indexHeaderOf(ElTableHeaderCell header) => header.column.title ?? '#';

  /// 内置 index 列的行号值：默认展示序号从 1 起，column.index 可给起始值或生成器。
  static Object? _indexValueOf(ElTableCell cell) {
    final index = cell.column.index;
    return switch (index) {
      ElTableIndexBuilder builder => builder(cell),
      int start => RenderOrdinalGutter.ordinalAt(cell.rowIndex, firstNumber: start),
      null => RenderOrdinalGutter.ordinalAt(cell.rowIndex),
      _ => index,
    };
  }

  /// 内置 expanded 列的展开控件内容。
  static Object _expansionControlOf(ElTableCell cell) {
    final expandable = cell.column.expandable?.call(cell.row) ?? true;
    return ElTableExpansionControl(
      expanded: cell.controller.isExpanded(cell.row),
      disabled: !expandable,
      row: cell.row,
      rowKey: cell.rowKey,
      rowIndex: cell.rowIndex,
    );
  }
}

class _TableSelectionAggregate {
  _TableSelectionAggregate(this.selectableCount, this.selectedCount);

  final int selectableCount;
  int selectedCount;
}

class _TablePathReader {
  _TablePathReader(String path)
    : _direct = path.isNotEmpty && !path.contains('.') ? path : null,
      _segments = path.isEmpty || !path.contains('.') ? null : List<String>.unmodifiable(path.split('.')),
      _empty = path.isEmpty;

  final String? _direct;
  final List<String>? _segments;
  final bool _empty;

  Object? read(Object? source) {
    if (_empty) return null;
    final direct = _direct;
    if (direct != null) return source is Map ? source[direct] : null;
    Object? current = source;
    for (final segment in _segments!) {
      if (current is! Map) return null;
      current = current[segment];
    }
    return current;
  }
}

class _TableColumnPlan {
  const _TableColumnPlan({
    required this.column,
    required this.index,
    required this.key,
    required this.directField,
    required this.nestedReader,
    required this.geometryColumn,
    required this.width,
    required this.minWidth,
    required this.flex,
    required this.align,
    required this.headerAlign,
    required this.headerStyle,
    required this.cellStyleBuilder,
    required this.resizable,
    required this.showOverflow,
    required this.headerBuilder,
    required this.sorter,
    required this.requiresContentContext,
    required this.requiresCellContext,
  });

  /// 内置 checkbox / expanded 控件的默认列宽（历史值，保持不变）。
  static const double _builtInControlWidth = 48;

  factory _TableColumnPlan.compile(
    ElTableController controller,
    ElTableColumn column,
    int index, {
    Object? resolvedKey,
  }) {
    final type = column.type;
    final builtIn = type != null;
    final field = column.prop;
    final directField = field != null && field.isNotEmpty && !field.contains('.') ? field : null;
    // 内置列的历史默认：居中、不可拖拽调宽；index 宽度由行号位数自适应。
    final align = column.align ?? (builtIn ? TextAlign.center : null);
    final width = builtIn ? controller._builtInWidthOf(column, type) : column.width;
    final minWidth = builtIn ? null : column.minWidth;
    final flex = builtIn ? null : column.flex;
    return _TableColumnPlan(
      column: column,
      index: index,
      key: resolvedKey ?? controller.columnKeyOf(column, index),
      directField: directField,
      nestedReader: field == null || directField != null ? null : _TablePathReader(field),
      geometryColumn: ElTableColumn(width: width, minWidth: minWidth, flex: flex),
      width: width,
      minWidth: minWidth,
      flex: flex,
      align: align,
      headerAlign: column.headerAlign ?? align,
      headerStyle: column.headerStyle,
      cellStyleBuilder: column.cellStyleBuilder,
      resizable: builtIn ? false : column.resizable,
      showOverflow: column.showOverflow,
      headerBuilder: column.headerBuilder,
      sorter: column.sorter,
      requiresContentContext:
          (!(type == ElTableColumnType.expanded) && column.slotBuilder != null) || builtIn || column.formatter != null,
      requiresCellContext:
          (!(type == ElTableColumnType.expanded) && column.slotBuilder != null) ||
          builtIn ||
          column.formatter != null ||
          column.cellStyleBuilder != null,
    );
  }

  final ElTableColumn column;
  final int index;
  final Object key;
  final String? directField;
  final _TablePathReader? nestedReader;
  final ElTableColumn geometryColumn;
  final double? width;
  final double? minWidth;
  final double? flex;
  final TextAlign? align;
  final TextAlign? headerAlign;
  final ElStyle? headerStyle;
  final ElTableCellStyleBuilder? cellStyleBuilder;
  final bool? resizable;
  final bool? showOverflow;
  final ElTableHeaderBuilder? headerBuilder;
  final Comparator<ElTableRow>? sorter;
  final bool requiresContentContext;
  final bool requiresCellContext;

  /// 当前列是否 index 行号列。
  bool get isIndex => column.type == ElTableColumnType.index;

  bool get isExpansion => column.type == ElTableColumnType.expanded;

  bool get hasExpansionSlot => isExpansion && column.slotBuilder != null;

  /// index 行号是纯值，可由行 render 直接托管；声明 slotBuilder 或非整数起始值时退回 element 路径。
  bool get canHostIndex => isIndex && column.slotBuilder == null && (column.index == null || column.index is int);

  /// index 列始终由底层按行号位数自适应。
  bool get hasAutoIndexWidth => isIndex;

  Object? valueOf(ElTableRow row) {
    final field = directField;
    return field == null ? nestedReader?.read(row) : row[field];
  }

  Object? hostedValueOf(ElTableController controller, ElTableRow row, int rowIndex) {
    if (!requiresContentContext) return valueOf(row);
    return null;
  }

  Object? headerContentOf(BuildContext context, ElTableController controller) {
    final builder = headerBuilder;
    if (builder != null) {
      return builder(
        context,
        ElTableHeaderCell(controller: controller, column: column, columnKey: key, columnIndex: index),
      );
    }
    final type = column.type;
    if (type == null) return column.title;
    final header = ElTableHeaderCell(controller: controller, column: column, columnKey: key, columnIndex: index);
    if (type == ElTableColumnType.checkbox) return ElTableController._checkboxHeaderOf(header);
    if (type == ElTableColumnType.index) return ElTableController._indexHeaderOf(header);
    return column.title;
  }

  ElTableCell cellOf(ElTableController controller, ElTableRow row, Object rowKey, int rowIndex) => ElTableCell(
    controller: controller,
    row: row,
    rowKey: rowKey,
    rowIndex: rowIndex,
    column: column,
    columnKey: key,
    columnIndex: index,
    value: valueOf(row),
  );

  Object? contentOf(BuildContext context, ElTableCell cell) {
    final slotBuilder = column.slotBuilder;
    if (slotBuilder != null && !isExpansion) return slotBuilder(context, cell);
    switch (column.type) {
      case ElTableColumnType.index:
        return ElTableController._indexValueOf(cell);
      case ElTableColumnType.checkbox:
        return ElTableController._checkboxControlOf(cell);
      case ElTableColumnType.expanded:
        return ElTableController._expansionControlOf(cell);
      case null:
        break;
    }
    final formatter = column.formatter;
    return formatter == null ? cell.value : formatter(cell.value, cell);
  }

  ElStyle? styleOf(ElTableCell cell) => cellStyleBuilder?.call(cell);

  Object? expandedContentOf(BuildContext context, ElTableCell cell) => column.slotBuilder?.call(context, cell);
}
