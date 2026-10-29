import 'dart:io';

import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 表格导出面契约（作者 2026-09-18 拍板：`table_column.dart` 拆成独立库 + 公共 barrel 整文件导出）。
///
/// 本文件**只** import 公共 barrel `package:flutter_base/ui.dart`：下面每个类型都写了显式标注，
/// 于是「能不能从 barrel 命名」由编译器裁决 —— 少一个名字，本文件立刻编译失败。
///
/// 反方向（6 个包内载体必须不可命名）没法把「编译失败」写成一条应当通过的断言，
/// 所以改用源码契约：把 barrel 的两条导出指令展开成真实可见的名字集合，再逐一比对。
/// 同时校验「没有第三种状态」—— 表格库里每个公开声明要么在 barrel 上，要么是登记在册的包内载体。
void main() {
  test('5 个入口 + 20 个配套类型都能从 package:flutter_base/ui.dart 显式命名', () {
    // 状态与选项 / 数据与上下文。
    const ElTableStyle style = ElTableStyle();
    const ElTableColumnType columnType = ElTableColumnType.checkbox;
    const ElTableColumnFixed fixed = ElTableColumnFixed.left;
    const ElTableSelectionState selectionState = ElTableSelectionState.none;
    const ElTableSort sort = ElTableSort(columnKey: 'name', ascending: true);
    const ElTableTagOption tagOption = ElTableTagOption(value: '1', label: '启用');

    final ElTableRow firstRow = <String, Object?>{'id': 1, 'name': 'Alice', 'score': 10};
    final ElTableRow secondRow = <String, Object?>{'id': 2, 'name': 'Bob', 'score': 20};

    // 回调类型：按惯用写法声明局部函数，再用 `isA<别名>()` 显式点到每个 typedef 的名字 ——
    // 别名一旦从 barrel 上消失，这里每一条都会立刻编译失败。
    bool selectable(ElTableRow row) => row['name'] == 'Alice';
    Object? format(Object? value, ElTableCell cell) => '${cell.rowKey}:$value';
    ElStyle? cellStyle(ElTableCell cell) => const ElStyle(bgColor: Color(0xffffffff));
    ElStyle? rowStyle(ElTableRowContext row) => row.rowIndex.isEven ? const ElStyle() : null;
    Object? slot(BuildContext context, ElTableCell cell) => cell.value;
    Object? header(BuildContext context, ElTableHeaderCell cell) => cell.columnIndex;
    Widget headerCell(BuildContext context, ElTableHeaderCellScope scope) => scope.defaultCell;
    Object? empty(BuildContext context, ElTableController controller) => '空';
    Object? summary(BuildContext context, ElTableSummaryCell cell) => cell.columnIndex;

    expect(selectable, isA<ElTableRowPredicate>());
    expect(format, isA<ElTableCellFormatter>());
    expect(cellStyle, isA<ElTableCellStyleBuilder>());
    expect(rowStyle, isA<ElTableRowStyleBuilder>());
    expect(slot, isA<ElTableCellBuilder>());
    expect(header, isA<ElTableHeaderBuilder>());
    expect(headerCell, isA<ElTableHeaderCellBuilder>());
    expect(empty, isA<ElTableEmptyBuilder>());
    expect(summary, isA<ElTableSummaryCellBuilder>());

    final ElTableColumn checkbox = ElTableColumn(
      type: columnType,
      selectable: selectable,
      tagOptions: const [tagOption],
    );
    final ElTableColumn name = ElTableColumn(
      title: '名称',
      prop: 'name',
      fixed: fixed,
      formatter: format,
      cellStyleBuilder: cellStyle,
      slotBuilder: slot,
      headerBuilder: header,
    );
    final ElTableController controller = ElTableController(
      rowKey: 'id',
      data: <ElTableRow>[firstRow, secondRow],
      columns: <ElTableColumn>[checkbox, name],
      rowStyleBuilder: rowStyle,
      summaryBuilder: summary,
      emptyBuilder: empty,
    );
    addTearDown(controller.dispose);
    final ElTable table = ElTable(controller: controller, style: style, headerCellBuilder: headerCell);

    // 上下文类型：真实构造，不用 null 占位。
    final ElTableHeaderCell headerContext = ElTableHeaderCell(
      controller: controller,
      column: name,
      columnKey: 'name',
      columnIndex: 1,
    );
    final ElTableHeaderCellScope headerScope = ElTableHeaderCellScope(
      header: headerContext,
      content: const ElView(),
      defaultCell: const ElView(),
      sortable: true,
      sorted: false,
      ascending: null,
      toggleSort: null,
      sort: null,
      clearSort: null,
    );
    final ElTableCell cell = ElTableCell(
      controller: controller,
      row: firstRow,
      rowKey: 1,
      rowIndex: 0,
      column: name,
      columnKey: 'name',
      columnIndex: 1,
      value: 'Alice',
    );
    final ElTableRowContext rowContext = ElTableRowContext(
      controller: controller,
      row: firstRow,
      rowKey: 1,
      rowIndex: 0,
    );
    final ElTableSummaryCell summaryCell = ElTableSummaryCell(
      controller: controller,
      column: name,
      columnKey: 'name',
      columnIndex: 1,
      data: <ElTableRow>[firstRow, secondRow],
    );
    final ElTableSelectionChange selectionChange = ElTableSelectionChange(
      controller: controller,
      row: rowContext,
      selected: true,
    );

    // 25 个名字全部出现在这一个列表里：任何一个从 barrel 上消失，本文件就编译不过。
    final List<Object?> surface = <Object?>[
      table, // ElTable
      style, // ElTableStyle
      controller, // ElTableController
      name, // ElTableColumn
      columnType, // ElTableColumnType
      firstRow, // ElTableRow
      rowContext, // ElTableRowContext
      sort, // ElTableSort
      cell, // ElTableCell
      headerContext, // ElTableHeaderCell
      headerScope, // ElTableHeaderCellScope
      summaryCell, // ElTableSummaryCell
      selectionChange, // ElTableSelectionChange
      selectionState, // ElTableSelectionState
      tagOption, // ElTableTagOption
      fixed, // ElTableColumnFixed
      selectable, // ElTableRowPredicate
      slot, // ElTableCellBuilder
      format, // ElTableCellFormatter
      cellStyle, // ElTableCellStyleBuilder
      header, // ElTableHeaderBuilder
      headerCell, // ElTableHeaderCellBuilder
      empty, // ElTableEmptyBuilder
      rowStyle, // ElTableRowStyleBuilder
      summary, // ElTableSummaryCellBuilder
    ];
    expect(surface, hasLength(25), reason: '入口 5 + 配套 20。');

    // 不只是「能编译」：这些类型的真值确实流动起来了。
    expect(table.controller, same(controller));
    expect(controller.columns, hasLength(2));
    expect(selectionState, ElTableSelectionState.none);
    expect(controller.selectionState(where: selectable), ElTableSelectionState.none);
    expect(checkbox.type, ElTableColumnType.checkbox);
    expect(fixed, ElTableColumnFixed.left);
    expect(tagOption.label, '启用');
    expect(sort.columnKey, 'name');
    expect(firstRow['id'], 1);
    expect(secondRow['name'], 'Bob');
    expect(headerContext.columnIndex, 1);
    expect(headerScope.defaultCell, isA<ElView>());
    expect(cell.rowKey, 1);
    expect(rowContext.rowIndex, 0);
    expect(summaryCell.data, hasLength(2));
    expect(selectionChange.selected, isTrue);
    expect(format(cell.value, cell), '1:Alice');
    expect(cellStyle(cell)?.bgColor, const Color(0xffffffff));
    expect(rowStyle(rowContext), isNotNull, reason: '展示序 0 是偶数行。');
  });

  test('barrel 可见的表格类型恰好是 5 入口 + 20 配套，5 个包内载体仍不可命名', () {
    final source = _read('lib/ui.dart');

    final tableExports = RegExp(r"export 'src/ui/cores/table/([^']+\.dart)'")
        .allMatches(source)
        .map((match) => match.group(1))
        .toList();
    expect(tableExports, <String>[
      'table_column.dart',
      'table.dart',
    ], reason: '表格只有这两条导出指令：一条整文件放「列 + 配套类型」，一条 show 入口与少数同库配套类型。');

    final columnExport = RegExp(r"export 'src/ui/cores/table/table_column\.dart'([^;]*);")
        .firstMatch(source)!
        .group(1)!;
    expect(columnExport.trim(), isEmpty, reason: 'table_column.dart 按整文件导出，不再逐个 show / hide 列名字。');

    final shown = RegExp(r"export 'src/ui/cores/table/table\.dart'\s+show\s+([^;]*);").firstMatch(source)!.group(1)!;
    final visible = <String>{
      ..._publicDeclarationsIn('lib/src/ui/cores/table/table_column.dart'),
      ...RegExp(r'[A-Za-z_][A-Za-z0-9_]*').allMatches(shown).map((match) => match.group(0)!),
    };

    expect(visible, <String>{...entryPoints, ...companions}, reason: '可见面就是 5 个入口 + 20 个配套类型。');
    expect(visible, hasLength(25));
    for (final carrier in carriers) {
      expect(visible, isNot(contains(carrier)), reason: '$carrier 只做包内载体，不得从 barrel 命名。');
      expect(source.contains(carrier), isFalse, reason: '$carrier 连名字都不该出现在 barrel 源码里。');
    }
  });

  test('表格库的公开声明只有两种命运：在 barrel 上，或是登记在册的包内载体', () {
    final declarations = <String>{for (final path in _tableSourceFiles()) ..._publicDeclarationsIn(path)};
    expect(declarations, <String>{
      ...entryPoints,
      ...companions,
      ...carriers,
    }, reason: '新增 / 删除顶层公开类型时，必须同时更新 barrel 与这份清单，不允许出现两不管的类型。');
    expect(
      const <String>[...entryPoints, ...companions, ...carriers],
      hasLength(declarations.length),
      reason: '清单里不允许重名。',
    );
  });

  test('table_column.dart 已是独立库，且 table.dart 仍然转发它的类型', () {
    final column = _read('lib/src/ui/cores/table/table_column.dart');
    expect(column.contains("part of 'table.dart';"), isFalse, reason: '它不再是 table.dart 的 part。');
    expect(
      column.contains("import 'table.dart' show ElTableController;"),
      isTrue,
      reason: '独立库后它自己 import 需要的 el_ui 类型。',
    );

    final library = _read('lib/src/ui/cores/table/table.dart');
    expect(library.contains("part 'table_column.dart';"), isFalse);
    expect(library.contains("import 'table_column.dart';"), isTrue);
    expect(
      library.contains("export 'table_column.dart';"),
      isTrue,
      reason: '直连 table.dart 的包内代码（测试、其它 part）照旧能命名列与配套类型。',
    );
  });
}

