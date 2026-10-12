import 'dart:convert';
import 'dart:io';

import 'package:flutter_base/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 为存储行为测试管理隔离的临时目录、存储组和快照读取。
class StorageTestContext {
  /// 当前用例的临时根目录。
  late Directory root;

  /// 当前用例的默认存储组。
  late ElStorageGroup group;

  /// 为每个用例创建独立的存储组。
  void setUp() {
    root = Directory.systemTemp.createTempSync('flutter_base_storage_test_');
    group = ElStorageGroup(storagePath: root.path, key: 'main');
  }

  /// 关闭存储并仅清理本夹具创建的临时目录。
  void tearDown() {
    group.removeStorageAll();
    group.closeAll();
    if (!root.existsSync()) return;
    final target = p.normalize(root.absolute.path);
    final tempRoot = p.normalize(Directory.systemTemp.absolute.path);
    if (!p.isWithin(tempRoot, target) ||
        !p.basename(target).startsWith('flutter_base_storage_test_')) {
      throw StateError('拒绝删除测试临时目录之外的路径：$target');
    }
    root.deleteSync(recursive: true);
  }

  /// 返回指定存储对象的快照文件。
  File fileOfKey(String key, [ElStorageGroup? targetGroup]) =>
      File(p.join((targetGroup ?? group).storagePath!, '$key.json'));

  /// 在截止时间内等待后台持久化完成。
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

  Map<String, dynamic> _readSnapshot(
    String key, [
    ElStorageGroup? targetGroup,
  ]) => (jsonDecode(fileOfKey(key, targetGroup).readAsStringSync()) as Map)
      .cast<String, dynamic>();

  /// 读取快照中的业务数据。
  Map<String, dynamic> readSnapshotData(
    String key, [
    ElStorageGroup? targetGroup,
  ]) =>
      (_readSnapshot(key, targetGroup)['data'] as Map).cast<String, dynamic>();

  /// 读取快照中的过期时间元数据。
  Map<String, dynamic> readSnapshotExpires(
    String key, [
    ElStorageGroup? targetGroup,
  ]) => (_readSnapshot(key, targetGroup)['expires'] as Map)
      .cast<String, dynamic>();

  /// 读取快照的业务数据版本。
  int readSnapshotVersion(String key, [ElStorageGroup? targetGroup]) =>
      _readSnapshot(key, targetGroup)['version'] as int;
}
