import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter/widgets.dart';

import '../../../flutter/views/view/style/style.dart';
import 'table.dart' show ElTableController;

/// 表格行数据统一使用 Map，动态表头和运行时加列都按字段名读取。
typedef ElTableRow = Map<String, Object?>;

/// 判断业务行是否允许参与某个列类型行为，例如 selection 或 expand。
typedef ElTableRowPredicate = bool Function(ElTableRow row);

/// 格式化单元格展示值，返回值会交给上层渲染策略处理。
typedef ElTableCellFormatter = Object? Function(Object? value, ElTableCell cell);

/// 自定义表头渲染，适合列类型或上层组件库替换默认表头内容。
typedef ElTableHeaderBuilder = Object? Function(BuildContext context, ElTableHeaderCell header);

/// 自定义完整表头单元格；可直接复用默认单元格，也可接管分组内容与排序交互。
typedef ElTableHeaderCellBuilder = Widget Function(BuildContext context, ElTableHeaderCellScope header);

/// 自定义单元格渲染，适合列级 slotBuilder 或列类型按业务行、列和值生成内容。
typedef ElTableCellBuilder = Object? Function(BuildContext context, ElTableCell cell);

/// 按单元格上下文返回附加样式；null 表示只使用表格皮肤与列类型给的默认单元格样式。
typedef ElTableCellStyleBuilder = ElStyle? Function(ElTableCell cell);

/// 构建整表空状态内容；返回值按 ElView.child 的宽容口径渲染。
typedef ElTableEmptyBuilder = Object? Function(BuildContext context, ElTableController controller);

/// 按展示行返回附加样式；null 表示只使用表格皮肤中的默认行样式。
typedef ElTableRowStyleBuilder = ElStyle? Function(ElTableRowContext row);

/// 构建合计行的单元格内容；每个可见叶子列调用一次。
typedef ElTableSummaryCellBuilder = Object? Function(BuildContext context, ElTableSummaryCell cell);

/// 列固定方向，底层表格用同一份滚动真值把列投影到左侧或右侧。
enum ElTableColumnFixed {
  /// 固定在左侧。
  left,

  /// 固定在右侧。
  right,
}

/// 内置列类型；不设类型（null）时按普通数据列渲染。
///
/// 只有这三个内置值，用户不再自定义列类型；用户写法与枚举一致：
/// `ElTableColumn(type: ElTableColumnType.checkbox)` / `type: .checkbox`。
///
/// 这里没有写成 `enum`：`Enum.index` 是枚举自带的实例成员（序号），
/// 枚举值再取名叫 `index` 会与之同名冲突（`conflicting_static_and_instance`），
/// 所以用「私有构造 + 三个 const 值」表达同一个封闭集合。
@immutable
final class ElTableColumnType {
  const ElTableColumnType._(this.name);

  /// 行号列：从 1 起显示展示序号，列宽按行数位数在底层自适应。
  static const ElTableColumnType index = ElTableColumnType._('index');

  /// 行选择列：表头三态 + 行复选框。
  static const ElTableColumnType checkbox = ElTableColumnType._('checkbox');

  /// 展开列：行详情展开/收起。
  static const ElTableColumnType expanded = ElTableColumnType._('expanded');

  /// 全部内置列类型，声明顺序即此处顺序。
  static const List<ElTableColumnType> values = <ElTableColumnType>[index, checkbox, expanded];

  /// 类型标识，与 [values] 中的成员一一对应，也用于调试输出。
  final String name;

  @override
  String toString() => 'ElTableColumnType.$name';
}

/// 多选表头的聚合状态。
enum ElTableSelectionState {
  /// 没有任何可选行被选中。
  none,

  /// 部分可选行被选中，表头应展示半选态。
  partial,

  /// 全部可选行都已选中。
  all,
}

