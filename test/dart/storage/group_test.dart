import 'dart:io';

import 'package:flutter_base/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'storage_test_support.dart';

void main() {
  final context = StorageTestContext();

  setUp(context.setUp);

  tearDown(context.tearDown);

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
      p.normalize(context.group.storagePath!),
      p.normalize(p.join(context.root.path, 'main')),
    );
  });

  test('重复 group key 会触发调试断言', () {
    final first = ElStorageGroup(storagePath: context.root.path, key: 'dup');
    addTearDown(first.closeAll);

    expect(
      () => ElStorageGroup(
        storagePath: p.join(context.root.path, 'other'),
        key: 'dup',
      ),
      throwsA(isA<AssertionError>()),
    );

    first.closeAll();
    final second = ElStorageGroup(storagePath: context.root.path, key: 'dup');
    addTearDown(second.closeAll);
    expect(second.key, 'dup');
  });

  test('不同 group key 支持在同一路径使用相同 storage key', () async {
    final otherGroup = ElStorageGroup(
      storagePath: context.root.path,
      key: 'other',
    );
    addTearDown(() {
      otherGroup.removeStorageAll();
      otherGroup.closeAll();
    });

    final first = await context.group.open('same', debounceTime: 1);
    final second = await otherGroup.open('same', debounceTime: 1);

    first.setItem('value', 'first');
    second.setItem('value', 'second');
    await context.eventually(
      () =>
          context.fileOfKey('same').existsSync() &&
          context.fileOfKey('same', otherGroup).existsSync(),
    );

    expect(context.readSnapshotData('same'), {'value': 'first'});
    expect(context.readSnapshotData('same', otherGroup), {'value': 'second'});
  });

  test('open 相同 key 会返回已打开实例', () async {
    final first = await context.group.open('same_open', debounceTime: 1);
    final second = await context.group.open('same_open', debounceTime: 1000);
    final third = await context.group.open('same_open', debounceTime: 0);

    expect(identical(first, second), isTrue);
    expect(identical(first, third), isTrue);
    expect(context.group.length, 1);
    expect(context.group.get('same_open'), same(first));
    expect(context.group.has('same_open'), isTrue);
    expect(context.group.keys, ['same_open']);
    expect(context.group.storages, [first]);
  });

  test('并发 open 相同 key 会返回同一个实例', () async {
    final firstOpening = context.group.open('same_pending', debounceTime: 1);
    final secondOpening = context.group.open(
      'same_pending',
      debounceTime: 1000,
    );

    final first = await firstOpening;
    final second = await secondOpening;

    expect(second, same(first));
    expect(context.group.length, 1);
  });

  test('removeStorage 会清理快照文件', () async {
    final storage = await context.group.open('remove', debounceTime: 1);

    storage.setItem('foo', 'bar');
    await context.eventually(() => context.fileOfKey('remove').existsSync());
    expect(context.group.has('remove'), isTrue);

    context.group.removeStorage('remove');

    expect(context.group.has('remove'), isFalse);
    expect(context.fileOfKey('remove').existsSync(), isFalse);
  });

  test('removeStorage 可在 close 后继续删除本地快照', () async {
    final storage = await context.group.open(
      'remove_after_close',
      debounceTime: 1,
    );

    storage.setItem('foo', 'bar');
    context.group.close('remove_after_close');
    expect(context.fileOfKey('remove_after_close').existsSync(), isTrue);

    context.group.removeStorage('remove_after_close');

    expect(context.fileOfKey('remove_after_close').existsSync(), isFalse);
  });

  test('group removeStorage(key) 只删除目标存储', () async {
    final first = await context.group.open('first_remove', debounceTime: 1);
    final second = await context.group.open('second_remove', debounceTime: 1);

    first.setItem('foo', 'bar');
    second.setItem('hello', 'world');
    await context.eventually(
      () =>
          context.fileOfKey('first_remove').existsSync() &&
          context.fileOfKey('second_remove').existsSync(),
    );

    context.group.removeStorage('first_remove');

    expect(first.isClose, isTrue);
    expect(second.isClose, isFalse);
    expect(context.group.has('first_remove'), isFalse);
    expect(context.group.has('second_remove'), isTrue);
    expect(context.fileOfKey('first_remove').existsSync(), isFalse);
    expect(context.fileOfKey('second_remove').existsSync(), isTrue);
  });

  test('group clear(key) 只清空目标存储', () async {
    final first = await context.group.open('first_clear', debounceTime: 1);
    final second = await context.group.open('second_clear', debounceTime: 1);

    first.setItem('foo', 'bar');
    second.setItem('hello', 'world');
    await context.eventually(
      () =>
          context.fileOfKey('first_clear').existsSync() &&
          context.fileOfKey('second_clear').existsSync(),
    );

    context.group.clear('first_clear');

    await context.eventually(
      () => context.readSnapshotData('first_clear').isEmpty,
    );
    expect(context.readSnapshotData('second_clear'), {'hello': 'world'});
  });

  test('group clearAll 会批量清空已打开存储', () async {
    final first = await context.group.open('first_clear_all', debounceTime: 1);
    final second = await context.group.open(
      'second_clear_all',
      debounceTime: 1,
    );

    first.setItem('foo', 'bar');
    second.setItem('hello', 'world');
    await context.eventually(
      () =>
          context.fileOfKey('first_clear_all').existsSync() &&
          context.fileOfKey('second_clear_all').existsSync(),
    );

    context.group.clearAll();

    await context.eventually(() {
      final firstJson = context.readSnapshotData('first_clear_all');
      final secondJson = context.readSnapshotData('second_clear_all');
      return firstJson.isEmpty && secondJson.isEmpty;
    });
  });

  test('group removeStorageAll 会批量清理快照文件', () async {
    final first = await context.group.open('first', debounceTime: 1);
    final second = await context.group.open('second', debounceTime: 1);

    first.setItem('foo', 'bar');
    second.setItem('hello', 'world');
    await context.eventually(
      () =>
          context.fileOfKey('first').existsSync() &&
          context.fileOfKey('second').existsSync(),
    );

    context.group.removeStorageAll();

    expect(context.group.length, 0);
    expect(context.fileOfKey('first').existsSync(), isFalse);
    expect(context.fileOfKey('second').existsSync(), isFalse);
  });

  test('group close(key) 只关闭目标存储', () async {
    final first = await context.group.open('first_close', debounceTime: 1);
    final second = await context.group.open('second_close', debounceTime: 1);

    first.setItem('foo', 'bar');
    second.setItem('hello', 'world');

    context.group.close('first_close');

    expect(first.isClose, isTrue);
    expect(second.isClose, isFalse);
    expect(context.group.has('first_close'), isFalse);
    expect(context.group.has('second_close'), isTrue);
    expect(second.getItem<String>('hello'), 'world');
  });

  test('group closeAll 会批量关闭并允许重新打开', () async {
    final first = await context.group.open('first_close_all', debounceTime: 1);
    final second = await context.group.open(
      'second_close_all',
      debounceTime: 1,
    );

    first.setItem('foo', 'bar');
    second.setItem('hello', 'world');

    context.group.closeAll();

    expect(first.isClose, isTrue);
    expect(second.isClose, isTrue);
    expect(context.group.length, 0);
    expect(() => first.hasKey('foo'), throwsA(isA<StateError>()));
    expect(
      (await context.group.open(
        'first_close_all',
        debounceTime: 1,
      )).getItem<String>('foo'),
      'bar',
    );
  });
}
