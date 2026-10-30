// ignore_for_file: prefer_initializing_formals

part of 'table.dart';

/// 底层表格，负责把 controller 状态投影成可滚动、可交互的网格。
///
/// 滚动窗口与用户交互事件全部平铺在本构造上（对齐 `ElEditableView` 的命名参数形态）；
/// 内部再把它们合成包内的 viewport / event 对象，不对外承诺这两个类型。
///
/// 外观解析顺序：显式 [style] → `ElComponentProvider` 里登记的 `tableStyleBuilder` 工厂 →
/// 默认皮肤（`const ElTableStyle()`）。品牌差异只走这一条样式注入通道，
/// 上层不提供任何表格实现（渲染 / 布局 / 命中 / 排序 / 选择 / 展开全在本类内）。
class ElTable extends StatefulWidget {
  /// 创建表格。
  const ElTable({
    super.key,
    required this.controller,
    this.style = const ElTableStyle(),
    this.focusNode,
    this.semanticLabel,
    this.headerCellBuilder,
    this.columnReorderable = false,
    this.height,
    this.onSort,
    this.onClearSort,
    this.onSelectionChanged,
    this.onCurrentChanged,
    this.onExpansionChanged,
    this.onRowTap,
    this.onRowDoubleTap,
    this.onRowSecondaryTap,
    this.onCellTap,
    this.onColumnOrderChanged,
    this.onColumnWidthsChanged,
    this.onRowHeightsChanged,
  }) : assert(height == null || height > 0, 'height 必须是正数。');

  /// 数据、列配置、运行状态与命令 API。
  final ElTableController controller;

  /// 表格皮肤；不传时优先取 `ElComponentProvider` 登记的 `tableStyleBuilder`，再回落到默认皮肤。
  final ElTableStyle style;

  /// 表格根焦点节点；null 表示只展示，不进入键盘遍历。
  final FocusNode? focusNode;

  /// 表格根语义标签。
  final String? semanticLabel;

  /// 完整表头单元格构建器；普通调用只配置列，组件库皮肤可用它接管分组与叶子表头。
  final ElTableHeaderCellBuilder? headerCellBuilder;

  /// 是否允许用户横向拖拽叶子表头来调整顶层列或分组顺序。
  final bool columnReorderable;

  /// 视口高度；null 表示按内容自然高度布局。
  final double? height;

  /// 用户提交排序时触发。
  final ValueChanged<ElTableSort>? onSort;

  /// 用户清除排序时触发。
  final VoidCallback? onClearSort;

  /// 用户选择变化时触发；上下文本身不扫描完整数据。
  final ValueChanged<ElTableSelectionChange>? onSelectionChanged;

  /// 用户切换当前行时触发；声明本回调也会启用普通数据行的点击命中。
  final ValueChanged<ElTableRow?>? onCurrentChanged;

  /// 用户展开或收起数据行时触发。
  final void Function(ElTableRow row, bool expanded)? onExpansionChanged;

  /// 用户单击数据行时触发；上下文包含排序后的展示序号，声明后也会同步 currentRow。
  final ValueChanged<ElTableRowContext>? onRowTap;

  /// 用户双击数据行时触发。
  ///
  /// 声明本回调后，底层会在派发前先把该行设为当前行
  /// （`controller.currentRow` 在该行；与回调内部自行赋值不冲突）。
  final ValueChanged<ElTableRowContext>? onRowDoubleTap;

  /// 用户右键数据行时触发。
  ///
  /// 声明本回调后，底层会在派发前先把该行设为当前行
  /// （`controller.currentRow` 在该行；与回调内部自行赋值不冲突）。
  final void Function(ElTableRowContext row, Offset globalPosition)? onRowSecondaryTap;

  /// 用户单击数据单元格时触发。
  final ValueChanged<ElTableCell>? onCellTap;

  /// 用户完成表头拖拽换序时触发，参数是完整顶层列顺序快照。
  final ValueChanged<List<Object>>? onColumnOrderChanged;

  /// 用户完成列宽拖拽时触发，参数是完整列宽快照。
  final ValueChanged<Map<Object, double>>? onColumnWidthsChanged;

  /// 用户完成行高拖拽时触发，参数是完整行高快照。
  final ValueChanged<Map<Object, double>>? onRowHeightsChanged;

  /// 包内交互事件集合：由平铺回调合成；未声明任何回调时为 null。
  ElTableEvent? get _eventConfig => _declaresEvents
      ? ElTableEvent(
          onSort: onSort,
          onClearSort: onClearSort,
          onSelectionChanged: onSelectionChanged,
          onCurrentChanged: onCurrentChanged,
          onExpansionChanged: onExpansionChanged,
          onRowTap: onRowTap,
          onRowDoubleTap: onRowDoubleTap,
          onRowSecondaryTap: onRowSecondaryTap,
          onCellTap: onCellTap,
          onColumnOrderChanged: onColumnOrderChanged,
          onColumnWidthsChanged: onColumnWidthsChanged,
          onRowHeightsChanged: onRowHeightsChanged,
        )
      : null;

  /// 是否声明了任一交互回调。
  bool get _declaresEvents =>
      onSort != null ||
      onClearSort != null ||
      onSelectionChanged != null ||
      onCurrentChanged != null ||
      onExpansionChanged != null ||
      onRowTap != null ||
      onRowDoubleTap != null ||
      onRowSecondaryTap != null ||
      onCellTap != null ||
      onColumnOrderChanged != null ||
      onColumnWidthsChanged != null ||
      onRowHeightsChanged != null;

  @override
  State<ElTable> createState() => _TableViewState();
}

class _TableViewState extends State<ElTable> {
  static const int _columnVirtualThreshold = 24;

  /// 当前 widget 的交互事件集合，随 widget 更新同步。
  ElTableEvent? _event;

  final _TableGridCoordinator _grid = _TableGridCoordinator();
  final ElScrollController _verticalController = ElScrollController();
  ScrollController? _horizontalController;

  bool _autoScrollX = false;
  double? _columnResizeBase;
  double? _columnResizePointerStart;
  double? _rowResizeBase;
  double _columnResizeFloor = 40;
  List<int> _visualColumns = const [];
  List<int> _leftColumns = const [];
  List<int> _middleColumns = const [];
  List<int> _rightColumns = const [];
  List<_TableColumnPlan>? _projectedPlans;
  bool? _projectedHorizontal;
  bool _handlesRowEvents = false;
  List<_TableColumnPlan> _columnPlans = const [];
  List<ElTableRow> _displayRows = const [];
  List<ElTableRow> _pinnedRows = const [];
  _TableColumnPlan? _expansionPlan;
  final Map<Object, GlobalKey> _expandedDetailKeys = <Object, GlobalKey>{};
  final Map<Object, GlobalKey> _headerCellKeys = <Object, GlobalKey>{};
  _TableColumnReorderSession? _columnReorder;
  List<ElStyle?> _dataCellStyles = const [];
  List<ElStyle?> _headerCellStyles = const [];
  ElStyle _rowStyle = const ElStyle();
  ElStyle _currentRowStyle = const ElStyle();
  ElStyle _headerStyle = const ElStyle();
  ElStyle _expandedStyle = const ElStyle();
  ElStyle? _stripeRowStyle;
  ElStyle? _columnDividerStyle;
  Color? _fixedDividerColor;
  double _fixedDividerWidth = 1;
  List<BoxShadow>? _fixedColumnShadow;
  ElTableStyle? _preparedStyle;

  /// 最近一次 build 解析出的生效皮肤；键盘与滚动路径复用同一份真值。
  ElTableStyle _activeStyle = const ElTableStyle();
  List<_TableColumnPlan>? _preparedPlans;
  List<int>? _preparedVisual;
  bool _preparedLazyStyles = false;
  int _currentRowRevealGeneration = 0;
  List<List<ElTableColumn>>? _preparedHeaderPaths;
  List<int>? _preparedHeaderVisual;
  List<List<({int start, int end, ElTableColumn? column})>> _preparedGroupHeaders = const [];

  int _publishedColumnRevision = -1;
  int _publishedGeometryRevision = -1;
  bool? _publishedForcedWidth;
  double? _publishedMinColumnWidth;
  List<int>? _publishedVisual;
  int _naturalWidthGeometryRevision = -1;
  List<_TableColumnPlan>? _naturalWidthPlans;
  double? _naturalWidthMinColumnWidth;
  double _cachedNaturalWidth = 0;

  List<ElTableRow>? _cachedData;
  List<_TableColumnPlan>? _cachedPlans;
  int _cachedProjectionRevision = -1;
  Object? _cachedSortColumnKey;
  List<ElTableRow>? _cachedAscendingRows;
  List<ElTableRow>? _cachedDescendingRows;

  @override
  void initState() {
    super.initState();
    _syncConfig();
    _grid.onHOverflowChanged = _handleHorizontalOverflowChanged;
    _attachController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant ElTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncConfig();
    if (!identical(oldWidget.controller, widget.controller)) {
      _clearColumnReorderImmediately();
      _detachController(oldWidget.controller);
      _attachController(widget.controller);
      _invalidateRows();
    }
    if (oldWidget.columnReorderable && !widget.columnReorderable) _clearColumnReorderImmediately();
  }

  /// 把 widget 上的平铺回调参数合成包内 event 对象，避免逐处拆解。
  void _syncConfig() {
    _event = widget._eventConfig;
  }

  /// 解析生效皮肤：显式 [ElTable.style] 优先，其次是 `ElComponentProvider` 登记的
  /// `tableStyleBuilder` 工厂，最后回落到 `const ElTableStyle()`。
  ///
  /// 未登记品牌主题时必须能裸用表格，所以这里读 `maybeOf`，不用会 assert 的 `of`。
  ElTableStyle _resolveStyle(BuildContext context) {
    final declared = widget.style;
    if (!identical(declared, const ElTableStyle())) return declared;
    return ElComponentProvider.maybeOf(context)?.tableStyleBuilder?.call(context) ?? declared;
  }

  @override
  void dispose() {
    _detachController(widget.controller);
    _grid.dispose();
    _verticalController.dispose();
    _horizontalController?.dispose();
    super.dispose();
  }

