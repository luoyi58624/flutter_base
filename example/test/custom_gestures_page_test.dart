import 'dart:io';
import 'dart:ui' as ui;

import 'package:example/src/pages/custom_gestures.dart';
import 'package:example/src/pages/index.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _desktopSize = Size(1280, 1000);
const _settledGesture = Duration(milliseconds: 700);
const _screenshotPath = String.fromEnvironment('GESTURE_SCREENSHOT');
const _previewFontPath = String.fromEnvironment('GESTURE_PREVIEW_FONT');
const _iconFontPath = String.fromEnvironment('GESTURE_ICON_FONT');

Finder _key(String value) => find.byKey(ValueKey(value));

int _count(WidgetTester tester, String name) =>
    int.parse(tester.widget<Text>(_key('count.$name')).data!);

Future<void> _pumpPage(
  WidgetTester tester, {
  Size size = _desktopSize,
  double textScale = 1,
  String? fontFamily,
  Widget page = const CustomGesturesPage(),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: fontFamily == null ? null : ThemeData(fontFamily: fontFamily),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

Future<Finder> _reveal(WidgetTester tester, String key) async {
  final target = _key(key);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  return target;
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(await _reveal(tester, key));
  await tester.pump();
}

void main() {
  testWidgets('元素范围由页面判断，范围内移动可点击而移出后主动取消', (tester) async {
    await _pumpPage(tester);
    final target = await _reveal(tester, 'gesture.basic.target');
    final bounds = tester.getRect(target);
    final inside = await tester.startGesture(
      Offset(bounds.left + 10, bounds.center.dy),
    );
    await inside.moveTo(Offset(bounds.right - 10, bounds.center.dy));
    await inside.up();
    await tester.pump(_settledGesture);
    expect(_count(tester, 'tap'), 1);
    final outside = await tester.startGesture(bounds.center);
    await outside.moveTo(Offset(bounds.right + 10, bounds.center.dy));
    await tester.pump(const Duration(milliseconds: 600));
    await outside.moveTo(bounds.center);
    await outside.up();
    await tester.pump(_settledGesture);
    expect(_count(tester, 'tap'), 1);
    expect(_count(tester, 'longPress'), 0);
    await tester.tap(target);
    await tester.pump(_settledGesture);
    expect(_count(tester, 'tap'), 2);
  });

  testWidgets('基础操作区直接显示单击、双击、三击和长按结果', (tester) async {
    await _pumpPage(tester);
    final target = await _reveal(tester, 'gesture.basic.target');

    await tester.tap(target);
    await tester.pump();
    expect(_count(tester, 'tap'), 1);
    expect(_count(tester, 'doubleTap'), 0);
    expect(_count(tester, 'tripleTap'), 0);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(target);
    await tester.pump();
    expect(_count(tester, 'tap'), 2);
    expect(_count(tester, 'doubleTap'), 1);
    expect(_count(tester, 'tripleTap'), 0);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(target);
    await tester.pump();
    expect(_count(tester, 'tap'), 3);
    expect(_count(tester, 'doubleTap'), 1);
    expect(_count(tester, 'tripleTap'), 1);

    await tester.pump(_settledGesture);
    final press = await tester.startGesture(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_count(tester, 'longPress'), 1);
    await press.up();
    await tester.pump(_settledGesture);
    expect(_count(tester, 'tap'), 3);
    expect(_count(tester, 'longPress'), 1);
  });

  testWidgets('鼠标右键、中键、前进和后退按钮分别计数', (tester) async {
    await _pumpPage(tester);
    final target = await _reveal(tester, 'gesture.basic.target');
    final position = tester.getCenter(target);
    final buttons = <int, String>{
      kSecondaryButton: 'secondaryTap',
      kTertiaryButton: 'tertiaryTap',
      kForwardMouseButton: 'forwardTap',
      kBackMouseButton: 'backTap',
    };
    var pointer = 100;
    for (final entry in buttons.entries) {
      final gesture = await tester.startGesture(
        position,
        pointer: pointer++,
        kind: PointerDeviceKind.mouse,
        buttons: entry.key,
      );
      await gesture.up();
      await tester.pump();
      expect(_count(tester, entry.value), 1);
    }
    expect(_count(tester, 'tap'), 0);
    expect(_count(tester, 'longPress'), 0);
  });

  testWidgets('延迟单击保留识别窗口，双击取消待发单击', (tester) async {
    await _pumpPage(tester);
    await _tap(tester, 'gesture.defer');
    final target = await _reveal(tester, 'gesture.basic.target');

    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 250));
    expect(_count(tester, 'tap'), 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_count(tester, 'tap'), 1);

    await tester.pump(_settledGesture);
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(target);
    await tester.pump();
    expect(_count(tester, 'doubleTap'), 1);
    expect(_count(tester, 'tap'), 1);
    await tester.pump(_settledGesture);
    expect(_count(tester, 'tap'), 1);
    expect(_count(tester, 'tripleTap'), 0);
  });

  testWidgets('El 子点击向父冒泡，开关只截断 El 传播', (tester) async {
    await _pumpPage(tester);
    await _tap(tester, 'gesture.bubble.target');
    expect(_count(tester, 'bubbleChild'), 1);
    expect(_count(tester, 'bubbleParent'), 1);

    await _tap(tester, 'gesture.bubble.stop');
    await _tap(tester, 'gesture.bubble.target');
    expect(_count(tester, 'bubbleChild'), 2);
    expect(_count(tester, 'bubbleParent'), 1);
  });

  testWidgets('El 内层点击获胜，外层官方 Tap 不触发', (tester) async {
    await _pumpPage(tester);
    await _tap(tester, 'gesture.elInOfficial.target');
    await tester.pump(_settledGesture);
    expect(_count(tester, 'mixedEl'), 1);
    expect(_count(tester, 'mixedOfficialOuter'), 0);
  });

  testWidgets('官方内层点击获胜，外层 El 不触发', (tester) async {
    await _pumpPage(tester);
    await _tap(tester, 'gesture.officialInEl.target');
    await tester.pump(_settledGesture);
    expect(_count(tester, 'mixedOfficialChild'), 1);
    expect(_count(tester, 'mixedElOuter'), 0);
  });

  testWidgets('ListView 赢得拖拽后，行点击取消且列表真实滚动', (tester) async {
    await _pumpPage(tester);
    final target = await _reveal(tester, 'gesture.scroll.target');
    final list = _key('gesture.scroll.list');
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    final initialPixels = position.pixels;

    await tester.tap(target);
    await tester.pump(_settledGesture);
    expect(_count(tester, 'scrollTap'), 1);
    expect(position.pixels, initialPixels);

    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(initialPixels));
    expect(_count(tester, 'scrollTap'), 1);
    expect(_count(tester, 'scrollCancel'), 1);
    await tester.pump(_settledGesture);
    expect(_count(tester, 'scrollTap'), 1);
  });

  testWidgets('重置清空计数并释放待发单击，下一次手势重新计数', (tester) async {
    await _pumpPage(tester);
    await _tap(tester, 'gesture.basic.target');
    expect(_count(tester, 'tap'), 1);
    await tester.pump(_settledGesture);
    await _tap(tester, 'gesture.defer');
    final target = await _reveal(tester, 'gesture.basic.target');
    await tester.tap(target);
    await tester.pump();
    expect(_count(tester, 'tap'), 1);

    await _tap(tester, 'gesture.reset');
    await tester.pump(_settledGesture);
    for (final counter in <String>[
      'tap',
      'doubleTap',
      'tripleTap',
      'longPress',
      'secondaryTap',
      'tertiaryTap',
      'forwardTap',
      'backTap',
      'bubbleChild',
      'bubbleParent',
      'mixedEl',
      'mixedOfficialOuter',
      'mixedOfficialChild',
      'mixedElOuter',
      'scrollTap',
      'scrollCancel',
    ]) {
      expect(_count(tester, counter), 0, reason: '$counter 应在重置后保持为零');
    }
    await _tap(tester, 'gesture.basic.target');
    await tester.pump(_settledGesture);
    expect(_count(tester, 'tap'), 1);
    expect(_count(tester, 'doubleTap'), 0);
    expect(_count(tester, 'tripleTap'), 0);
  });

  testWidgets('首页自定义手势导航打开可操作页面', (tester) async {
    await _pumpPage(tester, page: const HomePage());
    final navigation = find.text('自定义手势');
    await tester.ensureVisible(navigation);
    await tester.tap(navigation);
    await tester.pumpAndSettle();
    expect(find.byType(CustomGesturesPage), findsOneWidget);
    await _tap(tester, 'gesture.basic.target');
    expect(_count(tester, 'tap'), 1);
  });

  testWidgets('窄屏与放大文字下所有测试区可访问且没有布局溢出', (tester) async {
    await _pumpPage(tester, size: const Size(390, 844), textScale: 1.4);
    expect(tester.takeException(), isNull);
    for (final key in <String>[
      'gesture.basic.target',
      'gesture.defer',
      'gesture.bubble.target',
      'gesture.bubble.stop',
      'gesture.elInOfficial.target',
      'gesture.officialInEl.target',
      'gesture.scroll.target',
      'gesture.reset',
    ]) {
      await _reveal(tester, key);
      expect(tester.takeException(), isNull, reason: '$key 应可正常布局');
    }
  });

  testWidgets('窄屏可直接打开事件记录并查看刚才的点击', (tester) async {
    await _pumpPage(tester, size: const Size(390, 844), textScale: 1.4);
    await _tap(tester, 'gesture.basic.target');
    await tester.pump(_settledGesture);
    await _tap(tester, 'gesture.logs');
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('tap')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.textContaining('基础点击')),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存自定义手势测试页桌面预览', (tester) async {
    if (_iconFontPath.isNotEmpty) {
      await tester.runAsync(() async {
        final font = FontLoader('MaterialIcons');
        font.addFont(
          File(_iconFontPath).readAsBytes().then(ByteData.sublistView),
        );
        await font.load();
      });
    }
    if (_previewFontPath.isNotEmpty) {
      await tester.runAsync(() async {
        final font = FontLoader('GesturePreview');
        font.addFont(
          File(_previewFontPath).readAsBytes().then(ByteData.sublistView),
        );
        await font.load();
      });
    }
    await _pumpPage(
      tester,
      fontFamily: _previewFontPath.isEmpty ? null : 'GesturePreview',
    );
    await tester.tap(_key('gesture.basic.target'));
    await tester.pump(_settledGesture);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      _key('gesture.page.capture'),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        expect(bytes, isNotNull);
        final output = File(_screenshotPath);
        await output.parent.create(recursive: true);
        await output.writeAsBytes(
          bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
      } finally {
        image.dispose();
      }
    });
  }, skip: _screenshotPath.isEmpty);
}
