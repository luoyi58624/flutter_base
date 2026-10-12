part of 'index.dart';

ElStorageGroup? _storageGroup;
ElStorage? _localStorage;

/// 全局默认本地存储对象。
ElStorage get localStorage {
  final storage = _localStorage;
  if (storage != null && !storage.isClose) return storage;

  assert(storage != null, '请执行 el.init() 方法');
  if (storage == null) throw StateError('请执行 el.init() 方法');
  throw StateError('默认本地存储已关闭，不能继续操作');
}

/// Element Flutter 机制层的全局服务扩展。
extension ElStorageExt on El {
  /// 初始化本地存储，同时接管 Obs 的默认存储对象；重复调用不生效。
  ///
  /// [debounceTime] 透传给默认组内存储对象的序列化防抖（毫秒，默认 200）；
  /// 传 0 时每次变更直接写入——测试环境用它避免防抖 Timer 悬挂。
  Future<void> initStorage({
    String? storagePath,
    String key = 'el_storage',
    int debounceTime = 200,
  }) async {
    if (_storageGroup != null) return;
    final path = const bool.fromEnvironment('dart.library.js_interop')
        ? null
        : storagePath ?? (await getApplicationSupportDirectory()).path;
    final group = ElStorageGroup(storagePath: path, key: key);
    try {
      final storage = await group.open(
        'local_storage',
        debounceTime: debounceTime,
      );
      Obs.localStorage = await group.open(
        'el_obs_storage',
        debounceTime: debounceTime,
      );
      (Obs.expireLocalStorage = await group.open(
        'el_obs_expire_storage',
        debounceTime: debounceTime,
      )).clearExpire();

      _localStorage = storage;
      _storageGroup = group;
    } catch (_) {
      group.closeAll();
      rethrow;
    }
  }
}
