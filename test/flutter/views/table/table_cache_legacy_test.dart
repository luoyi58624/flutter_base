import 'dart:io';

import 'package:flutter_base/dart.dart' show ElStorageGroup;
import 'package:flutter_base/src/flutter/views/table/table.dart';
import 'package:flutter_test/flutter_test.dart';

/// 旧格式列缓存负载的兼容契约（schema 1、没有 `fixed` 字段）。
///
/// 内核的列缓存通道是「当前执行目录 + `el_ui_table/el_ui_tables.json`」这一份存储，
/// 所以这里先把 cwd 换成临时目录、独占这份存储，再写一份**旧版本**负载进去，
/// 让内核自己去恢复它 —— 老缓存既不能被当成损坏，也不能被凭空补出固定列。
void main() {
  test('旧列缓存负载没有 fixed 字段时按未固定恢复，其余配置照常生效', () async {
    const id = 'table-api-cache-legacy';
    const columns = <ElTableColumn>[
      ElTableColumn(key: 'name', title: '名称', prop: 'name'),
      ElTableColumn(key: 'age', title: '年龄', prop: 'age'),
      ElTableColumn(key: 'status', title: '状态', prop: 'status', fixed: .left),
    ];
    final root = Directory.systemTemp.createTempSync('el_ui_table_cache_legacy');
    final previousCurrent = Directory.current;
    Directory.current = root.path;
    addTearDown(() {
      Directory.current = previousCurrent;
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    // 与内核同一套存储通道，写入一份旧格式负载：schema 1、没有 fixed 字段。
    final group = ElStorageGroup(key: 'el_ui_table');
    final storage = await group.open('el_ui_tables');
    storage.setItem<Object?>('table.v1.$id', <String, Object?>{
      'schema': 1,
      'order': <String>['key:s:age', 'key:s:name', 'key:s:status'],
      'visibility': <String, bool>{'key:s:status': false},
      'widths': <String, double>{'key:s:name': 144},
      'sortKey': null,
      'sortAscending': null,
    });
    group.closeAll();

    final reader = ElTableController(id: id, cacheEnabled: true, columns: columns);
    addTearDown(() {
      reader.clearCachedConfiguration();
      reader.dispose();
    });

    // 构造期只能读内存镜像，存储打开后内核会再重放一次恢复；等这次恢复落地。
    for (var attempt = 0; attempt < 200 && reader.columnWidths.isEmpty; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(reader.columnWidths, const {'name': 144.0}, reason: '旧负载的列宽照常恢复 → 缓存没有被当成损坏。');
    expect(reader.columnOrderKeys, const ['age', 'name', 'status'], reason: '旧负载的顺序照常恢复。');
    expect(reader.columnVisibility['status'], isFalse, reason: '旧负载的显隐照常恢复。');
    expect(reader.columns.map((column) => column.fixed), const [
      null,
      null,
      ElTableColumnFixed.left,
    ], reason: '旧负载没有 fixed 字段 → 全部未固定；列上声明的固定方向保持声明值。');
  });
}
