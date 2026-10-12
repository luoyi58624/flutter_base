import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

import '../utils/index.dart' show ElLog;

import 'index.dart'
    show
        ElCodec,
        ElCodecException,
        ElStorage,
        ElStorageGroup,
        ElStorageMigration,
        ElStorageMigrationException;

const _storeName = 'kv';
const _snapshotKey = 'snapshot';

String _dbNameOf(String groupKey, String storageKey) => groupKey.isEmpty
    ? 'el_storage_snapshot_$storageKey'
    : 'el_storage_snapshot_${groupKey}_$storageKey';

Future<JSAny?> _request(IDBRequest request) {
  final completer = Completer<JSAny?>();
  request.onsuccess = ((Event _) => completer.complete(request.result)).toJS;
  request.onerror = ((Event _) {
    completer.completeError(
      StateError(request.error?.message ?? 'IDB request error'),
    );
  }).toJS;
  return completer.future;
}

Future<IDBDatabase> _openDatabase(String name) {
  final completer = Completer<IDBDatabase>();
  final request = window.indexedDB.open(name, 1);
  request.onupgradeneeded = ((Event _) {
    final db = request.result as IDBDatabase;
    if (!db.objectStoreNames.contains(_storeName)) {
      db.createObjectStore(_storeName);
    }
  }).toJS;
  request.onsuccess = ((Event _) {
    completer.complete(request.result as IDBDatabase);
  }).toJS;
  request.onerror = ((Event _) {
    completer.completeError(
      StateError(request.error?.message ?? 'IDB open error'),
    );
  }).toJS;
  return completer.future;
}

Future<String> _loadSnapshot(IDBDatabase db) async {
  final tx = db.transaction(_storeName.toJS, 'readonly');
  final result = await _request(
    tx.objectStore(_storeName).get(_snapshotKey.toJS),
  );
  return result == null ? '{}' : (result as JSString).toDart;
}

/// Web 端存储组，路径参数无意义，数据写入 IndexedDB。
class $StorageGroup extends ElStorageGroup {
  $StorageGroup({String? storagePath, super.key = '', super.codec})
    : super.base(storagePath: null);

  @override
  Future<ElStorage> createPlatformStorage(
    String key,
    String identity,
    int debounceTime,
    ElCodec codec,
    int version,
    List<ElStorageMigration> migrations,
  ) async {
    final dbName = _dbNameOf(this.key, key);
    final db = await _openDatabase(dbName);
    var snapshot = '{}';
    try {
      snapshot = await _loadSnapshot(db);
    } catch (e) {
      ElLog.w(e, title: 'ElStorage init Exception');
    }
    return $Storage(
      this,
      key,
      identity,
      codec,
      version,
      migrations,
      debounceTime,
      dbName,
      db,
      snapshot,
    );
  }

  @override
  String storageIdentity(String key) => '${this.key}::$key';

  @override
  void clearPlatformStorage(String key) {
    unawaited(_clearDatabase(key));
  }

  @override
  void removePlatformStorage(String key) {
    window.indexedDB.deleteDatabase(_dbNameOf(this.key, key));
  }

  Future<void> _clearDatabase(String key) async {
    try {
      final db = await _openDatabase(_dbNameOf(this.key, key));
      final tx = db.transaction(_storeName.toJS, 'readwrite');
      await _request(
        tx.objectStore(_storeName).put('{}'.toJS, _snapshotKey.toJS),
      );
      db.close();
    } catch (e) {
      ElLog.w(e, title: 'ElStorage clear Exception');
    }
  }
}

/// 使用 IndexedDB 的单条记录保存整份 Map 快照。
class $Storage extends ElStorage {
  // ignore: use_super_parameters
  $Storage(
    ElStorageGroup group,
    String key,
    String identity,
    ElCodec codec,
    int version,
    List<ElStorageMigration> migrations,
    int debounceTime,
    this._dbName,
    this._db,
    String snapshot,
  ) : super(group, key, identity, codec, version, migrations, debounceTime) {
    try {
      loadSnapshotText(snapshot);
    } on ElCodecException {
      rethrow;
    } on ElStorageMigrationException {
      rethrow;
    } catch (e) {
      ElLog.w(e, title: 'ElStorage init Exception');
    }
  }

  final String _dbName;
  final IDBDatabase _db;

  @override
  void writeData() {
    unawaited(_writeSnapshot(snapshotText()));
  }

  Future<void> _writeSnapshot(String snapshot) async {
    try {
      final tx = _db.transaction(_storeName.toJS, 'readwrite');
      await _request(
        tx.objectStore(_storeName).put(snapshot.toJS, _snapshotKey.toJS),
      );
    } catch (e) {
      ElLog.w(e, title: 'ElStorage write Exception');
    }
  }

  @override
  void onClose() {
    _db.close();
  }

  @override
  void onRemoved() {
    try {
      _db.close();
      window.indexedDB.deleteDatabase(_dbName);
    } catch (e) {
      ElLog.w(e, title: 'ElStorage removePlatform Exception');
    }
  }
}
