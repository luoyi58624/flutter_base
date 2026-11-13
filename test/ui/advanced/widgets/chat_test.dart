import 'dart:async';

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

class _Location extends ElChatMessage {
  // ignore: prefer_const_constructors_in_immutables
  _Location({required super.id}) : super(isMine: false);
}

Widget _app(Widget child, {double height = 360}) => ElComponentProvider(
  components: el.mobileComponents,
  child: MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: .topCenter,
        child: SizedBox(width: 360, height: height, child: child),
      ),
    ),
  ),
);

ElChatTextMessage _message(int index, {int lines = 1}) =>
    ElChatTextMessage(id: index, isMine: index.isEven, text: '消息 $index${'\n正文' * (lines - 1)}');

Widget _paddedList(BuildContext context, SliverChildBuilderDelegate delegate) => SliverPadding(
  padding: EdgeInsets.symmetric(vertical: 12),
  sliver: SliverList(delegate: delegate),
);

void main() {
  testWidgets('消息方向、默认附件和自定义内容按各自的消息模型渲染', (tester) async {
    ElChatFileMessage? opened;
    await tester.pumpWidget(
      _app(
        ElChatScroll(
          messages: [
            ElChatTextMessage(id: 0, isMine: true, text: '自己的消息'),
            ElChatTextMessage(id: 1, isMine: false, text: '对方的消息'),
            ElChatFileMessage(id: 2, isMine: false, name: '报价单.pdf', size: 2048),
            ElChatImageMessage(id: 3, isMine: true, src: 'assets/missing-chat-image.png', aspectRatio: 4),
            _Location(id: 4),
          ],
          avatarBuilder: (_, message) => message.id == 4 ? Text('自定义头像') : null,
          messageBuilder: (_, message) => message is _Location ? Text('自定义位置') : null,
          onOpenFile: (message) => opened = message,
        ),
        height: 520,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsNWidgets(2));
    expect(tester.getCenter(find.text('自己的消息')).dx, greaterThan(tester.getCenter(find.text('对方的消息')).dx));
    expect(find.text('自定义头像'), findsOneWidget);
    expect(find.text('自定义位置'), findsOneWidget);
    expect(find.byType(ElImagePreview), findsOneWidget);
    expect(find.text('2.00KB'), findsOneWidget);
    await tester.tap(find.text('报价单.pdf'));
    expect(opened?.id, 2);
    expect(tester.takeException(), isNull);
  });

  for (final custom in [false, true]) {
    testWidgets('聊天按 ID 定位未构建消息，处理重叠请求和回到末尾（自定义 Sliver $custom）', (tester) async {
      final controller = ElChatScrollController();
      final messages = List.generate(180, (i) => _message(i, lines: i % 4 + 1));
      final scroll = ScrollController();
      addTearDown(controller.dispose);
      addTearDown(scroll.dispose);
      expect(await controller.jumpToMessage(100), isFalse);
      await tester.pumpWidget(
        _app(
          ElChatScroll(
            messages: messages,
            controller: controller,
            scrollController: scroll,
            sliverBuilder: custom ? _paddedList : null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.isAttached, isTrue);
      expect(controller.atLatest.value, isTrue);
      expect(await controller.jumpToMessage('missing'), isFalse);
      final superseded = controller.jumpToMessage(4);
      final jump = controller.jumpToMessage(120, alignment: 0);
      await tester.pumpAndSettle(Duration(milliseconds: 16));
      expect(await superseded, isFalse);
      expect(await jump, isTrue);
      final target = find.textContaining('消息 120');
      expect(target.hitTestable(), findsOneWidget);
      final viewport = tester.getRect(find.byType(ElChatScroll));
      expect(tester.getTopLeft(target).dy - viewport.top, inInclusiveRange(0, 48));
      expect(controller.atLatest.value, isFalse);

      final latest = controller.animateToLatest();
      await tester.pumpAndSettle();
      expect(await latest, isTrue);
      expect(controller.atLatest.value, isTrue);
      expect(scroll.offset, scroll.position.minScrollExtent);

      final detached = controller.jumpToMessage(30);
      await tester.pumpWidget(SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(await detached, isFalse);
      expect(controller.isAttached, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('聊天历史加载合并并发触发，失败后允许重试', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final requests = <Completer<void>>[];
    await tester.pumpWidget(
      _app(
        ElChatScroll(
          messages: List.generate(28, _message),
          scrollController: scroll,
          onLoadEarlier: () {
            final request = Completer<void>();
            requests.add(request);
            return request.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    for (var i = 0; i < 3 && requests.isEmpty; i++) {
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
    expect(requests, hasLength(1));
    expect(find.text('正在加载历史消息', skipOffstage: false), findsOneWidget);
    await tester.pump(Duration(seconds: 1));
    expect(requests, hasLength(1));

    requests.single.completeError(StateError('离线'));
    await tester.pumpAndSettle();
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final retry = find.text('重试加载历史消息');
    await tester.tap(retry.hitTestable());
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    requests.last.complete();
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('聊天收到大量变高消息、清除历史或输入区改变高度时保留阅读位置', (tester) async {
    final controller = ElChatScrollController();
    addTearDown(controller.dispose);
    final messages = List.generate(1000, (i) => _message(i, lines: i % 5 + 1));
    Widget page(List<ElChatMessage> data, double height) => _app(
      ElChatScroll(
        messages: data,
        controller: controller,
        messageBuilder: (_, message) => message is ElChatTextMessage ? Text(message.text) : null,
      ),
      height: height,
    );

    await tester.pumpWidget(page(messages, 430));
    await tester.pumpAndSettle();
    final jump = controller.jumpToMessage(700);
    await tester.pumpAndSettle();
    expect(await jump, isTrue);
    final reader = find.textContaining('消息 700');
    expect(reader.hitTestable(), findsOneWidget);
    final before = tester.getTopLeft(reader).dy;

    final updated = [
      ...messages.skip(80),
      ...List.generate(80, (index) => _message(1000 + index, lines: index % 7 + 1)),
    ];
    await tester.pumpWidget(page(updated, 430));
    await tester.pumpAndSettle();
    expect(reader.hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(reader).dy, closeTo(before, .5));

    await tester.pumpWidget(page(updated, 355));
    await tester.pumpAndSettle();
    expect(reader.hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(reader).dy, closeTo(before, .5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('聊天面板阻止重复发送，并保留失败或发送期间新编辑的草稿', (tester) async {
    final draft = ValueNotifier('  第一条  ');
    addTearDown(draft.dispose);
    final sends = <(String, Completer<bool>)>[];
    await tester.pumpWidget(
      _app(
        ElChatComposer(
          modelValue: draft,
          actions: [Text('附件工具')],
          panel: Text('展开区域'),
          onSend: (text) {
            final result = Completer<bool>();
            sends.add((text, result));
            return result.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('附件工具'), findsOneWidget);
    expect(find.text('展开区域'), findsOneWidget);
    final send = find.byWidgetPredicate((widget) => widget is ElButton && widget.semanticLabel == '发送');
    await tester.tap(send);
    await tester.pump();
    await tester.tap(send);
    expect(sends, hasLength(1));
    expect(sends.first.$1, '第一条');
    sends.first.$2.complete(false);
    await tester.pumpAndSettle();
    expect(draft.value, '  第一条  ');

    await tester.tap(send);
    await tester.pump();
    draft.value = '第二条';
    await tester.pump();
    sends.last.$2.complete(true);
    await tester.pumpAndSettle();
    expect(draft.value, '第二条');

    await tester.tap(send);
    await tester.pump();
    sends.last.$2.complete(true);
    await tester.pumpAndSettle();
    expect(draft.value, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('聊天面板桌面 Enter 发送，Shift+Enter 换行并保留 IME 组字', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final draft = ValueNotifier('你好');
    final focus = FocusNode();
    addTearDown(draft.dispose);
    addTearDown(focus.dispose);
    final sent = <String>[];
    await tester.pumpWidget(
      _app(
        ElChatComposer(
          modelValue: draft,
          focusNode: focus,
          onSend: (text) {
            sent.add(text);
            return true;
          },
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();
    expect(draft.value, contains('\n'));
    expect(sent, isEmpty);

    final input = tester.widget<ElEditableView>(find.byType(ElEditableView));
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();
    expect(input.controller!.composing.isCollapsed, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent, isEmpty);
    tester.testTextInput.updateEditingValue(
      TextEditingValue(text: '你好', selection: TextSelection.collapsed(offset: 2)),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(sent, ['你好']);
    expect(draft.value, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
