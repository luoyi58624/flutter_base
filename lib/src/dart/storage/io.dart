import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/index.dart' show ElLog;

import 'index.dart'
    show
        ElCodec,
        ElCodecException,
        ElStorage,
        ElStorageGroup,
        ElStorageMigration,
        ElStorageMigrationException;

String _resolveStoragePath(String? storagePath, String groupKey) {
  final root = Directory(storagePath ?? Directory.current.path).absolute.path;
  return groupKey.isEmpty
      ? root
      : Directory(p.join(root, groupKey)).absolute.path;
}

/// IO 端存储组，使用目录保存 JSON 快照文件。
class $StorageGroup extends ElStorageGroup {
  $StorageGroup({String? storagePath, super.key = '', super.codec})
    : super.base(storagePath: _resolveStoragePath(storagePath, key)) {
    final dir = Directory(this.storagePath!);
    if (!dir.existsSync()) dir.createSync(recursive: true);
  }

  @override
  ElStorage createPlatformStorage(
    String key,
    String identity,
    int debounceTime,
    ElCodec codec,
    int version,
    List<ElStorageMigration> migrations,
  ) => $Storage(this, key, identity, codec, version, migrations, debounceTime);

  @override
  void clearPlatformStorage(String key) {
    storageFile(key).writeAsStringSync('{}');
  }

  @override
  void removePlatformStorage(String key) {
    final file = storageFile(key);
    if (file.existsSync()) file.deleteSync();
  }

  @override
  String storageIdentity(String key) {
    final path = p.normalize(storagePath!);
    return '${Platform.isWindows ? path.toLowerCase() : path}::$key';
  }

  File storageFile(String key) => File(p.join(storagePath!, '$key.json'));
}

/// 使用单个 JSON 文件保存整份 Map 快照。
class $Storage extends ElStorage {
  $Storage(
    ElStorageGroup group,
    String key,
    String identity,
    ElCodec codec,
    int version,
    List<ElStorageMigration> migrations,
    int debounceTime,
  ) : super(group, key, identity, codec, version, migrations, debounceTime) {
    file = (group as $StorageGroup).storageFile(key);
    if (!file.existsSync()) return;

    try {
      loadSnapshotText(file.readAsStringSync());
    } on ElCodecException {
      rethrow;
    } on ElStorageMigrationException {
      rethrow;
    } catch (e) {
      ElLog.w(e, title: 'ElStorage init data Exception');
    }
  }

  late final File file;

  @override
  void writeData() {
    // 落盘是防抖异步的：目录可能在调度期间被删掉（例如测试跑完清理缓存目录），
    // 直接 write 会抛 PathNotFoundException。写前确保父目录存在（幂等）。
    final parent = file.parent;
    if (!parent.existsSync()) parent.createSync(recursive: true);
    file.writeAsStringSync(snapshotText());
  }

  @override
  void onRemoved() {
    if (file.existsSync()) file.deleteSync();
  }
}
