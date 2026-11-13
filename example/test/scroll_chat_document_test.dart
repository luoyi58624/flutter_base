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
  // 复用用例显式选择 recycler，页面默认模式另行验证。
  if (page is! RecyclerRichDocumentPage) {
    tester.widget<PopupMenuButton<Object>>(find.byKey(ValueKey('chat-menu'))).onSelected!(SliverExampleMode.recycler);
    await tester.pumpAndSettle();
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

String _chatCount(WidgetTester tester) => tester.widget<Text>(find.byKey(ValueKey('chat-count'))).data!;

Finder _chatViewport() => find.descendant(
  of: find.byType(ElChatScroll),
  matching: find.byWidgetPredicate((widget) => widget is CustomScrollView && widget.reverse),
);

ScrollPosition _chatPosition(WidgetTester tester) =>
    tester.widget<CustomScrollView>(_chatViewport()).controller!.position;

Finder _visibleMessage(WidgetTester tester) {
  final viewport = tester.getRect(_chatViewport());
  final messages = find.byWidgetPredicate((widget) => widget is Text && (widget.data?.startsWith('消息 #') ?? false));
  // 拖动活动会忽略列表子项的命中，用实际坐标判断消息是否在视口内。
  Element? visible;
  var distance = double.infinity;
  for (final element in messages.evaluate()) {
    final text = find.byWidget(element.widget);
    final center = tester.getCenter(text);
    final distanceToCenter = (center.dy - viewport.center.dy).abs();
    if (center.isFinite && viewport.contains(center) && distanceToCenter < distance) {
      visible = element;
      distance = distanceToCenter;
    }
  }
  return find.text((visible!.widget as Text).data!);
}

Future<void> _expectStreamContentUpdate(WidgetTester tester, SliverExampleMode mode, int step) async {
  final body = find
      .byWidgetPredicate((widget) => widget is Text && (widget.data?.startsWith('小林的滚动记录正在整理。') ?? false))
      .hitTestable();
  final row = find.ancestor(
    of: body,
    matching: find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_ChatMessageRow'),
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
  final play = find.byKey(ValueKey('chat-live-play'));
  final advance = find.byKey(ValueKey('chat-live-step'));
  final reset = find.byKey(ValueKey('chat-live-reset'));
  final playWidget = tester.widget(play);
  final advanceWidget = tester.widget(advance);
  final resetWidget = tester.widget(reset);
  final playSelector = selectorFor(play);
  final advanceSelector = selectorFor(advance);
  final viewportWidget = tester.widget(_chatViewport());
  final sliver = mode == .official
      ? find.byType(SliverList)
      : find.descendant(of: _chatViewport(), matching: find.byWidgetPredicate((widget) => widget is ElSliverList));
  final sliverWidget = tester.widget(sliver);
  final rowWidget = tester.widget(row);
  final bodyElement = tester.element(body);
  final bodyRender = tester.renderObject(body);
  final timeWidget = tester.widget(time);
  final timeElement = tester.element(time);
  final count = _chatCount(tester);
  var rowBuilds = 0;
  var playBuilds = 0;
  var advanceBuilds = 0;
  final previous = debugOnRebuildDirtyWidget;
  debugOnRebuildDirtyWidget = (element, builtOnce) {
    previous?.call(element, builtOnce);
    if (identical(element, rowElement)) rowBuilds++;
    if (identical(element, playSelector)) playBuilds++;
    if (identical(element, advanceSelector)) advanceBuilds++;
  };
  try {
    await _tap(tester, 'chat-live-step');
  } finally {
    debugOnRebuildDirtyWidget = previous;
  }
  expect(tester.widget(_chatViewport()), same(viewportWidget));
  expect(tester.widget(sliver), same(sliverWidget));
  expect(tester.widget(row), same(rowWidget));
  expect(tester.element(row), same(rowElement));
  expect(tester.element(body), same(bodyElement));
  expect(tester.renderObject(body), same(bodyRender));
  expect(tester.widget<Text>(body).data, contains(step == 7 ? '记录结束。' : '第 $step 段：'));
  expect(tester.widget(time), same(timeWidget));
  expect(tester.element(time), same(timeElement));
  expect(rowBuilds, 0, reason: '纯正文变化不重新构建已绑定消息行。');
  expect(tester.widget(reset), same(resetWidget), reason: '正文增长不改变复位动作。');
  if (step == 7) {
    expect(playBuilds, 1);
    expect(advanceBuilds, 1);
    expect(tester.widget<IconButton>(play).onPressed, isNull);
    expect(tester.widget<TextButton>(advance).onPressed, isNull);
  } else {
    expect(tester.widget(play), same(playWidget));
    expect(tester.widget(advance), same(advanceWidget));
    expect(playBuilds, 0, reason: '播放状态未变，不应因正文增长重新构建按钮配置。');
    expect(advanceBuilds, 0);
  }
  expect(_chatCount(tester), count);
  expect(_chatPosition(tester).extentBefore, closeTo(0, .5));
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
    testWidgets('实时群聊 ${mode.label} 插入第一批消息后仍可用同一指针拖动', (tester) async {
      await _open(tester, RecyclerLiveChatPage());
      tester.widget<PopupMenuButton<Object>>(find.byKey(ValueKey('chat-menu'))).onSelected!(mode);
      await tester.pumpAndSettle();
      final position = _chatPosition(tester);
      position.jumpTo(4800);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('chat-live-play')));
      await tester.pump();

      final list = _chatViewport();
      final drag = await tester.startGesture(tester.getCenter(list));
      await drag.moveBy(Offset(0, 120));
      await tester.pump(Duration(milliseconds: 200));
      await drag.moveBy(Offset(0, 180));
      await tester.pump(Duration(milliseconds: 230));
      expect(position.activity, isA<DragScrollActivity>());
      final message = _visibleMessage(tester);
      final y = tester.getTopLeft(message).dy;

      await drag.moveBy(Offset(0, 24));
      await tester.pump(Duration(milliseconds: 20));
      expect(_chatCount(tester), '1051 条');
      expect(message, findsOneWidget);
      expect(tester.getTopLeft(message).dy, closeTo(y + 24, .5));
      expect(position.activity, isA<DragScrollActivity>());

      await drag.moveBy(Offset(0, 48));
      await tester.pump();
      expect(tester.getTopLeft(message).dy, closeTo(y + 72, .5));
      await drag.up();
      await _tap(tester, 'chat-live-play');
      expect(tester.takeException(), isNull);
    });

    testWidgets('实时群聊 ${mode.label} 插入第一批消息时保留惯性位移', (tester) async {
      await _open(tester, RecyclerLiveChatPage());
      tester.widget<PopupMenuButton<Object>>(find.byKey(ValueKey('chat-menu'))).onSelected!(mode);
      await tester.pumpAndSettle();
      final position = _chatPosition(tester) as ScrollPositionWithSingleContext;
      position.jumpTo(4800);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('chat-live-play')));
      position.goBallistic(1800);
      await tester.pump();
      for (var i = 0; i < 29; i++) {
        await tester.pump(Duration(milliseconds: 15));
      }

      final message = _visibleMessage(tester);
      final y = tester.getTopLeft(message).dy;
      final pixels = position.pixels;
      double? movement;
      void recordMovement() => movement ??= position.pixels - pixels;
      position.addListener(recordMovement);
      try {
        await tester.pump(Duration(milliseconds: 15));
      } finally {
        position.removeListener(recordMovement);
      }
      expect(_chatCount(tester), '1051 条');
      expect(message.hitTestable(), findsOneWidget);
      expect(movement, greaterThan(0));
      expect(tester.getTopLeft(message).dy, closeTo(y + movement!, .5));
      expect(position.activity, isA<BallisticScrollActivity>());
      expect(position.activity!.velocity, greaterThan(0));

      final nextY = tester.getTopLeft(message).dy;
      await tester.pump(Duration(milliseconds: 30));
      expect(tester.getTopLeft(message).dy, greaterThan(nextY));
      await _tap(tester, 'chat-live-play');
      expect(tester.takeException(), isNull);
    });
  }

  for (final mode in [SliverExampleMode.official, SliverExampleMode.recycler, SliverExampleMode.builder]) {
    testWidgets('实时群聊 ${mode.label} 保留阅读锚点，并在末尾跟随同一条流式消息', (tester) async {
      await _open(tester, RecyclerLiveChatPage());
      if (mode != .recycler) {
        await _tap(tester, 'chat-menu');
        await _tap(tester, 'chat-mode-${mode.name}');
      }
      final position = _chatPosition(tester);
      position.jumpTo(760);
      await tester.pumpAndSettle();
      final message = _visibleMessage(tester);
      final y = tester.getTopLeft(message).dy;

      await _tap(tester, 'chat-live-step');
      expect(_chatCount(tester), '1051 条');
      expect(tester.getTopLeft(message).dy, closeTo(y, .5));
      await _tap(tester, 'chat-live-step');
      expect(_chatCount(tester), '1051 条');
      expect(tester.getTopLeft(message).dy, closeTo(y, .5));
      expect(tester.widget<Text>(find.byKey(ValueKey('chat-unread-count'))).data, '1');

      await _tap(tester, 'chat-menu');
      await _tap(tester, 'chat-latest');
      expect(find.textContaining('第 1 段：').hitTestable(), findsOneWidget);
      await _tap(tester, 'chat-live-step');
      expect(_chatCount(tester), '1052 条');
      expect(find.textContaining('第 2 段：').hitTestable(), findsOneWidget);
      expect(find.text('我在这边也看到最新进度了。').hitTestable(), findsOneWidget);
      expect(position.extentBefore, closeTo(0, .5));
      await _tap(tester, 'chat-live-reset');
      expect(_chatCount(tester), '1000 条');
      expect(find.text('并发脚本 0 / 8'), findsOneWidget);
      expect(find.textContaining('消息 #1000：').hitTestable(), findsOneWidget);
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
      expect(_chatCount(tester), '1103 条');
      await _tap(tester, 'chat-live-reset');
      await _tap(tester, 'chat-live-step');
      await _expectStreamContentUpdate(tester, mode, 1);
      expect(find.textContaining('记录结束。').hitTestable(), findsNothing, reason: '复位后旧槽位的内容不能污染新消息绑定。');
      await tester.pumpWidget(SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('实时群聊靠近末尾时保留拖动，停稳后才跟随新消息', (tester) async {
    await _open(tester, RecyclerLiveChatPage());
    final position = _chatPosition(tester);
    position.jumpTo(32);
    await tester.pumpAndSettle();
    await _tap(tester, 'chat-live-step');
    expect(position.pixels, closeTo(0, .5));
    expect(find.text('小林的滚动记录正在整理。').hitTestable(), findsOneWidget);

    await _tap(tester, 'chat-live-reset');
    final drag = await tester.startGesture(tester.getCenter(_chatViewport()));
    await drag.moveBy(Offset(0, 22));
    await drag.moveBy(Offset(0, 24));
    await tester.pump();
    expect(position.pixels, inExclusiveRange(0, 48));
    final message = _visibleMessage(tester);
    final y = tester.getTopLeft(message).dy;

    tester.widget<TextButton>(find.byKey(ValueKey('chat-live-step'))).onPressed!();
    await tester.pump();
    expect(_chatCount(tester), '1051 条');
    expect(tester.getTopLeft(message).dy, closeTo(y, .5));
    expect(position.activity, isA<DragScrollActivity>());
    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

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
    expect(_chatCount(tester), '1103 条');
    expect(tester.widget<IconButton>(playback).onPressed, isNull);
    expect(tester.widget<TextButton>(find.byKey(ValueKey('chat-live-step'))).onPressed, isNull);
    await _tap(tester, 'chat-live-reset');
    expect(tester.widget<IconButton>(playback).onPressed, isNotNull);
    expect(tester.widget<TextButton>(find.byKey(ValueKey('chat-live-step'))).onPressed, isNotNull);
    await tester.tap(playback);
    await tester.pump();
    await tester.pumpWidget(SizedBox());
    await tester.pump(Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('聊天长列表通过新组件定位消息并发送文字', (tester) async {
    await _open(tester, RecyclerChatPage());
    expect(find.byType(ElChatScroll), findsOneWidget);
    expect(find.byType(ElChatComposer), findsOneWidget);
    await _tap(tester, 'chat-menu');
    await _tap(tester, 'chat-locate');
    expect(find.textContaining('消息 #950：').hitTestable(), findsOneWidget);
    await _tap(tester, 'chat-menu');
    await _tap(tester, 'chat-latest');

    await tester.tap(find.byType(ElEditableView));
    await tester.pumpAndSettle();
    tester.testTextInput.enterText('一条测试消息');
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is ElButton && widget.semanticLabel == '发送'));
    await tester.pumpAndSettle();
    expect(_chatCount(tester), '1001 条');
    expect(find.text('一条测试消息').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('富文本文档常驻和惰性容器均能找到未挂载的小节并保持各节交互状态', (tester) async {
    await _open(tester, RecyclerRichDocumentPage());
    final last = find.byKey(ValueKey('rich-document-title-999'));
    final code = find.byKey(ValueKey('rich-document-code-999'));
    var primed = false;
    for (final mode in SliverExampleMode.values.reversed) {
      {
        await _tap(tester, 'comparison-mode-menu');
        await _tap(tester, 'comparison-mode-${mode.name}');
      }
      expect(last.hitTestable(), findsNothing);
      await _locate(tester, 1000);
      expect(last.hitTestable(), findsOneWidget);
      if (!primed) {
        await _tap(tester, 'rich-document-code-toggle-999');
        expect(code, findsOneWidget);
        await _tap(tester, 'rich-document-check-999');
        primed = true;
      }
      expect(code, findsOneWidget);
      expect(tester.widget<Switch>(find.byKey(ValueKey('rich-document-check-999'))).value, isTrue);
      await _locate(tester, 1);
      expect(find.byKey(ValueKey('rich-document-title-0')).hitTestable(), findsOneWidget);
      expect(find.byKey(ValueKey('rich-document-code-0')), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