/// 排序状态对象，事件层用它避免散落的列键和方向参数。
@immutable
class ElTableSort {
  /// 创建排序状态。
  const ElTableSort({required this.columnKey, required this.ascending});

  /// 排序列身份，通常来自 [ElTableColumn.key] 或 [ElTableColumn.prop]。
  final Object columnKey;

  /// true 表示升序，false 表示降序。
  final bool ascending;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ElTableSort && other.columnKey == columnKey && other.ascending == ascending;

  @override
  int get hashCode => Object.hash(columnKey, ascending);
}

/// 标签列常用的值到展示配置映射，底层只保存配置不绑定具体视觉组件。
@immutable
class ElTableTagOption {
  /// 创建标签映射项。
  const ElTableTagOption({required this.value, this.label, this.type, this.color, this.style, this.meta});

  /// 与单元格原始值匹配的业务值。
  final Object? value;

  /// 展示内容，通常是文本，也可以由上层渲染策略解释成其他内容。
  final Object? label;

  /// 标签语义类型，具体含义由上层组件库决定。
  final Object? type;

  /// 标签颜色，底层不强制使用。
  final Color? color;

  /// 标签样式，底层不强制使用。
  final ElStyle? style;

  /// 业务侧保留的扩展数据。
  final Object? meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElTableTagOption &&
          other.value == value &&
          other.label == label &&
          other.type == type &&
          other.color == color &&
          other.style == style &&
          other.meta == meta;

  @override
  int get hashCode => Object.hash(value, label, type, color, style, meta);
}

/// 表格列配置对象；扩展靠 [type]、[slotBuilder]、[formatter] 与 [children] 完成。
@immutable
final class ElTableColumn {
  /// 创建列配置；不提供命名构造，避免把业务列类型锁死在底层包里。
  const ElTableColumn({
    this.key,
    this.type,
    this.prop,
    this.title,
    this.width,
    this.minWidth,
    this.flex,
    this.fixed,
    this.visible = true,
    this.sort = false,
    this.initialSortAscending = true,
    this.sortField,
    this.showOverflow,
    this.align,
    this.indexTextAlign = TextAlign.center,
    this.headerAlign,
    this.cellStyleBuilder,
    this.headerStyle,
    this.headerBuilder,
    this.resizable,
    this.selectable,
    this.expandable,
    this.index,
    this.slotBuilder,
    this.formatter,
    this.sorter,
    this.tagOptions,
    this.children = const [],
  }) : assert(width == null || width > 0, 'width 必须是正数。'),
       assert(minWidth == null || minWidth > 0, 'minWidth 必须是正数。'),
       assert(flex == null || flex > 0, 'flex 必须是正数。');

  /// 列稳定身份；不传时 controller 会按字段、标题与位置推导。
  final Object? key;

  /// 内置列类型；null 表示普通数据列，按 prop / slotBuilder / formatter 渲染。
  final ElTableColumnType? type;

  /// 单元格取值字段，默认 Map 行会按它读取值。
  final String? prop;

  /// 表头内容。
  final Object? title;

  /// 普通列的固定宽度，仅 type 为 null 时生效；内置列由组件统一定宽。
  final double? width;

  /// 普通弹性列或未定宽列的最小宽度，仅 type 为 null 时生效。
  final double? minWidth;

  /// 普通列未声明固定宽度时分配剩余宽度的权重，默认 1，内置列忽略。
  final double? flex;

  /// 固定列方向；null 表示参与普通横向滚动区域。
  final ElTableColumnFixed? fixed;

  /// 是否参与表格可见列解析。
  final bool visible;

  /// 是否允许用户对该列发起排序。
  final bool sort;

  /// 首次点击可排序表头时使用的方向；数值资源列通常设为 false。
  final bool initialSortAscending;

  /// 排序提交给外部系统时使用的字段名，不声明时通常回退到 [prop]。
  final String? sortField;

  /// 内容溢出策略开关，具体展示由上层组件库决定。
  final bool? showOverflow;

