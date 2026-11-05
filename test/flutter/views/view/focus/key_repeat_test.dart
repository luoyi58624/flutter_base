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

  test('重复间隔默认 100ms，支持覆盖、合并、清空与相等性', () {
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
    expect(defaults.hasSameTapConfiguration(custom), isTrue, reason: '键盘间隔不打断指针会话');
    expect(() => ElEventConfig(keyRepeatInterval: Duration(milliseconds: -1)), throwsAssertionError);
  });

  testWidgets('默认首按立即触发，100ms 内重复事件被丢弃且保持消费状态，松开实时恢复', (tester) async {
    final node = focusNode();
    var taps = 0;
    await host(tester, button(node, () => taps++));
    await focus(tester, node);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    expect(taps, 1);
    await tester.pump();
    expect(colorOf(tester), Colors.red);
    expect(await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter), isTrue);
    expect(taps, 1);
    await tester.pump(Duration(milliseconds: 99));
    expect(await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter), isTrue);
    expect(taps, 1);
    await tester.pump(Duration(milliseconds: 1));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    expect(taps, 2);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    expect(taps, 2);
    await tester.pump(Duration(milliseconds: 500));
    expect(taps, 2, reason: '跳过的事件不排队，也不会自行补发');
    expect(colorOf(tester), Colors.red);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 2);
    expect(colorOf(tester), Colors.blue);
  });

  for (final interval in [Duration(milliseconds: 40), Duration(milliseconds: 200)]) {
    testWidgets('自定义重复间隔按边界生效：$interval', (tester) async {
      final node = focusNode();
      var taps = 0;
      await host(
        tester,
        button(
          node,
          () => taps++,
          event: ElEvent(config: ElEventConfig(keyRepeatInterval: interval)),
        ),
      );
      await focus(tester, node);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.pump(interval - Duration(milliseconds: 1));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      expect(taps, 1);
      await tester.pump(Duration(milliseconds: 1));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      expect(taps, 2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    });
  }

  testWidgets('零间隔不限制连续重复，普通点击与新的按下也不等待', (tester) async {
    final node = focusNode();
    var taps = 0;
    await host(
      tester,
      button(
        node,
        () => taps++,
        event: ElEvent(config: ElEventConfig(keyRepeatInterval: Duration.zero)),
      ),
    );
    await focus(tester, node);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    for (var index = 0; index < 4; index++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    }
    expect(taps, 5);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    expect(taps, 6);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
  });

  testWidgets('默认窗口不会限制鼠标点击或下一次实际按下', (tester) async {
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

  testWidgets('同一节点不同物理按键分别限流，非激活键的重复回调也生效', (tester) async {
    final node = focusNode();
    final calls = <LogicalKeyboardKey>[];
    await host(
      tester,
      ElView(
        focusNode: node,
        event: ElEvent(
          onKeyDown: (event) {
            calls.add(event.logicalKey!);
            event.preventDefault();
          },
        ),
      ),
    );
    await focus(tester, node);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump(Duration(milliseconds: 50));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(Duration(milliseconds: 50));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    expect(calls, [LogicalKeyboardKey.enter, LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.enter]);
    await tester.pump(Duration(milliseconds: 50));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    expect(calls.last, LogicalKeyboardKey.arrowDown);
    expect(calls.length, 4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
  });

  testWidgets('冒泡节点各自使用本地配置，子节点的零间隔不被祖先覆盖', (tester) async {
    final node = focusNode();
    var childCalls = 0;
    var parentCalls = 0;
    await host(
      tester,
      ElView(
        event: ElEvent(
          config: ElEventConfig(keyRepeatInterval: Duration(milliseconds: 200)),
          onKeyDown: (_) => parentCalls++,
        ),
        child: ElView(
          focusNode: node,
          event: ElEvent(
            config: ElEventConfig(keyRepeatInterval: Duration.zero),
            onKeyDown: (_) => childCalls++,
          ),
        ),
      ),
    );
    await focus(tester, node);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    for (var index = 0; index < 2; index++) {
      await tester.pump(Duration(milliseconds: 20));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    }
    expect(childCalls, 3);
    expect(parentCalls, 1);
    await tester.pump(Duration(milliseconds: 160));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    expect(childCalls, 4);
    expect(parentCalls, 2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
  });

  testWidgets('只声明 onKeyRepeat 时，从第一次实际回调开始计算间隔', (tester) async {
    final node = focusNode();
    var repeats = 0;
    await host(
      tester,
      ElView(
        focusNode: node,
        event: ElEvent(onKeyRepeat: (_) => repeats++),
      ),
    );
    await focus(tester, node);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    expect(repeats, 0);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    expect(repeats, 1);
    await tester.pump(Duration(milliseconds: 99));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    expect(repeats, 1);
    await tester.pump(Duration(milliseconds: 1));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    expect(repeats, 2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
  });

  testWidgets('跳过的重复键仍保留停止冒泡和消费结果', (tester) async {
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
    expect(children, 1);
    expect(parents, 0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
  });

  testWidgets('同构重建不重置窗口，后续执行最新回调且按当前配置判断间隔', (tester) async {
    final node = focusNode();
    var taps = 0;
    await host(tester, button(node, () => taps++));
    await focus(tester, node);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump(Duration(milliseconds: 30));
    await host(tester, button(node, () => taps += 10));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    expect(taps, 1);
    await tester.pump(Duration(milliseconds: 10));
    await host(
      tester,
      button(
        node,
        () => taps += 10,
        event: ElEvent(config: ElEventConfig(keyRepeatInterval: Duration(milliseconds: 40))),
      ),
    );
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    expect(taps, 11);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
  });

  for (final reset in ['escape', 'blur', 'disabled', 'unmount']) {
    testWidgets('$reset 后清理旧窗口，不遗留重复触发限制', (tester) async {
      final node = focusNode();
      var taps = 0;
      await host(tester, button(node, () => taps++));
      await focus(tester, node);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.pump(Duration(milliseconds: 20));
      if (reset == 'escape') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else if (reset == 'blur') {
        node.unfocus();
        await tester.pump();
      } else {
        await host(tester, reset == 'disabled' ? button(node, () => taps++, disabled: true) : SizedBox());
        await host(tester, button(node, () => taps++));
      }
      await focus(tester, node);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      expect(taps, 2);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      expect(taps, 2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    });
  }
}
