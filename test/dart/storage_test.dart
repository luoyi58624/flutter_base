import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_base/src/dart/gen/index.dart';
import 'package:flutter_base/src/dart/storage/index.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';

class _Base64ElCodec extends ElCodec {
  _Base64ElCodec();

  @override
  String encode(Uint8List bytes) => base64UrlEncode(bytes);

  @override
  Uint8List decode(String text) => base64Url.decode(text);
}

void main() {
  late Directory root;
  late ElStorageGroup group;

  File fileOfKey(String key, [ElStorageGroup? targetGroup]) =>
      File(p.join((targetGroup ?? group).storagePath!, '$key.json'));

  Future<void> eventually(
    bool Function() predicate, {
    Duration timeout = const Duration(seconds: 2),
    Duration interval = const Duration(milliseconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      if (predicate()) return;
      if (DateTime.now().isAfter(deadline)) fail('等待条件超时: $timeout');
      await Future<void>.delayed(interval);
    }
  }

  Map<String, dynamic> readSnapshot(
    String key, [
    ElStorageGroup? targetGroup,
  ]) => (jsonDecode(fileOfKey(key, targetGroup).readAsStringSync()) as Map)
      .cast<String, dynamic>();

  Map<String, dynamic> readSnapshotData(
    String key, [
    ElStorageGroup? targetGroup,
  ]) => (readSnapshot(key, targetGroup)['data'] as Map).cast<String, dynamic>();

  Map<String, dynamic> readSnapshotExpires(
    String key, [
    ElStorageGroup? targetGroup,
  ]) => (readSnapshot(key, targetGroup)['expires'] as Map)
      .cast<String, dynamic>();

  int readSnapshotVersion(String key, [ElStorageGroup? targetGroup]) =>
      readSnapshot(key, targetGroup)['version'] as int;

  setUp(() {
    root = Directory.systemTemp.createTempSync('flutter_base_storage_test_');
    group = ElStorageGroup(storagePath: root.path, key: 'main');
  });

  tearDown(() {
    group.removeStorageAll();
    group.closeAll();
    if (root.existsSync()) {
      final target = p.normalize(root.absolute.path);
      final tempRoot = p.normalize(Directory.systemTemp.absolute.path);
      if (!p.isWithin(tempRoot, target) ||
          !p.basename(target).startsWith('flutter_base_storage_test_')) {
        throw StateError('拒绝删除测试临时目录之外的路径：$target');
      }
      root.deleteSync(recursive: true);
    }
  });

  test('group 默认使用当前执行目录', () {
    final currentGroup = ElStorageGroup();
    addTearDown(currentGroup.closeAll);
    expect(
      p.normalize(currentGroup.storagePath!),
      p.normalize(Directory.current.path),
    );
  });

  test('group key 会作为 IO 分组目录', () {
    expect(
      p.normalize(group.storagePath!),
      p.normalize(p.join(root.path, 'main')),
    );
  });

  test('重复 group key 会触发调试断言', () {
    final first = ElStorageGroup(storagePath: root.path, key: 'dup');
    addTearDown(first.closeAll);

    expect(
      () => ElStorageGroup(storagePath: p.join(root.path, 'other'), key: 'dup'),
      throwsA(isA<AssertionError>()),
    );

    first.closeAll();
    final second = ElStorageGroup(storagePath: root.path, key: 'dup');
    addTearDown(second.closeAll);
    expect(second.key, 'dup');
  });

  test('不同 group key 支持在同一路径使用相同 storage key', () async {
    final otherGroup = ElStorageGroup(storagePath: root.path, key: 'other');
    addTearDown(() {
      otherGroup.removeStorageAll();
      otherGroup.closeAll();
    });

    final first = await group.open('same', debounceTime: 1);
    final second = await otherGroup.open('same', debounceTime: 1);

    first.setItem('value', 'first');
    second.setItem('value', 'second');
    await eventually(
      () =>
          fileOfKey('same').existsSync() &&
          fileOfKey('same', otherGroup).existsSync(),
    );

    expect(readSnapshotData('same'), {'value': 'first'});
    expect(readSnapshotData('same', otherGroup), {'value': 'second'});
  });

  test('open 相同 key 会返回已打开实例', () async {
    final first = await group.open('same_open', debounceTime: 1);
    final second = await group.open('same_open', debounceTime: 1000);
    final third = await group.open('same_open', debounceTime: 0);

    expect(identical(first, second), isTrue);
    expect(identical(first, third), isTrue);
    expect(group.length, 1);
    expect(group.get('same_open'), same(first));
    expect(group.has('same_open'), isTrue);
    expect(group.keys, ['same_open']);
    expect(group.storages, [first]);
  });

  test('debounceTime<=0 会立即持久化', () async {
    final storage = await group.open('no_debounce', debounceTime: -1);

    storage.setItem('foo', 'bar');
    expect(fileOfKey('no_debounce').existsSync(), isTrue);
    expect(readSnapshotData('no_debounce'), {'foo': 'bar'});

    storage.setItem('count', 1);
    expect(readSnapshotData('no_debounce'), {'foo': 'bar', 'count': 1});
  });

  test('setItem write=false 只更新内存，可手动持久化', () async {
    final storage = await group.open('manual_write', debounceTime: 1);

    storage.setItem('foo', 'bar', write: false);
    await Future<void>.delayed(Duration(milliseconds: 20));
    expect(fileOfKey('manual_write').existsSync(), isFalse);

    storage.write();

    expect(fileOfKey('manual_write').existsSync(), isTrue);
    expect(readSnapshotData('manual_write'), {'foo': 'bar'});
  });

  test('group codec 会编码本地快照并支持重新打开', () async {
    final codecGroup = ElStorageGroup(
      storagePath: root.path,
      key: 'codec_group',
      codec: _Base64ElCodec(),
    );
    addTearDown(codecGroup.closeAll);

    final storage = await codecGroup.open('secret', debounceTime: 0);
    storage.setItem('token', 'abc');

    final text = fileOfKey('secret', codecGroup).readAsStringSync();
    expect(text.contains('abc'), isFalse);
    expect((jsonDecode(text) as Map).containsKey('payload'), isTrue);

    codecGroup.close('secret');
    final reopened = await codecGroup.open('secret', debounceTime: 0);
    expect(reopened.getItem<String>('token'), 'abc');
  });

  test('storage codec 可以显式使用明文覆盖 group codec', () async {
    final codecGroup = ElStorageGroup(
      storagePath: root.path,
      key: 'codec_override',
      codec: _Base64ElCodec(),
    );
    addTearDown(codecGroup.closeAll);

    final storage = await codecGroup.open(
      'plain',
      debounceTime: 0,
      codec: ElCodec(),
    );
    storage.setItem('token', 'abc');

    expect(storage.codec.runtimeType, ElCodec);
    expect(readSnapshotData('plain', codecGroup), {'token': 'abc'});
  });

  test('打开编码快照时需要匹配的 codec', () async {
    final codecGroup = ElStorageGroup(
      storagePath: root.path,
      key: 'codec_error',
      codec: _Base64ElCodec(),
    );

    final storage = await codecGroup.open('secret', debounceTime: 0);
    storage.setItem('token', 'abc');
    codecGroup.closeAll();

    final wrongGroup = ElStorageGroup(
      storagePath: root.path,
      key: 'codec_error',
    );
    addTearDown(wrongGroup.closeAll);

    expect(
      wrongGroup.open('secret', debounceTime: 0),
      throwsA(isA<ElCodecException>()),
    );
  });

  test('并发 open 相同 key 会返回同一个实例', () async {
    final firstOpening = group.open('same_pending', debounceTime: 1);
    final secondOpening = group.open('same_pending', debounceTime: 1000);

    final first = await firstOpening;
    final second = await secondOpening;

    expect(second, same(first));
    expect(group.length, 1);
  });

  test('setItem/getItem/removeItem/removeMultiItem/clear 功能正常', () async {
    final storage = await group.open('basic', debounceTime: 1);

    storage.setItem('k1', 'v1');
    storage.setItem('k2', 2);
    storage.setItem('k3', true);
    await eventually(() => fileOfKey('basic').existsSync());

    expect(storage.length, 3);
    expect(storage.hasKey('k1'), isTrue);
    expect(storage.getItem<String>('k1'), 'v1');
    expect(storage.getItem<int>('k2'), 2);
    expect(storage.getItem<bool>('k3'), true);
    expect(readSnapshotData('basic'), {'k1': 'v1', 'k2': 2, 'k3': true});

    storage.removeItem('k2');
    await eventually(() => readSnapshotData('basic')['k2'] == null);
    expect(storage.hasKey('k2'), isFalse);

    storage.setItem('k4', 4);
    storage.removeMultiItem(['k1', 'k3']);
    await eventually(() {
      final json = readSnapshotData('basic');
      return json['k1'] == null && json['k3'] == null && json['k4'] == 4;
    });
    expect(storage.keys, ['k4']);

    storage.clear();
    await eventually(() => readSnapshotData('basic').isEmpty);
    expect(storage.length, 0);
  });

  test('初始化会读取已有 JSON 快照', () async {
    fileOfKey('load').writeAsStringSync(
      jsonEncode({
        '__el_storage_snapshot_version__': 1,
        'version': 1,
        'data': {
          'x': 1,
          'nested': {'ok': true},
        },
        'expires': <String, dynamic>{},
      }),
    );

    final storage = await group.open('load', debounceTime: 1);

    expect(storage.version, 1);
    expect(storage.getItem<int>('x'), 1);
    expect(storage.getItem<Map>('nested'), {'ok': true});
  });

  test('旧格式根 Map 不再读取为用户数据', () async {
    fileOfKey('legacy_root').writeAsStringSync(
      jsonEncode({
        'x': 1,
        'nested': {'ok': true},
      }),
    );

    final storage = await group.open('legacy_root', debounceTime: 0);

    expect(storage.length, 0);
    expect(storage.getItem<int>('x'), isNull);
  });

  test('open 会迁移旧版本数据并写回本地快照', () async {
    fileOfKey('migrate').writeAsStringSync(
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

    final storage = await group.open(
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
    expect(readSnapshotVersion('migrate'), 2);
    expect((readSnapshotData('migrate')['users'] as List).first, {
      'id': 1,
      'name': 'old',
      'role': 'user',
    });
  });

  test('缺少迁移规则会抛出错误', () async {
    fileOfKey('missing_migration').writeAsStringSync(
      jsonEncode({
        '__el_storage_snapshot_version__': 1,
        'version': 1,
        'data': {'foo': 'bar'},
        'expires': <String, dynamic>{},
      }),
    );

    expect(
      group.open('missing_migration', debounceTime: 0, version: 2),
      throwsA(isA<ElStorageMigrationException>()),
    );
  });

  test('removeStorage 会清理快照文件', () async {
    final storage = await group.open('remove', debounceTime: 1);

    storage.setItem('foo', 'bar');
    await eventually(() => fileOfKey('remove').existsSync());
    expect(group.has('remove'), isTrue);

    group.removeStorage('remove');

    expect(group.has('remove'), isFalse);
    expect(fileOfKey('remove').existsSync(), isFalse);
  });

  test('removeStorage 可在 close 后继续删除本地快照', () async {
    final storage = await group.open('remove_after_close', debounceTime: 1);

    storage.setItem('foo', 'bar');
    group.close('remove_after_close');
    expect(fileOfKey('remove_after_close').existsSync(), isTrue);

    group.removeStorage('remove_after_close');

    expect(fileOfKey('remove_after_close').existsSync(), isFalse);
  });

  test('group removeStorage(key) 只删除目标存储', () async {
    final first = await group.open('first_remove', debounceTime: 1);
    final second = await group.open('second_remove', debounceTime: 1);

    first.setItem('foo', 'bar');
    second.setItem('hello', 'world');
    await eventually(
      () =>
          fileOfKey('first_remove').existsSync() &&
          fileOfKey('second_remove').existsSync(),
    );

    group.removeStorage('first_remove');

    expect(first.isClose, isTrue);
    expect(second.isClose, isFalse);
    expect(group.has('first_remove'), isFalse);
    expect(group.has('second_remove'), isTrue);
    expect(fileOfKey('first_remove').existsSync(), isFalse);
    expect(fileOfKey('second_remove').existsSync(), isTrue);
  });

  test('group clear(key) 只清空目标存储', () async {
    final first = await group.open('first_clear', debounceTime: 1);
    final second = await group.open('second_clear', debounceTime: 1);

    first.setItem('foo', 'bar');
    second.setItem('hello', 'world');
    await eventually(
      () =>
          fileOfKey('first_clear').existsSync() &&
          fileOfKey('second_clear').existsSync(),
    );

    group.clear('first_clear');

    await eventually(() => readSnapshotData('first_clear').isEmpty);
    expect(readSnapshotData('second_clear'), {'hello': 'world'});
  });

  test('group clearAll 会批量清空已打开存储', () async {
    final first = await group.open('first_clear_all', debounceTime: 1);
    final second = await group.open('second_clear_all', debounceTime: 1);

    first.setItem('foo', 'bar');
    second.setItem('hello', 'world');
    await eventually(
      () =>
          fileOfKey('first_clear_all').existsSync() &&
          fileOfKey('second_clear_all').existsSync(),
    );

    group.clearAll();

    await eventually(() {
      final firstJson = readSnapshotData('first_clear_all');
      final secondJson = readSnapshotData('second_clear_all');
      return firstJson.isEmpty && secondJson.isEmpty;
    });
  });

  test('group removeStorageAll 会批量清理快照文件', () async {
    final first = await group.open('first', debounceTime: 1);
    final second = await group.open('second', debounceTime: 1);

    first.setItem('foo', 'bar');
    second.setItem('hello', 'world');
    await eventually(
      () => fileOfKey('first').existsSync() && fileOfKey('second').existsSync(),
    );

    group.removeStorageAll();

    expect(group.length, 0);
    expect(fileOfKey('first').existsSync(), isFalse);
    expect(fileOfKey('second').existsSync(), isFalse);
  });

  test('storage close 会从 group 释放并禁止继续操作', () async {
    final storage = await group.open('close', debounceTime: 1);

    storage.setItem('foo', 'bar');
    group.close('close');

    expect(group.has('close'), isFalse);
    expect(storage.isClose, isTrue);
    expect(fileOfKey('close').existsSync(), isTrue);
    expect(() => storage.getItem<String>('foo'), throwsA(isA<StateError>()));
    expect(() => storage.setItem('next', 'value'), throwsA(isA<StateError>()));
    expect(storage.clear, throwsA(isA<StateError>()));

    final reopened = await group.open('close', debounceTime: 1);
    expect(reopened.getItem<String>('foo'), 'bar');
    expect(reopened, isNot(same(storage)));
  });

  test('group close(key) 只关闭目标存储', () async {
    final first = await group.open('first_close', debounceTime: 1);
    final second = await group.open('second_close', debounceTime: 1);

    first.setItem('foo', 'bar');
    second.setItem('hello', 'world');

    group.close('first_close');

    expect(first.isClose, isTrue);
    expect(second.isClose, isFalse);
    expect(group.has('first_close'), isFalse);
    expect(group.has('second_close'), isTrue);
    expect(second.getItem<String>('hello'), 'world');
  });

  test('group closeAll 会批量关闭并允许重新打开', () async {
    final first = await group.open('first_close_all', debounceTime: 1);
    final second = await group.open('second_close_all', debounceTime: 1);

    first.setItem('foo', 'bar');
    second.setItem('hello', 'world');

    group.closeAll();

    expect(first.isClose, isTrue);
    expect(second.isClose, isTrue);
    expect(group.length, 0);
    expect(() => first.hasKey('foo'), throwsA(isA<StateError>()));
    expect(
      (await group.open(
        'first_close_all',
        debounceTime: 1,
      )).getItem<String>('foo'),
      'bar',
    );
  });

  test('serialize + expire 行为正常', () async {
    final storage = await group.open('expire', debounceTime: 1);

    final now = DateTime.now();
    storage.setItem<DateTime>(
      'dt',
      now,
      serialize: ElDateTimeSerialize(),
      expire: Duration(milliseconds: 80),
    );
    await eventually(() => fileOfKey('expire').existsSync());

    final v1 = storage.getItem<DateTime>(
      'dt',
      serialize: ElDateTimeSerialize(),
    );
    expect(v1?.millisecondsSinceEpoch, now.millisecondsSinceEpoch);

    await Future<void>.delayed(Duration(milliseconds: 100));
    expect(
      storage.getItem<DateTime>('dt', serialize: ElDateTimeSerialize()),
      isNull,
    );
    expect(storage.hasKey('dt'), isFalse);
  });

  test('用户 Map 字段不会被误判为过期数据', () async {
    final storage = await group.open('expire_collision', debounceTime: 0);
    final payload = {'expire_date': 1, 'data': 'origin'};

    storage.setItem('payload', payload);

    expect(storage.getItem<Map>('payload'), payload);
    expect(readSnapshotData('expire_collision')['payload'], payload);
    expect(readSnapshotExpires('expire_collision'), isEmpty);
  });

  test('setItem write=false 支持手动写入过期元数据', () async {
    final storage = await group.open('manual_expire', debounceTime: 1);

    storage.setItem('token', 'abc', expire: Duration(seconds: 1), write: false);
    await Future<void>.delayed(Duration(milliseconds: 20));
    expect(fileOfKey('manual_expire').existsSync(), isFalse);

    storage.write();

    expect(readSnapshotData('manual_expire'), {'token': 'abc'});
    expect(readSnapshotExpires('manual_expire')['token'], isA<int>());
  });

  test('过期时间 API 行为正常', () async {
    final storage = await group.open('expire_api', debounceTime: 0);

    storage.setItem('session', 'ok', expire: Duration(seconds: 1));

    expect(storage.checkExpire('missing'), isFalse);
    expect(storage.checkExpire('session'), isFalse);
    expect(storage.ttl('session'), isNotNull);
    expect(storage.removeExpire('session'), isTrue);
    expect(storage.ttl('session'), isNull);
    expect(readSnapshotExpires('expire_api'), isEmpty);
  });

  test('setExpire includeUpdate=false 不覆盖已有过期时间', () async {
    final storage = await group.open('set_expire', debounceTime: 1);

    storage.setItem('a', 1, expire: Duration(hours: 1));
    await eventually(() => fileOfKey('set_expire').existsSync());
    final firstExpire = readSnapshotExpires('set_expire')['a'];

    storage.setExpire('a', Duration(hours: 2), includeUpdate: false);
    await Future<void>.delayed(Duration(milliseconds: 20));
    expect(readSnapshotExpires('set_expire')['a'], firstExpire);
  });
}
