import 'package:example/src/pages/examples/recycler_view/chat.dart';
import 'package:example/src/pages/examples/recycler_view/rich_document.dart';
import 'package:example/src/pages/examples/recycler_view/scroll_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester, Widget page, {double width = 390}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
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

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

String _chatCount(WidgetTester tester) => tester.widget<Text>(find.byKey(ValueKey('chat-count'))).data!;

ScrollPosition _chatPosition(WidgetTester tester, RecyclerExampleScrollMode mode) => switch (mode) {
  .listView => tester.widget<ListView>(find.byType(ListView)).controller!.position,
  .elScrollView => tester.state<ElScrollViewState>(find.byType(ElScrollView)).position,
  .recyclerView => tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView)).controller!.position,
  .recyclerView2 => tester.widget<ElRecyclerView2>(find.byKey(ValueKey('recycler2-chat-list'))).controller!.position,
};

Future<void> _locate(WidgetTester tester, int section) async {
  await _tap(tester, 'rich-document-contents');
  await tester.enterText(find.byKey(ValueKey('rich-document-search')), '$section');
  await tester.pumpAndSettle();
  await _tap(tester, 'rich-document-directory-${section - 1}');
}

void main() {
  for (final mode in RecyclerExampleScrollMode.values) {
    testWidgets('实时群聊 ${mode.label} 保留阅读锚点，并在末尾跟随同一条流式消息', (tester) async {
      await _open(tester, RecyclerLiveChatPage());
      if (mode != .recyclerView) {
        await _tap(tester, 'chat-menu');
        await _tap(tester, 'chat-mode-${mode.name}');
      }
      final position = _chatPosition(tester, mode);
      position.jumpTo(mode == .recyclerView ? position.maxScrollExtent - 760 : 760);
      await tester.pumpAndSettle();
      final reader = find
          .byWidgetPredicate((widget) => widget is Text && (widget.data?.startsWith('消息 #') ?? false))
          .hitTestable()
          .first;
      final text = tester.widget<Text>(reader).data!;
      final y = tester.getTopLeft(find.text(text)).dy;

      await _tap(tester, 'chat-live-step');
      expect(_chatCount(tester), '10051 条');
      expect(tester.getTopLeft(find.text(text)).dy, closeTo(y, .5));
      await _tap(tester, 'chat-live-step');
      expect(_chatCount(tester), '10051 条');
      expect(tester.getTopLeft(find.text(text)).dy, closeTo(y, .5));
      expect(tester.widget<Text>(find.byKey(ValueKey('chat-unread-count'))).data, '1');

      await _tap(tester, 'chat-menu');
      await _tap(tester, 'chat-latest');
      expect(find.textContaining('第 1 段：').hitTestable(), findsOneWidget);
      await _tap(tester, 'chat-live-step');
      expect(_chatCount(tester), '10052 条');
      expect(find.textContaining('第 2 段：').hitTestable(), findsOneWidget);
      expect(find.text('我在这边也看到最新进度了。').hitTestable(), findsOneWidget);
      expect(mode == .recyclerView ? position.extentAfter : position.extentBefore, closeTo(0, .5));
      await _tap(tester, 'chat-live-reset');
      expect(_chatCount(tester), '10000 条');
      expect(find.text('并发脚本 0 / 8'), findsOneWidget);
      expect(find.textContaining('消息 #10000：').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('实时群聊可以暂停并自动结束，离开页面会清除尚未触发的事件', (tester) async {
    await _open(tester, RecyclerLiveChatPage());
    final playback = find.byKey(ValueKey('chat-live-play'));
    await tester.tap(playback);
    await tester.pump();
    await tester.pump(Duration(milliseconds: 450));
    await tester.pump();
    expect(find.text('并发脚本 1 / 8'), findsOneWidget);
    await tester.tap(playback);
    await tester.pump();
    await tester.pump(Duration(seconds: 2));
    expect(find.text('并发脚本 1 / 8'), findsOneWidget);
    await tester.tap(playback);
    await tester.pump();
    for (var i = 0; i < 7; i++) {
      await tester.pump(Duration(milliseconds: 450));
      await tester.pump();
    }
    expect(find.text('并发脚本 8 / 8'), findsOneWidget);
    expect(_chatCount(tester), '10103 条');
    expect(tester.widget<IconButton>(playback).onPressed, isNull);
    await _tap(tester, 'chat-live-reset');
    await tester.tap(playback);
    await tester.pump();
    await tester.pumpWidget(SizedBox());
    await tester.pump(Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('富文本文档三种容器均能找到未挂载的小节并保持各节交互状态', (tester) async {
    await _open(tester, RecyclerRichDocumentPage());
    final last = find.byKey(ValueKey('rich-document-title-239'));
    final code = find.byKey(ValueKey('rich-document-code-239'));
    var primed = false;
    for (final mode in RecyclerExampleScrollMode.values.reversed) {
      if (mode != .recyclerView) {
        await _tap(tester, 'comparison-mode-menu');
        await _tap(tester, 'comparison-mode-${mode.name}');
      }
      expect(last, findsNothing);
      await _locate(tester, 240);
      expect(last.hitTestable(), findsOneWidget);
      if (!primed) {
        await _tap(tester, 'rich-document-code-toggle-239');
        expect(code, findsOneWidget);
        await _tap(tester, 'rich-document-check-239');
        primed = true;
      }
      expect(code, findsOneWidget);
      expect(tester.widget<Switch>(find.byKey(ValueKey('rich-document-check-239'))).value, isTrue);
      await _locate(tester, 1);
      expect(find.byKey(ValueKey('rich-document-title-0')).hitTestable(), findsOneWidget);
      expect(find.byKey(ValueKey('rich-document-code-0')), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
