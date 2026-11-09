import 'package:example/src/pages/examples/scroll_examples/chat.dart';
import 'package:example/src/pages/examples/scroll_examples/cards.dart';
import 'package:example/src/widgets/example_scrollbar.dart';
import 'package:example/src/pages/examples/scroll_examples/selection.dart';
import 'package:example/src/state/index.dart';
import 'package:example/src/widgets/doc_scroll_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester, Widget page) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(
        theme: ThemeData(platform: .android),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String page, String mode) async {
  await tester.tap(find.byKey(ValueKey('$page-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('$page-mode-$mode')));
  await tester.pumpAndSettle();
}

ScrollPosition _position(WidgetTester tester) {
  final bar = tester.widget<CupertinoScrollbar>(find.byType(CupertinoScrollbar));
  expect(bar.thumbVisibility, isTrue);
  expect(bar.controller!.positions, hasLength(1));
  final scrollable = tester.state<ScrollableState>(
    find.descendant(of: find.byType(RecyclerExampleScrollbar), matching: find.byType(Scrollable)).first,
  );
  expect(identical(bar.controller!.position, scrollable.position), isTrue);
  return bar.controller!.position;
}

Future<double> _dragCupertinoThumb(WidgetTester tester, {bool bottom = false}) async {
  final position = _position(tester);
  final before = position.pixels;
  final rect = tester.getRect(find.byType(CupertinoScrollbar));
  final start = Offset(rect.right - 4.5, bottom ? rect.bottom - 21 : rect.top + 21);
  final gesture = await tester.startGesture(start);
  // Cupertino 按原生规则按住 100ms 后才能从内容拖动切换为滑块拖动。
  await tester.pump(Duration(milliseconds: 130));
  await gesture.moveBy(Offset(0, bottom ? -120 : 120));
  await tester.pump(Duration(milliseconds: 16));
  await gesture.moveBy(Offset(0, bottom ? -30 : 30));
  await tester.pump(Duration(milliseconds: 16));
  final moved = (position.pixels - before).abs();
  await tester.pump(Duration(milliseconds: 120));
  await gesture.up();
  await tester.pumpAndSettle();
  return moved;
}

void main() {
  for (final mode in ['recycler', 'official']) {
    testWidgets('安卓复杂卡片 $mode 可拖动 iOS 滑块跳转大量独立记录', (tester) async {
      await _open(tester, RecyclerCardsPage());
      if (mode == 'official') await _choose(tester, 'cards', mode);
      expect(await _dragCupertinoThumb(tester), greaterThan(10000));
      expect(find.textContaining('观测 #00001').hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('安卓复选列表 $mode 常显 iOS 滚动条，触摸拖动关联真实列表', (tester) async {
      await _open(tester, RecyclerSelectionPage());
      if (mode == 'official') await _choose(tester, 'selection', mode);
      expect(find.byType(CupertinoScrollbar), findsOneWidget);
      expect(find.byType(Scrollbar), findsNothing);
      expect(await _dragCupertinoThumb(tester), greaterThan(10000), reason: '拖动轨道应按比例跳过大量条目');
      expect(find.text('条目 00001').hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('安卓聊天 $mode 从底部向上拖滚动条，输入栏不进入拖拽区域', (tester) async {
      await _open(tester, RecyclerChatPage());
      if (mode == 'official') await _choose(tester, 'chat', mode);
      final position = _position(tester);
      expect(position.pixels - position.minScrollExtent, lessThan(1));
      expect(
        tester.getRect(find.byType(CupertinoScrollbar)).bottom,
        lessThanOrEqualTo(tester.getRect(find.byKey(ValueKey('chat-composer'))).top),
      );
      expect(await _dragCupertinoThumb(tester, bottom: true), greaterThan(10000));
      expect(position.pixels, greaterThan(position.minScrollExtent + 10000));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('两种容器反复切换时滚动条始终只连接当前滚动位置', (tester) async {
    await _open(tester, RecyclerSelectionPage());
    final controller = tester.widget<CupertinoScrollbar>(find.byType(CupertinoScrollbar)).controller!;
    for (final mode in ['official', 'recycler', 'official', 'recycler']) {
      final previous = _position(tester);
      await _choose(tester, 'selection', mode);
      final next = _position(tester);
      expect(identical(next, previous), isFalse);
      expect(tester.widget<CupertinoScrollbar>(find.byType(CupertinoScrollbar)).controller, same(controller));
      expect(next.pixels, closeTo(0, .01));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final mode in DocScrollMode.values) {
    testWidgets('通用文档 ${mode.label} 支持安卓 iOS 风格滑块拖动', (tester) async {
      final oldMode = GlobalState.docScrollMode.value;
      final oldRepeat = GlobalState.docRepeatCount.value;
      GlobalState.docScrollMode.value = mode;
      GlobalState.docRepeatCount.value = 1;
      addTearDown(() {
        GlobalState.docScrollMode.value = oldMode;
        GlobalState.docRepeatCount.value = oldRepeat;
      });
      await _open(
        tester,
        Scaffold(
          body: DocScrollView(
            itemCount: 100,
            itemBuilder: (context, index) => SizedBox(height: 100, child: Text('文档 $index')),
          ),
        ),
      );
      if (mode == .elScrollView) {
        final scroll = tester.widget<ElScrollView>(find.byType(ElScrollView));
        expect(scroll.scrollbar, isA<ElIosScrollBar>());
        final state = tester.state<ElScrollViewState>(find.byType(ElScrollView));
        final thumb = find.byKey(ValueKey('el-scrollbar-thumb-vertical'));
        expect(thumb, findsOneWidget);
        final before = state.position.pixels;
        final gesture = await tester.startGesture(tester.getCenter(thumb));
        await tester.pump(Duration(milliseconds: 130));
        await gesture.moveBy(Offset(0, 150));
        await tester.pump(Duration(milliseconds: 16));
        expect(state.position.pixels - before, greaterThan(500));
        await tester.pump(Duration(milliseconds: 120));
        await gesture.up();
        await tester.pumpAndSettle();
      } else {
        expect(find.byType(CupertinoScrollbar), findsOneWidget);
        expect(await _dragCupertinoThumb(tester), greaterThan(500));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
