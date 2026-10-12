import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('平台与快捷键使用本机和测试环境信息', () {
    expect(ElPlatform.isWindows, Platform.isWindows);
    expect(ElPlatform.isMacOS, Platform.isMacOS);
    expect(ElPlatform.isDesktopClient, ElPlatform.isDesktop);
    expect(ElPlatform.isFlutterTest, isTrue);
    expect(ElPlatform.isMobileWeb, isFalse);
    expect(
      ElShortcutUtil.ctrl,
      Platform.isMacOS ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control,
    );
  });

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

  test('Flutter 扩展保留 CSS 内边距和文本缩放语义', () {
    expect([10].toEdgeInsets, EdgeInsets.all(10));
    expect(
      [10, 20].toEdgeInsets,
      EdgeInsets.symmetric(vertical: 10, horizontal: 20),
    );
    expect([10, 20, 30].toEdgeInsets, EdgeInsets.fromLTRB(20, 10, 20, 30));
    expect(
      [10.0, 20.0, 30.0, 40.0].toEdgeInsets,
      EdgeInsets.fromLTRB(40, 10, 20, 30),
    );
    expect(<double>[].toEdgeInsets, isNull);
    expect(10.applyTextScale(TextScaler.linear(2)), 20);
    expect(10.0.applyTextScale(TextScaler.linear(2), maxValue: 15), 15);
    expect(700.toFontWeight(), FontWeight.w700);
    expect(123.toFontWeight(FontWeight.w300), FontWeight.w300);
    expect(
      AxisDirection.left.applyTextDirection(TextDirection.rtl),
      AxisDirection.right,
    );
    expect(Size(2, 3).toOffset, Offset(2, 3));
  });

  test('颜色混合和明暗调整保留端点与透明度', () {
    final first = Color(0x80123456);
    final second = Color(0xffabcdef);
    expect(first.mix(second, 0), first);
    expect(first.mix(second, 100), second);
    expect(first.toHex(hasAlpha: true), '#80123456');
    expect(first.elOpacity(0.5).a, 0.5);
    expect(Colors.black.brighten(100), Colors.white);
    expect(Colors.white.darken(100), Colors.black);
    expect(Colors.black.isDark, isTrue);
    expect(Colors.white.isHighlight, isFalse);
    expect(() => first.mix(second, 101), throwsAssertionError);
  });

  test('尺寸工具在有限约束下等比缩放', () {
    expect(
      ElFlutterUtil.calcConstraintsSize(
        Size(100, 50),
        BoxConstraints(maxWidth: 50, maxHeight: 50),
      ),
      Size(50, 25),
    );
    expect(
      ElFlutterUtil.calcConstraintsSize(
        Size(50, 100),
        BoxConstraints(maxWidth: 50, maxHeight: 50),
      ),
      Size(25, 50),
    );
  });

  testWidgets('帧回调按是否主动请求帧执行', (tester) async {
    final calls = <String>[];
    safeCallback(() => calls.add('safe'));
    expect(calls, ['safe']);
    nextTick(() => calls.add('tick'));
    nextFrame(() => calls.add('frame'));
    await tester.pump();
    expect(calls, ['safe', 'frame', 'tick']);
  });

  test('通知对象可解绑并在释放前发送一次通知', () {
    var calls = 0;
    void listener() => calls++;
    final notify = ElNotify()..addListener(listener);
    notify.notifyListeners();
    expect(calls, 1);
    notify.removeListener(listener);
    notify.notifyListeners();
    expect(calls, 1);
    notify.dispose();
    final dispose = ElDisposeNotify()..addListener(listener);
    dispose.dispose();
    expect(calls, 2);
    dispose.dispose();
    expect(calls, 2);
  });
}
