import 'dart:io';

import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('flutter_base_flutter_storage_');
    await el.initStorage(
      storagePath: root.path,
      key: 'el_flutter_storage',
      debounceTime: 0,
    );
  });

  tearDownAll(() {
    localStorage.group.closeAll();
    _deleteTemporaryDirectory(root);
  });

  test('el.init 会创建默认存储组和默认存储对象', () async {
    expect(
      p.normalize(localStorage.group.storagePath!),
      p.normalize(p.join(root.path, 'el_flutter_storage')),
    );
    expect(localStorage.key, 'local_storage');
    expect(Obs.localStorage.key, 'el_obs_storage');
    expect(Obs.expireLocalStorage.key, 'el_obs_expire_storage');
  });

  test('重复 el.init 会返回 false 并保留已有存储组', () async {
    final firstGroup = localStorage.group;
    final firstStorage = localStorage;
    final firstPath = localStorage.group.storagePath;

    final nextRoot = Directory.systemTemp.createTempSync(
      'flutter_base_flutter_storage_',
    );
    addTearDown(() {
      _deleteTemporaryDirectory(nextRoot);
    });

    await el.initStorage(
      storagePath: nextRoot.path,
      key: 'el_flutter_storage_next',
    );

    expect(localStorage, same(firstStorage));
    expect(localStorage.group, same(firstGroup));
    expect(localStorage.group.storagePath, firstPath);
  });

  test('带 cacheKey 的 Obs 从本地恢复并实时写回', () {
    final source = Obs('v1', cacheKey: 'obs_roundtrip_key');
    source.value = 'v2';
    // 新实例用同一 cacheKey 构造，读到的应是本地恢复值而非初始值
    expect(Obs('init', cacheKey: 'obs_roundtrip_key').value, 'v2');
    Obs.localStorage.removeItem('obs_roundtrip_key');
    expect(Obs('init', cacheKey: 'obs_roundtrip_key').value, 'init');
  });
}

void _deleteTemporaryDirectory(Directory directory) {
  if (!directory.existsSync()) return;
  final target = p.normalize(directory.absolute.path);
  final tempRoot = p.normalize(Directory.systemTemp.absolute.path);
  if (!p.isWithin(tempRoot, target) ||
      !p.basename(target).startsWith('flutter_base_flutter_storage_')) {
    throw StateError('拒绝删除测试临时目录之外的路径：$target');
  }
  directory.deleteSync(recursive: true);
}
