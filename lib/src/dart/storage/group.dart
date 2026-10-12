part of 'index.dart';

/// 正在使用的存储标识，避免同一个物理存储被多个实例同时写入。
final Set<String> _activeStorageIdentities = {};

final Map<String, ElStorageGroup> _debugActiveGroupKeys = {};

bool _debugClaimGroupKey(ElStorageGroup group) {
  final owner = _debugActiveGroupKeys[group.key];
  if (owner != null && !identical(owner, group)) {
    throw AssertionError('ElStorageGroup Error: The key "${group.key}" has already been used');
  }
  _debugActiveGroupKeys[group.key] = group;
  return true;
}

bool _debugReleaseGroupKey(ElStorageGroup group) {
  if (identical(_debugActiveGroupKeys[group.key], group)) {
    _debugActiveGroupKeys.remove(group.key);
  }
  return true;
}

/// 一组本地存储对象，负责统一配置存储路径、创建存储实例和批量释放资源。
abstract class ElStorageGroup {
  /// 创建存储组。
  ///
  /// [storagePath] 是 IO 端的根目录，默认使用当前执行目录；Web 端会忽略此参数。
  /// [key] 是当前存储组独占的分组 key，IO 端会作为子目录，默认使用空字符串。
  factory ElStorageGroup({String? storagePath, String key = '', ElCodec? codec}) =>
      $StorageGroup(storagePath: storagePath, key: key, codec: codec);

  /// 平台实现使用的基础构造方法。
  @protected
  ElStorageGroup.base({required this.storagePath, required this.key, ElCodec? codec})
    : codec = codec ?? const ElCodec() {
    assert(_debugClaimGroupKey(this));
  }

  /// 当前组使用的存储路径；Web 端没有文件路径，因此固定为 null。
  final String? storagePath;

  /// 当前组独占的分组 key。
  final String key;

  /// 当前组默认的快照编码器，单个 storage 可以在 [open] 时覆盖。
  final ElCodec codec;

  final Map<String, ElStorage> _storages = {};
  final Map<String, Future<ElStorage>> _openingStorages = {};

  /// 当前组内已创建且尚未关闭的存储数量。
  int get length => _storages.length;

  /// 当前组内已创建且尚未关闭的存储 key。
  Iterable<String> get keys => _storages.keys;

  /// 当前组内已创建且尚未关闭的存储对象。
  Iterable<ElStorage> get storages => _storages.values;

  /// 打开本地存储对象，你可以指定不同的 key 创建多个隔离的存储对象。
  ///
  /// 平台数据会在此阶段加载完毕，拿到 [ElStorage] 后所有读写都是同步 Map 操作。
  /// [debounceTime] 是当前存储对象的序列化防抖时间，单位毫秒；小于等于 0 时每次变更直接写入。
  /// [codec] 为 null 时继承当前组的默认编码器，传入 `const ElCodec()` 可显式使用明文快照。
  /// [version] 是当前业务数据版本，打开旧版本快照时会按 [migrations] 升级并写回本地。
  /// 若当前组已经打开或正在打开相同 key 的存储对象，则返回同一个实例。
  Future<ElStorage> open(
    String storageKey, {
    int debounceTime = 200,
    ElCodec? codec,
    int version = 1,
    List<ElStorageMigration> migrations = const [],
  }) async {
    assert(_debugClaimGroupKey(this));

    final current = _storages[storageKey];
    if (current != null) return current;

    final opening = _openingStorages[storageKey];
    if (opening != null) return opening;

    final identity = storageIdentity(storageKey);
    if (_activeStorageIdentities.contains(identity)) {
      throw StateError('ElStorage Error: The storage "$storageKey" has already been opened');
    }

    final next = _openStorage(storageKey, identity, debounceTime, codec ?? this.codec, version, migrations);
    _openingStorages[storageKey] = next;
    return next;
  }

