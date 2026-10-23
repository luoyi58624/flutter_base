import 'package:flutter_base/dart.dart';

/// 按指定微秒单位编解码，验证导入前缀、命名构造和命名参数均被保留。
class DurationUnits implements ElSerialize<Duration> {
  /// 指定一个序列化单位对应的微秒数。
  const DurationUnits.units({required this.scale});

  /// 一个序列化单位对应的微秒数。
  final int scale;

  @override
  Duration? deserialize(String? str) {
    final value = int.tryParse(str ?? '');
    return value == null ? null : Duration(microseconds: value * scale);
  }

  @override
  String? serialize(Duration? obj) =>
      obj == null ? null : (obj.inMicroseconds ~/ scale).toString();
}
