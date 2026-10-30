part of 'table.dart';

/// 一次用户选择变化；完整选择集合通过 controller 惰性读取，单行交互不扫描全量数据。
@immutable
class ElTableSelectionChange {
  /// 创建选择变化上下文。
  const ElTableSelectionChange({required this.controller, this.row, this.selected});

  /// 当前表格控制器。
  final ElTableController controller;

  /// 单行切换时的展示行；表头全选或取消全选时为 null。
  final ElTableRowContext? row;

  /// 单行切换后的状态；批量变化时为 null。
  final bool? selected;

  /// 当前选中行键的 O(1) 不可修改视图。
  Set<Object> get selectedRowKeys => controller.selectedRowKeys;

  /// 按原始数据顺序惰性生成完整选中行；只有业务读取时才付出扫描成本。
  List<ElTableRow> get selectedRows => controller.selectedRows;
}

/// 表格用户交互事件监听器集合，程序直接调用 controller API 不触发这些回调。
@immutable
class ElTableEvent {
  /// 创建表格事件监听器集合。
  const ElTableEvent({
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
  });

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

  /// 用户双击数据行时触发；底层在派发前先把该行设为当前行。
  final ValueChanged<ElTableRowContext>? onRowDoubleTap;

  /// 用户右键数据行时触发；底层在派发前先把该行设为当前行。
  final void Function(ElTableRowContext row, Offset globalPosition)? onRowSecondaryTap;

  /// 用户单击数据单元格时触发。
  final ValueChanged<ElTableCell>? onCellTap;

  /// 用户完成表头拖拽换序时触发，参数是完整顶层列顺序快照。
  final ValueChanged<List<Object>>? onColumnOrderChanged;

  /// 用户完成列宽拖拽时触发，参数是完整列宽快照。
  final ValueChanged<Map<Object, double>>? onColumnWidthsChanged;

  /// 用户完成行高拖拽时触发，参数是完整行高快照。
  final ValueChanged<Map<Object, double>>? onRowHeightsChanged;
}
