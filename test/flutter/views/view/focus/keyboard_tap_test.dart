import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final key = ValueKey('keyboard-tap');
  final base = Colors.blue;
  final pressed = Colors.red;

  ElStyle style() => ElStyle(
    width: 120,
    height: 64,
    backgroundColor: base,
    onTap: ElStyle(backgroundColor: pressed),
  );

  Color? colorOf(WidgetTester tester, [Key? target]) =>
      tester.renderObject<ElRenderView>(find.byKey(target ?? key)).committedResolvedStyle.box.backgroundColor;

  Future<void> host(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  Future<void> focus(WidgetTester tester, FocusNode node) async {
    node.requestFocus();
    await tester.pump();
    expect(node.hasPrimaryFocus, isTrue);
  }

  for (final activationKey in [LogicalKeyboardKey.enter, LogicalKeyboardKey.numpadEnter, LogicalKeyboardKey.space]) {
    testWidgets('普通 ElView 无键盘回调时也响应按压样式：${activationKey.keyLabel}', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      var builds = 0;
      await host(
        tester,
        ElView(
          key: key,
          focusNode: node,
          style: style(),
          child: Builder(
            builder: (_) {
              builds++;
              return Text('按压');
            },
          ),
        ),
      );
      await focus(tester, node);
      expect(colorOf(tester), base);
      await tester.sendKeyDownEvent(activationKey);
      await tester.pump();
      expect(colorOf(tester), pressed);
      await tester.sendKeyRepeatEvent(activationKey);
      await tester.pump();
      expect(colorOf(tester), pressed);
      await tester.sendKeyUpEvent(activationKey);
      await tester.pump();
      expect(colorOf(tester), base);
      expect(builds, 1, reason: '按压样式由 ElView 内部处理，不重建内容');
    });
  }

  testWidgets('只声明焦点变体时创建的内部焦点节点也能驱动 onTap', (tester) async {
    await host(
      tester,
      ElView(
        key: key,
        style: style().merge(ElStyle(onFocusVisible: ElStyle(opacity: 0.8))),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.renderObject<ElRenderView>(find.byKey(key)).committedResolvedStyle.box.opacity, 0.8);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(colorOf(tester), pressed);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(colorOf(tester), base);
  });

  testWidgets('只更新样式，不合成点击或吞掉用户未消费的键盘事件', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    var taps = 0;
    final phases = <ElEventPhase>[];
    await host(
      tester,
      ElView(
        key: key,
        focusNode: node,
        style: style(),
        event: ElEvent(onTap: (_) => taps++, onKeyDown: (event) => phases.add(event.phase)),
      ),
    );
    await focus(tester, node);
    expect(await tester.sendKeyDownEvent(LogicalKeyboardKey.enter), isFalse);
    await tester.pump();
    expect(colorOf(tester), pressed);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(colorOf(tester), base);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    expect(colorOf(tester), base);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    expect(taps, 0);
    expect(phases, [ElEventPhase.keyDown, ElEventPhase.keyDown]);
  });

  testWidgets('按住时重建并替换事件闭包，释放仍退出按压态', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    Widget view(String label) => ElView(
      key: key,
      focusNode: node,
      style: style(),
      event: ElEvent(onKeyDown: (_) {}),
      child: label,
    );
    await host(tester, view('之前'));
    await focus(tester, node);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(colorOf(tester), pressed);
    await host(tester, view('之后'));
    expect(colorOf(tester), pressed);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(colorOf(tester), base);
  });

  testWidgets('多个激活键同时按住，全部释放后才恢复；Esc 取消本轮反馈', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await host(tester, ElView(key: key, focusNode: node, style: style()));
    await focus(tester, node);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(colorOf(tester), pressed);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(colorOf(tester), base);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(colorOf(tester), base);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
  });

  testWidgets('失焦立即清除，重新聚焦后旧按键释放不会恢复按压态', (tester) async {
    final node = FocusNode();
    final other = FocusNode();
    addTearDown(node.dispose);
    addTearDown(other.dispose);
    await host(
      tester,
      Row(
        children: [
          ElView(key: key, focusNode: node, style: style()),
          ElView(focusNode: other),
        ],
      ),
    );
    await focus(tester, node);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(colorOf(tester), pressed);
    await focus(tester, other);
    expect(colorOf(tester), base);
    await focus(tester, node);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(colorOf(tester), base);
  });

  testWidgets('按住时禁用或卸载会清除反馈，不向下一次挂载泄漏', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    Widget view(bool disabled) => ElView(
      key: key,
      focusNode: node,
      style: style(),
      event: ElEvent(disabled: disabled),
    );
    await host(tester, view(false));
    await focus(tester, node);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(colorOf(tester), pressed);
    await host(tester, view(true));
    expect(colorOf(tester), base);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await host(tester, view(false));
    await focus(tester, node);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await host(tester, SizedBox());
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await host(tester, view(false));
    expect(colorOf(tester), base);
    expect(tester.takeException(), isNull);
  });

  for (final releaseKeyboardFirst in [true, false]) {
    testWidgets('指针与键盘共用按压态，单方释放不清除另一方：$releaseKeyboardFirst', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await host(tester, ElView(key: key, focusNode: node, style: style()));
      await focus(tester, node);
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)), kind: .mouse);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(colorOf(tester), pressed);
      if (releaseKeyboardFirst) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      } else {
        await gesture.up();
      }
      await tester.pump();
      expect(colorOf(tester), pressed);
      if (releaseKeyboardFirst) {
        await gesture.up();
      } else {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      }
      await tester.pump();
      expect(colorOf(tester), base);
    });
  }

  testWidgets('键盘事件冒泡时，只给拥有主焦点的 ElView 应用按压态', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    final parentKey = ValueKey('keyboard-tap-parent');
    await host(
      tester,
      ElView(
        key: parentKey,
        style: style(),
        child: ElView(key: key, focusNode: node, style: style()),
      ),
    );
    await focus(tester, node);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(colorOf(tester), pressed);
    expect(colorOf(tester, parentKey), base);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(colorOf(tester), base);
  });
}
