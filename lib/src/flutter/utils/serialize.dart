import 'dart:convert';
import 'dart:ui';

import '../../../dart.dart';
import '../extensions/index.dart';

import 'package:meta/meta_meta.dart';

@Target({TargetKind.field})
class ElBrightnessSerialize implements ElSerialize<Brightness> {
  const ElBrightnessSerialize();

  @override
  String? serialize(Brightness? obj) => obj?.name;

  @override
  Brightness? deserialize(String? str) {
    if (str == null) return null;
    if (str == 'dark') return Brightness.dark;
    if (str == 'light') return Brightness.light;
    return null;
  }
}

@Target({TargetKind.field})
class ElColorSerialize implements ElSerialize<Color> {
  const ElColorSerialize();

  @override
  String? serialize(Color? obj) => obj?.toHex();

  @override
  Color? deserialize(String? str) => str?.toColor();
}

@Target({TargetKind.field})
class ElSizeSerialize implements ElSerialize<Size> {
  const ElSizeSerialize();

  @override
  String? serialize(Size? obj) =>
      jsonEncode({'width': obj?.width, 'height': obj?.height});

  @override
  Size? deserialize(String? str) {
    if (str == null) return null;
    final map = jsonDecode(str);
    if (map is Map) {
      return Size(
        ElDartUtil.safeDouble(map['width']),
        ElDartUtil.safeDouble(map['height']),
      );
    } else {
      return null;
    }
  }
}

@Target({TargetKind.field})
class ElOffsetSerialize implements ElSerialize<Offset> {
  const ElOffsetSerialize();

  @override
  String? serialize(Offset? obj) => jsonEncode({'dx': obj?.dx, 'dy': obj?.dy});

  @override
  Offset? deserialize(String? str) {
    if (str == null) return null;
    final map = jsonDecode(str);
    if (map is Map) {
      return Offset(
        ElDartUtil.safeDouble(map['dx']),
        ElDartUtil.safeDouble(map['dy']),
      );
    } else {
      return null;
    }
  }
}

@Target({TargetKind.field})
class ElLocaleSerialize implements ElSerialize<Locale> {
  const ElLocaleSerialize();

  @override
  String? serialize(Locale? obj) => obj == null
      ? null
      : jsonEncode({
          'languageCode': obj.languageCode,
          'countryCode': obj.countryCode,
        });

  @override
  Locale? deserialize(String? str) {
    if (str == null) return null;
    final map = jsonDecode(str);
    if (map is Map) {
      return Locale(
        ElDartUtil.safeString(map['languageCode']),
        ElDartUtil.safeString(map['countryCode']),
      );
    } else {
      return null;
    }
  }
}
