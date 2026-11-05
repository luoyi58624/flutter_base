import 'dart:async';
import 'dart:io';

import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

/// 为每个示例测试文件准备独立存储，避免读取或改写用户的应用设置。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final directory = Directory.systemTemp.createTempSync('flutter_base_example_test_');
  await el.initStorage(storagePath: directory.path, key: 'settings', debounceTime: 0);
  final group = Obs.localStorage.group;
  setUp(() {
    Obs.localStorage.clear();
    Obs.expireLocalStorage.clear();
  });
  tearDownAll(() {
    final groupDirectory = Directory(group.storagePath!);
    if (groupDirectory.parent.absolute.path != directory.absolute.path) {
      throw StateError('拒绝清理测试临时目录之外的存储：${groupDirectory.path}');
    }
    // group 只删除已打开的已知快照文件，随后仅删除空目录，不扫描或递归删除。
    group.removeStorageAll();
    group.closeAll();
    if (groupDirectory.existsSync()) groupDirectory.deleteSync();
    if (directory.existsSync()) directory.deleteSync();
  });
  await testMain();
}