  void _attachController(ElTableController controller) {
    controller
      .._attach(this)
      ..addListener(_handleControllerChanged);
  }

  void _detachController(ElTableController controller) {
    controller
      ..removeListener(_handleControllerChanged)
      .._detach(this);
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final reorder = _columnReorder;
    if (reorder != null && reorder.columnRevision != widget.controller._columnRevision) {
      _clearColumnReorderImmediately();
    }
    setState(() {});
  }

  void _invalidateRows() {
    _cachedData = null;
    _cachedPlans = null;
    _cachedSortColumnKey = null;
    _cachedAscendingRows = null;
    _cachedDescendingRows = null;
    _cachedProjectionRevision = -1;
  }

  void _handleHorizontalOverflowChanged() {
    if (!mounted || _columnResizeBase != null || _rowResizeBase != null) return;
    final next = _grid.hOverflow;
    if (next != _autoScrollX) setState(() => _autoScrollX = next);
  }

  void _syncHorizontalOverflow() {
    if (!mounted) return;
    final next = _grid.hOverflow;
    if (next != _autoScrollX) setState(() => _autoScrollX = next);
  }

  List<ElTableRow> _resolveDisplayRows(List<ElTableRow> data, List<_TableColumnPlan> plans) {
    final controller = widget.controller;
    if (_cachedProjectionRevision == controller._projectionRevision && identical(_cachedPlans, plans)) {
      return controller.sortAscending == false
          ? _cachedDescendingRows ?? _cachedData!
          : _cachedAscendingRows ?? _cachedData!;
    }
    _cachedProjectionRevision = controller._projectionRevision;

    final pinnedKeys = controller._pinnedRowKeys;
    List<ElTableRow> base;
    if (pinnedKeys.isEmpty) {
      _pinnedRows = const [];
      base = data;
    } else {
      final pinned = <ElTableRow>[];
      final body = <ElTableRow>[];
      for (final row in data) {
        (pinnedKeys.contains(controller.rowKeyOf(row)) ? pinned : body).add(row);
      }
      _pinnedRows = List<ElTableRow>.unmodifiable(pinned);
      base = List<ElTableRow>.unmodifiable(body);
    }

    final sort = controller.localSort ? controller.sortState : null;
    if (!identical(_cachedData, base) || !identical(_cachedPlans, plans)) {
      _cachedData = base;
      _cachedPlans = plans;
      _cachedSortColumnKey = null;
      _cachedAscendingRows = null;
      _cachedDescendingRows = null;
    }
    if (sort == null || base.length < 2) {
      _cachedAscendingRows = base;
      _cachedDescendingRows = base;
      return base;
    }

    _TableColumnPlan? sortPlan;
    for (final plan in plans) {
      if (plan.key == sort.columnKey) {
        sortPlan = plan;
        break;
      }
    }
    if (sortPlan == null) return base;

    if (_cachedSortColumnKey != sort.columnKey) {
      _cachedSortColumnKey = sort.columnKey;
      _cachedAscendingRows = null;
      _cachedDescendingRows = null;
    }
    final cached = sort.ascending ? _cachedAscendingRows : _cachedDescendingRows;
    if (cached != null) return cached;

    final orders = _sortRows(base, sortPlan);
    _cachedAscendingRows = orders.ascending;
    _cachedDescendingRows = orders.descending;
    return sort.ascending ? orders.ascending : orders.descending;
  }

  static int _compareValues(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    if (a is num && b is num) return a.compareTo(b);
    if (a is Comparable && a.runtimeType == b.runtimeType) return a.compareTo(b);
    return a.toString().compareTo(b.toString());
  }

  static const int _maxGroupedSortKeys = 512;

  // 常见状态/枚举/分数字段按低基数桶稳定展开，避免 O(n log n)；高基数字段
  // 只读取一次 Map 值再稳定归并，杜绝比较器热循环里的重复动态取值。
  static ({List<ElTableRow> ascending, List<ElTableRow> descending}) _sortRows(
    List<ElTableRow> data,
    _TableColumnPlan plan,
  ) {
    final customSorter = plan.sorter;
    if (customSorter != null) {
      final ascending = _stableMergeRows(data, customSorter);
      return (ascending: ascending, descending: _reverseComparatorGroups(ascending, customSorter));
    }

    final values = List<Object?>.filled(data.length, null, growable: false);
    Map<Object?, List<ElTableRow>>? groups = <Object?, List<ElTableRow>>{};
    var groupKind = 0;
    for (var index = 0; index < data.length; index++) {
      final row = data[index];
      final value = plan.valueOf(row);
      values[index] = value;
      final currentGroups = groups;
      if (currentGroups == null) continue;
      final kind = _groupSortKind(value);
      if (kind < 0 || kind > 0 && groupKind > 0 && kind != groupKind) {
        groups = null;
        continue;
      }
      if (kind > 0) groupKind = kind;
      final existing = currentGroups[value];
      if (existing != null) {
        existing.add(row);
      } else if (currentGroups.length >= _maxGroupedSortKeys) {
        groups = null;
      } else {
        currentGroups[value] = <ElTableRow>[row];
      }
    }

    if (groups != null) return _groupedOrders(data.length, data.first, groups);
    final sorted = _stableMergeValues(data, values, groupKind);
    return (ascending: sorted.rows, descending: _reverseValueGroups(sorted.rows, sorted.values, groupKind));
  }

  static int _groupSortKind(Object? value) => switch (value) {
    null => 0,
    num _ => 1,
    String _ => 2,
    bool _ => 3,
    _ => -1,
  };

  static ({List<ElTableRow> ascending, List<ElTableRow> descending}) _groupedOrders(
    int length,
    ElTableRow fill,
    Map<Object?, List<ElTableRow>> groups,
  ) {
    final keys = groups.keys.toList(growable: false)..sort(_compareValues);
    final ascending = List<ElTableRow>.filled(length, fill, growable: false);
    final descending = List<ElTableRow>.filled(length, fill, growable: false);
    var ascendingIndex = 0;
    var descendingIndex = 0;
    for (final key in keys) {
      for (final row in groups[key]!) {
        ascending[ascendingIndex++] = row;
      }
    }
    for (var keyIndex = keys.length - 1; keyIndex >= 0; keyIndex--) {
      for (final row in groups[keys[keyIndex]]!) {
        descending[descendingIndex++] = row;
      }
    }
    return (ascending: ascending, descending: descending);
  }

  static ({List<ElTableRow> rows, List<Object?> values}) _stableMergeValues(
    List<ElTableRow> data,
    List<Object?> dataValues,
    int valueKind,
  ) {
    var rows = List<ElTableRow>.of(data, growable: false);
    var values = dataValues;
    var scratchRows = List<ElTableRow>.filled(data.length, data.first, growable: false);
    var scratchValues = List<Object?>.filled(data.length, null, growable: false);
    for (var width = 1; width < data.length; width *= 2) {
      for (var start = 0; start < data.length; start += width * 2) {
        final middle = math.min(start + width, data.length);
        final end = math.min(start + width * 2, data.length);
        var left = start;
        var right = middle;
        for (var output = start; output < end; output++) {
          final takeLeft =
              right >= end || left < middle && _compareKnownValues(values[left], values[right], valueKind) <= 0;
          final source = takeLeft ? left++ : right++;
          scratchRows[output] = rows[source];
          scratchValues[output] = values[source];
        }
      }
      final oldRows = rows;
      rows = scratchRows;
      scratchRows = oldRows;
      final oldValues = values;
      values = scratchValues;
      scratchValues = oldValues;
    }
    return (rows: rows, values: values);
  }

