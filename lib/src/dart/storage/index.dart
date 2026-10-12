import 'dart:async';

import 'package:meta/meta.dart';

import '../gen/index.dart';
import '../utils/index.dart';

import './codec.dart';
import './migration.dart';
import './web.dart' if (dart.library.io) './io.dart';

export './codec.dart' show ElCodec, ElCodecException;
export './migration.dart'
    show ElStorageMigrate, ElStorageMigration, ElStorageMigrationException;

part 'group.dart';

/// 存储快照版本 key，避免把用户数据和存储元数据混在同一层。
const _snapshotVersionKey = '__el_storage_snapshot_version__';
const _snapshotVersion = 1;
const _snapshotDataVersionKey = 'version';
const _snapshotDataKey = 'data';
const _snapshotExpiresKey = 'expires';

/// 一个简单的 key - value 本地存储类，在 web 端使用 IndexedDB，在客户端保存到 JSON 文件。
///
/// 数据读写全部走内存 Map（同步），默认在后台防抖保存整份快照，也可调用 [write] 手动保存。
abstract class ElStorage {
  /// 平台实现使用的基础构造方法。
  @protected
  ElStorage(
    this.group,
    this.key,
    this._identity,
    this.codec,
    this.targetVersion,
    List<ElStorageMigration> migrations,
    int debounceTime,
  ) : migrations = List.unmodifiable(migrations) {
    _version = targetVersion;
    _persist = debounceTime <= 0
        ? write
        : ElDartUtil.debounce(write, debounceTime, key: this);
  }

  /// 当前存储对象所属的存储组。
  final ElStorageGroup group;

  /// 用于区分多个存储对象。
  final String key;

  final String _identity;

  /// 当前 storage 实际使用的快照编码器。
  final ElCodec codec;

  /// 当前存储期望迁移到的业务数据版本。
  final int targetVersion;

  /// 当前存储的业务数据迁移规则。
  final List<ElStorageMigration> migrations;

  late int _version;

  /// 当前已经加载的业务数据版本。
  int get version => _version;

  /// 当前存储对象所在的存储路径；Web 端没有文件路径，因此固定为 null。
  String? get storagePath => group.storagePath;

  /// 本地存储对象，只保存用户数据，过期时间由存储元数据单独维护。
  @protected
  final Map<String, dynamic> data = {};

  final Map<String, int> _expires = {};

  /// 持久化调度器；debounceTime 为 0 时直接写入，否则走防抖写入。
  late final void Function() _persist;

  bool _isClose = false;

  /// 当前存储对象是否已经关闭或删除。
  bool get isClose => _isClose;

  void _checkOpen() {
    if (_isClose) throw StateError('ElStorage "$key" 已关闭，不能继续操作');
  }

  /// 将当前内存快照写入本地，web 平台写入 IndexedDB，客户端则写入 JSON 文件。
  void write() {
    if (_isClose) return;
    writeData();
  }

  /// 平台实现写入当前快照。
  @protected
  void writeData() {}

  /// 生成需要落盘的平台快照。
  @protected
  Map<String, dynamic> snapshotData() => {
    _snapshotVersionKey: _snapshotVersion,
    _snapshotDataVersionKey: _version,
    _snapshotDataKey: data,
    _snapshotExpiresKey: _expires,
  };

  /// 生成需要落盘的平台快照文本。
  @protected
  String snapshotText() => encodeStorageSnapshot(key, snapshotData(), codec);

  /// 从平台快照文本恢复内存数据。
  @protected
  void loadSnapshotText(String text) {
    loadSnapshot(decodeStorageSnapshot(key, text, codec));
  }

  /// 从平台快照恢复内存数据。
  @protected
  void loadSnapshot(dynamic snapshot) {
    data.clear();
    _expires.clear();
    if (snapshot is! Map) return;

    final source = snapshot.cast<String, dynamic>();
    if (source[_snapshotVersionKey] != _snapshotVersion) return;

    _version = _versionOf(source[_snapshotDataVersionKey]);
    _loadDataMap(source[_snapshotDataKey]);
    _loadExpiresMap(source[_snapshotExpiresKey]);
    final migrated = _migrateToTargetVersion();
    _removeExpireKeys(_expiredKeys());
    if (migrated) write();
  }

  int _versionOf(dynamic rawVersion) =>
      rawVersion is num ? rawVersion.toInt() : 1;

  void _loadDataMap(dynamic rawData) {
    if (rawData is! Map) return;
    data.addAll(rawData.cast<String, dynamic>());
  }

  void _loadExpiresMap(dynamic rawExpires) {
    if (rawExpires is! Map) return;
    for (final entry in rawExpires.entries) {
      final expiresAt = entry.value;
      if (entry.key is String && expiresAt is num) {
        _expires[entry.key as String] = expiresAt.toInt();
      }
    }
  }

  bool _migrateToTargetVersion() {
    if (_version == targetVersion) return false;
    if (_version > targetVersion) {
      throw ElStorageMigrationException(
        'ElStorage "$key" 本地数据版本 $_version 高于目标版本 $targetVersion',
      );
    }

    var currentVersion = _version;
    while (currentVersion < targetVersion) {
      final migration = _migrationFrom(currentVersion);
      if (migration == null) {
        throw ElStorageMigrationException(
          'ElStorage "$key" 缺少从 $currentVersion 到 $targetVersion 的迁移规则',
        );
      }
      if (migration.to <= currentVersion || migration.to > targetVersion) {
        throw ElStorageMigrationException(
          'ElStorage "$key" 迁移版本不合法：${migration.from} -> ${migration.to}',
        );
      }
      try {
        migration.migrate(data);
      } catch (error) {
        throw ElStorageMigrationException(
          'ElStorage "$key" 执行 ${migration.from} -> ${migration.to} 迁移失败',
          error,
        );
      }
      currentVersion = migration.to;
    }
    _version = targetVersion;
    return true;
  }

