import 'dart:convert';
import 'dart:io';

import 'package:flutter_base/dart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'storage_test_support.dart';

void main() {
  final context = StorageTestContext();

  setUp(context.setUp);

  tearDown(context.tearDown);

  test('debounceTime<=0 会立即持久化', () async {
    final storage = await context.group.open('no_debounce', debounceTime: -1);

    storage.setItem('foo', 'bar');
    expect(context.fileOfKey('no_debounce').existsSync(), isTrue);
    expect(context.readSnapshotData('no_debounce'), {'foo': 'bar'});

    storage.setItem('count', 1);
    expect(context.readSnapshotData('no_debounce'), {'foo': 'bar', 'count': 1});
  });

  test('setItem write=false 只更新内存，可手动持久化', () async {
    final storage = await context.group.open('manual_write', debounceTime: 1);

    storage.setItem('foo', 'bar', write: false);
    await Future<void>.delayed(Duration(milliseconds: 20));
    expect(context.fileOfKey('manual_write').existsSync(), isFalse);

    storage.write();

    expect(context.fileOfKey('manual_write').existsSync(), isTrue);
    expect(context.readSnapshotData('manual_write'), {'foo': 'bar'});
  });

  test('setItem/getItem/removeItem/removeMultiItem/clear 功能正常', () async {
    final storage = await context.group.open('basic', debounceTime: 1);

    storage.setItem('k1', 'v1');
    storage.setItem('k2', 2);
    storage.setItem('k3', true);
    await context.eventually(() => context.fileOfKey('basic').existsSync());

    expect(storage.length, 3);
    expect(storage.hasKey('k1'), isTrue);
    expect(storage.getItem<String>('k1'), 'v1');
    expect(storage.getItem<int>('k2'), 2);
    expect(storage.getItem<bool>('k3'), true);
    expect(context.readSnapshotData('basic'), {
      'k1': 'v1',
      'k2': 2,
      'k3': true,
    });

    storage.removeItem('k2');
    await context.eventually(
      () => context.readSnapshotData('basic')['k2'] == null,
    );
    expect(storage.hasKey('k2'), isFalse);

    storage.setItem('k4', 4);
    storage.removeMultiItem(['k1', 'k3']);
    await context.eventually(() {
      final json = context.readSnapshotData('basic');
      return json['k1'] == null && json['k3'] == null && json['k4'] == 4;
    });
    expect(storage.keys, ['k4']);

    storage.clear();
    await context.eventually(() => context.readSnapshotData('basic').isEmpty);
    expect(storage.length, 0);
  });

  test('初始化会读取已有 JSON 快照', () async {
    context
        .fileOfKey('load')
        .writeAsStringSync(
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

    final storage = await context.group.open('load', debounceTime: 1);

    expect(storage.version, 1);
    expect(storage.getItem<int>('x'), 1);
    expect(storage.getItem<Map>('nested'), {'ok': true});
  });

  test('旧格式根 Map 不再读取为用户数据', () async {
    context
        .fileOfKey('legacy_root')
        .writeAsStringSync(
          jsonEncode({
            'x': 1,
            'nested': {'ok': true},
          }),
        );

    final storage = await context.group.open('legacy_root', debounceTime: 0);

    expect(storage.length, 0);
    expect(storage.getItem<int>('x'), isNull);
  });

  test('storage close 会从 group 释放并禁止继续操作', () async {
    final storage = await context.group.open('close', debounceTime: 1);

    storage.setItem('foo', 'bar');
    context.group.close('close');

    expect(context.group.has('close'), isFalse);
    expect(storage.isClose, isTrue);
    expect(context.fileOfKey('close').existsSync(), isTrue);
    expect(() => storage.getItem<String>('foo'), throwsA(isA<StateError>()));
    expect(() => storage.setItem('next', 'value'), throwsA(isA<StateError>()));
    expect(storage.clear, throwsA(isA<StateError>()));

    final reopened = await context.group.open('close', debounceTime: 1);
    expect(reopened.getItem<String>('foo'), 'bar');
    expect(reopened, isNot(same(storage)));
  });

  test('serialize + expire 行为正常', () async {
    final storage = await context.group.open('expire', debounceTime: 1);

    final now = DateTime.now();
    storage.setItem<DateTime>(
      'dt',
      now,
      serialize: ElDateTimeSerialize(),
      expire: Duration(milliseconds: 80),
    );
    await context.eventually(() => context.fileOfKey('expire').existsSync());

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
    final storage = await context.group.open(
      'expire_collision',
      debounceTime: 0,
    );
    final payload = {'expire_date': 1, 'data': 'origin'};

    storage.setItem('payload', payload);

    expect(storage.getItem<Map>('payload'), payload);
    expect(context.readSnapshotData('expire_collision')['payload'], payload);
    expect(context.readSnapshotExpires('expire_collision'), isEmpty);
  });

  test('setItem write=false 支持手动写入过期元数据', () async {
    final storage = await context.group.open('manual_expire', debounceTime: 1);

    storage.setItem('token', 'abc', expire: Duration(seconds: 1), write: false);
    await Future<void>.delayed(Duration(milliseconds: 20));
    expect(context.fileOfKey('manual_expire').existsSync(), isFalse);

    storage.write();

    expect(context.readSnapshotData('manual_expire'), {'token': 'abc'});
    expect(context.readSnapshotExpires('manual_expire')['token'], isA<int>());
  });

  test('过期时间 API 行为正常', () async {
    final storage = await context.group.open('expire_api', debounceTime: 0);

    storage.setItem('session', 'ok', expire: Duration(seconds: 1));

    expect(storage.checkExpire('missing'), isFalse);
    expect(storage.checkExpire('session'), isFalse);
    expect(storage.ttl('session'), isNotNull);
    expect(storage.removeExpire('session'), isTrue);
    expect(storage.ttl('session'), isNull);
    expect(context.readSnapshotExpires('expire_api'), isEmpty);
  });

  test('setExpire includeUpdate=false 不覆盖已有过期时间', () async {
    final storage = await context.group.open('set_expire', debounceTime: 1);

    storage.setItem('a', 1, expire: Duration(hours: 1));
    await context.eventually(
      () => context.fileOfKey('set_expire').existsSync(),
    );
    final firstExpire = context.readSnapshotExpires('set_expire')['a'];

    storage.setExpire('a', Duration(hours: 2), includeUpdate: false);
    await Future<void>.delayed(Duration(milliseconds: 20));
    expect(context.readSnapshotExpires('set_expire')['a'], firstExpire);
  });

  test('存储使用迁移后的工具调度写入并支持过期', () async {
    final storage = await context.group.open('sample', debounceTime: 0);
    storage.setItem('answer', 42);
    expect(storage.getItem<int>('answer'), 42);
    expect(
      File('${context.group.storagePath}/sample.json').readAsStringSync(),
      contains('42'),
    );
    storage.setItem('expired', 1, expire: Duration(milliseconds: -1));
    expect(storage.getItem<int>('expired'), isNull);
  });
}
