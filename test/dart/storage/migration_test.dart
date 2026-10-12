import 'dart:convert';

import 'package:flutter_base/dart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'storage_test_support.dart';

void main() {
  final context = StorageTestContext();

  setUp(context.setUp);

  tearDown(context.tearDown);

  test('open 会迁移旧版本数据并写回本地快照', () async {
    context
        .fileOfKey('migrate')
        .writeAsStringSync(
          jsonEncode({
            '__el_storage_snapshot_version__': 1,
            'version': 1,
            'data': {
              'users': [
                {'id': 1, 'name': 'old'},
              ],
              'next_id': 2,
            },
            'expires': <String, dynamic>{},
          }),
        );

    final storage = await context.group.open(
      'migrate',
      debounceTime: 0,
      version: 2,
      migrations: [
        ElStorageMigration(
          from: 1,
          to: 2,
          migrate: (data) {
            final rows = data['users'];
            if (rows is! List) return;
            for (final row in rows) {
              if (row is Map) row['role'] ??= 'user';
            }
          },
        ),
      ],
    );

    final users = storage.getItem<List>('users')!;
    expect(storage.version, 2);
    expect(users.first, {'id': 1, 'name': 'old', 'role': 'user'});
    expect(context.readSnapshotVersion('migrate'), 2);
    expect((context.readSnapshotData('migrate')['users'] as List).first, {
      'id': 1,
      'name': 'old',
      'role': 'user',
    });
  });

  test('缺少迁移规则会抛出错误', () async {
    context
        .fileOfKey('missing_migration')
        .writeAsStringSync(
          jsonEncode({
            '__el_storage_snapshot_version__': 1,
            'version': 1,
            'data': {'foo': 'bar'},
            'expires': <String, dynamic>{},
          }),
        );

    expect(
      context.group.open('missing_migration', debounceTime: 0, version: 2),
      throwsA(isA<ElStorageMigrationException>()),
    );
  });
}
