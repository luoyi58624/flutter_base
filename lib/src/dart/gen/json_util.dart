part of 'index.dart';

/// fromJson 类型转换错误的统一前缀。
const String _fromJsonErrorStart = '(error) ElModelGenerator fromJson: ';

/// fromJson 类型转换错误的统一后缀。
const String _fromJsonErrorEnd = '提示：此错误仅在开发环境下显示。';

/// 此工具类用于代码生成（fromJson），直接访问 Map 对象很容易出现低级类型转换错误，
/// 例如：int is not String.
///
/// 所有读取方法的尾部都有一个可选的 [underlineKey] 参数，由代码生成器在编译期算好
/// 驼峰 key 对应的下划线 key 直接传入，运行时不再做字符串转换；不传时回退为运行时
/// 转换（兼容旧版生成代码）。
class $ElJsonUtil {
  /// 禁止实例化工具类。
  $ElJsonUtil._(); // coverage:ignore-line

  /// json key 需要同时支持驼峰、下划线。
  static dynamic _getJsonValue(
    dynamic json,
    String key, [
    String? underlineKey,
  ]) {
    if (json is! Map) return null;
    final value = json[key];
    if (value != null) return value;
    final key2 = underlineKey ?? key.toUnderline;
    return key2 == key ? null : json[key2];
  }

