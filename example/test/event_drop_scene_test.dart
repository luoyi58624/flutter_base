import 'package:example/src/pages/components/event/advanced/examples/drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _key(String key) => find.byKey(ValueKey('advanced-drop-$key'));

Future<void> _show(WidgetTester tester) async {
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 248, child: ElDropInteractionExample())),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) => tester.widget<Text>(_key(key)).data!;

void main() {
  for (final slop in [12.0, 18.0]) {
    testWidgets('滚动页内缓慢纵向拖放使用设备容差 $slop，源外仍能正常滚动', (tester) async {
      final scroll = ScrollController(initialScrollOffset: 100);
      addTearDown(scroll.dispose);
      addTearDown(() => tester.pumpWidget(SizedBox()));
      await tester.pumpWidget(
        ElComponentProvider(
          components: el.mobileComponents,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(gestureSettings: DeviceGestureSettings(touchSlop: slop)),
              child: child!,
            ),
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  controller: scroll,
                  physics: ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      SizedBox(height: 180),
                      SizedBox(width: 248, child: ElDropInteractionExample()),
                      SizedBox(height: 800),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(_key('file')));
      await gesture.moveBy(Offset(0, slop * .5));
      await tester.pump();
      expect(_text(tester, 'phase'), '就绪');
      await gesture.moveBy(Offset(0, slop * .6));
      await tester.pump();
      expect(_text(tester, 'phase'), '拖放中', reason: '不能等到双倍 pan 容差才起拖，此时外层滚动已抢走指针');
      expect(scroll.offset, 100);
      await gesture.moveTo(tester.getCenter(_key('inbox')));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('收件箱 1'), findsOneWidget);
      expect(_text(tester, 'opened'), '打开 0');
      expect(scroll.offset, 100);

      await tester.dragFrom(Offset(305, 400), Offset(0, -100));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(100));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('文件可以点击打开，真实拖放接收后不误打开且按压结束', (tester) async {
    await _show(tester);
    await tester.tap(_key('file'));
    await tester.pumpAndSettle();
    expect(_text(tester, 'opened'), '打开 1');

    final gesture = await tester.startGesture(tester.getCenter(_key('file')));
    await tester.pump();
    expect(_text(tester, 'press'), '按下');
    await gesture.moveBy(Offset(0, 40));
    await tester.pump();
    expect(_text(tester, 'phase'), '拖放中');
    expect(_text(tester, 'press'), '松开');
    // 记录真实回调，页面可观察先后关系；此处不把争议中的顺序固化成新合同。
    expect(_text(tester, 'sequence'), contains('开始拖放'));
    expect(_text(tester, 'sequence'), contains('取消按压'));
    await gesture.moveTo(tester.getCenter(_key('inbox')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('收件箱 1'), findsOneWidget);
    expect(_text(tester, 'phase'), '已投放');
    expect(_text(tester, 'opened'), '打开 1');
    expect(tester.takeException(), isNull);

    await tester.tap(_key('reset'));
    await tester.pumpAndSettle();
    expect(find.text('收件箱 0'), findsOneWidget);
    expect(_text(tester, 'opened'), '打开 0');
    expect(_text(tester, 'sequence'), '—');
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('锁定区拒绝投放，取消操作也不误触外层点击', (tester) async {
    await _show(tester);
    final rejected = await tester.startGesture(tester.getCenter(_key('file')));
    await rejected.moveBy(Offset(0, 40));
    await rejected.moveTo(tester.getCenter(_key('locked')));
    await tester.pump();
    await rejected.up();
    await tester.pumpAndSettle();
    expect(_text(tester, 'phase'), '未投放');
    expect(find.text('收件箱 0'), findsOneWidget);
    expect(_text(tester, 'opened'), '打开 0');

    final canceled = await tester.startGesture(tester.getCenter(_key('file')));
    await canceled.moveBy(Offset(0, 40));
    await tester.pump();
    await canceled.cancel();
    await tester.pumpAndSettle();
    expect(_text(tester, 'phase'), '未投放');
    expect(_text(tester, 'press'), '松开');
    expect(_text(tester, 'opened'), '打开 0');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