  Future<ElStorage> _openStorage(
    String storageKey,
    String identity,
    int debounceTime,
    ElCodec codec,
    int version,
    List<ElStorageMigration> migrations,
  ) async {
    _activeStorageIdentities.add(identity);
    try {
      final storage = await createPlatformStorage(storageKey, identity, debounceTime, codec, version, migrations);
      _storages[storageKey] = storage;
      return storage;
    } catch (_) {
      _activeStorageIdentities.remove(identity);
      rethrow;
    } finally {
      _openingStorages.remove(storageKey);
    }
  }

  /// 获取当前组已经打开的存储对象，未打开时返回 null。
  ElStorage? get(String key) => _storages[key];

  /// 检查当前组是否已经打开指定存储对象。
  bool has(String key) => _storages.containsKey(key);

  /// 清空指定存储对象的数据，不删除本地存储文件或 IndexedDB。
  void clear(String key) {
    assert(_debugClaimGroupKey(this));

    final storage = _storages[key];
    if (storage == null) {
      clearPlatformStorage(key);
      return;
    }
    storage.clear();
  }

  /// 关闭指定存储对象，不删除本地存储文件或 IndexedDB。
  ///
  /// 关闭是 group 的专属操作：先落盘快照，再清内存状态、脱离存储组并触发平台
  /// 清理钩子；外部对 `el_storage` / Obs 声明的存储实例**没有**关闭入口。
  void close(String key) {
    final storage = _storages[key];
    assert(storage != null, 'ElStorage Error: The storage "$key" has not been opened');

    storage!.write();
    storage._isClose = true;
    storage.data.clear();
    storage._expires.clear();
    _detach(storage);
    storage.onClose();
  }

  /// 删除指定存储对象对应的本地存储，不关闭其他存储。
  void removeStorage(String key) {
    assert(_debugClaimGroupKey(this));

    final storage = _storages[key];
    if (storage != null) {
      storage._isClose = true;
      storage.data.clear();
      storage._expires.clear();
      storage.onRemoved();
      _detach(storage);
      return;
    }

    final identity = storageIdentity(key);
    if (_activeStorageIdentities.contains(identity)) {
      throw StateError('ElStorage Error: The storage "$key" is opened by another group');
    }
    removePlatformStorage(key);
  }

  /// 清空当前组内所有已打开存储对象的数据，不删除本地存储文件或 IndexedDB。
  void clearAll() {
    for (final storage in List<ElStorage>.of(_storages.values)) {
      storage.clear();
    }
  }

  /// 关闭当前组内所有已打开存储对象，不删除本地存储文件或 IndexedDB。
  void closeAll() {
    for (final storage in List<ElStorage>.of(_storages.values)) {
      storage.write();
      storage._isClose = true;
      storage.data.clear();
      storage._expires.clear();
      _detach(storage);
      storage.onClose();
    }
    _storages.clear();
    assert(_debugReleaseGroupKey(this));
  }

  /// 删除当前组内所有已打开存储对象对应的本地存储。
  void removeStorageAll() {
    for (final storage in List<ElStorage>.of(_storages.values)) {
      storage._isClose = true;
      storage.data.clear();
      storage._expires.clear();
      storage.onRemoved();
      _detach(storage);
    }
    _storages.clear();
    assert(_debugReleaseGroupKey(this));
  }

  /// 平台实现创建具体存储对象。
  @protected
  FutureOr<ElStorage> createPlatformStorage(
    String key,
    String identity,
    int debounceTime,
    ElCodec codec,
    int version,
    List<ElStorageMigration> migrations,
  );

  /// 平台实现清空未打开的物理存储。
  @protected
  void clearPlatformStorage(String key) {}

  /// 平台实现删除未打开的物理存储。
  @protected
  void removePlatformStorage(String key) {}

  /// 平台实现生成物理存储标识，用于跨组防重。
  @protected
  String storageIdentity(String key) => key;

  void _detach(ElStorage storage) {
    if (identical(_storages[storage.key], storage)) _storages.remove(storage.key);
    _activeStorageIdentities.remove(storage._identity);
  }
}
