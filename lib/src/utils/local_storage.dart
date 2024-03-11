part of flutter_base;

/// 存储设置了过期时间的数据库，key为存储库标签tag + 存储key，value为过期时间戳
Box<int>? _expireDataBox;

/// 获取过期key
String _getExpireKey(String tag, String key) {
  return '${tag}_$key';
}

/// 简单key-value键值存储库，基于[Hive]，支持所有平台(包括web，基于IndexedDB)。
/// 提示：泛型 T 支持指定基础类型、List、Map、以及任意Object对象，但是有两点需要注意：
/// * List、Map的泛型只能是dynamic，否则重启应用再次加载数据会出现类型转换错误，这是dart的类型系统限制，即使是[Hive]也做不到帮你自动转回指定的类型，取出数据后你需要自己手动转换数据类型。
/// * 存储Object对象你必须实现适配器，具体操作请自行查看[Hive]文档：https://docs.hivedb.dev/#/custom-objects/type_adapters，或者查看example的示例代码。
class LocalStorage<T> {
  /// 存储库实例
  late Box<T> box;

  /// 当前存储库的标签
  late String tag;

  LocalStorage._();

  /// 初始化容器，由于构造函数不能是异步，所以只能提供静态方法创建，你可以根据tag创建多个容器，例如：
  /// ```dart
  /// var localStorage = await LocalStorage.init(); // 当执行initMyFlutter时默认创建
  /// var httpLocalStorage = await LocalStorage.init('http');
  /// var sessionLocalStorage = await LocalStorage.init('session');
  /// ```
  static Future<LocalStorage<T>> init<T>([String? tag]) async {
    tag ??= 'default';
    var box = await Hive.openBox<T>(tag);
    _expireDataBox ??= await Hive.openBox<int>('expire_data_box');
    // 清除过期key
    Future.delayed(Duration.zero, () {
      List<String> keys = box.keys.toList().cast<String>();
      for (int i = 0; i < box.length; i++) {
        var expireTime = _expireDataBox!.get(_getExpireKey(tag!, keys[i]));
        if (expireTime != null && expireTime < currentMilliseconds) {
          box.delete(keys[i]);
          _expireDataBox!.delete(_getExpireKey(tag, keys[i]));
        }
      }
    });
    return LocalStorage._()
      ..box = box
      ..tag = tag;
  }

  /// 设置本地数据
  /// * key 存储的键，注意：[Hive]要求key的长度必须小于255，若你需要存储很长的key，可以使用md5将原字符加密为128位的字符串
  /// * value
  /// * duration 设置key的持续时间，单位毫秒
  /// * expireTime 设置key的具体过期时间
  void setItem(
    String key,
    T value, {
    int duration = -1,
    DateTime? expireTime,
  }) {
    box.put(key, value);
    if (duration > 0) {
      _expireDataBox!.put(_getExpireKey(tag, key), currentMilliseconds + duration);
    } else if (expireTime != null && expireTime.millisecondsSinceEpoch > currentMilliseconds) {
      _expireDataBox!.put(_getExpireKey(tag, key), expireTime.millisecondsSinceEpoch);
    }
  }

  /// 读取指定key数据
  T? getItem(String key, [T? defaultValue]) {
    var expireTime = _expireDataBox!.get(_getExpireKey(tag, key));
    if (expireTime == null || expireTime > currentMilliseconds) {
      return box.get(key, defaultValue: defaultValue);
    } else {
      box.delete(key);
      _expireDataBox!.delete(_getExpireKey(tag, key));
      return defaultValue;
    }
  }

  /// 删除指定key数据
  void removeItem(String key) {
    box.delete(key);
  }

  /// 清除容器所有数据
  void clear() {
    box.clear();
  }
}

/// 对[Hive]的LazyBox进行的封装，使用方式与LocalStorage完全一致，只不过所有操作变为异步(async、await)。
///
/// LocalStorage会将所有数据一次性全部加载进内存，所以你不应该将它用来存储大量数据，若你要存储大量数据，请改用LazyLocalStorage，
/// 它只会一次加载所有的key到内存中，然后根据你访问的key异步读取磁盘中的value，所以获取数据将变成异步操作。
class LazyLocalStorage<T> {
  /// 存储库实例
  late LazyBox<T> lazyBox;

  /// 当前存储库的标签
  late String tag;

  LazyLocalStorage._();

  static Future<LazyLocalStorage<T>> init<T>([String? tag]) async {
    tag ??= 'default';
    var box = await Hive.openLazyBox<T>(tag);
    _expireDataBox ??= await Hive.openBox<int>('expire_data_box');
    // 清除过期key
    Future.delayed(Duration.zero, () {
      List<String> keys = box.keys.toList().cast<String>();
      for (int i = 0; i < box.length; i++) {
        var expireTime = _expireDataBox!.get(_getExpireKey(tag!, keys[i]));
        if (expireTime != null && expireTime < currentMilliseconds) {
          box.delete(keys[i]);
          _expireDataBox!.delete(_getExpireKey(tag, keys[i]));
        }
      }
    });
    return LazyLocalStorage._()
      ..lazyBox = box
      ..tag = tag;
  }

  /// 设置本地数据
  /// * key 存储的键，注意：[Hive]要求key的长度必须小于255，若你需要存储很长的key，可以使用md5将原字符加密为128位的字符串
  /// * value
  /// * duration 设置key的持续时间，单位毫秒
  /// * expireTime 设置key的具体过期时间
  Future<void> setItem(
    String key,
    T value, {
    int duration = -1,
    DateTime? expireTime,
  }) async {
    await lazyBox.put(key, value);
    if (duration > 0) {
      _expireDataBox!.put(_getExpireKey(tag, key), currentMilliseconds + duration);
    } else if (expireTime != null && expireTime.millisecondsSinceEpoch > currentMilliseconds) {
      _expireDataBox!.put(_getExpireKey(tag, key), expireTime.millisecondsSinceEpoch);
    }
  }

  /// 读取指定key数据
  Future<T?> getItem(String key, [T? defaultValue]) async {
    var expireTime = _expireDataBox!.get(_getExpireKey(tag, key));
    if (expireTime == null || expireTime > currentMilliseconds) {
      return await lazyBox.get(key, defaultValue: defaultValue);
    } else {
      await lazyBox.delete(key);
      _expireDataBox!.delete(_getExpireKey(tag, key));
      return defaultValue;
    }
  }

  /// 删除指定key数据
  Future<void> removeItem(String key) async {
    await lazyBox.delete(key);
  }

  /// 清除容器所有数据
  Future<void> clear() async {
    await lazyBox.clear();
  }
}