  ElStorageMigration? _migrationFrom(int version) {
    for (final migration in migrations) {
      if (migration.from == version) return migration;
    }
    return null;
  }

  /// 被所属 [ElStorageGroup] 关闭时的平台资源清理钩子（如 web 关闭 IndexedDB 连接）。
  ///
  /// 关闭流程由 group 执行：先落盘快照，再清内存状态、脱离存储组，最后调用本钩子。
  /// 存储定位等同 web 的 localStorage，上层不允许对 storage 实例直接关闭。
  @protected
  void onClose() {}

  /// 被所属 [ElStorageGroup] 彻底移除时的平台资源清理钩子（如 web 的 deleteDatabase）。
  @protected
  void onRemoved() {}

  /// 存储的 key 数量
  int get length {
    _checkOpen();
    clearExpire();
    return data.length;
  }

  /// 访问所有 key
  Iterable<String> get keys {
    _checkOpen();
    clearExpire();
    return data.keys;
  }

  /// 访问所有过期 key
  List<String> get expireKeys {
    _checkOpen();
    return _expiredKeys();
  }

  /// 检查是否存在 key 数据
  bool hasKey(String key) {
    _checkOpen();
    if (_isExpired(key)) {
      _removeItem(key);
      return false;
    }
    return data.containsKey(key);
  }

  /// 设置数据
  void setItem<T>(
    String key,
    T item, {
    ElSerialize? serialize, // 如果 item 不是基本类型，那么必须指定序列化才能正确缓存
    Duration? expire, // 设置过期时间
    bool write = true, // 是否触发持久化，false 时只更新内存，可稍后手动调用 write()
  }) {
    _checkOpen();
    data[key] = serialize == null ? item : serialize.serialize(item);
    if (expire == null) {
      _expires.remove(key);
    } else {
      _expires[key] = ElDartUtil.currentMilliseconds + expire.inMilliseconds;
    }
    if (write) _persist();
  }

  /// 获取数据
  T? getItem<T>(String key, {ElSerialize? serialize}) {
    _checkOpen();
    if (_isExpired(key)) {
      _removeItem(key);
      return null;
    }

    final result = data[key];
    if (result == null) return null;
    return serialize == null ? result : serialize.deserialize(result);
  }

  /// 删除数据
  void removeItem(String key) {
    _checkOpen();
    _removeItem(key);
  }

  /// 批量删除数据
  void removeMultiItem(Iterable<String> keys) {
    _checkOpen();
    var changed = false;
    for (final key in keys) {
      if (!data.containsKey(key)) continue;
      data.remove(key);
      _expires.remove(key);
      changed = true;
    }
    if (changed) _persist();
  }

  /// 清空数据
  void clear() {
    _checkOpen();
    data.clear();
    _expires.clear();
    _persist();
  }

  /// 给已有的数据设置过期时间。
  bool setExpire(
    String key,
    Duration expire, {
    bool includeUpdate = true,
    bool write = true,
  }) {
    _checkOpen();
    if (!data.containsKey(key)) return false;
    if (_isExpired(key)) {
      _removeItem(key, write: write);
      return false;
    }
    if (!includeUpdate && _expires.containsKey(key)) return false;

    _expires[key] = ElDartUtil.currentMilliseconds + expire.inMilliseconds;
    if (write) _persist();
    return true;
  }

  /// 移除已有数据的过期时间。
  bool removeExpire(String key, {bool write = true}) {
    _checkOpen();
    if (_isExpired(key)) {
      _removeItem(key, write: write);
      return false;
    }
    if (!data.containsKey(key) || !_expires.containsKey(key)) return false;
    _expires.remove(key);
    if (write) _persist();
    return true;
  }

  /// 获取数据剩余过期时间，未设置过期时间或已经过期时返回 null。
  Duration? ttl(String key) {
    _checkOpen();
    if (_isExpired(key)) {
      _removeItem(key);
      return null;
    }

    final expiresAt = _expires[key];
    if (expiresAt == null) return null;
    return Duration(milliseconds: expiresAt - ElDartUtil.currentMilliseconds);
  }

  /// 检查数据是否已过期，key 不存在时返回 false。
  bool checkExpire(String key) {
    _checkOpen();
    return _isExpired(key);
  }

  /// 清除已过期的数据。
  List<String> clearExpire({bool write = true}) {
    _checkOpen();
    final keys = _expiredKeys();
    _removeExpireKeys(keys);
    if (write && keys.isNotEmpty) _persist();
    return keys;
  }

  List<String> _expiredKeys() {
    final now = ElDartUtil.currentMilliseconds;
    final result = <String>[];
    for (final entry in _expires.entries) {
      if (!data.containsKey(entry.key) || entry.value <= now) {
        result.add(entry.key);
      }
    }
    return result;
  }

  bool _isExpired(String key) {
    final expiresAt = _expires[key];
    return expiresAt != null && expiresAt <= ElDartUtil.currentMilliseconds;
  }

  void _removeItem(String key, {bool write = true}) {
    final existed = data.containsKey(key);
    final hadExpire = _expires.containsKey(key);
    if (!existed && !hadExpire) return;
    data.remove(key);
    _expires.remove(key);
    if (write) _persist();
  }

  void _removeExpireKeys(Iterable<String> keys) {
    for (final key in keys) {
      data.remove(key);
      _expires.remove(key);
    }
  }
}
