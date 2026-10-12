import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter 序列化器从主入口可用并能恢复对象', () {
    final brightness = ElBrightnessSerialize();
    expect(
      brightness.deserialize(brightness.serialize(Brightness.dark)),
      Brightness.dark,
    );
    expect(brightness.deserialize('invalid'), isNull);
    final color = ElColorSerialize();
    expect(
      color.deserialize(color.serialize(Color(0xff123456))),
      Color(0xff123456),
    );
    final size = ElSizeSerialize();
    expect(size.deserialize(size.serialize(Size(3, 4))), Size(3, 4));
    final offset = ElOffsetSerialize();
    expect(offset.deserialize(offset.serialize(Offset(3, 4))), Offset(3, 4));
    final locale = ElLocaleSerialize();
    expect(
      locale.deserialize(locale.serialize(Locale('zh', 'CN'))),
      Locale('zh', 'CN'),
    );
    expect(locale.deserialize(null), isNull);
  });
}