  /// 数据单元格对齐方式。
  final TextAlign? align;

  /// 内置行号在总序号测量宽度内的数字对齐，默认居中；整体位置仍由 [align] 控制。
  final TextAlign indexTextAlign;

  /// 表头单元格对齐方式，null 时跟随 [align] 或默认策略。
  final TextAlign? headerAlign;

  /// 按行动态生成的数据单元格附加样式，适合热力色、告警色等数据驱动外观；
  /// 这是列级单元格外观的唯一入口（列类型默认样式 → 本构建器 → 单元格实际样式）。
  final ElTableCellStyleBuilder? cellStyleBuilder;

  /// 当前列表头单元格叠加到表格默认表头单元格样式之上的样式。
  final ElStyle? headerStyle;

  /// 当前列表头内容构建器；优先于列类型的 headerBuilder 与 title。
  final ElTableHeaderBuilder? headerBuilder;

  /// 普通列是否允许拖拽调宽，null 时跟随表格默认策略；内置列始终不可调宽。
  final bool? resizable;

  /// 当前行是否允许被本列选择；null 表示允许。
  final ElTableRowPredicate? selectable;

  /// 当前行是否允许被本列展开；null 表示允许。
  final ElTableRowPredicate? expandable;

  /// 序号列配置，允许上层决定起始值、偏移或展示规则。
  final Object? index;

  /// 单元格渲染函数；普通列用它接管单元格，expand 列用它构建展开详情，箭头仍由内置类型渲染。
  final ElTableCellBuilder? slotBuilder;

  /// 单元格格式化函数，通常在默认数据列渲染前执行。
  final ElTableCellFormatter? formatter;

  /// 当前列的本地行比较器，本地排序优先使用它。
  final Comparator<ElTableRow>? sorter;

  /// 标签列选项，底层不绑定具体 Tag 组件。
  final List<ElTableTagOption>? tagOptions;

  /// 子列配置，用于多级表头；布局时叶子列参与数据区域。
  final List<ElTableColumn> children;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElTableColumn &&
          other.key == key &&
          other.type == type &&
          other.prop == prop &&
          other.title == title &&
          other.width == width &&
          other.minWidth == minWidth &&
          other.flex == flex &&
          other.fixed == fixed &&
          other.visible == visible &&
          other.sort == sort &&
          other.initialSortAscending == initialSortAscending &&
          other.sortField == sortField &&
          other.showOverflow == showOverflow &&
          other.align == align &&
          other.indexTextAlign == indexTextAlign &&
          other.headerAlign == headerAlign &&
          identical(other.cellStyleBuilder, cellStyleBuilder) &&
          other.headerStyle == headerStyle &&
          identical(other.headerBuilder, headerBuilder) &&
          other.resizable == resizable &&
          identical(other.selectable, selectable) &&
          identical(other.expandable, expandable) &&
          other.index == index &&
          identical(other.slotBuilder, slotBuilder) &&
          identical(other.formatter, formatter) &&
          identical(other.sorter, sorter) &&
          listEquals(other.tagOptions, tagOptions) &&
          listEquals(other.children, children);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    key,
    type,
    prop,
    title,
    width,
    minWidth,
    flex,
    fixed,
    visible,
    sort,
    initialSortAscending,
    sortField,
    showOverflow,
    align,
    indexTextAlign,
    headerAlign,
    cellStyleBuilder,
    headerStyle,
    headerBuilder,
    resizable,
    selectable,
    expandable,
    index,
    slotBuilder,
    formatter,
    sorter,
    Object.hashAll(tagOptions ?? const <ElTableTagOption>[]),
    Object.hashAll(children),
  ]);
}

/// 表头单元格上下文，列类型通过它拿到 controller、列、位置和列身份。
@immutable
class ElTableHeaderCell {
  /// 创建表头单元格上下文。
  const ElTableHeaderCell({
    required this.controller,
    required this.column,
    required this.columnKey,
    required this.columnIndex,
  });

