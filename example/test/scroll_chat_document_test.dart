import 'package:example/src/pages/examples/scroll_examples/chat.dart';
import 'package:example/src/pages/examples/scroll_examples/rich_document.dart';
import 'package:example/src/pages/examples/scroll_examples/scroll_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
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

ScrollPosition _chatPosition(WidgetTester tester, SliverExampleMode mode) =>
    tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!.position;

Future<void> _expectStreamContentUpdate(WidgetTester tester, SliverExampleMode mode, int step) async {
  final body = find
      .byWidgetPredicate((widget) => widget is Text && (widget.data?.startsWith('小林的滚动记录正在整理。') ?? false))
      .hitTestable();
  final row = find.ancestor(
    of: body,
    matching: find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_OfficialChatRow'),
  );
  final time = find.descendant(
    of: row,
    matching: find.byWidgetPredicate(
      (widget) => widget is Text && RegExp(r'^\d{2}:\d{2}$').hasMatch(widget.data ?? ''),
    ),
  );
  Element selectorFor(Finder leaf) {
    Element? result;
    tester.element(leaf).visitAncestorElements((ancestor) {
      if (ancestor.widget is! ElListenableBuilder) return true;
      result = ancestor;
      return false;
    });
    return result!;
  }

  final rowElement = tester.element(row);
  final bodySelector = selectorFor(body);
  final timeSelector = selectorFor(time);
  final viewportWidget = tester.widget(find.byType(CustomScrollView));
  final sliver = mode == .official ? find.byType(SliverList) : find.byType(ElSliverRecyclerList);
  final sliverWidget = tester.widget(sliver);
  final rowWidget = tester.widget(row);
  final bodyElement = tester.element(body);
  final bodyRender = tester.renderObject(body);
  final timeWidget = tester.widget(time);
  final timeElement = tester.element(time);
  final count = _chatCount(tester);
  var rowBuilds = 0;
  var bodyBuilds = 0;
  var timeBuilds = 0;
  final previous = debugOnRebuildDirtyWidget;
  debugOnRebuildDirtyWidget = (element, builtOnce) {
    previous?.call(element, builtOnce);
    if (identical(element, rowElement)) rowBuilds++;
    if (identical(element, bodySelector)) bodyBuilds++;
    if (identical(element, timeSelector)) timeBuilds++;
  };
  try {
    await _tap(tester, 'chat-live-step');
  } finally {
    debugOnRebuildDirtyWidget = previous;
  }
  expect(tester.widget(find.byType(CustomScrollView)), same(viewportWidget));
  expect(tester.widget(sliver), same(sliverWidget));
  expect(tester.widget(row), same(rowWidget));
  expect(tester.element(row), same(rowElement));
  expect(tester.element(body), same(bodyElement));
  expect(tester.renderObject(body), same(bodyRender));
  expect(tester.widget<Text>(body).data, contains(step == 7 ? '记录结束。' : '第 $step 段：'));
  expect(tester.widget(time), same(timeWidget));
  expect(tester.element(time), same(timeElement));
  expect(rowBuilds, 0, reason: '纯正文变化不重新构建已绑定消息行。');
  expect(bodyBuilds, greaterThan(0));
  expect(timeBuilds, 0, reason: '消息时间未变，不应调度时间选择器。');
  expect(_chatCount(tester), count);
  expect(_chatPosition(tester, mode).extentBefore, closeTo(0, .5));
  expect(tester.takeException(), isNull);
}

Future<void> _locate(WidgetTester tester, int section) async {
  await _tap(tester, 'rich-document-contents');
  await tester.enterText(find.byKey(ValueKey('rich-document-search')), '$section');
  await tester.pumpAndSettle();
  await _tap(tester, 'rich-document-directory-${section - 1}');
}

void main() {
  for (final mode in SliverExampleMode.values) {
    testWidgets('实时群聊 ${mode.label} 保留阅读锚点，并在末尾跟随同一条流式消息', (tester) async {
      await _open(tester, RecyclerLiveChatPage());
      if (mode != .recycler) {
        await _tap(tester, 'chat-menu');
        await _tap(tester, 'chat-mode-${mode.name}');
      }
      final position = _chatPosition(tester, mode);
      position.jumpTo(760);
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
      expect(position.extentBefore, closeTo(0, .5));
      await _tap(tester, 'chat-live-reset');
      expect(_chatCount(tester), '10000 条');
      expect(find.text('并发脚本 0 / 8'), findsOneWidget);
      expect(find.textContaining('消息 #10000：').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('实时群聊 ${mode.label} 流式正文只更新叶子并保留时间和列表配置', (tester) async {
      await _open(tester, RecyclerLiveChatPage());
      if (mode != .recycler) {
        await _tap(tester, 'chat-menu');
        await _tap(tester, 'chat-mode-${mode.name}');
      }
      for (var step = 0; step < 8; step++) {
        if ([1, 3, 6, 7].contains(step)) {
          await _expectStreamContentUpdate(tester, mode, step);
        } else {
          await _tap(tester, 'chat-live-step');
        }
      }
      expect(_chatCount(tester), '10103 条');
      await _tap(tester, 'chat-live-reset');
      await _tap(tester, 'chat-live-step');
      await _expectStreamContentUpdate(tester, mode, 1);
      expect(find.textContaining('记录结束。').hitTestable(), findsNothing, reason: '复位后旧槽位的内容不能污染新消息绑定。');
      await tester.pumpWidget(SizedBox.shrink());
      await tester.pump();
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
    for (final mode in SliverExampleMode.values.reversed) {
      {
        await _tap(tester, 'comparison-mode-menu');
        await _tap(tester, 'comparison-mode-${mode.name}');
      }
      expect(last.hitTestable(), findsNothing);
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
