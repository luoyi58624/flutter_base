part of flutter_base;

/// 响应式变量持久化存储库，无需对外公开
LocalStorage? _obsLocalStorage;

class _LocalDataModel {
  /// 持久化数据类型字符串，如果类型发生变化将清除旧的本地数据
  late String type;

  /// 过期时间，单位：截止日期的时间戳；默认-1，表示永不过期。
  /// 示例：
  /// * 30分钟后过期：DateTime.now().millisecondsSinceEpoch + 1000 * 60 * 30
  /// * 2024年1月1日过期：DateTime(2024, 1, 1).millisecondsSinceEpoch
  late int expire;

  /// 存储的数据
  dynamic data;

  _LocalDataModel(this.type, this.expire, this.data);

  _LocalDataModel.fromJson(Map<String, dynamic> json) {
    type = json['type'] ?? '';
    expire = json['expire'] ?? -1;
    data = json['data'];
  }

  Map<String, dynamic> toJson() {
    final mapData = <String, dynamic>{};
    mapData['type'] = type;
    mapData['expire'] = expire;
    mapData['data'] = data;
    return mapData;
  }
}

/// 序列化函数类型声明，[LocalStorage]可以自动转换基础数据类型、List、Map，但模型对象需要你手动转换，
/// 示例：
/// ```dart
/// // 创建的模型对象提供 toJson、fromJson 两种序列化方法即可，它们均可以自动生成
/// serializeFun: (model) => jsonEncode(model.toJson()),
/// deserializeFun: (json) => UserModel.fromJson(jsonDecode(json))
/// ```
/// 注意：List、Map如果存放的是模型对象，你也必须进行手动转换
typedef SerializeFun<T> = String Function(T model);

/// 反序列化函数类型声明
typedef DeserializeFun<T> = T Function(String json);

/// 返回一个过期时间函数
typedef ExpireFun = int Function();

/// 初始化响应式变量的本地存储
Future<void> initLocalObs() async {
  _obsLocalStorage = await LocalStorage.create('local_obs');
}

void _assertLocalStorage() {
  assert(_obsLocalStorage != null, '请执行 initLocalObs 函数初始化响应式变量的本地存储');
}

/// 创建基于[Getx]响应式变量(Observable State)，更新时会同步至本地，重新加载时会取本地数据作为初始值
/// * value - 初始值
/// * key - 本地缓存key，请确保它们唯一
///
/// * clear - 清除本地缓存，此属性一般用于重置本地数据
/// * expireFun - 过期时间函数，默认返回-1，表示永不过期，每次更新变量时都会调用此函数，注意：只有卸载控制器再重新加载时才会生效
/// * serializeFun - 序列化函数，如果你传入的是对象，你必须将其转换为字符串才能缓存在本地
/// * deserializeFun - 反序列化函数，将本地存储的字符串转回目标对象
Rx<T> useLocalObs<T>(
  T value,
  String key, {
  bool clear = false,
  ExpireFun? expireFun,
  SerializeFun<T>? serializeFun,
  DeserializeFun<T>? deserializeFun,
}) {
  _assertLocalStorage();
  if (clear) _obsLocalStorage!.removeItem(key);
  String valueType = T.toString();
  bool isBaseType = DartUtil.isBaseTypeString(valueType) || value is Map;
  expireFun ??= () => -1;

  /// 序列化Color对象
  if (value is Color) {
    serializeFun ??= (value) => (value as Color).toHex();
    deserializeFun ??= (value) => ColorUtil.hexToColor((value)) as T;
  }
  assert(isBaseType || (serializeFun != null && deserializeFun != null), '请为响应式持久化变量[$key]提供序列化和反序列化函数');
  late Rx<T> $value;
  dynamic localData = _obsLocalStorage!.getItem(key);
  if (localData == null) {
    $value = value.obs;
  } else {
    var localDataModel = _LocalDataModel.fromJson(jsonDecode(localData));
    if (localDataModel.type != valueType) {
      // 如果更改了响应式变量类型，则清除旧数据
      _obsLocalStorage!.removeItem(key);
      $value = value.obs;
    } else if (localDataModel.expire != -1 && localDataModel.expire < DateTime.now().millisecondsSinceEpoch) {
      // 如果用户设置了过期时间，同时过期时间小于当前时间，则清除旧数据
      _obsLocalStorage!.removeItem(key);
      $value = value.obs;
    } else {
      if (isBaseType && deserializeFun == null) {
        $value = (localDataModel.data as T).obs;
      } else {
        $value = deserializeFun!(localDataModel.data).obs;
      }
    }
  }
  // 提示：当你卸载控制器后getx会自动释放它，无须手动销毁
  ever($value, (v) {
    _obsLocalStorage!.setItem(
      key,
      jsonEncode(
        _LocalDataModel(valueType, expireFun!(), serializeFun == null ? v : serializeFun(v)).toJson(),
      ),
    );
  });
  return $value;
}