/// 表格对外承诺的 5 个入口。
const List<String> entryPoints = <String>[
  'ElTable',
  'ElTableStyle',
  'ElTableController',
  'ElTableColumn',
  'ElTableColumnType',
];

/// 配套类型（作者 2026-09-18 清单逐项枚举，共 20 个）：
/// 缺了它们，用户写不出列描述符与回调签名。
const List<String> companions = <String>[
  // 数据与上下文
  'ElTableRow',
  'ElTableRowContext',
  'ElTableSort',
  // 单元格与表头
  'ElTableCell',
  'ElTableHeaderCell',
  'ElTableHeaderCellScope',
  'ElTableSummaryCell',
  'ElTableSelectionChange',
  // 状态与选项
  'ElTableSelectionState',
  'ElTableTagOption',
  'ElTableColumnFixed',
  // 回调类型
  'ElTableRowPredicate',
  'ElTableCellBuilder',
  'ElTableCellFormatter',
  'ElTableCellStyleBuilder',
  'ElTableHeaderBuilder',
  'ElTableHeaderCellBuilder',
  'ElTableEmptyBuilder',
  'ElTableRowStyleBuilder',
  'ElTableSummaryCellBuilder',
];

/// 做过包内载体的 5 个类型：整库 / 整文件导出的反向名单。
const List<String> carriers = <String>[
  'ElTableEvent',
  'ElTableSelectionControl',
  'ElTableExpansionControl',
  'ElTableColumnBuilder',
  'ElTableIndexBuilder',
];

/// 顶层公开声明（下划线开头的不导出，本库内也确实没有）。
final RegExp _declaration = RegExp(
  r'^(?:abstract final class|abstract class|final class|base class|sealed class|interface class'
  r'|mixin|class|enum|typedef|extension)\s+([A-Za-z][A-Za-z0-9_]*)',
  multiLine: true,
);

List<String> _publicDeclarationsIn(String path) => _declaration
    .allMatches(_read(path))
    .map((match) => match.group(1)!)
    .where((name) => !name.startsWith('_'))
    .toList();

List<String> _tableSourceFiles() =>
    _resolveDirectory('lib/src/ui/cores/table')
        .listSync()
        .whereType<File>()
        .map((file) => file.path)
        .where((path) => path.endsWith('.dart'))
        .toList()
      ..sort();

/// `flutter test` 的 cwd 是 flutter_base 包根。
File _resolve(String relative) => File(relative);

Directory _resolveDirectory(String relative) => Directory(relative);

String _read(String relative) => _resolve(relative).readAsStringSync();
