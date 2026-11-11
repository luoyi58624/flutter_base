import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final key = ValueKey('key-repeat');

  FocusNode focusNode() {
    final node = FocusNode();
    addTearDown(node.dispose);
    return node;
  }

  Future<void> host(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  Widget button(FocusNode node, VoidCallback onPressed, {ElEvent? event, bool disabled = false}) => ElButtonView(
    key: key,
    focusNode: node,
    onPressed: onPressed,
    disabled: disabled,
    event: event,
    style: ElStyle(
      width: 120,
      height: 60,
      backgroundColor: Colors.blue,
      onTap: ElStyle(backgroundColor: Colors.red),
    ),
    child: '重复触发',
  );

  Future<void> focus(WidgetTester tester, FocusNode node) async {
    node.requestFocus();
    await tester.pump();
    expect(node.hasPrimaryFocus, isTrue);
  }

  Color? colorOf(WidgetTester tester) =>
      tester.renderObject<ElRenderView>(find.byKey(key)).committedResolvedStyle.box.backgroundColor;

  test('旧版重复间隔字段仍支持复制、合并和清空', () {
    final defaults = ElEventConfig();
    final custom = ElEventConfig(keyRepeatInterval: Duration(milliseconds: 40));
    expect(defaults.keyRepeatInterval, Duration(milliseconds: 100));
    expect(defaults.merge(custom).keyRepeatInterval, Duration(milliseconds: 40));
    expect(custom.merge(defaults).keyRepeatInterval, Duration(milliseconds: 40));
    expect(defaults.withFallback(custom).keyRepeatInterval, Duration(milliseconds: 40));
    expect(custom.copyWith().keyRepeatInterval, Duration(milliseconds: 40));
    expect(custom.copyWith(keyRepeatInterval: Duration.zero).keyRepeatInterval, Duration.zero);
    expect(custom.copyWith(keyRepeatInterval: null).keyRepeatInterval, Duration(milliseconds: 100));
    expect(custom, ElEventConfig(keyRepeatInterval: Duration(milliseconds: 40)));
    expect(custom, isNot(defaults));
    expect(() => ElEventConfig(keyRepeatInterval: Duration(milliseconds: -1)), throwsAssertionError);
  });

  testWidgets('每个 Flutter 重复事件即时激活，松开恢复样式', (tester) async {
    final node = focusNode();
    var taps = 0;
    await host(
      tester,
      button(
        node,
        () => taps++,
        event: ElEvent(config: ElEventConfig(keyRepeatInterval: Duration(seconds: 1))),
      ),
    );
    await focus(tester, node);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    expect(taps, 1);
    await tester.pump();
    expect(colorOf(tester), Colors.red);

    for (var count = 2; count <= 4; count++) {
      expect(await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter), isTrue);
      expect(taps, count);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 4);
    expect(colorOf(tester), Colors.blue);
  });

  testWidgets('鼠标与键盘可以分别激活按钮', (tester) async {
    final node = focusNode();
    var taps = 0;
    await host(tester, button(node, () => taps++));
    await focus(tester, node);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.tap(find.byKey(key), kind: .mouse);
    expect(taps, 2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    expect(taps, 3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
  });

  testWidgets('子节点的重复键和父节点的回退回调各执行一次', (tester) async {
    final node = focusNode();
    final calls = <(String, ElEventPhase)>[];
    await host(
      tester,
      ElView(
        event: ElEvent(onKeyDown: (event) => calls.add(('parent', event.phase))),
        child: ElView(
          focusNode: node,
          event: ElEvent(onKeyRepeat: (event) => calls.add(('child', event.phase))),
        ),
      ),
    );
    await focus(tester, node);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    expect(calls, [
      ('parent', ElEventPhase.keyDown),
      ('child', ElEventPhase.keyRepeat),
      ('parent', ElEventPhase.keyRepeat),
      ('child', ElEventPhase.keyRepeat),
      ('parent', ElEventPhase.keyRepeat),
    ]);
  });

  testWidgets('重复键的回退回调可以消费并停止冒泡', (tester) async {
    final node = focusNode();
    var children = 0;
    var parents = 0;
    await host(
      tester,
      ElView(
        event: ElEvent(onKeyDown: (_) => parents++),
        child: ElView(
          focusNode: node,
          event: ElEvent(
            onKeyDown: (event) {
              children++;
              event
                ..preventDefault()
                ..stopPropagation();
            },
          ),
        ),
      ),
    );
    await focus(tester, node);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    expect(await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter), isTrue);
    expect(children, 2);
    expect(parents, 0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
  });

  testWidgets('同构重建后的重复键执行最新回调', (tester) async {
    final node = focusNode();
    var taps = 0;
    await host(tester, button(node, () => taps++));
    await focus(tester, node);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await host(tester, button(node, () => taps += 10));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    expect(taps, 11);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
  });
}