/// 创建基于[Getx]响应式[List]列表(Observable State)，更新时会同步至本地，重新加载时会取本地数据作为初始值
/// * value - 初始值
/// * key - 本地缓存key，请确保它们唯一
///
/// * clear - 清除本地缓存，此属性一般用于重置本地数据
/// * expireFun - 过期时间函数，默认返回-1，表示永不过期，每次更新变量时都会调用此函数
/// * serializeFun - 序列化函数，如果你传入的是对象，你必须将其转换为字符串才能缓存在本地
/// * deserializeFun - 反序列化函数，将本地存储的字符串转回目标对象
RxList<T> useLocalListObs<T>(
  List<T> value,
  String key, {
  bool clear = false,
  ExpireFun? expireFun,
  SerializeFun<T>? serializeFun,
  DeserializeFun<T>? deserializeFun,
}) {
  _assertLocalStorage();
  if (clear) _obsLocalStorage!.removeItem(key);
  String valueType = T.toString();
  bool isBaseType = DartUtil.isBaseTypeString(valueType) || value is List<Map>;
  expireFun ??= () => -1;
  assert(isBaseType || (serializeFun != null && deserializeFun != null), '请为响应式持久化变量[$key]提供序列化和反序列化函数');
  late RxList<T> $value;
  dynamic localData = _obsLocalStorage!.getItem(key);
  if (localData == null) {
    $value = value.obs;
  } else {
    var localDataModel = _LocalDataModel.fromJson(jsonDecode(localData));
    if (localDataModel.type != valueType) {
      // 如果更改了响应式变量类型，则清除旧数据
      _obsLocalStorage!.removeItem(key);
      $value = value.obs;
    } else if (localDataModel.expire != -1 && localDataModel.expire < DateTime.now().millisecondsSinceEpoch) {
      // 如果用户设置了过期时间，同时过期时间小于当前时间，则清除旧数据
      _obsLocalStorage!.removeItem(key);
      $value = value.obs;
    } else {
      List listData = localDataModel.data;
      // 如果是基本数据类型，则直接通过cast强转类型返回数据，否则你必须提供序列化和反序列化函数进行转换
      if (isBaseType && deserializeFun == null) {
        $value = listData.cast<T>().obs;
      } else {
        $value = listData.map((value) => deserializeFun!(value)).cast<T>().toList().obs;
      }
    }
  }
  // 列表可能会频繁更新，这里使用节流同步本地数据
  interval(
    $value,
    (v) {
      _obsLocalStorage!.setItem(
        key,
        jsonEncode(
          _LocalDataModel(
            valueType,
            expireFun!(),
            serializeFun == null
                ? v
                : v.map((value) {
                    return serializeFun(value);
                  }).toList(),
          ).toJson(),
        ),
      );
    },
    time: const Duration(seconds: 1),
  );
  return $value;
}

/// 创建基于[Getx]响应式[Map]对象(Observable State)，key强制为String，更新时会同步至本地，重新加载时会取本地数据作为初始值
/// * value - 初始值
/// * key - 本地缓存key，请确保它们唯一
///
/// * clear - 清除本地缓存，此属性一般用于重置本地数据
/// * expireFun - 过期时间函数，默认返回-1，表示永不过期，每次更新变量时都会调用此函数
/// * serializeFun - 序列化函数，如果你传入的是对象，你必须将其转换为字符串才能缓存在本地
/// * deserializeFun - 反序列化函数，将本地存储的字符串转回目标对象
///
/// 示例：
/// ```dart
/// // value为int类型的Map
/// final localMap = useLocalMapObs<int>({}, 'localMap');
///
/// // value为Model实体对象类型的Map，必须包含序列化方法toJson、fromJson
/// final userModelMap = useLocalMapObs<UserModel>(
///   {},
///   'userModelMap',
///   serializeFun: (value) => jsonEncode(value.toJson()),
///   deserializeFun: (value) => UserModel.fromJson(jsonDecode(value)),
/// );
///
/// // 注意：操作响应式Map不要加.value
/// controller.localMap['key'] = 1;
/// controller.localMap.addAll({'key': 1});
///
/// controller.localMap.update('key',(value)=>value+1);
/// ```
RxMap<String, T> useLocalMapObs<T>(
  Map<String, T> value,
  String key, {
  bool clear = false,
  ExpireFun? expireFun,
  SerializeFun<T>? serializeFun,
  DeserializeFun<T>? deserializeFun,
}) {
  _assertLocalStorage();
  if (clear) _obsLocalStorage!.removeItem(key);
  String valueType = T.toString();
  bool isBaseType = DartUtil.isBaseTypeString(valueType) || valueType.contains('Map');
  expireFun ??= () => -1;
  assert(isBaseType || (serializeFun != null && deserializeFun != null), '请为响应式持久化变量[$key]提供序列化和反序列化函数');
  late RxMap<String, T> $value;
  dynamic localData = _obsLocalStorage!.getItem(key);
  if (localData == null) {
    $value = value.obs;
  } else {
    var localDataModel = _LocalDataModel.fromJson(jsonDecode(localData));
    if (localDataModel.type != valueType) {
      // 如果更改了响应式变量类型，则清除旧数据
      _obsLocalStorage!.removeItem(key);
      $value = value.obs;
    } else if (localDataModel.expire != -1 && localDataModel.expire < DateTime.now().millisecondsSinceEpoch) {
      // 如果用户设置了过期时间，同时过期时间小于当前时间，则清除旧数据
      _obsLocalStorage!.removeItem(key);
      $value = value.obs;
    } else {
      Map mapData = localDataModel.data;
      // 如果是基本数据类型，则直接通过cast强转类型返回数据，否则你必须提供序列化和反序列化函数进行转换
      if (isBaseType && deserializeFun == null) {
        $value = mapData.cast<String, T>().obs;
      } else {
        $value = mapData.map((key, value) => MapEntry(key, deserializeFun!(value))).cast<String, T>().obs;
      }
    }
  }
  ever($value, (v) {
    _obsLocalStorage!.setItem(
      key,
      jsonEncode(
        _LocalDataModel(
          valueType,
          expireFun!(),
          serializeFun == null ? v : v.map((key, value) => MapEntry(key, serializeFun(value))),
        ).toJson(),
      ),
    );
  });
  return $value;
}