  /// 读取字符串字段。只对具有无歧义字符串表示的标量（num/bool/BigInt）做隐式转换，
  /// Map、List 等复合类型静默 toString 只会把脏数据变成更难排查的脏字符串，一律返回 null。
  static String? $string(dynamic json, String key, [String? underlineKey]) {
    final value = _getJsonValue(json, key, underlineKey);
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool || value is BigInt) {
      return value.toString();
    }
    return null;
  }

  /// 读取 num 字段，支持 num 与可解析字符串。
  static num? $num(dynamic json, String key, [String? underlineKey]) {
    final value = _getJsonValue(json, key, underlineKey);
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }

  /// 读取 int 字段，支持 num 与可解析字符串。
  static int? $int(dynamic json, String key, [String? underlineKey]) {
    final value = _getJsonValue(json, key, underlineKey);
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final v = num.tryParse(value.trim());
      return v?.toInt();
    }
    return int.tryParse(value.toString().trim());
  }

  /// 读取 double 字段，支持 num 与可解析字符串。
  static double? $double(dynamic json, String key, [String? underlineKey]) {
    final value = _getJsonValue(json, key, underlineKey);
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return double.tryParse(value.toString().trim());
  }

  /// 读取 bool 字段，支持 bool、num、`0/1` 与 bool 字符串。
  static bool? $bool(dynamic json, String key, [String? underlineKey]) {
    final value = _getJsonValue(json, key, underlineKey);
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().trim().toLowerCase();
    if (s == '1') return true;
    if (s == '0') return false;
    return bool.tryParse(s);
  }

  /// 读取 List 字段；传入 [model] 时，将每个 Map 元素递归反序列化成模型。
  static List<T>? $list<T>(
    dynamic json,
    String key, [
    T? model,
    String? underlineKey,
  ]) {
    final value = _getJsonValue(json, key, underlineKey);
    if (value is List) {
      try {
        final serializeModel = _asSerializeModel<T>(model);
        if (serializeModel != null) {
          return value
              .map((item) => _modelFromJson<T>(item, serializeModel))
              .toList();
        }
        return List<T>.from(value);
      } catch (e) {
        _throwFromJsonError(key, 'List<${T.toString()}>', value);
      }
    }
    return null;
  }

  /// 读取 Set 字段；传入 [model] 时，将每个 Map 元素递归反序列化成模型。
  static Set<T>? $set<T>(
    dynamic json,
    String key, [
    T? model,
    String? underlineKey,
  ]) {
    final value = _getJsonValue(json, key, underlineKey);
    if (value is Iterable) {
      try {
        final serializeModel = _asSerializeModel<T>(model);
        if (serializeModel != null) {
          return value
              .map((item) => _modelFromJson<T>(item, serializeModel))
              .toSet();
        }
        return Set<T>.from(value);
      } catch (e) {
        _throwFromJsonError(key, 'Set<${T.toString()}>', value);
      }
    }
    return null;
  }

  /// 读取 Map 字段；传入 [model] 时，将每个 Map value 递归反序列化成模型。
  static Map<String, T>? $map<T>(
    dynamic json,
    String key, [
    T? model,
    String? underlineKey,
  ]) {
    final value = _getJsonValue(json, key, underlineKey);
    if (value is Map) {
      try {
        final serializeModel = _asSerializeModel<T>(model);
        if (serializeModel != null) {
          return <String, T>{
            for (final entry in value.entries)
              entry.key as String: _modelFromJson<T>(
                entry.value,
                serializeModel,
              ),
          };
        }
        return Map<String, T>.from(value);
      } catch (e) {
        _throwFromJsonError(key, 'Map<String, ${T.toString()}>', value);
      }
    }
    return null;
  }

  /// 读取模型字段，并委托给模型自身的 fromJson。
  static T? $model<T>(
    dynamic json,
    String key,
    T model, [
    String? underlineKey,
  ]) {
    final value = _getJsonValue(json, key, underlineKey);
    if (value == null) return null;
    final serializeModel = _asSerializeModel<T>(model);
    if (serializeModel == null) return null;
    return _modelFromJson(value, serializeModel);
  }

  /// 当内置的数据转换不满足目标类型时，将统一进入自定义序列化方法，
  /// 如果用户没有提供自定义序列化，那么程序将抛出异常。
  static T? $custom<T>(
    dynamic json,
    String key,
    ElSerialize<T> serialize, [
    String? underlineKey,
  ]) {
    final value = _getJsonValue(json, key, underlineKey);
    if (value == null) return null;
    return serialize.deserialize(_asSerializeInput(value));
  }

  /// 读取 List 字段，用自定义序列化逐个还原元素（例如 `List<DateTime>`），
  /// 反序列化失败（返回 null 或抛出异常）的元素按目标可空性处理：
  /// 元素非空类型时跳过，可空类型时保留 null。
  static List<T>? $listCustom<T>(
    dynamic json,
    String key,
    ElSerialize serialize, [
    String? underlineKey,
  ]) {
    final value = _getJsonValue(json, key, underlineKey);
    if (value is! List) return null;
    final result = <T>[];
    for (final item in value) {
      final decoded = _decodeCustom(serialize, item);
      if (decoded is T) result.add(decoded);
    }
    return result;
  }

  /// 读取 Set 字段，用自定义序列化逐个还原元素。
  static Set<T>? $setCustom<T>(
    dynamic json,
    String key,
    ElSerialize serialize, [
    String? underlineKey,
  ]) {
    final value = _getJsonValue(json, key, underlineKey);
    if (value is! Iterable) return null;
    final result = <T>{};
    for (final item in value) {
      final decoded = _decodeCustom(serialize, item);
      if (decoded is T) result.add(decoded);
    }
    return result;
  }

  /// 读取 Map 字段，用自定义序列化逐个还原 value。
  static Map<String, T>? $mapCustom<T>(
    dynamic json,
    String key,
    ElSerialize serialize, [
    String? underlineKey,
  ]) {
    final value = _getJsonValue(json, key, underlineKey);
    if (value is! Map) return null;
    final result = <String, T>{};
    for (final entry in value.entries) {
      final decoded = _decodeCustom(serialize, entry.value);
      if (decoded is T) result[entry.key as String] = decoded;
    }
    return result;
  }

  /// 逐元素调用自定义反序列化，用户手写的序列化器遇到脏数据可能直接抛出，
  /// 单个坏元素不应导致整个集合解析失败。
  static dynamic _decodeCustom(ElSerialize serialize, dynamic item) {
    try {
      return serialize.deserialize(
        item == null ? null : _asSerializeInput(item),
      );
    } catch (_) {
      return null;
    }
  }

  /// 比较两个 List 是否相等，并安全处理 null。
  static bool eqList(List? value1, List? value2) {
    if (value1 == null && value2 == null) return true;
    if (value1 == null || value2 == null) return false;
    return value1.eq(value2);
  }

  /// 比较两个 Set 是否相等，并安全处理 null。
  static bool eqSet(Set? value1, Set? value2) {
    if (value1 == null && value2 == null) return true;
    if (value1 == null || value2 == null) return false;
    return value1.eq(value2);
  }

  /// 比较两个 Map 是否相等，并安全处理 null。
  static bool eqMap(Map? value1, Map? value2) {
    if (value1 == null && value2 == null) return true;
    if (value1 == null || value2 == null) return false;
    return value1.eq(value2);
  }

  /// [ElSerialize.deserialize] 只接受 String，后端把时间戳等值以数字下发是常态，
  /// 这里统一转成字符串交给反序列化，而不是直接类型转换崩溃。
  static String _asSerializeInput(dynamic value) {
    return value is String ? value : value.toString();
  }

  /// 将默认模型收窄成可反序列化接口。
  static ElSerializeModel? _asSerializeModel<T>(T? model) {
    if (model is ElSerializeModel) return model;
    return null;
  }

  /// 将 json Map 转换成模型实例。
  static T _modelFromJson<T>(dynamic value, ElSerializeModel model) {
    final result = switch (value) {
      null => model.fromJson(null),
      Map<String, dynamic>() => model.fromJson(value),
      Map() => model.fromJson(Map<String, dynamic>.from(value)),
      _ => model.fromJson(null),
    };
    return result as T;
  }

  /// 在调试环境抛出更明确的类型转换错误，发布环境保持历史兼容返回 null。
  static void _throwFromJsonError(String key, String target, Object value) {
    if (!const bool.fromEnvironment('dart.vm.product')) {
      throw '$_fromJsonErrorStart: $key -> $target 类型转换失败, '
          'json data: \n'
          '================================================================\n'
          '$value\n'
          '================================================================\n'
          '$_fromJsonErrorEnd';
    }
  }
}
