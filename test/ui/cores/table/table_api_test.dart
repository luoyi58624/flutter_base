import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_base/src/ui/cores/table/table.dart';
import 'package:flutter_base/src/flutter/views/view/style/resolved/resolved_style.dart';
import 'package:flutter_base/src/flutter/views/view/style/style.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 与实现同口径地实测数字字宽：el_ui 文本初值下 '0'..'9' 的最大宽度。
double measureDigitWidth() {
  final fontSize = InheritedText.initial.fontSize;
  final style = TextStyle(fontSize: fontSize);
  var maximum = 0.0;
  for (var digit = 0; digit <= 9; digit++) {
    final painter = TextPainter(
      text: TextSpan(text: '$digit', style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    maximum = math.max(maximum, painter.width);
    painter.dispose();
  }
  return math.max(1, maximum);
}

List<ElTableRow> rows(int count) => [
  for (var index = 0; index < count; index++) {'id': index},
];

class _CompactTableStyle extends ElTableStyle {
  const _CompactTableStyle();

  @override
  double get rowHeight => 28;

  @override
  double get headerHeight => 32;

  @override
  double get minColumnWidth => 70;

  @override
  EdgeInsetsGeometry get cellPadding => const .symmetric(horizontal: 8, vertical: 4);
}

class _WideTableStyle extends ElTableStyle {
  const _WideTableStyle();

  @override
  double get rowHeight => 48;

  @override
  double get minColumnWidth => 120;
}

void main() {
  tearDownAll(() {
    final cacheDir = Directory('el_ui_table');
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  ElTableController createController() => ElTableController(
    rowKey: 'id',
    data: const [
      {'id': 1, 'name': 'Alice'},
      {'id': 2, 'name': 'Bob'},
    ],
    columns: const [
      ElTableColumn(type: .checkbox, width: 55, fixed: .left),
      ElTableColumn(title: '名称', prop: 'name', minWidth: 160, sort: true, sortField: 'name'),
    ],
  );

  test('Controller 直接管理 data、columns 和列 slotBuilder', () {
    final controller = createController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);
    Object? operateSlotBuilder(BuildContext context, ElTableCell cell) => cell.row['name'];

    expect(controller.data, const [
      {'id': 1, 'name': 'Alice'},
      {'id': 2, 'name': 'Bob'},
    ]);
    expect(controller.columns.first.type, ElTableColumnType.checkbox);
    expect(controller.columns.last.prop, 'name');
    expect(controller.columns.last.key, isNull, reason: '核心不应偷偷改写用户的列配置。');

    controller.update(
      data: const [
        {'id': 3, 'name': 'Carol'},
      ],
      columns: [ElTableColumn(title: '操作', slotBuilder: operateSlotBuilder)],
      columnWidths: const {'username': 180},
      rowHeights: const {3: 44},
    );

    expect(controller.data.single, const {'id': 3, 'name': 'Carol'});
    expect(controller.columns.single.slotBuilder, same(operateSlotBuilder));
    expect(controller.columnWidths, const {'username': 180});
    expect(controller.rowHeights, const {3: 44});
    expect(notifications, 1);
  });

  test('Controller 按 id 缓存列显隐、顺序、宽度与排序', () {
    const id = 'table-api-cache-state';
    const columns = <ElTableColumn>[
      ElTableColumn(key: 'name', title: '名称', prop: 'name'),
      ElTableColumn(key: 'age', title: '年龄', prop: 'age', sort: true),
      ElTableColumn(key: 'status', title: '状态', prop: 'status'),
    ];
    final writer = ElTableController(id: id, cacheEnabled: true, columns: columns);
    expect(writer.moveColumnTo('age', 0), isTrue);
    expect(writer.setColumnVisible('status', false), isTrue);
    writer
      ..sort('age', ascending: false)
      ..setColumnWidth('age', 144);
    writer.dispose();

    final reader = ElTableController(id: id, cacheEnabled: true, columns: columns);
    addTearDown(() {
      reader.clearCachedConfiguration();
      reader.dispose();
    });

    expect(reader.columnOrderKeys, const ['age', 'name', 'status']);
    expect(reader.columnVisibility['status'], isFalse);
    expect(reader.visibleColumns.map((column) => column.key), const ['age', 'name']);
    expect(reader.columnWidths, const {'age': 144.0});
    expect(reader.sortState, const ElTableSort(columnKey: 'age', ascending: false));

    reader.columns = columns.reversed;
    expect(reader.columnOrderKeys, const ['age', 'name', 'status']);
    expect(reader.columnVisibility['status'], isFalse);
  });

  test('动态修改 id 与缓存开关会清除旧快照', () {
    const oldId = 'table-api-cache-old';
    const nextId = 'table-api-cache-next';
    const columns = <ElTableColumn>[
      ElTableColumn(key: 'name', title: '名称', prop: 'name'),
      ElTableColumn(key: 'age', title: '年龄', prop: 'age'),
    ];
    final controller = ElTableController(id: oldId, cacheEnabled: true, columns: columns)
      ..moveColumnTo('age', 0)
      ..setColumnWidth('age', 120);
    controller.id = nextId;
    controller.dispose();

    final oldReader = ElTableController(id: oldId, cacheEnabled: true, columns: columns);
    final nextReader = ElTableController(id: nextId, cacheEnabled: true, columns: columns);
    expect(oldReader.columnOrderKeys, const ['name', 'age']);
    expect(oldReader.columnWidths, isEmpty);
    expect(nextReader.columnOrderKeys, const ['age', 'name']);
    expect(nextReader.columnWidths, const {'age': 120.0});

    nextReader.cacheEnabled = false;
    final clearedReader = ElTableController(id: nextId, cacheEnabled: true, columns: columns);
    expect(clearedReader.columnOrderKeys, const ['name', 'age']);
    expect(clearedReader.columnWidths, isEmpty);
    oldReader.dispose();
    nextReader.dispose();
    clearedReader
      ..clearCachedConfiguration()
      ..dispose();
  });

  test('Controller 固定列命令按叶子列身份写入并支持分组内的叶子列', () {
    final controller = ElTableController(
      columns: const [
        ElTableColumn(key: 'name', title: '名称', prop: 'name'),
        ElTableColumn(
          key: 'info',
          title: '信息',
          children: [
            ElTableColumn(key: 'age', title: '年龄', prop: 'age'),
            ElTableColumn(key: 'city', title: '城市', prop: 'city'),
          ],
        ),
      ],
    );
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    expect(controller.setColumnFixed('name', .left), isTrue);
    expect(controller.columns.first.fixed, ElTableColumnFixed.left);
    expect(controller.visibleColumns.first.fixed, ElTableColumnFixed.left, reason: '渲染层读的叶子列计划必须同步。');
    expect(notifications, 1, reason: '每次成功写入只提交一次。');

    expect(controller.setColumnFixed('info/age', .right), isTrue, reason: '分组内叶子列用嵌套身份。');
    expect(controller.columns.last.children.map((column) => column.fixed), const [ElTableColumnFixed.right, null]);
    expect(controller.setColumnFixed('city', .left), isTrue, reason: '分组内叶子列也能用它自己的声明 key。');
    expect(controller.columns.last.children.map((column) => column.fixed), const [
      ElTableColumnFixed.right,
      ElTableColumnFixed.left,
    ]);
    expect(controller.setColumnFixed('age', .right), isFalse, reason: '状态未变必须返回 false。');
    expect(notifications, 3);

    expect(controller.setColumnFixed('name', null), isTrue, reason: 'null 表示取消固定。');
    expect(controller.columns.first.fixed, isNull);
    expect(controller.setColumnFixed('name', null), isFalse);
    expect(controller.setColumnFixed('info', .left), isFalse, reason: '固定方向按叶子列分带，分组列不是固定列身份。');
    expect(controller.setColumnFixed('info/missing', .left), isFalse);
    expect(notifications, 4);

    expect(controller.columns.first.prop, 'name', reason: '写入固定方向不能动其他列字段。');
    expect(controller.columns.last.key, 'info');
    expect(controller.columns.last.children.map((column) => column.key), const ['age', 'city']);
    expect(controller.columnOrderKeys, const ['name', 'info']);
    expect(controller.visibleColumns.map((column) => column.prop), const ['name', 'age', 'city']);
    expect(controller.columns.last.children.clear, throwsUnsupportedError, reason: '重建后的子列仍需冻结。');
  });

  test('Controller 换序命令支持分组内的叶子列', () {
    final controller = ElTableController(
      columns: const [
        ElTableColumn(
          key: 'identity',
          title: '身份',
          children: [
            ElTableColumn(key: 'name', title: '姓名', prop: 'name'),
            ElTableColumn(key: 'role', title: '角色', prop: 'role'),
            ElTableColumn(key: 'level', title: '等级', prop: 'level'),
          ],
        ),
        ElTableColumn(key: 'status', title: '状态', prop: 'status'),
      ],
    );
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);
    List<Object?> childKeys() => controller.columns.first.children.map((column) => column.key).toList();

    expect(controller.moveColumnTo('identity/level', 0), isTrue, reason: '分组内叶子列用嵌套身份换序。');
    expect(childKeys(), const ['level', 'name', 'role']);
    expect(controller.columnOrderKeys, const ['identity', 'status'], reason: '分组内换序不动顶层顺序。');
    expect(controller.visibleColumns.map((column) => column.key), const ['level', 'name', 'role', 'status']);

    expect(controller.moveColumnTo('level', 2), isTrue, reason: '分组内叶子列也能用声明 key。');
    expect(childKeys(), const ['name', 'role', 'level']);
    expect(controller.moveColumnTo('identity/level', 2), isFalse, reason: '目标下标与当前一致返回 false。');
    expect(controller.moveColumnTo('identity/name', 9), isTrue, reason: '越界目标收敛到该分组末尾。');
    expect(childKeys(), const ['role', 'level', 'name']);
    expect(notifications, 3);

    expect(controller.moveColumnTo('identity', 1), isTrue, reason: '顶层身份仍走顶层换序（表头拖拽路径）。');
    expect(controller.columnOrderKeys, const ['status', 'identity']);
    expect(controller.columns.map((column) => column.key), const ['status', 'identity']);
    expect(controller.moveColumnTo('identity/name', 0), isTrue, reason: '分组换了顶层位置后嵌套身份照样定位。');
    expect(controller.columns.last.children.map((column) => column.key), const ['name', 'role', 'level']);
    expect(controller.moveColumnTo('missing', 0), isFalse);
    expect(controller.moveColumnTo('identity/missing', 0), isFalse);
    expect(notifications, 5);
  });

  test('Controller setColumnOrder 同时按顶层身份与分组内身份重排', () {
    final controller = ElTableController(
      columns: const [
        ElTableColumn(key: 'a', prop: 'a'),
        ElTableColumn(
          key: 'group',
          title: '分组',
          children: [
            ElTableColumn(key: 'g1', prop: 'g1'),
            ElTableColumn(key: 'g2', prop: 'g2'),
            ElTableColumn(key: 'g3', prop: 'g3'),
          ],
        ),
        ElTableColumn(key: 'b', prop: 'b'),
      ],
    );
    addTearDown(controller.dispose);

    expect(controller.setColumnOrder(const ['b', 'group/g3', 'group/g1']), isTrue);
    expect(controller.columnOrderKeys, const ['b', 'a', 'group']);
    expect(controller.columns.last.children.map((column) => column.key), const ['g3', 'g1', 'g2']);
    expect(controller.setColumnOrder(const ['b', 'group/g3', 'group/g1']), isFalse, reason: '同一顺序必须返回 false。');
    expect(controller.setColumnOrder(const ['group/g2', 'missing']), isTrue);
    expect(controller.columns.last.children.map((column) => column.key), const ['g2', 'g3', 'g1']);
    expect(controller.setColumnOrder(const ['missing', 'group/missing']), isFalse);
    expect(controller.columnOrderKeys, const ['b', 'a', 'group']);
  });

  test('Controller 分组嵌套两层时固定与换序仍按递归身份定位', () {
    final controller = ElTableController(
      columns: const [
        ElTableColumn(
          key: 'outer',
          title: '外层',
          children: [
            ElTableColumn(
              key: 'inner',
              title: '内层',
              children: [
                ElTableColumn(key: 'left', title: '甲', prop: 'a'),
                ElTableColumn(key: 'right', title: '乙', prop: 'b'),
              ],
            ),
            ElTableColumn(key: 'tail', title: '尾', prop: 't'),
          ],
        ),
      ],
    );
    addTearDown(controller.dispose);

    expect(controller.setColumnFixed('outer/inner/right', .left), isTrue, reason: '两层分组内的叶子列。');
    expect(controller.columns.first.children.first.children.last.fixed, ElTableColumnFixed.left);
    expect(controller.moveColumnTo('outer/inner/right', 0), isTrue);
    expect(controller.columns.first.children.first.children.map((column) => column.key), const ['right', 'left']);
    expect(controller.columns.first.children.map((column) => column.key), const ['inner', 'tail'], reason: '只动目标那一层。');
    expect(controller.visibleColumns.map((column) => column.key), const ['right', 'left', 'tail']);
    expect(controller.setColumnFixed('outer/inner', .left), isFalse, reason: '分组层不是固定列身份。');
    expect(controller.moveColumnTo('outer/inner/left', 1), isFalse, reason: '同层只有两列，已在该层末尾。');
  });

  test('Controller 按 id 缓存列固定方向，恢复时按 token 身份应用', () {
    const id = 'table-api-cache-fixed';
    const columns = <ElTableColumn>[
      ElTableColumn(key: 'name', title: '名称', prop: 'name'),
      ElTableColumn(
        key: 'info',
        title: '信息',
        children: [
          ElTableColumn(key: 'age', title: '年龄', prop: 'age'),
          ElTableColumn(key: 'city', title: '城市', prop: 'city'),
        ],
      ),
    ];
    final writer = ElTableController(id: id, cacheEnabled: true, columns: columns)
      ..setColumnFixed('name', .left)
      ..setColumnFixed('info/age', .right);
    writer.dispose();

    final reader = ElTableController(id: id, cacheEnabled: true, columns: columns);
    addTearDown(() {
      reader.clearCachedConfiguration();
      reader.dispose();
    });

    expect(reader.columns.first.fixed, ElTableColumnFixed.left);
    expect(reader.columns.last.children.map((column) => column.fixed), const [ElTableColumnFixed.right, null]);
    expect(reader.visibleColumns.map((column) => column.fixed), const [
      ElTableColumnFixed.left,
      ElTableColumnFixed.right,
      null,
    ]);

    reader.columns = columns.reversed;
    expect(reader.columnOrderKeys, const ['name', 'info'], reason: '缓存里的顺序优先于新的声明顺序（既有语义）。');
    expect(reader.columns.first.fixed, ElTableColumnFixed.left, reason: '固定方向按 token 身份恢复，不随声明顺序。');
    expect(reader.columns.last.fixed, isNull, reason: '分组列没有固定记录，不能被写成固定。');
    expect(reader.columns.last.children.map((column) => column.fixed), const [ElTableColumnFixed.right, null]);
  });

  test('内置列类型是封闭的三个值，默认列宽由底层给出', () {
    expect(ElTableColumnType.values, const [
      ElTableColumnType.index,
      ElTableColumnType.checkbox,
      ElTableColumnType.expanded,
    ], reason: '列类型只有 index / checkbox / expanded 三个内置值，用户不再自定义。');

    final controller = ElTableController(
      columns: const [
        ElTableColumn(type: .checkbox),
        ElTableColumn(type: .expanded),
      ],
    );
    addTearDown(controller.dispose);

    expect(controller.columnWidthOf(controller.columns.first), 48);
    expect(controller.columnWidthOf(controller.columns.last), 48);
    expect(controller.columnAlignOf(controller.columns.first), TextAlign.center);
    expect(controller.columnResizableOf(controller.columns.first), isFalse);
  });

  testWidgets('index 列宽按实际最大位数随展示行数自动重算', (tester) async {
    final digitWidth = measureDigitWidth();
    final controller = ElTableController(columns: const [ElTableColumn(type: .index)]);
    addTearDown(controller.dispose);
    final column = controller.columns.single;

    // 未挂视图时没有皮肤内边距，空表仍为起始序号保留一字符。
    expect(controller.columnWidthOf(column), closeTo(digitWidth, 1e-9));

    controller.data = rows(9);
    expect(controller.columnWidthOf(column), closeTo(digitWidth, 1e-9));

    controller.data = rows(10);
    expect(controller.columnWidthOf(column), closeTo(2 * digitWidth, 1e-9));

    controller.data = rows(99);
    expect(controller.columnWidthOf(column), closeTo(2 * digitWidth, 1e-9));

    controller.data = rows(100);
    expect(controller.columnWidthOf(column), closeTo(3 * digitWidth, 1e-9));

    controller.data = rows(10000);
    expect(controller.columnWidthOf(column), closeTo(5 * digitWidth, 1e-9));
  });

  testWidgets('index 自动列宽逐列计算分页起始值，并在数据跨序号位数时刷新', (tester) async {
    final controller = ElTableController(
      data: rows(1),
      columns: [
        ElTableColumn(type: .index),
        ElTableColumn(type: .index, index: 999),
        ElTableColumn(type: .index, index: 10001),
      ],
    );
    addTearDown(controller.dispose);
    final columns = controller.columns;
    final initialWidths = columns.map(controller.columnWidthOf).toList();
    expect(initialWidths[1], greaterThanOrEqualTo(initialWidths[0]!));
    expect(initialWidths[2], greaterThan(initialWidths[1]!));

    // 数据量始终只有一位，但第二列的末尾序号从 999 跨到了 1000。
    controller.data = rows(2);
    expect(controller.columnWidthOf(columns[0]), initialWidths[0]);
    expect(controller.columnWidthOf(columns[1]), greaterThan(initialWidths[1]!));
    expect(controller.columnWidthOf(columns[2]), initialWidths[2]);

    controller.update(data: rows(1));
    expect(controller.columnWidthOf(columns[1]), initialWidths[1]);

    controller.columns = [ElTableColumn(type: .index, index: 101)];
    final pageWidth = controller.columnWidthOf(controller.columns.single)!;
    controller.columns = [ElTableColumn(type: .index, index: 1001)];
    expect(controller.columnWidthOf(controller.columns.single), greaterThan(pageWidth));
  });

  testWidgets('只有普通列读取宽度配置，内置列统一定宽且不可拖拽', (tester) async {
    final controller = ElTableController(
      data: rows(1),
      columns: [
        for (final type in ElTableColumnType.values)
          ElTableColumn(type: type, width: 12, minWidth: 200, flex: 10, resizable: true),
        ElTableColumn(prop: 'fixed', width: 72, resizable: true),
        ElTableColumn(prop: 'flexible', minWidth: 66, flex: 2),
      ],
    );
    addTearDown(controller.dispose);
    expect(controller.columnWidthOf(controller.columns.first), closeTo(measureDigitWidth(), 1e-9));
    for (final column in controller.columns.skip(1).take(2)) {
      expect(controller.columnWidthOf(column), 48);
    }
    for (final column in controller.columns.take(3)) {
      expect(controller.columnMinWidthOf(column), isNull);
      expect(controller.columnResizableOf(column), isFalse);
    }
    expect(controller.columnWidthOf(controller.columns[3]), 72);
    expect(controller.columnResizableOf(controller.columns[3]), isTrue);
    expect(controller.columnWidthOf(controller.columns[4]), isNull);
    expect(controller.columnMinWidthOf(controller.columns[4]), 66);

    controller.data = rows(10000);
    expect(controller.columnWidthOf(controller.columns.first), greaterThan(48));
    expect(controller.columnWidthOf(controller.columns[1]), 48);
    expect(controller.columnWidthOf(controller.columns[2]), 48);
    controller.update(data: rows(1));
    expect(controller.columnWidthOf(controller.columns.first), closeTo(measureDigitWidth(), 1e-9));
  });

  test('Controller 冻结子列和标签选项配置', () {
    final children = <ElTableColumn>[const ElTableColumn(title: '子列', prop: 'child')];
    final tagOptions = <ElTableTagOption>[const ElTableTagOption(value: '1', label: '启用')];
    final controller = ElTableController(
      columns: [
        ElTableColumn(title: '分组', children: children),
        ElTableColumn(title: '状态', prop: 'status', tagOptions: tagOptions),
      ],
    );
    addTearDown(controller.dispose);

    children.clear();
    tagOptions.clear();
    expect(controller.columns.first.children, hasLength(1));
    expect(controller.visibleColumns.map((column) => column.prop), const ['child', 'status']);
    expect(controller.columns.last.tagOptions, hasLength(1));
    expect(controller.columns.first.children.clear, throwsUnsupportedError);
    expect(controller.columns.last.tagOptions!.clear, throwsUnsupportedError);
  });

  test('Controller API 使用属性与自然动词', () {
    final controller = createController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    const alice = {'id': 1, 'name': 'Alice'};
    const bob = {'id': 2, 'name': 'Bob'};
    controller.sort('name', ascending: false);
    controller.select(alice);
    controller.currentRow = bob;
    controller.expand(bob);

    expect(controller.sortColumnKey, 'name');
    expect(controller.sortAscending, isFalse);
    expect(controller.selectedRows, const [alice]);
    expect(controller.currentRow, bob);
    expect(controller.expandedRows, const [bob]);
    expect(notifications, 4);
    expect(controller.sortState, const ElTableSort(columnKey: 'name', ascending: false));

    controller.sort('name', ascending: false);
    controller.select(alice);
    controller.currentRow = bob;
    controller.expand(bob);
    expect(notifications, 4, reason: '同值操作必须幂等。');

    controller.clearSort();
    controller.toggleSelection(bob);
    controller.collapseAll();
    expect(controller.sortColumnKey, isNull);
    expect(controller.sortAscending, isNull);
    expect(controller.selectedRows, const [alice, bob]);
    expect(controller.expandedRows, isEmpty);
  });

  test('sortRequired：清除命令短路，开关只约束交互', () {
    final controller = createController();
    addTearDown(controller.dispose);
    controller.sort('name', ascending: false);

    var notifications = 0;
    controller.addListener(() => notifications++);

    expect(controller.sortRequired, isFalse, reason: '默认三态可清除。');
    controller.sortRequired = true;
    expect(controller.sortRequired, isTrue);
    expect(notifications, 1);
    controller.sortRequired = true;
    expect(notifications, 1, reason: '同值赋值不通知。');
    expect(controller.sortState, const ElTableSort(columnKey: 'name', ascending: false), reason: '切换开关不改动当前排序状态。');

    controller.clearSort();
    expect(controller.sortColumnKey, 'name');
    expect(controller.sortAscending, isFalse);
    expect(notifications, 1, reason: 'sortRequired 下清除命令直接短路，不通知。');

    controller.update(sortRequired: false);
    expect(controller.sortRequired, isFalse);
    controller.clearSort();
    expect(controller.sortState, isNull);
    expect(notifications, 3);
  });

  test('数据刷新在当前行消失时按展示位置修复，并保留选择与展开身份', () {
    final controller = ElTableController(
      rowKey: 'id',
      pinnedRowKeys: const [1],
      data: const [
        {'id': 1, 'score': 0},
        {'id': 2, 'score': 10},
        {'id': 3, 'score': 20},
        {'id': 4, 'score': 30},
      ],
      columns: const [ElTableColumn(prop: 'score', sort: true)],
    );
    addTearDown(controller.dispose);
    controller
      ..sort('score', ascending: false)
      ..currentRowKey = 3
      ..selectedRowKeys = const [3]
      ..expandedRowKeys = const [3];

    controller.data = const [
      {'id': 1, 'score': 0},
      {'id': 5, 'score': 40},
      {'id': 6, 'score': 50},
    ];

    expect(controller.currentRowKey, 5, reason: '当前行消失后应保持原展示位置，而不是跳到首尾。');
    expect(controller.selectedRowKeys, const {3});
    expect(controller.expandedRowKeys, const {3});
    expect(controller.selectedRows, isEmpty);
    expect(controller.expandedRows, isEmpty);

    controller.data = const [
      {'id': 1, 'score': 0},
      {'id': 3, 'score': 60},
      {'id': 5, 'score': 40},
      {'id': 6, 'score': 50},
    ];
    expect(controller.selectedRows.map((row) => row['id']), const [3]);
    expect(controller.expandedRows.map((row) => row['id']), const [3]);
  });

  test('Controller 列顺序与显隐命令保持稳定身份语义', () {
    final controller = ElTableController(
      columns: const [
        ElTableColumn(key: 'a', prop: 'a'),
        ElTableColumn(key: 'b', prop: 'b'),
        ElTableColumn(key: 'c', prop: 'c'),
      ],
    );
    addTearDown(controller.dispose);

    expect(controller.setColumnOrder(const ['c']), isTrue);
    expect(controller.columnOrderKeys, const ['c', 'a', 'b']);
    expect(controller.setColumnOrder(const ['c', 'c', 'missing']), isFalse);

    expect(controller.setColumnVisible('b', false), isTrue);
    expect(controller.columnVisibility['b'], isFalse);
    expect(controller.visibleColumns.map((column) => column.key), const ['c', 'a']);
    expect(controller.setColumnVisible('missing', false), isFalse);
    expect(controller.toggleColumnVisible('b'), isTrue);
    expect(controller.columnVisibility['b'], isTrue);
    expect(controller.toggleColumnVisible('missing'), isFalse);
  });

  test('Controller 选择与展开命令覆盖条件批量和单行回退', () {
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'enabled': true},
        {'id': 2, 'enabled': false},
        {'id': 3, 'enabled': true},
      ],
    );
    addTearDown(controller.dispose);
    bool enabled(ElTableRow row) => row['enabled'] == true;

    expect(controller.hasSelectableRows(where: enabled), isTrue);
    controller.selectAll(where: enabled);
    expect(controller.selectedRowKeys, const {1, 3});
    expect(controller.selectionState(where: enabled), ElTableSelectionState.all);

    controller.unselect(controller.data.first);
    expect(controller.selectedRowKeys, const {3});
    expect(controller.selectionState(where: enabled), ElTableSelectionState.partial);
    controller.select(controller.data[1]);
    controller.unselectAll(where: enabled);
    expect(controller.selectedRowKeys, const {2});
    controller.clearSelection();
    expect(controller.selectedRowKeys, isEmpty);

    controller.toggleExpansion(controller.data.first);
    expect(controller.isExpanded(controller.data.first), isTrue);
    controller.collapse(controller.data.first);
    expect(controller.isExpanded(controller.data.first), isFalse);
    controller.expand(controller.data.last);
    controller.collapseAll();
    expect(controller.expandedRowKeys, isEmpty);
  });

  test('Controller 列宽与行高 reset/clear 命令保持幂等', () {
    final controller = ElTableController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller
      ..setColumnWidth('a', 100)
      ..setColumnWidth('b', 120)
      ..resetColumnWidth('a');
    expect(controller.columnWidths, const {'b': 120.0});
    controller.clearColumnWidths();
    expect(controller.columnWidths, isEmpty);

    controller
      ..setRowHeight(1, 44)
      ..setRowHeight(2, 52)
      ..resetRowHeight(1);
    expect(controller.rowHeights, const {2: 52.0});
    controller.clearRowHeights();
    expect(controller.rowHeights, isEmpty);

    final settledNotifications = notifications;
    controller
      ..resetColumnWidth('missing')
      ..clearColumnWidths()
      ..resetRowHeight('missing')
      ..clearRowHeights();
    expect(notifications, settledNotifications, reason: '空 reset/clear 不应产生无意义通知。');
  });

  test('sortedRows 对任意数据复用表格稳定排序算法', () {
    final controller = ElTableController(columns: const [ElTableColumn(prop: 'score', sort: true)]);
    addTearDown(controller.dispose);
    const rows = [
      {'id': 1, 'score': 2},
      {'id': 2, 'score': 1},
      {'id': 3, 'score': 1},
      {'id': 4, 'score': 3},
    ];

    controller.sort('score');
    expect(controller.sortedRows(rows).map((row) => row['id']), [2, 3, 1, 4]);

    controller.sort('score', ascending: false);
    expect(controller.sortedRows(rows).map((row) => row['id']), [4, 1, 2, 3]);

    controller.localSort = false;
    expect(controller.sortedRows(rows), rows);
  });

  test('Controller 解析 rowKey、columnKey 和 value', () {
    final controller = ElTableController(
      data: const [
        {
          'id': 1,
          'profile': {'name': 'Alice'},
          'status': 'active',
        },
      ],
      columns: [
        const ElTableColumn(prop: 'profile.name'),
        ElTableColumn(title: '操作', slotBuilder: (context, cell) => cell.row['id']),
        const ElTableColumn(prop: 'status'),
        const ElTableColumn(prop: 'absent.name'),
      ],
    );
    addTearDown(controller.dispose);

    expect(controller.rowKeyOf(controller.data.single), 1);
    expect(controller.columnKeyOf(controller.columns.first, 0), 'profile.name');
    expect(controller.columnKeyOf(controller.columns[1], 1), isA<int>());
    expect(controller.valueOf(controller.data.single, controller.columns.first), 'Alice');
    expect(controller.valueOf(controller.data.single, controller.columns[2]), 'active');
    expect(controller.valueOf(controller.data.single, controller.columns[3]), isNull);

    final nestedKeyController = ElTableController(
      rowKey: 'profile.name',
      data: const [
        {
          'id': 1,
          'profile': {'name': 'Alice'},
        },
      ],
    );
    addTearDown(nestedKeyController.dispose);
    expect(nestedKeyController.rowKeyOf(nestedKeyController.data.single), 'Alice');
    expect(
      () => ElTableController(
        rowKey: 'missing.id',
        data: const [
          <String, Object?>{'id': 1},
        ],
      ),
      throwsArgumentError,
    );
  });

  test('rowKey 唯一性在需要全量索引时惰性校验', () {
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice'},
        {'id': 1, 'name': 'Bob'},
      ],
    );
    addTearDown(controller.dispose);

    expect(() => controller.rowByKey(1), throwsArgumentError);
  });

  testWidgets('内置 checkbox 列提供表头三态和行选择状态', (tester) async {
    late BuildContext buildContext;
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Builder(
          builder: (context) {
            buildContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
        {'id': 3, 'name': 'Carol'},
      ],
      columns: [ElTableColumn(type: .checkbox, selectable: (row) => row['id'] != 3)],
    );
    addTearDown(controller.dispose);
    final column = controller.columns.single;

    expect(controller.columnWidthOf(column), 48);
    expect(controller.columnAlignOf(column), TextAlign.center);
    expect(controller.selectionState(where: column.selectable), ElTableSelectionState.none);
    var header = controller.headerContentOf(buildContext, column, 0) as ElTableSelectionControl;
    expect(header.isHeader, isTrue);
    expect(header.checked, isFalse);
    expect(header.indeterminate, isFalse);
    expect(header.disabled, isFalse);

    controller.select(controller.data.first);
    header = controller.headerContentOf(buildContext, column, 0) as ElTableSelectionControl;
    expect(header.state, ElTableSelectionState.partial);
    expect(header.indeterminate, isTrue);

    final selectedCell =
        controller.cellContentOf(buildContext, controller.data.first, 0, column, 0) as ElTableSelectionControl;
    final disabledCell =
        controller.cellContentOf(buildContext, controller.data.last, 2, column, 0) as ElTableSelectionControl;
    expect(selectedCell.checked, isTrue);
    expect(selectedCell.rowKey, 1);
    expect(disabledCell.disabled, isTrue);

    controller.toggleAllSelection(where: column.selectable);
    expect(controller.selectedRowKeys, {1, 2});
    expect(
      (controller.headerContentOf(buildContext, column, 0) as ElTableSelectionControl).state,
      ElTableSelectionState.all,
    );

    controller.toggleAllSelection(where: column.selectable);
    expect(controller.selectedRowKeys, isEmpty);
  });

  testWidgets('内置 index 与 expanded 类型返回语义内容', (tester) async {
    late BuildContext buildContext;
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Builder(
          builder: (context) {
            buildContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice'},
      ],
      columns: [
        const ElTableColumn(type: .index),
        const ElTableColumn(type: .index, index: 10),
        const ElTableColumn(type: .expanded),
      ],
    );
    addTearDown(controller.dispose);

    expect(controller.headerContentOf(buildContext, controller.columns[0], 0), '#');
    expect(controller.cellContentOf(buildContext, controller.data.single, 0, controller.columns[0], 0), 1);
    expect(controller.cellContentOf(buildContext, controller.data.single, 0, controller.columns[1], 1), 10);

    controller.expand(controller.data.single);
    final expand =
        controller.cellContentOf(buildContext, controller.data.single, 0, controller.columns[2], 2)
            as ElTableExpansionControl;
    expect(expand.expanded, isTrue);
    expect(expand.rowKey, 1);
    expect(controller.columnResizableOf(controller.columns[2]), isFalse);
  });

  test('Controller 可直接替换选择与展开行', () {
    final controller = createController();
    addTearDown(controller.dispose);

    const alice = {'id': 1, 'name': 'Alice'};
    const bob = {'id': 2, 'name': 'Bob'};
    controller.selectedRows = const [bob];
    controller.expandedRows = const [alice];

    expect(controller.isSelected(bob), isTrue);
    expect(controller.isExpanded(alice), isTrue);
    expect(controller.selectedRows, const [bob]);
    expect(controller.expandedRows, const [alice]);
  });

  test('Event 只向用户传递直观业务值', () {
    ElTableSort? sorted;
    ElTableSelectionChange? selected;
    ElTableRowContext? tapped;
    ElTableCell? tappedCell;
    final event = ElTableEvent(
      onSort: (sort) => sorted = sort,
      onSelectionChanged: (change) => selected = change,
      onRowTap: (row) => tapped = row,
      onCellTap: (cell) => tappedCell = cell,
    );
    final controller = createController();
    addTearDown(controller.dispose);
    final cell = ElTableCell(
      controller: controller,
      row: controller.data.first,
      rowKey: 1,
      rowIndex: 0,
      column: controller.columns.last,
      columnKey: 'name',
      columnIndex: 1,
      value: 'Alice',
    );

    event.onSort?.call(const ElTableSort(columnKey: 'name', ascending: false));
    controller.select(controller.data.first);
    event.onSelectionChanged?.call(
      ElTableSelectionChange(
        controller: controller,
        row: ElTableRowContext(controller: controller, row: controller.data.first, rowKey: 1, rowIndex: 0),
        selected: true,
      ),
    );
    event.onRowTap?.call(ElTableRowContext(controller: controller, row: controller.data.first, rowKey: 1, rowIndex: 0));
    event.onCellTap?.call(cell);

    expect(sorted, const ElTableSort(columnKey: 'name', ascending: false));
    expect(selected?.selectedRows, const [
      {'id': 1, 'name': 'Alice'},
    ]);
    expect(selected?.row?.rowIndex, 0);
    expect(tapped?.row, const {'id': 1, 'name': 'Alice'});
    expect(tapped?.rowIndex, 0);
    expect(tappedCell, cell);
  });

  testWidgets('ElTable 持有装配状态，且上层只需注入 style 值', (tester) async {
    final controller = createController();
    const viewKey = ValueKey<String>('table-view');

    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Align(
          alignment: .topLeft,
          child: SizedBox(
            width: 320,
            height: 240,
            child: ElTable(key: viewKey, controller: controller, style: const _CompactTableStyle()),
          ),
        ),
      ),
    );

    final view = tester.widget<ElTable>(find.byKey(viewKey));
    expect(view, isA<StatefulWidget>());
    expect(view.controller, same(controller));
    expect(view.style, isA<_CompactTableStyle>());
    expect(view.style.rowHeight, 28);
    expect(tester.renderObject<RenderBox>(find.byKey(viewKey)).size, const Size(320, 240));

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('Style 直接控制几何且同 key 更新复用约束宿主', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ],
      columns: const [
        ElTableColumn(prop: 'name'),
        ElTableColumn(prop: 'status'),
      ],
    );
    const viewKey = ValueKey<String>('styled-table-view');

    Widget build(ElTableStyle style) {
      return Directionality(
        textDirection: .ltr,
        child: UnconstrainedBox(
          alignment: .topLeft,
          child: ElTable(key: viewKey, controller: controller, style: style),
        ),
      );
    }

    await tester.pumpWidget(build(const _CompactTableStyle()));
    final renderObject = tester.renderObject<RenderBox>(find.byKey(viewKey));
    expect(renderObject.size, const Size(140, 88));

    await tester.pumpWidget(build(const _WideTableStyle()));
    expect(tester.renderObject<RenderBox>(find.byKey(viewKey)), same(renderObject));
    expect(renderObject.size, const Size(240, 144));

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('viewport 高度决定表格窗口尺寸', (tester) async {
    final controller = createController();
    const viewKey = ValueKey<String>('viewport-table-view');

    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: UnconstrainedBox(
          alignment: .topLeft,
          child: ElTable(key: viewKey, controller: controller, height: 180),
        ),
      ),
    );

    final view = tester.widget<ElTable>(find.byKey(viewKey));
    expect(view.height, 180);
    expect(tester.renderObject<RenderBox>(find.byKey(viewKey)).size, const Size(208, 180));

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('同 key 更新 controller、style 和 event 时复用 RenderObject', (tester) async {
    final first = createController();
    final second = createController();
    const viewKey = ValueKey<String>('stable-table-view');

    Widget build(ElTableController controller, ElTableStyle style, {ValueChanged<ElTableRowContext>? onRowTap}) =>
        Directionality(
          textDirection: .ltr,
          child: SizedBox(
            width: 200,
            height: 100,
            child: ElTable(key: viewKey, controller: controller, style: style, onRowTap: onRowTap),
          ),
        );

    await tester.pumpWidget(build(first, const _CompactTableStyle()));
    final renderObject = tester.renderObject(find.byKey(viewKey));

    await tester.pumpWidget(build(second, const _WideTableStyle(), onRowTap: (_) {}));

    expect(tester.renderObject(find.byKey(viewKey)), same(renderObject));
    second.data = const [
      {'id': 3, 'name': 'Carol'},
    ];
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    first.dispose();
    second.dispose();
  });

  testWidgets('滚动 API 按 rowKey 定位 viewport 行', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      data: [
        for (var index = 0; index < 100; index++) {'id': index, 'name': 'User $index'},
      ],
      columns: const [ElTableColumn(title: '名称', prop: 'name', width: 160)],
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: ElTable(controller: controller, height: 160),
      ),
    );

    final scroll = controller.scrollTo(90);
    await tester.pumpAndSettle();
    expect(await scroll, isTrue);
    expect(await controller.scrollTo(999), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  test('Controller 集中管理表头、空态、固定行、汇总、行样式和排序模式', () {
    Object? summary(BuildContext context, ElTableSummaryCell cell) => cell.columnIndex;
    Object? empty(BuildContext context, ElTableController controller) => 'empty';
    ElStyle? rowStyle(ElTableRowContext row) => row.rowIndex.isEven ? const ElStyle(bgColor: Color(0xffeeeeee)) : null;
    final controller = ElTableController(
      showHeader: false,
      emptyBuilder: empty,
      pinnedRowKeys: const [1],
      summaryBuilder: summary,
      rowStyleBuilder: rowStyle,
      rowResizable: true,
      localSort: false,
    );
    addTearDown(controller.dispose);

    expect(controller.showHeader, isFalse);
    expect(controller.emptyBuilder, same(empty));
    expect(controller.pinnedRowKeys, {1});
    expect(controller.summaryBuilder, same(summary));
    expect(controller.rowStyleBuilder, same(rowStyle));
    expect(controller.rowResizable, isTrue);
    expect(controller.localSort, isFalse);

    controller.update(showHeader: true, pinnedRowKeys: const [2], rowResizable: false, localSort: true);
    expect(controller.showHeader, isTrue);
    expect(controller.pinnedRowKeys, {2});
    expect(controller.rowResizable, isFalse);
    expect(controller.localSort, isTrue);

    controller
      ..emptyBuilder = null
      ..summaryBuilder = null
      ..rowStyleBuilder = null;
    expect(controller.emptyBuilder, isNull);
    expect(controller.summaryBuilder, isNull);
    expect(controller.rowStyleBuilder, isNull);
  });

  test('重复字段列获得独立状态 key，重复显式 key 直接拒绝', () {
    final controller = ElTableController(
      columns: const [
        ElTableColumn(prop: 'name'),
        ElTableColumn(prop: 'name'),
      ],
    );
    addTearDown(controller.dispose);

    final first = controller.columnKeyOf(controller.visibleColumns[0], 0);
    final second = controller.columnKeyOf(controller.visibleColumns[1], 1);
    expect(first, 'name');
    expect(second, isNot(first));

    expect(
      () => ElTableController(
        columns: const [
          ElTableColumn(key: 'same', prop: 'a'),
          ElTableColumn(key: 'same', prop: 'b'),
        ],
      ),
      throwsArgumentError,
    );
  });

  testWidgets('选择表头聚合在单行切换时增量更新', (tester) async {
    late BuildContext buildContext;
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Builder(
          builder: (context) {
            buildContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    var predicateCalls = 0;
    bool selectable(ElTableRow row) {
      predicateCalls++;
      return row['enabled'] == true;
    }

    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'enabled': true},
        {'id': 2, 'enabled': true},
        {'id': 3, 'enabled': false},
      ],
      columns: [ElTableColumn(type: .checkbox, selectable: selectable)],
    );
    addTearDown(controller.dispose);
    final column = controller.columns.single;

    controller.headerContentOf(buildContext, column, 0);
    expect(predicateCalls, 3);
    controller.headerContentOf(buildContext, column, 0);
    expect(predicateCalls, 3, reason: '同一数据和规则的表头聚合应直接命中缓存。');

    controller.select(controller.data.first);
    controller.headerContentOf(buildContext, column, 0);
    expect(predicateCalls, 4, reason: '单行变化只需判断这一行，不应重新扫描全部数据。');
  });
}
