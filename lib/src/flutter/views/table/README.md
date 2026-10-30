# Table

导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。ElTableController 持有数据、列与交互状态；ElTable 提供视口、外观和用户事件。外部控制器长期持有，先卸载表格再 dispose。

## 数据、列与单元格

```dart
final controller = ElTableController(
  rowKey: 'id',
  data: [{'id': 1, 'name': 'Alice', 'score': 95}],
  columns: [
    ElTableColumn(type: ElTableColumnType.index, title: '序号'),
    ElTableColumn(prop: 'name', title: '姓名', width: 140, fixed: ElTableColumnFixed.left),
    ElTableColumn(
      prop: 'score', title: '得分', sort: true,
      formatter: (value, cell) => '$value 分',
      cellStyleBuilder: (cell) => ElStyle(color: Colors.blue),
    ),
    ElTableColumn(
      key: 'actions', title: '操作',
      slotBuilder: (_, cell) => ElButtonView(onPressed: () {}, child: '查看 ${cell.row['name']}'),
    ),
  ],
);
ElTable(controller: controller, height: 320);
```

| 列配置 | 说明 |
| --- | --- |
| key / prop / title | 稳定身份、Map 取值字段、表头；prop 支持点路径 |
| width / minWidth / flex | 普通列定宽或按权重分剩余宽；内置列统一定宽，index 随序号位数自适应 |
| fixed / visible | 左右固定、显隐 |
| formatter / slotBuilder | 格式化值或返回完整内容；cell 包含 row、rowKey、rowIndex、column、value 等 |
| headerBuilder / headerStyle / headerAlign | 表头内容与外观；ElTable.headerCellBuilder 可接管完整表头单元格 |
| align / cellStyleBuilder / showOverflow | 单元格对齐、数据驱动样式、溢出配置 |
| children | 分组表头，叶子列参与数据区域 |

rowKey 需要对应唯一稳定值；需要选择、展开、重排数据时不要用临时下标作为业务身份。height 不传时按内容自然高度布局。

## 选择、当前行与展开

```dart
final controller = ElTableController(
  rowKey: 'id',
  data: [{'id': 1, 'name': 'Alice'}],
  columns: [
    ElTableColumn(type: ElTableColumnType.checkbox, selectable: (row) => row['id'] != 0),
    ElTableColumn(
      type: ElTableColumnType.expanded,
      slotBuilder: (_, cell) => Text('详情：${cell.row['name']}'),
    ),
    ElTableColumn(prop: 'name', title: '姓名'),
  ],
);
ElTable(
  controller: controller, height: 240,
  onSelectionChanged: (_) => debugPrint('${controller.selectedRowKeys}'),
  onExpansionChanged: (row, expanded) => debugPrint('$expanded'),
  onRowTap: (row) => debugPrint('${row.rowKey}'),
);
ElButtonView(onPressed: controller.selectAll, child: '全选');
```

| 控制器 API | 用途 |
| --- | --- |
| selectedRowKeys / selectedRows | 读取或替换选中集合 |
| select / unselect / toggleSelection | 操作单行，入参为业务行 Map |
| selectAll / unselectAll / toggleAllSelection / clearSelection | 批量选择；前三者支持 where 过滤 |
| selectionState / isSelected | 表头三态与单行状态 |
| currentRow / currentRowKey | 当前行，与多选集合独立 |
| expand / collapse / toggleExpansion / collapseAll | 展开操作；expandedRowKeys / expandedRows 读写集合 |
| scrollTo(rowKey) | 定位业务行，返回是否成功 |

checkbox 列的 selectable、expanded 列的 expandable 控制每行是否允许操作。onSelectionChanged 是用户交互事件；程序化操作后监听 controller 获取变化。onCurrentChanged、onRowDoubleTap、onRowSecondaryTap、onCellTap 分别接当前行、双击、右键和单元格事件。

## 排序与远程数据

```dart
final controller = ElTableController(
  rowKey: 'id', localSort: false,
  data: [{'id': 1, 'name': 'Alice'}],
  columns: [ElTableColumn(prop: 'name', title: '姓名', sort: true, sortField: 'user_name')],
);
ElTable(
  controller: controller, height: 240,
  onSort: (sort) {
    // 用 sort.columnKey / ascending 请求服务端，再替换 controller.data。
  },
  onClearSort: () {},
);
```

默认 localSort 为 true；列的 sorter 可自定义本地比较器，initialSortAscending 控制首次排序方向，sortRequired 禁止清空排序。外部分页先对完整数据调用 `controller.sortedRows(rows)` 再截页，避免只排序当前页。

## 配置更新与尺寸持久化

```dart
final controller = ElTableController(
  id: 'users', cacheEnabled: true, rowKey: 'id',
  data: [{'id': 1, 'name': 'Alice'}],
  columns: [ElTableColumn(prop: 'name', title: '姓名', resizable: true)],
);
controller.data = [...controller.data, {'id': 2, 'name': 'Bob'}];
controller.setColumnWidth('name', 180);
controller.setRowHeight(1, 48);
ElTable(controller: controller, height: 320, columnReorderable: true);
```

- data、columns 用新集合替换，或用 update 批量更新；不要直接修改只读配置集合。
- setColumnVisible / toggleColumnVisible、setColumnFixed、setColumnOrder / moveColumnTo 调整列配置。
- setColumnWidth / resetColumnWidth / clearColumnWidths；setRowHeight / resetRowHeight / clearRowHeights 管理尺寸，rowResizable 开启行高拖动。
- showHeader、emptyBuilder、pinnedRowKeys、summaryBuilder、rowStyleBuilder 分别控制表头、空态、固定行、合计与行样式。
- id + cacheEnabled 启用配置缓存，使用项目 ElStorage 配置；clearCachedConfiguration 清除当前表缓存。
- 用户拖动事件为 onColumnOrderChanged / onColumnWidthsChanged / onRowHeightsChanged；focusNode 开启根键盘入口。

外观通过 ElTableStyle 覆写，未覆写字段可取 ElComponentProvider 的 tableStyleBuilder。**现有反向依赖：该模块仍导入 UI 层 ElComponentProvider**，目录迁入 Flutter 不代表依赖已经消除。
