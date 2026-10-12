import 'dart:io';

import 'package:flutter_base/src/dart/storage/index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('存储使用迁移后的工具调度写入并支持过期', () async {
    final directory = Directory.systemTemp.createTempSync(
      'flutter_base_storage_',
    );
    final group = ElStorageGroup(storagePath: directory.path, key: 'utility');
    addTearDown(() {
      group.closeAll();
      directory.deleteSync(recursive: true);
    });
    final storage = await group.open('sample', debounceTime: 0);
    storage.setItem('answer', 42);
    expect(storage.getItem<int>('answer'), 42);
    expect(
      File('${group.storagePath}/sample.json').readAsStringSync(),
      contains('42'),
    );
    storage.setItem('expired', 1, expire: Duration(milliseconds: -1));
    expect(storage.getItem<int>('expired'), isNull);
  });
}
