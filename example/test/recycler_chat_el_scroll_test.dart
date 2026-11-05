import 'package:example/src/pages/examples/recycler_view/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(
        theme: ThemeData(platform: .android),
        home: RecyclerChatPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String action) async {
  await tester.tap(find.byKey(ValueKey('chat-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('chat-$action')));
  await tester.pumpAndSettle();
}

ElScrollViewState _state(WidgetTester tester) => tester.state<ElScrollViewState>(find.byType(ElScrollView));

String _count(WidgetTester tester) => tester.widget<Text>(find.byKey(ValueKey('chat-count'))).data!;

String _unread(WidgetTester tester) {
  final badge = tester.widget<Badge>(
    find.descendant(of: find.byKey(ValueKey('chat-menu')), matching: find.byType(Badge)),
  );
  return badge.isLabelVisible ? (badge.label! as Text).data! : '0';
}

void main() {
  testWidgets('ElScrollView 聊天真实虚拟化一万条正序消息，初始贴底且发送接收继续跟随', (tester) async {
    await _open(tester);
    await _choose(tester, 'mode-elScrollView');
    expect(find.byType(rv.RecyclerView), findsNothing);
    expect(find.byType(ListView), findsNothing);
    final scroll = tester.widget<ElScrollView>(find.byType(ElScrollView));
    final rows = tester.widget<ElListView>(find.byType(ElListView));
    expect(scroll.reverse, isTrue);
    expect(scroll.preserveAnchor, isTrue);
    expect(rows.itemCount, 10000);
    expect(rows.keepAlive, isFalse);
    expect(
      find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_ChatRow').evaluate().length,
      lessThan(30),
    );
    expect(find.textContaining('消息 #10000：').hitTestable(), findsOneWidget);
    expect(_state(tester).position.pixels, closeTo(0, .01));
    final latest = find.textContaining('消息 #10000：');
    final previous = find.textContaining('消息 #9999：');
    expect(tester.getTopLeft(previous).dy, lessThan(tester.getTopLeft(latest).dy), reason: 'El reverse 不能再翻一次业务消息顺序');

    await tester.enterText(find.byKey(ValueKey('chat-composer')), 'ElScrollView 发出的独立消息');
    await tester.tap(find.byKey(ValueKey('chat-send')));
    await tester.pumpAndSettle();
    expect(find.text('ElScrollView 发出的独立消息').hitTestable(), findsOneWidget);
    expect(_count(tester), '10001 条');
    expect(_state(tester).position.pixels, closeTo(0, .01));
    await _choose(tester, 'receive');
    expect(_count(tester), '10002 条');
    expect(find.textContaining('消息 #10002：').hitTestable(), findsOneWidget);
    expect(_unread(tester), '0');
    expect(tester.takeException(), isNull);
  });

  testWidgets('ElScrollView 阅读旧消息时前插历史与追加消息保留实际文本锚点', (tester) async {
    await _open(tester);
    await _choose(tester, 'mode-elScrollView');
    _state(tester).position.jumpTo(750);
    await tester.pumpAndSettle();
    final textFinder = find
        .byWidgetPredicate((widget) => widget is Text && (widget.data?.startsWith('消息 #') ?? false))
        .hitTestable()
        .first;
    final text = tester.widget<Text>(textFinder).data!;
    final before = tester.getTopLeft(find.text(text)).dy;
    await _choose(tester, 'load-earlier');
    expect(_count(tester), '10050 条');
    expect(tester.getTopLeft(find.text(text)).dy, closeTo(before, .1));
    await _choose(tester, 'receive');
    expect(_unread(tester), '1');
    expect(tester.getTopLeft(find.text(text)).dy, closeTo(before, .1));
    await _choose(tester, 'latest');
    expect(_state(tester).position.pixels, closeTo(0, .01));
    expect(find.textContaining('消息 #10001：').hitTestable(), findsOneWidget);
    expect(_unread(tester), '0');
    expect(tester.takeException(), isNull);
  });

  testWidgets('三种聊天容器切换保留消息和输入草稿，每次从相同的最新位置开始', (tester) async {
    await _open(tester);
    await tester.enterText(find.byKey(ValueKey('chat-composer')), '跨三种容器的消息');
    await tester.tap(find.byKey(ValueKey('chat-send')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ValueKey('chat-composer')), '切换时保留的草稿');
    for (final mode in ['elScrollView', 'listView', 'recyclerView', 'elScrollView']) {
      await _choose(tester, 'mode-$mode');
      expect(_count(tester), '10001 条');
      expect(find.text('跨三种容器的消息').hitTestable(), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(ValueKey('chat-composer'))).controller!.text, '切换时保留的草稿');
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byKey(ValueKey('chat-send')));
    await tester.pumpAndSettle();
    expect(_count(tester), '10002 条');
    expect(find.text('切换时保留的草稿').hitTestable(), findsOneWidget);
  });

  testWidgets('安卓 ElScrollView 聊天内建 iOS 滑块可以向上拖动，输入栏在滚动区域外', (tester) async {
    await _open(tester);
    await _choose(tester, 'mode-elScrollView');
    final scroll = tester.widget<ElScrollView>(find.byType(ElScrollView));
    expect(scroll.scrollbar, isA<ElIosScrollBar>());
    final thumb = find.byKey(ValueKey('el-scrollbar-thumb-vertical'));
    expect(thumb, findsOneWidget);
    expect(
      tester.getRect(find.byType(ElScrollView)).bottom,
      lessThanOrEqualTo(tester.getRect(find.byKey(ValueKey('chat-composer'))).top),
    );
    final gesture = await tester.startGesture(tester.getCenter(thumb));
    await tester.pump(Duration(milliseconds: 130));
    await gesture.moveBy(Offset(0, -130));
    await tester.pump(Duration(milliseconds: 16));
    expect(_state(tester).position.pixels, greaterThan(10000));
    await tester.pump(Duration(milliseconds: 120));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.textContaining('消息 #10000：').hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
