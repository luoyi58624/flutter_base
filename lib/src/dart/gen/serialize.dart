part of 'index.dart';

/// 对象序列化接口
abstract interface class ElSerialize<T> {
  /// 将对象转换成字符串
  String? serialize(T? obj);

  /// 将字符串转换成对象
  T? deserialize(String? str);
}

/// 数据模型序列化接口
abstract interface class ElSerializeModel<T> {
  /// 将 Map 转成对象
  T fromJson(Map<String, dynamic>? json);

  /// 将对象转成 Map 键值对
  Map<String, dynamic> toJson();
}

// =============================================================================
// 内置一些默认的 Dart 对象序列化
// =============================================================================

/// 通用枚举序列化，按 [Enum.name] 编解码，免去为每个枚举手写 if 链：
/// ```dart
/// @ElEnumSerialize(ThemeMode.values)
/// final ThemeMode? themeMode;
/// ```
@Target({TargetKind.field})
class ElEnumSerialize<T extends Enum> implements ElSerialize<T> {
  const ElEnumSerialize(this.values);

  /// 枚举的全部值，直接传 `XxxEnum.values`
  final List<T> values;

  @override
  String? serialize(T? obj) => obj?.name;

  @override
  T? deserialize(String? str) {
    if (str == null) return null;
    for (final value in values) {
      if (value.name == str) return value;
    }
    return null;
  }
}

/// DateTime 序列化（毫秒时间戳字符串），体积小、无时区歧义
@Target({TargetKind.field})
class ElDateTimeSerialize implements ElSerialize<DateTime> {
  const ElDateTimeSerialize();

  @override
  String? serialize(DateTime? obj) => obj?.millisecondsSinceEpoch.toString();

  @override
  DateTime? deserialize(String? str) {
    if (str == null) return null;
    final ms = int.tryParse(str);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
}

/// DateTime 序列化（ISO8601 字符串），可读性好、与主流后端接口格式一致，
/// 反序列化兼容任何 [DateTime.parse] 支持的格式
@Target({TargetKind.field})
class ElDateTimeIso8601Serialize implements ElSerialize<DateTime> {
  const ElDateTimeIso8601Serialize();

  @override
  String? serialize(DateTime? obj) => obj?.toIso8601String();

  @override
  DateTime? deserialize(String? str) => str == null ? null : DateTime.tryParse(str);
}

@Target({TargetKind.field})
class ElDurationSerialize implements ElSerialize<Duration> {
  const ElDurationSerialize();

  @override
  String? serialize(Duration? obj) => obj?.inMicroseconds.toString();

  @override
  Duration? deserialize(String? str) {
    if (str == null) return null;
    final us = int.tryParse(str);
    return us == null ? null : Duration(microseconds: us);
  }
}

/// Uri 序列化
@Target({TargetKind.field})
class ElUriSerialize implements ElSerialize<Uri> {
  const ElUriSerialize();

  @override
  String? serialize(Uri? obj) => obj?.toString();

  @override
  Uri? deserialize(String? str) => str == null ? null : Uri.tryParse(str);
}

/// BigInt 序列化
@Target({TargetKind.field})
class ElBigIntSerialize implements ElSerialize<BigInt> {
  const ElBigIntSerialize();

  @override
  String? serialize(BigInt? obj) => obj?.toString();

  @override
  BigInt? deserialize(String? str) => str == null ? null : BigInt.tryParse(str);
}

/// 二进制数据序列化（base64），适合在 JSON 中携带小块二进制数据；
/// 大块二进制建议直接存 [ElStorage]（io 端 JSON 快照、web 端 IndexedDB 均原生支持字符串存储）
@Target({TargetKind.field})
class ElUint8ListSerialize implements ElSerialize<Uint8List> {
  const ElUint8ListSerialize();

  @override
  String? serialize(Uint8List? obj) => obj == null ? null : base64Encode(obj);

  @override
  Uint8List? deserialize(String? str) {
    if (str == null) return null;
    try {
      return base64Decode(str);
    } catch (_) {
      return null;
    }
  }
}