  /// 所属表格控制器。
  final ElTableController controller;

  /// 当前列配置。
  final ElTableColumn column;

  /// 当前列稳定身份。
  final Object columnKey;

  /// 当前展示序列号。
  final int columnIndex;
}

/// 完整表头单元格上下文，给上层皮肤保留默认实现、分组信息与排序命令。
@immutable
class ElTableHeaderCellScope {
  /// 创建完整表头单元格上下文。
  const ElTableHeaderCellScope({
    required this.header,
    required this.content,
    required this.defaultCell,
    required this.sortable,
    required this.sorted,
    required this.ascending,
    required this.toggleSort,
    required this.sort,
    required this.clearSort,
    this.isGroup = false,
    this.columnSpan = 1,
  });

  /// 当前列、稳定身份与展示位置。
  final ElTableHeaderCell header;

  /// 已解析的表头内容，不含默认排序指示图形。
  final Widget content;

  /// 底层完整默认单元格，包含样式、整块点击排序和当前方向指示。
  final Widget defaultCell;

  /// 当前列是否允许排序。
  final bool sortable;

  /// 当前列是否是控制器正在使用的排序列。
  final bool sorted;

  /// 当前排序方向；未排序时为 null。
  final bool? ascending;

  /// 按列配置的初始方向开始排序，之后在升序与降序之间切换。
  final VoidCallback? toggleSort;

  /// 显式设置当前列的排序方向。
  final ValueChanged<bool>? sort;

  /// 清除当前表格排序状态。
  final VoidCallback? clearSort;

  /// 是否为跨越多个叶子列的分组表头。
  final bool isGroup;

  /// 当前表头横跨的叶子列数量，普通叶子表头固定为 1。
  final int columnSpan;
}

/// 单元格上下文，列类型和事件通过它拿到行、列、位置和值。
@immutable
class ElTableCell {
  /// 创建单元格上下文。
  const ElTableCell({
    required this.controller,
    required this.row,
    required this.rowKey,
    required this.rowIndex,
    required this.column,
    required this.columnKey,
    required this.columnIndex,
    required this.value,
  });

  /// 所属表格控制器。
  final ElTableController controller;

  /// 原始业务行。
  final ElTableRow row;

  /// 当前行稳定身份。
  final Object rowKey;

  /// 当前展示序行号。
  final int rowIndex;

  /// 当前列配置。
  final ElTableColumn column;

  /// 当前列稳定身份。
  final Object columnKey;

  /// 当前展示序列号。
  final int columnIndex;

  /// 单元格原始值，来自 prop 点路径。
  final Object? value;
}

/// 展示行上下文，行事件与行样式通过它共享稳定身份和排序后的展示序号。
@immutable
class ElTableRowContext {
  /// 创建展示行上下文。
  const ElTableRowContext({required this.controller, required this.row, required this.rowKey, required this.rowIndex});

  /// 所属表格控制器。
  final ElTableController controller;

  /// 原始业务行。
  final ElTableRow row;

  /// 当前行稳定身份。
  final Object rowKey;

  /// 包含固定行偏移在内的当前展示序号。
  final int rowIndex;
}

/// 合计单元格上下文，汇总函数可访问列身份与原始全量数据。
@immutable
class ElTableSummaryCell {
  /// 创建合计单元格上下文。
  const ElTableSummaryCell({
    required this.controller,
    required this.column,
    required this.columnKey,
    required this.columnIndex,
    required this.data,
  });

  /// 所属表格控制器。
  final ElTableController controller;

  /// 当前可见叶子列。
  final ElTableColumn column;

  /// 当前列稳定身份。
  final Object columnKey;

  /// 当前列在声明序中的序号。
  final int columnIndex;

  /// controller 中未经固定行拆分与本地排序的完整数据。
  final List<ElTableRow> data;
}