  static int _compareKnownValues(Object? a, Object? b, int kind) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return switch (kind) {
      1 => (a as num).compareTo(b as num),
      2 => (a as String).compareTo(b as String),
      3 => (a as bool ? 1 : 0).compareTo(b as bool ? 1 : 0),
      _ => _compareValues(a, b),
    };
  }

  static List<ElTableRow> _stableMergeRows(List<ElTableRow> data, Comparator<ElTableRow> compare) {
    var rows = List<ElTableRow>.of(data, growable: false);
    var scratch = List<ElTableRow>.filled(data.length, data.first, growable: false);
    for (var width = 1; width < data.length; width *= 2) {
      for (var start = 0; start < data.length; start += width * 2) {
        final middle = math.min(start + width, data.length);
        final end = math.min(start + width * 2, data.length);
        var left = start;
        var right = middle;
        for (var output = start; output < end; output++) {
          final takeLeft = right >= end || left < middle && compare(rows[left], rows[right]) <= 0;
          scratch[output] = rows[takeLeft ? left++ : right++];
        }
      }
      final oldRows = rows;
      rows = scratch;
      scratch = oldRows;
    }
    return rows;
  }

  static List<ElTableRow> _reverseValueGroups(List<ElTableRow> rows, List<Object?> values, int valueKind) {
    final descending = List<ElTableRow>.filled(rows.length, rows.first, growable: false);
    var output = 0;
    var end = rows.length;
    while (end > 0) {
      var start = end - 1;
      // 逆序只翻转值组，不翻转组内行，升降序都保持输入中的等值顺序。
      while (start > 0 && _compareKnownValues(values[start - 1], values[end - 1], valueKind) == 0) {
        start--;
      }
      for (var index = start; index < end; index++) {
        descending[output++] = rows[index];
      }
      end = start;
    }
    return descending;
  }

  static List<ElTableRow> _reverseComparatorGroups(List<ElTableRow> rows, Comparator<ElTableRow> compare) {
    final descending = List<ElTableRow>.filled(rows.length, rows.first, growable: false);
    var output = 0;
    var end = rows.length;
    while (end > 0) {
      var start = end - 1;
      while (start > 0 && compare(rows[start - 1], rows[end - 1]) == 0) {
        start--;
      }
      for (var index = start; index < end; index++) {
        descending[output++] = rows[index];
      }
      end = start;
    }
    return descending;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final style = _activeStyle = _resolveStyle(context);
    // 行号列宽 = 内容宽 + 单元格内边距；必须在取 plans 之前同步，否则本帧拿到的还是上一份宽度。
    controller._syncIndexColumnPadding(style.cellHorizontalPadding);
    // 内容宽按生效文字环境实测，同样要在取 plans 之前同步（同上一行）。
    if (controller._hasAutoIndexWidth) {
      controller._syncIndexTextEnvironment((
        style: _resolveIndexMeasureTextStyle(style),
        scaler: MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
        direction: Directionality.maybeOf(context) ?? TextDirection.ltr,
        locale: Localizations.maybeLocaleOf(context),
      ));
    }
    final event = _event;
    _handlesRowEvents =
        widget.focusNode != null ||
        event?.onCurrentChanged != null ||
        event?.onRowTap != null ||
        event?.onRowDoubleTap != null ||
        event?.onRowSecondaryTap != null;
    final plans = controller._visibleColumnPlans;
    final rows = _resolveDisplayRows(controller._data, plans);
    _columnPlans = plans;
    _displayRows = rows;
    _expandedDetailKeys.removeWhere((key, value) => !controller._expandedRowKeys.contains(key));

    final rowHeight = _positive(style.rowHeight, 40, 'ElTableStyle.rowHeight');
    final headerHeight = _positive(style.headerHeight ?? rowHeight, rowHeight, 'ElTableStyle.headerHeight');
    final minColumnWidth = _positive(style.minColumnWidth, 80, 'ElTableStyle.minColumnWidth');
    final resizeHitSize = _positive(style.resizeHitSize, 8, 'ElTableStyle.resizeHitSize');
    _fixedDividerColor = style.fixedDividerColor;
    _fixedDividerWidth = style.fixedDividerWidth;
    _fixedColumnShadow = style.fixedColumnShadow;

    if (plans.isEmpty) {
      _expansionPlan = null;
      return _TableConstraintHost(
        naturalWidth: 0,
        child: _tableRoot(style, controller._data.isEmpty ? _empty(style, rowHeight) : null),
      );
    }

    _ensureColumnMetadata(plans);
    // 横向滚动没有开关：内容溢出视口就自动启用，列数达到阈值时先乐观启用，避免首帧闪动。
    final horizontalEnabled = _autoScrollX || plans.length >= _columnVirtualThreshold;
    final horizontalShell = horizontalEnabled;
    _ensureVisualProjection(plans, horizontalEnabled);
    final visual = _visualColumns;
    final columnVirtual =
        horizontalEnabled &&
        // autoRowHeight：行高由全列实测得出，与「稀疏挂载只挂窗口内列」互斥，
        // 这是列虚拟化恒开后唯一保留的例外，让动态行高恒能成立。
        !style.autoRowHeight;
    _prepareCellStyles(style, plans, visual, lazy: columnVirtual);

    _publishGridSpec(controller, plans, visual, horizontalEnabled, minColumnWidth);
    if (horizontalShell) {
      _grid.attachHorizontal(_horizontalController ??= ScrollController());
    } else {
      _grid.attachHorizontal(null);
    }

    final height = widget.height;
    final dataRowHeight = style.autoRowHeight ? null : rowHeight;
    return _TableConstraintHost(
      naturalWidth: _naturalWidth(controller, plans, minColumnWidth),
      child: _tableRoot(
        style,
        height == null
            ? _naturalTable(
                style,
                rows,
                plans,
                visual,
                horizontalShell: horizontalShell,
                rowHeight: dataRowHeight,
                minRowHeight: rowHeight,
                headerHeight: headerHeight,
                resizeHitSize: resizeHitSize,
                columnVirtual: columnVirtual,
              )
            : _viewportTable(
                style,
                rows,
                plans,
                visual,
                horizontalShell: horizontalShell,
                rowHeight: dataRowHeight,
                minRowHeight: rowHeight,
                headerHeight: headerHeight,
                resizeHitSize: resizeHitSize,
                columnVirtual: columnVirtual,
              ),
      ),
    );
  }

  ElView _tableRoot(ElTableStyle style, Widget? child) => ElView(
    focusNode: widget.focusNode,
    event: widget.focusNode == null ? null : ElEvent(onKeyDown: _handleFocusKey),
    semantics: widget.semanticLabel == null
        ? null
        : ElSemantics(container: true, explicitChildNodes: true, label: widget.semanticLabel),
    style: _rootStyle(style),
    child: child,
  );

  void _ensureColumnMetadata(List<_TableColumnPlan> plans) {
    if (identical(_projectedPlans, plans)) return;
    _projectedPlans = plans;
    _projectedHorizontal = null;
    final left = <int>[];
    final middle = <int>[];
    final right = <int>[];
    for (var index = 0; index < plans.length; index++) {
      final plan = plans[index];
      switch (plan.column.fixed) {
        case ElTableColumnFixed.left:
          left.add(index);
        case ElTableColumnFixed.right:
          right.add(index);
        case null:
          middle.add(index);
      }
    }
    _leftColumns = List<int>.unmodifiable(left);
    _middleColumns = List<int>.unmodifiable(middle);
    _rightColumns = List<int>.unmodifiable(right);
  }

  void _ensureVisualProjection(List<_TableColumnPlan> plans, bool horizontalEnabled) {
    if (_projectedHorizontal == horizontalEnabled) return;
    _projectedHorizontal = horizontalEnabled;
    _visualColumns = List<int>.unmodifiable(
      horizontalEnabled
          ? <int>[..._leftColumns, ..._middleColumns, ..._rightColumns]
          : <int>[for (var index = 0; index < plans.length; index++) index],
    );
    _expansionPlan = null;
    for (final index in _visualColumns) {
      final plan = plans[index];
      if (plan.hasExpansionSlot) {
        _expansionPlan = plan;
        break;
      }
    }
  }

  void _publishGridSpec(
    ElTableController controller,
    List<_TableColumnPlan> plans,
    List<int> visual,
    bool horizontalEnabled,
    double minColumnWidth,
  ) {
    if (_publishedColumnRevision == controller._columnRevision &&
        _publishedGeometryRevision == controller._geometryRevision &&
        _publishedForcedWidth == horizontalEnabled &&
        _publishedMinColumnWidth == minColumnWidth &&
        identical(_publishedVisual, visual)) {
      return;
    }
    _publishedColumnRevision = controller._columnRevision;
    _publishedGeometryRevision = controller._geometryRevision;
    _publishedForcedWidth = horizontalEnabled;
    _publishedMinColumnWidth = minColumnWidth;
    _publishedVisual = visual;
    _grid.spec = _TableGridSpec(
      columns: [for (final index in visual) plans[index].geometryColumn],
      leftCount: horizontalEnabled ? _leftColumns.length : 0,
      rightCount: horizontalEnabled ? _rightColumns.length : 0,
      columnMinWidth: minColumnWidth,
      forcedWidth: horizontalEnabled,
      resizeOverrides: _columnWidthOverrides(controller, plans, visual),
    );
  }

  double _naturalWidth(ElTableController controller, List<_TableColumnPlan> plans, double minColumnWidth) {
    if (_naturalWidthGeometryRevision == controller._geometryRevision &&
        identical(_naturalWidthPlans, plans) &&
        _naturalWidthMinColumnWidth == minColumnWidth) {
      return _cachedNaturalWidth;
    }
    _naturalWidthGeometryRevision = controller._geometryRevision;
    _naturalWidthPlans = plans;
    _naturalWidthMinColumnWidth = minColumnWidth;
    var result = 0.0;
    for (final plan in plans) {
      final override = plan.column.type == null ? controller._columnWidths[plan.key] : null;
      result += override ?? plan.width ?? plan.minWidth ?? minColumnWidth;
    }
    return _cachedNaturalWidth = result;
  }

  ElStyle _rootStyle(ElTableStyle style) {
    final height = widget.height;
    final root = style.border ? style.table.merge(style.frame) : style.table;
    return height == null ? root : root.merge(ElStyle(height: height));
  }

  static double _positive(double value, double fallback, String name) {
    assert(value.isFinite && value > 0, '$name 必须是有限正数，当前为 $value。');
    return value.isFinite && value > 0 ? value : fallback;
  }

  void _prepareCellStyles(ElTableStyle style, List<_TableColumnPlan> plans, List<int> visual, {required bool lazy}) {
    if (identical(_preparedStyle, style) &&
        identical(_preparedPlans, plans) &&
        identical(_preparedVisual, visual) &&
        _preparedLazyStyles == lazy) {
      return;
    }
    _preparedStyle = style;
    _preparedPlans = plans;
    _preparedVisual = visual;
    _preparedLazyStyles = lazy;
    // 网格线开关只改横线/竖线的取用，不参与布局与命中测试：
    // 横线总开关关闭时摘掉数据行与展开详情自带的下边框，声明 rowDivider 时由它接管；
    // 竖线只在声明 columnDivider 且开关打开时叠加。
    final showRowLines = style.horizontalGridLines ?? style.gridLines;
    var declaredRowStyle = style.row;
    var declaredExpandedStyle = style.expanded;
    if (!showRowLines) {
      declaredRowStyle = declaredRowStyle.copyWith(border: null);
      declaredExpandedStyle = declaredExpandedStyle.copyWith(border: null);
    } else {
      final rowDivider = style.rowDivider;
      if (rowDivider != null) {
        declaredRowStyle = declaredRowStyle.merge(rowDivider);
        declaredExpandedStyle = declaredExpandedStyle.merge(rowDivider);
      }
    }
    final currentStyle = style.currentRow;
    _rowStyle = declaredRowStyle;
    _currentRowStyle = currentStyle == null ? declaredRowStyle : _rowStyle.merge(currentStyle);
    _stripeRowStyle = style.stripe ? style.stripeRow : null;
    _expandedStyle = declaredExpandedStyle;
    _columnDividerStyle = (style.verticalGridLines ?? style.gridLines) ? style.columnDivider : null;
    _headerStyle = style.header;
    if (lazy) {
      _dataCellStyles = List<ElStyle?>.filled(visual.length, null);
      _headerCellStyles = List<ElStyle?>.filled(visual.length, null);
    } else {
      _dataCellStyles = [for (final index in visual) _resolveCellStyle(style, plans[index], header: false)];
      _headerCellStyles = [for (final index in visual) _resolveCellStyle(style, plans[index], header: true)];
    }
  }

  /// 解析单元格基础样式：几何 / 溢出 → 表头或数据单元格 → 竖线 → 表头列级扩展。
  ///
  /// 数据单元格的合并链到此为止：列类型默认（内置枚举列目前没有额外默认样式）
  /// → `ElTableColumn.cellStyleBuilder` 在调用点动态叠加。静态列样式这一层已删除。
  ElStyle _resolveCellStyle(ElTableStyle style, _TableColumnPlan plan, {required bool header}) {
    final base = ElStyle(
      padding: style.cellPadding,
      alignment: _alignmentFor(header ? plan.headerAlign : plan.align),
      textAlign: header ? plan.headerAlign : plan.align,
      minHeight: !header && style.autoRowHeight ? style.rowHeight : null,
      overflow: header || plan.showOverflow == true ? TextOverflow.ellipsis : null,
      maxLines: header || plan.showOverflow == true ? 1 : null,
    ).merge(header ? style.headerCell : style.cell).merge(_columnDividerStyle);
    return header ? base.merge(plan.headerStyle) : base;
  }

  ElStyle _dataCellStyleAt(int visualIndex) => _dataCellStyles[visualIndex] ??= _resolveCellStyle(
    _preparedStyle!,
    _preparedPlans![_preparedVisual![visualIndex]],
    header: false,
  );

  ElStyle _headerCellStyleAt(int visualIndex) => _headerCellStyles[visualIndex] ??= _resolveCellStyle(
    _preparedStyle!,
    _preparedPlans![_preparedVisual![visualIndex]],
    header: true,
  );

  /// 解析序号列测宽用的生效文字样式。
  ///
  /// 单元格渲染走的是级联：祖上级联（站点字体族等）→ 表格根 `style.table` →
  /// 行 `style.row` → 单元格 `style.cell`。这里按同一顺序叠出等价样式，量出来的
  /// 字宽才和实际渲染一致——序号列宽本来就是"内容宽 + 内边距"，内容宽按错的字体
  /// 算，末位序号就会换行。
  ///
  /// 祖上级联取**已提交**产物（`committedResolvedStyle`，overlay 的
  /// 级联桥同一入口）。表格根是在本帧 build 里刚建的，它的声明尚未提交，所以由本
  /// 方法显式叠上。没有 ElView 祖先（裸用表格）时回落到 el_ui 文本初值；祖先首帧
  /// 尚未提交级联时读到的是初值，下一帧同步修正，不会锁死在错值上。
  TextStyle _resolveIndexMeasureTextStyle(ElTableStyle style) {
    final parent = context.findAncestorRenderObjectOfType<ElRenderView>()?.committedResolvedStyle;
    // 无 ElView 祖先时以 el_ui 文本初值为基准（裸用表格的既定行为，字号 15）。
    final base = inheritedTextToTextStyle(parent?.inheritedText ?? InheritedText.initial);
    // 只有数据单元格进本方法，表头声明不参与。
    return base
        .merge(elStyleToTextStyle(style.table))
        .merge(elStyleToTextStyle(style.row))
        .merge(elStyleToTextStyle(style.cell));
  }

  Map<int, double>? _columnWidthOverrides(
    ElTableController controller,
    List<_TableColumnPlan> plans,
    List<int> visual,
  ) {
    if (controller._columnWidths.isEmpty) return null;
    final result = <int, double>{};
    for (var visualIndex = 0; visualIndex < visual.length; visualIndex++) {
      final sourceIndex = visual[visualIndex];
      // 内置列由组件统一定宽，旧缓存与命令式覆盖不能重新压窄序号列。
      if (plans[sourceIndex].column.type != null) continue;
      final width = controller._columnWidths[plans[sourceIndex].key];
      if (width != null) result[visualIndex] = width;
    }
    return result.isEmpty ? null : result;
  }

  Widget _naturalTable(
    ElTableStyle style,
    List<ElTableRow> rows,
    List<_TableColumnPlan> plans,
    List<int> visual, {
    required bool horizontalShell,
    required double? rowHeight,
    required double minRowHeight,
    required double headerHeight,
    required double resizeHitSize,
    required bool columnVirtual,
  }) {
    if (!horizontalShell) {
      return ElView(
        event: _rowInteractionEvent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.controller.showHeader)
              ..._headerRows(style, plans, visual, _TableGridRowMode.plain, headerHeight, resizeHitSize, false),
            for (var index = 0; index < _pinnedRows.length; index++)
              _dataRow(
                style,
                _pinnedRows[index],
                index,
                plans,
                visual,
                _TableGridRowMode.plain,
                rowHeight,
                minRowHeight,
                false,
              ),
            for (var index = 0; index < rows.length; index++)
              _dataRow(
                style,
                rows[index],
                _pinnedRows.length + index,
                plans,
                visual,
                _TableGridRowMode.plain,
                rowHeight,
                minRowHeight,
                false,
              ),
            if (widget.controller._data.isEmpty) _empty(style, minRowHeight),
            if (widget.controller.summaryBuilder != null && widget.controller._data.isNotEmpty)
              _summaryRow(style, plans, visual, _TableGridRowMode.plain, rowHeight ?? minRowHeight, false),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TableGridRow(key: const ValueKey('el-table-ruler'), coordinator: _grid, mode: _TableGridRowMode.ruler),
        ElScrollView(
          axis: Axis.horizontal,
          shrinkWrap: true,
          controller: _horizontalController,
          // 表格不做窗口外预挂载：大跨度滚动不整窗创建额外列。
          cacheExtent: 0,
          event: _rowInteractionEvent,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.controller.showHeader)
                  ..._headerRows(
                    style,
                    plans,
                    visual,
                    _TableGridRowMode.shell,
                    headerHeight,
                    resizeHitSize,
                    columnVirtual,
                  ),
                for (var index = 0; index < _pinnedRows.length; index++)
                  _dataRow(
                    style,
                    _pinnedRows[index],
                    index,
                    plans,
                    visual,
                    _TableGridRowMode.shell,
                    rowHeight,
                    minRowHeight,
                    columnVirtual,
                  ),
                for (var index = 0; index < rows.length; index++)
                  _dataRow(
                    style,
                    rows[index],
                    _pinnedRows.length + index,
                    plans,
                    visual,
                    _TableGridRowMode.shell,
                    rowHeight,
                    minRowHeight,
                    columnVirtual,
                  ),
                if (widget.controller.summaryBuilder != null && widget.controller._data.isNotEmpty)
                  _summaryRow(style, plans, visual, _TableGridRowMode.shell, rowHeight ?? minRowHeight, columnVirtual),
              ],
            ),
          ],
        ),
        if (widget.controller._data.isEmpty) _empty(style, minRowHeight),
      ],
    );
  }

  Widget _viewportTable(
    ElTableStyle style,
    List<ElTableRow> rows,
    List<_TableColumnPlan> plans,
    List<int> visual, {
    required bool horizontalShell,
    required double? rowHeight,
    required double minRowHeight,
    required double headerHeight,
    required double resizeHitSize,
    required bool columnVirtual,
  }) {
    final mode = horizontalShell ? _TableGridRowMode.selfShift : _TableGridRowMode.plain;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (horizontalShell) _TableGridRow(coordinator: _grid, mode: _TableGridRowMode.ruler),
        if (widget.controller.showHeader)
          ..._headerRows(style, plans, visual, mode, headerHeight, resizeHitSize, columnVirtual),
        for (var index = 0; index < _pinnedRows.length; index++)
          _dataRow(style, _pinnedRows[index], index, plans, visual, mode, rowHeight, minRowHeight, columnVirtual),
        Expanded(
          child: ElView(
            style: const ElStyle(clipBehavior: Clip.hardEdge),
            child: widget.controller._data.isEmpty
                ? _empty(style, minRowHeight)
                : rows.isEmpty
                ? null
                : _scrollBody(style, rows, plans, visual, horizontalShell, rowHeight, minRowHeight, columnVirtual),
          ),
        ),
        if (widget.controller.summaryBuilder != null && widget.controller._data.isNotEmpty)
          _summaryRow(style, plans, visual, mode, rowHeight ?? minRowHeight, columnVirtual),
      ],
    );
  }

  Widget _scrollBody(
    ElTableStyle style,
    List<ElTableRow> rows,
    List<_TableColumnPlan> plans,
    List<int> visual,
    bool horizontalShell,
    double? rowHeight,
    double minRowHeight,
    bool columnVirtual,
  ) {
    final mode = horizontalShell ? _TableGridRowMode.shell : _TableGridRowMode.plain;
    // 行虚拟化恒开：数据行一律按行窗口惰性挂载。
    final children = <Widget>[
      ElListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) => _dataRow(
          style,
          rows[index],
          _pinnedRows.length + index,
          plans,
          visual,
          mode,
          rowHeight,
          minRowHeight,
          columnVirtual,
        ),
      ),
    ];
    return ElScrollView(
      axis: horizontalShell ? null : Axis.vertical,
      controller: _verticalController,
      horizontalController: horizontalShell ? _horizontalController : null,
      // 表格不做窗口外预挂载：大跨度滚动不整窗创建额外行。
      cacheExtent: 0,
      event: _rowInteractionEvent,
      children: children,
    );
  }

  Widget _headerRow(
    ElTableStyle style,
    List<_TableColumnPlan> plans,
    List<int> visual,
    _TableGridRowMode mode,
    double height,
    double resizeHitSize,
    bool columnVirtual,
  ) {
    return ElView(
      style: _headerStyle,
      event: mode == _TableGridRowMode.selfShift ? ElEvent(onPointerSignal: _forwardWheel) : null,
      child: _gridRow(
        mode: mode,
        rowHeight: height,
        columnVirtual: columnVirtual,
        cellCount: visual.length,
        hostedCellBuilder: columnVirtual
            ? (visualIndex) => _hostedHeaderCell(plans[visual[visualIndex]], visualIndex)
            : null,
        cellBuilder: (context, visualIndex) =>
            _headerCell(style, plans[visual[visualIndex]], visualIndex, resizeHitSize),
      ),
    );
  }

  List<Widget> _headerRows(
    ElTableStyle style,
    List<_TableColumnPlan> plans,
    List<int> visual,
    _TableGridRowMode mode,
    double height,
    double resizeHitSize,
    bool columnVirtual,
  ) {
    final controller = widget.controller;
    if (controller._headerDepth <= 1) {
      return <Widget>[_headerRow(style, plans, visual, mode, height, resizeHitSize, columnVirtual)];
    }
    final paths = controller._visibleColumnPaths;
    final groupHeaders = _groupHeadersOf(paths, visual);
    if (groupHeaders.isEmpty) {
      return <Widget>[_headerRow(style, plans, visual, mode, height, resizeHitSize, columnVirtual)];
    }

    final rows = <Widget>[];
    for (final spans in groupHeaders) {
      rows.add(
        ElView(
          style: style.groupHeader,
          event: mode == _TableGridRowMode.selfShift ? ElEvent(onPointerSignal: _forwardWheel) : null,
          child: _TableGridRow(
            coordinator: _grid,
            mode: mode,
            rowHeight: height,
            cellSpans: [for (final span in spans) _TableGridCellSpan(span.start, span.end)],
            children: [for (final span in spans) _groupHeaderCell(style, span.column, span.end - span.start)],
          ),
        ),
      );
    }
    rows.add(_headerRow(style, plans, visual, mode, height, resizeHitSize, columnVirtual));
    return rows;
  }

  List<List<({int start, int end, ElTableColumn? column})>> _groupHeadersOf(
    List<List<ElTableColumn>> paths,
    List<int> visual,
  ) {
    if (identical(_preparedHeaderPaths, paths) && identical(_preparedHeaderVisual, visual)) {
      return _preparedGroupHeaders;
    }
    _preparedHeaderPaths = paths;
    _preparedHeaderVisual = visual;
    var groupDepth = 0;
    for (final path in paths) {
      groupDepth = math.max(groupDepth, path.length - 1);
    }
    if (groupDepth == 0) return _preparedGroupHeaders = const [];

    final rows = <List<({int start, int end, ElTableColumn? column})>>[];
    for (var depth = 0; depth < groupDepth; depth++) {
      final spans = <({int start, int end, ElTableColumn? column})>[];
      var start = 0;
      ElTableColumn? current;
      var currentBand = -1;
      for (var visualIndex = 0; visualIndex < visual.length; visualIndex++) {
        final path = paths[visual[visualIndex]];
        final column = depth < path.length - 1 ? path[depth] : null;
        final band = _headerBandOf(visualIndex, visual.length);
        if (visualIndex == 0) {
          current = column;
          currentBand = band;
        } else if (!identical(current, column) || currentBand != band) {
          spans.add((start: start, end: visualIndex, column: current));
          start = visualIndex;
          current = column;
          currentBand = band;
        }
      }
      if (visual.isNotEmpty) spans.add((start: start, end: visual.length, column: current));
      rows.add(List.unmodifiable(spans));
    }
    return _preparedGroupHeaders = List.unmodifiable(rows);
  }

  Widget _groupHeaderCell(ElTableStyle style, ElTableColumn? column, int columnSpan) {
    var cellStyle = _groupHeaderCellStyle(style, column);
    if (column == null) return _cellBox(cellStyle, null);
    final controller = widget.controller;
    if (_columnReorder?.sourceTopLevelIndex == controller._topLevelIndexOfColumn(column)) {
      cellStyle = style.draggingHeaderCell.merge(cellStyle);
    }
    final content = _contentWidget(style, controller.headerContentOf(context, column, -1));
    final resolvedContent = content is Widget ? content : ElView(child: content);
    final defaultCell = _cellBox(cellStyle, content);
    final builder = widget.headerCellBuilder;
    if (builder == null) return defaultCell;
    return builder(
      context,
      ElTableHeaderCellScope(
        header: controller.headerCellOf(column, -1),
        content: resolvedContent,
        defaultCell: defaultCell,
        sortable: false,
        sorted: false,
        ascending: null,
        toggleSort: null,
        sort: null,
        clearSort: null,
        isGroup: true,
        columnSpan: columnSpan,
      ),
    );
  }

  int _headerBandOf(int visualIndex, int length) {
    if (_projectedHorizontal != true) return 0;
    if (visualIndex < _leftColumns.length) return -1;
    if (visualIndex >= length - _rightColumns.length) return 1;
    return 0;
  }

  ElStyle _groupHeaderCellStyle(ElTableStyle style, ElTableColumn? column) {
    final align = column?.headerAlign ?? column?.align ?? TextAlign.center;
    final extension = column?.headerStyle;
    return ElStyle(
      padding: style.cellPadding,
      alignment: _alignmentFor(align),
      textAlign: align,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    ).merge(style.cell).merge(_columnDividerStyle).merge(extension);
  }

  Widget _summaryRow(
    ElTableStyle style,
    List<_TableColumnPlan> plans,
    List<int> visual,
    _TableGridRowMode mode,
    double height,
    bool columnVirtual,
  ) {
    final controller = widget.controller;
    final builder = controller.summaryBuilder!;
    return ElView(
      style: style.summary,
      event: mode == _TableGridRowMode.selfShift ? ElEvent(onPointerSignal: _forwardWheel) : null,
      child: _gridRow(
        mode: mode,
        rowHeight: height,
        columnVirtual: columnVirtual,
        cellCount: visual.length,
        cellBuilder: (context, visualIndex) {
          final plan = plans[visual[visualIndex]];
          final content = builder(
            context,
            ElTableSummaryCell(
              controller: controller,
              column: plan.column,
              columnKey: plan.key,
              columnIndex: plan.index,
              data: controller.data,
            ),
          );
          return _cellBox(_dataCellStyleAt(visualIndex), _contentWidget(style, content));
        },
      ),
    );
  }

  Widget _dataRow(
    ElTableStyle style,
    ElTableRow row,
    int rowIndex,
    List<_TableColumnPlan> plans,
    List<int> visual,
    _TableGridRowMode mode,
    double? defaultHeight,
    double minRowHeight,
    bool columnVirtual,
  ) {
    final controller = widget.controller;
    final key = controller.rowKeyOf(row);
    final expansionPlan = _expansionPlan;
    final expanded = expansionPlan != null && controller.isExpanded(row);
    final itemKey = ValueKey<Object>(key);
    final rowHeight = controller._rowHeights[key] ?? defaultHeight;
    final canHostCells = _event?.onCellTap == null;
    final hostedCells = !columnVirtual && canHostCells ? _hostedCells(row, rowIndex, plans, visual) : null;
    final _TableHostedCellBuilder? hostedCellBuilder = canHostCells && (columnVirtual || hostedCells == null)
        ? (visualIndex) => _hostedCell(row, rowIndex, plans, visual, visualIndex)
        : null;
    final rowStyleBuilder = controller.rowStyleBuilder;
    final needsInteraction = _handlesRowInteraction;
    final rowContext = rowStyleBuilder != null || needsInteraction
        ? ElTableRowContext(controller: controller, row: row, rowKey: key, rowIndex: rowIndex)
        : null;
    var baseRowStyle = _rowStyle;
    final stripeRowStyle = _stripeRowStyle;
    if (stripeRowStyle != null && rowIndex.isOdd) baseRowStyle = baseRowStyle.merge(stripeRowStyle);
    if (style.highlightCurrentRow && controller.currentRowKey == key) {
      baseRowStyle = baseRowStyle.merge(_currentRowStyle);
    }
    final rowStyle = baseRowStyle.merge(rowStyleBuilder?.call(rowContext!));
    Widget gridRow = _gridRow(
      mode: mode,
      rowHeight: rowHeight,
      rowId: controller.rowResizable ? key : null,
      rowContext: needsInteraction ? rowContext : null,
      hostedCells: hostedCells,
      hostedCellBuilder: hostedCellBuilder,
      parentLayered: true,
      columnVirtual: columnVirtual,
      cellCount: visual.length,
      cellBuilder: (context, visualIndex) =>
          _dataCell(style, row, key, rowIndex, plans[visual[visualIndex]], visualIndex),
    );
    if (controller.rowResizable) {
      gridRow = ElStackView(
        fit: StackFit.passthrough,
        children: [
          gridRow,
          ElPositioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: math.min(style.resizeHitSize, rowHeight ?? minRowHeight),
            child: _rowResizeHandle(style, key),
          ),
        ],
      );
    }
    final Widget rowView = _TableRowView(key: expanded ? null : itemKey, style: rowStyle, child: gridRow);
    if (!expanded) return rowView;

    final cell = expansionPlan.cellOf(controller, row, key, rowIndex);
    final detail = ElView(
      key: _expandedDetailKeys.putIfAbsent(key, () => GlobalKey(debugLabel: 'el-table-expanded-$key')),
      style: _expandedStyle,
      child: _contentWidget(style, expansionPlan.expandedContentOf(context, cell)),
    );
    final detailRow = mode == _TableGridRowMode.plain
        ? detail
        : _TableGridRow(coordinator: _grid, mode: mode, freezeAll: true, children: [detail]);
    return Column(
      key: itemKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: mode == _TableGridRowMode.plain ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [rowView, detailRow],
    );
  }

  Widget _gridRow({
    required _TableGridRowMode mode,
    required double? rowHeight,
    Object? rowId,
    ElTableRowContext? rowContext,
    List<_TableHostedCell>? hostedCells,
    _TableHostedCellBuilder? hostedCellBuilder,
    bool parentLayered = false,
    required bool columnVirtual,
    required int cellCount,
    required IndexedWidgetBuilder cellBuilder,
  }) {
    // 稀疏挂载（列虚拟化 / 混合托管懒建）只挂载窗口内列，行高必须由外部给定：
    // 动态行高靠全列实测得到，稀疏挂载只测到窗口内列，行高会随横向滚动漂移。
    // rowHeight == null 时整行退回稠密 children（与行原语「列虚拟化行必须定高」
    // 的断言同一语义）——autoRowHeight 与列虚拟化互斥，避让的是动态行高这条。
    final lazyCells = columnVirtual || (hostedCellBuilder != null && rowHeight != null);
    final sparseHostedBuilder = lazyCells ? hostedCellBuilder : null;
    return _TableGridRow(
      coordinator: _grid,
      mode: mode,
      rowHeight: rowHeight,
      bandDividerColor: _fixedDividerColor,
      bandDividerWidth: _fixedDividerWidth,
      bandShadow: _fixedColumnShadow,
      resizeId: rowId,
      interactionData: rowContext,
      hostedCells: hostedCells,
      hostedCellBuilder: sparseHostedBuilder,
      windowed: columnVirtual,
      parentLayered: parentLayered,
      cellBuilder: lazyCells ? cellBuilder : null,
      cellCount: lazyCells ? cellCount : null,
      children: lazyCells || hostedCells != null
          ? const []
          : [for (var index = 0; index < cellCount; index++) cellBuilder(context, index)],
    );
  }

  List<_TableHostedCell>? _hostedCells(ElTableRow row, int rowIndex, List<_TableColumnPlan> plans, List<int> visual) {
    final result = <_TableHostedCell>[];
    for (var visualIndex = 0; visualIndex < visual.length; visualIndex++) {
      final cell = _hostedCell(row, rowIndex, plans, visual, visualIndex);
      if (cell == null) return null;
      result.add(cell);
    }
    return result;
  }

  _TableHostedCell? _hostedCell(
    ElTableRow row,
    int rowIndex,
    List<_TableColumnPlan> plans,
    List<int> visual,
    int visualIndex,
  ) {
    final plan = plans[visual[visualIndex]];
    if (plan.requiresContentContext && !plan.canHostIndex) return null;
    final controller = widget.controller;
    var style = _dataCellStyleAt(visualIndex);
    final styleBuilder = plan.cellStyleBuilder;
    if (styleBuilder != null) {
      final cell = plan.cellOf(widget.controller, row, widget.controller.rowKeyOf(row), rowIndex);
      final extension = styleBuilder(cell);
      if (extension != null) style = style.merge(extension);
    }
    final value = plan.canHostIndex
        ? (
            totalRows: controller.data.length,
            firstNumber: plan.column.index is int ? plan.column.index as int : 1,
            rowIndex: rowIndex,
            environment: _indexTextEnvironmentFor(style),
            textAlign: plan.column.indexTextAlign,
          )
        : plan.hostedValueOf(controller, row, rowIndex);
    if (value is Widget || value is InlineSpan || value is Iterable) return null;
    return _TableHostedCell(style, value);
  }

  _TableHostedCell? _hostedHeaderCell(_TableColumnPlan plan, int visualIndex) {
    if (widget.columnReorderable ||
        widget.headerCellBuilder != null ||
        plan.headerBuilder != null ||
        plan.column.type != null ||
        (plan.resizable ?? _preparedStyle!.columnResizable) ||
        plan.column.sort) {
      return null;
    }
    final content = plan.column.title;
    if (content is Widget || content is InlineSpan || content is Iterable) return null;
    final style = _headerCellStyleAt(visualIndex);
    return _TableHostedCell(style, content);
  }

  Widget _headerCell(ElTableStyle style, _TableColumnPlan plan, int visualIndex, double resizeHitSize) {
    final controller = widget.controller;
    final content = plan.headerContentOf(context, controller);
    final resolvedContent = _resolvedHeaderContent(style, plan, content);
    final scopeContent = resolvedContent is Widget ? resolvedContent : ElView(child: resolvedContent);
    final sort = controller.sortState;
    final sorted = sort?.columnKey == plan.key;
    final ascending = sorted ? sort!.ascending : null;
    final cellStyle = _headerCellStyleAt(visualIndex);
    final topLevelIndex = controller._topLevelIndexOfColumnKey(plan.key);
    final reorderable = widget.columnReorderable && topLevelIndex >= 0;
    final dragging = _columnReorder?.sourceTopLevelIndex == topLevelIndex;
    final headerKey = reorderable ? _headerCellKeys.putIfAbsent(plan.key, GlobalKey.new) : null;
    final reorderEvent = reorderable ? _columnReorderEvent(plan) : null;
    final interactiveCellStyle = dragging ? style.draggingHeaderCell.merge(cellStyle) : cellStyle;
    final defaultCell = plan.column.sort
        ? ElButtonView(
            key: headerKey,
            semanticLabel: '排序 ${plan.column.title ?? ''}，${sorted ? (ascending! ? '升序' : '降序') : '未排序'}',
            onPressed: () => _toggleSort(plan),
            style: interactiveCellStyle.merge(
              reorderable ? const ElStyle() : const ElStyle(cursor: SystemMouseCursors.click),
            ),
            event: reorderEvent,
            child: _headerContent(
              style,
              resolvedContent,
              align: plan.headerAlign,
              sorted: sorted,
              ascending: ascending,
            ),
          )
        : _cellBox(interactiveCellStyle, resolvedContent, key: headerKey, event: reorderEvent);
    final builder = widget.headerCellBuilder;
    Widget cell = builder == null
        ? defaultCell
        : builder(
            context,
            ElTableHeaderCellScope(
              header: ElTableHeaderCell(
                controller: controller,
                column: plan.column,
                columnKey: plan.key,
                columnIndex: plan.index,
              ),
              content: scopeContent,
              defaultCell: defaultCell,
              sortable: plan.column.sort,
              sorted: sorted,
              ascending: ascending,
              toggleSort: plan.column.sort ? () => _toggleSort(plan) : null,
              sort: plan.column.sort ? (value) => _setSort(plan.key, value) : null,
              clearSort: sorted && !controller.sortRequired ? _clearSort : null,
            ),
          );
    if (!(plan.resizable ?? style.columnResizable)) return cell;
    cell = ElStackView(
      fit: StackFit.passthrough,
      children: [
        cell,
        ElPositioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: resizeHitSize,
          child: _columnResizeHandle(style, plan.column, visualIndex),
        ),
      ],
    );
    return cell;
  }

  Object? _resolvedHeaderContent(ElTableStyle style, _TableColumnPlan plan, Object? content) {
    return content is ElTableSelectionControl
        ? _selectionControl(style, content, headerColumn: plan.column)
        : _contentWidget(style, content);
  }

  Object? _headerContent(
    ElTableStyle style,
    Object? content, {
    required TextAlign? align,
    required bool sorted,
    required bool? ascending,
  }) {
    if (!sorted) return content;
    final contentWidget = content is Widget ? content : ElView(child: content);
    final sortWidth = style.sort.width;
    final leftInset = (sortWidth is num ? sortWidth.toDouble() : 20.0) + 6;
    final leftAligned = align != TextAlign.center && align != TextAlign.right && align != TextAlign.end;
    return ElStackView(
      fit: StackFit.expand,
      children: [
        ElView(
          style: ElStyle(
            alignment: _alignmentFor(align),
            padding: leftAligned ? .only(left: leftInset) : null,
          ),
          child: contentWidget,
        ),
        ElPositioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: _TableSortIndicator(style: style.sort.merge(style.sortActive), ascending: ascending!),
        ),
      ],
    );
  }

  Widget _dataCell(
    ElTableStyle style,
    ElTableRow row,
    Object rowKey,
    int rowIndex,
    _TableColumnPlan plan,
    int visualIndex,
  ) {
    final controller = widget.controller;
    final onCellTap = _event?.onCellTap;
    if (!plan.requiresCellContext && onCellTap == null) {
      return _cellBox(_dataCellStyleAt(visualIndex), plan.valueOf(row));
    }
    final cell = plan.cellOf(controller, row, rowKey, rowIndex);
    final extension = plan.styleOf(cell);
    final cellStyle = extension == null
        ? _dataCellStyleAt(visualIndex)
        : _dataCellStyleAt(visualIndex).merge(extension);
    if (plan.canHostIndex) {
      final start = plan.column.index is int ? plan.column.index as int : 1;
      final environment = _indexTextEnvironmentFor(cellStyle);
      return _cellBox(
        cellStyle,
        OrdinalGutterHost.single(
          totalRows: controller.data.length,
          firstNumber: start,
          rowIndex: rowIndex,
          textAlign: plan.column.indexTextAlign,
          style: environment.style,
          textDirection: environment.direction,
          textScaler: environment.scaler,
          locale: environment.locale,
        ),
        event: onCellTap == null ? null : ElEvent(onTap: (_) => onCellTap(cell)),
      );
    }
    final content = plan.contentOf(context, cell);
    return _cellBox(
      cellStyle,
      _contentWidget(style, content),
      event: onCellTap == null ? null : ElEvent(onTap: (_) => onCellTap(cell)),
    );
  }

  Widget _cellBox(ElStyle style, Object? child, {Key? key, ElEvent? event}) =>
      ElView(key: key, style: style, event: event, child: child);

  _IndexTextEnvironment _indexTextEnvironmentFor(ElStyle style) {
    final base = widget.controller._indexTextEnvironment!;

    return (
      style: base.style.merge(elStyleToTextStyle(style)),
      scaler: base.scaler,
      direction: base.direction,
      locale: base.locale,
    );
  }

  Object? _contentWidget(ElTableStyle style, Object? content) => switch (content) {
    ElTableSelectionControl control => _selectionControl(style, control),
    ElTableExpansionControl control => _expansionControl(style, control),
    Widget widget => widget,
    _ => content,
  };

  Widget _selectionControl(ElTableStyle style, ElTableSelectionControl control, {ElTableColumn? headerColumn}) {
    final active = control.checked || control.indeterminate;
    return ElButtonView(
      disabled: control.disabled,
      selected: active,
      semanticLabel: control.isHeader ? '全选' : '选择行 ${(control.rowIndex ?? 0) + 1}',
      onPressed: () => _toggleSelection(control, headerColumn: headerColumn),
      style: ElStyle(width: style.controlHitSize, height: style.controlHitSize, alignment: .center),
      event: ElEvent(onTapDown: (event) => event.stopPropagation(), onTap: (event) => event.stopPropagation()),
      child: ElView(
        style: active ? style.selection.merge(style.selectionActive) : style.selection,

        child: control.indeterminate
            ? const ElView(style: ElStyle(width: 8, height: 2, bgColor: Color(0xffffffff)))
            : control.checked
            ? ElView(
                style: ElStyle(
                  width: 4,
                  height: 8,
                  margin: .only(bottom: 2),
                  transform: .rotate(0.7853981633974483),
                  border: ElBorder.only(
                    right: ElBorderSide(width: 1.6, color: Color(0xffffffff)),
                    bottom: ElBorderSide(width: 1.6, color: Color(0xffffffff)),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _expansionControl(ElTableStyle style, ElTableExpansionControl control) {
    return ElButtonView(
      disabled: control.disabled,
      selected: control.expanded,
      semanticLabel: '${control.expanded ? '收起' : '展开'}行 ${control.rowIndex + 1}',
      onPressed: () => _toggleExpansion(control),
      style: style.expand,
      event: ElEvent(onTapDown: (event) => event.stopPropagation(), onTap: (event) => event.stopPropagation()),
      child: ElView(
        style: ElStyle(
          width: 7,
          height: 10,
          bgColor: style.expand.color ?? const Color(0xff727984),
          clipper: _TableTriangleClipper(AxisDirection.right),
          transform: control.expanded ? ElTransform.rotate(math.pi / 2) : null,
          transitions: const [ElTransition.field(ElTransitionField.transform, Duration(milliseconds: 160))],
        ),
      ),
    );
  }

  ElEvent _columnReorderEvent(_TableColumnPlan plan) => ElEvent(
    onHorizontalDragStart: (event) {
      final session = _createColumnReorderSession(plan, event.globalPosition);
      if (session == null || !_grid.beginColumnReorder(session.sourceVisualStart, session.sourceVisualEnd)) return;
      event.eagerGesture(cancelSelfTap: true);
      setState(() => _columnReorder = session);
      _updateColumnReorder(event.globalPosition);
    },
    onHorizontalDragUpdate: (event) => _updateColumnReorder(event.globalPosition),
    onHorizontalDragEnd: (event) => _settleColumnReorder(event.globalPosition),
    onHorizontalDragCancel: (_) => _cancelColumnReorder(),
  );

  _TableColumnReorderSession? _createColumnReorderSession(_TableColumnPlan sourcePlan, Offset pointer) {
    final controller = widget.controller;
    final sourceTopLevelIndex = controller._topLevelIndexOfColumnKey(sourcePlan.key);
    if (sourceTopLevelIndex < 0) return null;
    final sourceFixed = controller._columnFixedOfKey(sourcePlan.key);
    final visualByTopLevel = <int, List<int>>{};
    final fixedByTopLevel = <int, Set<ElTableColumnFixed?>>{};
    for (var visualIndex = 0; visualIndex < _visualColumns.length; visualIndex++) {
      final plan = _columnPlans[_visualColumns[visualIndex]];
      final topLevelIndex = controller._topLevelIndexOfColumnKey(plan.key);
      if (topLevelIndex < 0) continue;
      visualByTopLevel.putIfAbsent(topLevelIndex, () => <int>[]).add(visualIndex);
      fixedByTopLevel.putIfAbsent(topLevelIndex, () => <ElTableColumnFixed?>{}).add(plan.column.fixed);
    }
    final sourceVisual = visualByTopLevel[sourceTopLevelIndex];
    if (sourceVisual == null ||
        sourceVisual.isEmpty ||
        fixedByTopLevel[sourceTopLevelIndex]?.length != 1 ||
        fixedByTopLevel[sourceTopLevelIndex]?.single != sourceFixed ||
        !_isContinuousVisualRange(sourceVisual)) {
      return null;
    }

    final targets = <_TableColumnReorderTarget>[];
    Rect? bandRect;
    for (final entry in visualByTopLevel.entries) {
      final indices = entry.value;
      final fixed = fixedByTopLevel[entry.key];
      if (fixed?.length != 1 || fixed!.single != sourceFixed || !_isContinuousVisualRange(indices)) continue;
      Rect? rect;
      for (final visualIndex in indices) {
        final plan = _columnPlans[_visualColumns[visualIndex]];
        final render = _headerCellKeys[plan.key]?.currentContext?.findRenderObject();
        if (render is! RenderBox || !render.attached || !render.hasSize) {
          rect = null;
          break;
        }
        final cellRect = render.localToGlobal(Offset.zero) & render.size;
        rect = rect == null ? cellRect : rect.expandToInclude(cellRect);
      }
      if (rect == null) continue;
      final target = _TableColumnReorderTarget(
        topLevelIndex: entry.key,
        visualStart: indices.first,
        visualEnd: indices.last + 1,
        rect: rect,
      );
      targets.add(target);
      bandRect = bandRect == null ? rect : bandRect.expandToInclude(rect);
    }
    _TableColumnReorderTarget? sourceTarget;
    for (final target in targets) {
      if (target.topLevelIndex == sourceTopLevelIndex) {
        sourceTarget = target;
        break;
      }
    }
    if (sourceTarget == null || bandRect == null || targets.length < 2) return null;
    targets.sort((a, b) => a.rect.left.compareTo(b.rect.left));
    return _TableColumnReorderSession(
      sourceKey: controller.columnOrderKeys[sourceTopLevelIndex],
      sourceTopLevelIndex: sourceTopLevelIndex,
      sourceVisualStart: sourceTarget.visualStart,
      sourceVisualEnd: sourceTarget.visualEnd,
      sourceRect: sourceTarget.rect,
      pointerStartX: pointer.dx,
      minOffset: bandRect.left - sourceTarget.rect.left,
      maxOffset: bandRect.right - sourceTarget.rect.right,
      targets: List<_TableColumnReorderTarget>.unmodifiable(targets),
      columnRevision: controller._columnRevision,
    );
  }

  static bool _isContinuousVisualRange(List<int> indices) {
    for (var index = 1; index < indices.length; index++) {
      if (indices[index] != indices[index - 1] + 1) return false;
    }
    return true;
  }

  void _updateColumnReorder(Offset pointer) {
    final session = _columnReorder;
    if (session == null) return;
    final rawOffset = pointer.dx - session.pointerStartX;
    final sourceOffset = rawOffset.clamp(session.minOffset, session.maxOffset).toDouble();
    final draggedCenter = session.sourceRect.center.dx + sourceOffset;
    var target = session.targets.first;
    var nearestDistance = double.infinity;
    for (final candidate in session.targets) {
      final distance = (candidate.rect.center.dx - draggedCenter).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        target = candidate;
      }
    }
    session.target = target;
    _grid.updateColumnReorder(sourceOffset: sourceOffset, targetStart: target.visualStart, targetEnd: target.visualEnd);
  }

  void _settleColumnReorder(Offset pointer) {
    final session = _columnReorder;
    if (session == null) return;
    _updateColumnReorder(pointer);
    if (session.target.topLevelIndex == session.sourceTopLevelIndex) {
      _grid.cancelColumnReorder(() => _finishColumnReorder(session, commit: false));
      return;
    }
    _grid.settleColumnReorder(() => _finishColumnReorder(session, commit: true));
  }

  void _cancelColumnReorder() {
    final session = _columnReorder;
    if (session == null) return;
    _grid.cancelColumnReorder(() => _finishColumnReorder(session, commit: false));
  }

  void _finishColumnReorder(_TableColumnReorderSession session, {required bool commit}) {
    if (!identical(_columnReorder, session)) return;
    _grid.clearColumnReorder();
    _columnReorder = null;
    final changed = commit && widget.controller.moveColumnTo(session.sourceKey, session.target.topLevelIndex);
    if (changed) {
      _event?.onColumnOrderChanged?.call(widget.controller.columnOrderKeys);
    } else if (mounted) {
      setState(() {});
    }
  }

  void _clearColumnReorderImmediately() {
    _columnReorder = null;
    _grid.clearColumnReorder();
  }

  Widget _columnResizeHandle(ElTableStyle style, ElTableColumn column, int visualIndex) {
    return ElView(
      style: style.resize,
      semantics: ElSemantics(label: '调整列宽 ${column.title ?? column.prop ?? visualIndex + 1}'),
      event: ElEvent(
        onTapDown: (event) {
          _columnResizePointerStart = event.globalPosition.dx;
          event.stopPropagation();
        },
        onTap: (event) => event.stopPropagation(),
        onHorizontalDragStart: (event) {
          event.stopPropagation();
          event.eagerGesture(cancelSelfTap: true);
          _columnResizeBase = _grid.beginColumnResize(visualIndex);
          _columnResizeFloor = widget.controller.columnMinWidthOf(column) ?? 40;
        },
        onHorizontalDragUpdate: (event) {
          final base = _columnResizeBase;
          if (base == null) return;
          final delta = event.globalPosition.dx - (_columnResizePointerStart ?? event.globalPosition.dx);
          _grid.updateColumnResize(visualIndex, (base + delta).clamp(_columnResizeFloor, double.infinity));
        },
        onHorizontalDragEnd: (_) => _commitColumnResize(),
        onHorizontalDragCancel: (_) => _cancelColumnResize(),
      ),
    );
  }

  Widget _rowResizeHandle(ElTableStyle style, Object rowKey) {
    return ElView(
      style: style.rowResize,
      semantics: ElSemantics(label: '调整行高'),
      event: ElEvent(
        onTapDown: (event) => event.stopPropagation(),
        onTap: (event) => event.stopPropagation(),
        onVerticalDragStart: (event) {
          event.eagerGesture(cancelSelfTap: true);
          _rowResizeBase = _grid.rowById(rowKey)?.size.height;
        },
        onVerticalDragUpdate: (event) {
          final base = _rowResizeBase;
          if (base == null) return;
          _grid.rowById(rowKey)?.liveHeight = (base + event.dragOffset.dy).clamp(20, double.infinity);
        },
        onVerticalDragEnd: (_) => _commitRowResize(rowKey),
        onVerticalDragCancel: (_) => _cancelRowResize(rowKey),
      ),
    );
  }

  void _commitColumnResize() {
    _columnResizeBase = null;
    _columnResizePointerStart = null;
    final live = _grid.takeLiveResize();
    _grid.clearLiveResize();
    if (live.isNotEmpty) {
      final widths = Map<Object, double>.of(widget.controller._columnWidths);
      for (final entry in live.entries) {
        if (entry.key < 0 || entry.key >= _visualColumns.length) continue;
        final columnIndex = _visualColumns[entry.key];
        widths[_columnPlans[columnIndex].key] = entry.value;
      }
      widget.controller.columnWidths = widths;
      _event?.onColumnWidthsChanged?.call(Map<Object, double>.unmodifiable(widths));
    }
    _syncHorizontalOverflow();
  }

  void _cancelColumnResize() {
    _columnResizeBase = null;
    _columnResizePointerStart = null;
    _grid.clearLiveResize();
    _syncHorizontalOverflow();
  }

  void _commitRowResize(Object rowKey) {
    _rowResizeBase = null;
    final render = _grid.rowById(rowKey);
    final height = render?.liveHeight;
    render?.liveHeight = null;
    if (height != null) {
      widget.controller.setRowHeight(rowKey, height);
      _event?.onRowHeightsChanged?.call(Map<Object, double>.unmodifiable(widget.controller.rowHeights));
    }
    _syncHorizontalOverflow();
  }

  void _cancelRowResize(Object rowKey) {
    _rowResizeBase = null;
    _grid.rowById(rowKey)?.liveHeight = null;
    _syncHorizontalOverflow();
  }

  void _setSort(Object columnKey, bool ascending) {
    widget.controller.sort(columnKey, ascending: ascending);
    _event?.onSort?.call(ElTableSort(columnKey: columnKey, ascending: ascending));
  }

  /// 表头点击的三态循环：未排序 → 列初始方向 → 反向 → 清除。
  /// [ElTableController.sortRequired] 为 true 时第三态不回未排序，退回列初始方向（只在升⇄降之间切）。
  void _toggleSort(_TableColumnPlan plan) {
    final controller = widget.controller;
    final current = controller.sortState;
    final initial = plan.column.initialSortAscending;
    if (current == null || current.columnKey != plan.key) {
      _setSort(plan.key, initial);
      return;
    }
    if (current.ascending == initial) {
      _setSort(plan.key, !initial);
      return;
    }
    if (controller.sortRequired) {
      _setSort(plan.key, initial);
      return;
    }
    _clearSort();
  }

  void _clearSort() {
    if (widget.controller.sortRequired) return;
    widget.controller.clearSort();
    _event?.onClearSort?.call();
  }

  void _toggleSelection(ElTableSelectionControl control, {ElTableColumn? headerColumn}) {
    if (control.disabled) return;
    ElTableRowContext? changedRow;
    bool? selected;
    if (control.isHeader) {
      widget.controller.toggleAllSelection(where: headerColumn?.selectable);
    } else {
      widget.controller.toggleSelection(control.row!);
      selected = widget.controller.isSelected(control.row!);
      changedRow = ElTableRowContext(
        controller: widget.controller,
        row: control.row!,
        rowKey: control.rowKey!,
        rowIndex: control.rowIndex!,
      );
    }
    _event?.onSelectionChanged?.call(
      ElTableSelectionChange(controller: widget.controller, row: changedRow, selected: selected),
    );
  }

  void _selectCurrent(ElTableRow row) {
    if (widget.controller.currentRowKey == widget.controller.rowKeyOf(row)) return;
    widget.controller.currentRow = row;
    _event?.onCurrentChanged?.call(row);
  }

  void _handleFocusKey(ElEventDetails callback) {
    final key = callback.logicalKey;
    if (key == null) return;
    final rows = <ElTableRow>[..._pinnedRows, ..._displayRows];
    if (rows.isEmpty) return;

    final controller = widget.controller;
    final currentKey = controller.currentRowKey;
    final currentIndex = currentKey == null ? -1 : rows.indexWhere((row) => controller.rowKeyOf(row) == currentKey);
    final rowHeight = _positive(_activeStyle.rowHeight, 40, 'ElTableStyle.rowHeight');
    final pageStep = math.max(1, ((widget.height ?? rowHeight * 10) / rowHeight).floor() - 1);
    int? nextIndex;
    if (key == LogicalKeyboardKey.arrowDown) {
      nextIndex = currentIndex < 0 ? 0 : math.min(rows.length - 1, currentIndex + 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      nextIndex = currentIndex < 0 ? rows.length - 1 : math.max(0, currentIndex - 1);
    } else if (key == LogicalKeyboardKey.home) {
      nextIndex = 0;
    } else if (key == LogicalKeyboardKey.end) {
      nextIndex = rows.length - 1;
    } else if (key == LogicalKeyboardKey.pageDown) {
      nextIndex = currentIndex < 0 ? 0 : math.min(rows.length - 1, currentIndex + pageStep);
    } else if (key == LogicalKeyboardKey.pageUp) {
      nextIndex = currentIndex < 0 ? rows.length - 1 : math.max(0, currentIndex - pageStep);
    }
    if (nextIndex == null) return;

    final row = rows[nextIndex];
    _selectCurrent(row);
    unawaited(_scrollToRow(controller.rowKeyOf(row)));
    callback
      ..preventDefault()
      ..stopPropagation();
  }

  void _toggleExpansion(ElTableExpansionControl control) {
    if (control.disabled) return;
    widget.controller.toggleExpansion(control.row);
    _event?.onExpansionChanged?.call(control.row, widget.controller.isExpanded(control.row));
  }

  ElEvent? get _rowInteractionEvent {
    final event = _event;
    final handlesTap = widget.focusNode != null || event?.onCurrentChanged != null || event?.onRowTap != null;
    if (!handlesTap && event?.onRowDoubleTap == null && event?.onRowSecondaryTap == null) return null;
    return ElEvent(
      onTap: !handlesTap
          ? null
          : (callback) {
              final row = _rowAt(callback.globalPosition);
              if (row != null) {
                _handleRowTap(row);
                callback.stopPropagation();
              }
            },
      onDoubleTap: event?.onRowDoubleTap == null
          ? null
          : (callback) {
              final row = _rowAt(callback.globalPosition);
              if (row != null) {
                _syncCurrentRowBeforeRowAction(row);
                event!.onRowDoubleTap!(row);
                callback.stopPropagation();
              }
            },
      onSecondaryTap: event?.onRowSecondaryTap == null
          ? null
          : (callback) {
              final row = _rowAt(callback.globalPosition);
              if (row != null) {
                _syncCurrentRowBeforeRowAction(row);
                event!.onRowSecondaryTap!(row, callback.globalPosition);
                callback.stopPropagation();
              }
            },
    );
  }

  /// 双击 / 右键数据行时，在派发用户回调前先把该行设为当前行。
  ///
  /// 这是旧 WinTable 薄壳在转发 `onRowDoubleTap` / `onRowSecondaryTap` 前做的同一件事，
  /// 薄壳删除后由底层承接（作者 2026-09-18 拍板）：声明了这两个回调的调用方，
  /// 在回调里读到的 `controller.currentRow` 已经是该行。
  /// 只写 `currentRow`、不派发 `onCurrentChanged`，与旧行为一致；
  /// 也不影响 `onRowTap` 等其它回调（它们各自同步）。
  void _syncCurrentRowBeforeRowAction(ElTableRowContext row) {
    widget.controller.currentRow = row.row;
  }

  bool get _handlesRowInteraction => _handlesRowEvents;

  ElTableRowContext? _rowAt(Offset globalPosition) {
    return _grid.rowAtGlobalPosition(globalPosition);
  }

  void _handleRowTap(ElTableRowContext row) {
    _selectCurrent(row.row);
    _event?.onRowTap?.call(row);
  }

  void _forwardWheel(ElEventDetails callback) {
    final original = callback.originalEvent;
    if (original is! PointerScrollEvent) return;
    if (_verticalController.hasClients && original.scrollDelta.dy != 0) {
      final position = _verticalController.position;
      position.jumpTo(
        (position.pixels + original.scrollDelta.dy).clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
    final horizontal = _horizontalController;
    if (horizontal != null && horizontal.hasClients && original.scrollDelta.dx != 0) {
      final position = horizontal.position;
      position.jumpTo(
        (position.pixels + original.scrollDelta.dx).clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
  }

  Widget _empty(ElTableStyle style, double rowHeight) {
    final controller = widget.controller;
    // 自然高度表格会给 auto 宽子项松约束，空状态必须显式使用整表宽度。
    // 空态内容只有 controller.emptyBuilder 一个入口，外观由 style.empty / emptyHeight 决定。
    return ElView(
      style: ElStyle(
        width: '100%',
        height: style.emptyHeight ?? rowHeight * 2,
        alignment: .center,
        textAlign: .center,
      ).merge(style.empty),
      child: controller.emptyBuilder?.call(context, controller),
    );
  }

  Future<bool> _scrollToRow(Object rowKey) async {
    for (final row in _pinnedRows) {
      if (widget.controller.rowKeyOf(row) == rowKey) return true;
    }
    final index = _displayRows.indexWhere((row) => widget.controller.rowKeyOf(row) == rowKey);
    if (index < 0 || widget.height == null) return false;
    if (!_verticalController.hasClients) {
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted || !_verticalController.hasClients) return false;
    }
    // 行虚拟化恒开，按行窗口定位即可。
    await _verticalController.scrollToIndex(index);
    return true;
  }

  void _scheduleCurrentRowReveal(Object? rowKey) {
    if (rowKey == null) return;
    final generation = ++_currentRowRevealGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _currentRowRevealGeneration || widget.controller.currentRowKey != rowKey) {
        return;
      }
      unawaited(_scrollToRow(rowKey));
    });
  }

  static Alignment _alignmentFor(TextAlign? align) => switch (align) {
    TextAlign.center => .center,
    TextAlign.right || TextAlign.end => .centerRight,
    _ => .centerLeft,
  };
}

class _TableColumnReorderSession {
  _TableColumnReorderSession({
    required this.sourceKey,
    required this.sourceTopLevelIndex,
    required this.sourceVisualStart,
    required this.sourceVisualEnd,
    required this.sourceRect,
    required this.pointerStartX,
    required this.minOffset,
    required this.maxOffset,
    required this.targets,
    required this.columnRevision,
  }) : target = targets.first;

  final Object sourceKey;
  final int sourceTopLevelIndex;
  final int sourceVisualStart;
  final int sourceVisualEnd;
  final Rect sourceRect;
  final double pointerStartX;
  final double minOffset;
  final double maxOffset;
  final List<_TableColumnReorderTarget> targets;
  final int columnRevision;
  _TableColumnReorderTarget target;
}

class _TableColumnReorderTarget {
  const _TableColumnReorderTarget({
    required this.topLevelIndex,
    required this.visualStart,
    required this.visualEnd,
    required this.rect,
  });

  final int topLevelIndex;
  final int visualStart;
  final int visualEnd;
  final Rect rect;
}
