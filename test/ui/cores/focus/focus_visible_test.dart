import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// `onFocusVisible`（CSS `:focus-visible`）——聚焦方式敏感的焦点指示变体。
///
/// 口径：只认「本次聚焦来源」——Tab / Shift+Tab / 方向键 / Home / End /
/// PageUp / PageDown / F10 等导航键换焦才点亮；指针（鼠标/触控板/触摸/手写笔）
/// 按下不点亮，且会立刻收起已有的环；程序化 requestFocus、窗口恢复、生命周期
/// 聚焦不点亮。与全局 [FocusManager.highlightMode] 无关（桌面恒为 traditional）。
void main() {
  const base = Color(0xFFFFFFFF);
  const focusBg = Color(0xFF16A34A); // onFocus 绿
  const ringBg = Color(0xFFEF4444); // onFocusVisible 红（应压过绿）

  /// Tab 默认遍历由 WidgetsApp 的快捷键分发，需要真实应用骨架。
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)),
      ),
    );
  }

  ElView focusBox(FocusNode node, {Key? key}) {
    return ElView(
      key: key,
      focusNode: node,
      style: const ElStyle(
        width: 80,
        height: 36,
        bgColor: base,
        onFocus: ElStyle(bgColor: focusBg),
        onFocusVisible: ElStyle(bgColor: ringBg),
      ),
    );
  }

  Color? bgOf(WidgetTester tester, Key key) =>
      tester.renderObject<ElRenderView>(find.byKey(key)).committedResolvedStyle.box.bgColor;

  Future<void> pressKey(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  /// 每个用例结束都把高亮策略恢复成 `automatic`，避免用例互相污染。
  void resetHighlightStrategy() {
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
  }

  testWidgets('Tab 键盘聚焦 → onFocusVisible 命中并压过 onFocus', (tester) async {
    const key = ValueKey('kb');
    final node = FocusNode(debugLabel: 'kb');
    addTearDown(node.dispose);

    await pump(tester, focusBox(node, key: key));
    expect(bgOf(tester, key), base);

    await pressKey(tester, LogicalKeyboardKey.tab);
    expect(node.hasPrimaryFocus, isTrue);
    expect(bgOf(tester, key), ringBg, reason: '键盘聚焦：focusVisible 优先级 > focus');
  });

  testWidgets('桌面默认形态：鼠标按下聚焦只命中 onFocus，不出焦点环', (tester) async {
    const key = ValueKey('ptr-default');
    final node = FocusNode(debugLabel: 'ptr-default');
    addTearDown(node.dispose);
    resetHighlightStrategy();
    // 真机桌面（windows/linux/macos）的默认高亮形态恒为 traditional，鼠标按下
    // 不会改变它——这正是旧实现恒出环的现场。测试宿主默认按 android 跑，
    // 这里显式把平台设成桌面，复现真实运行时。
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await pump(tester, focusBox(node, key: key));
      expect(
        FocusManager.instance.highlightMode,
        FocusHighlightMode.traditional,
        reason: '桌面默认高亮形态（旧实现因此恒出环）',
      );

      await tester.tap(find.byKey(key), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional, reason: '鼠标按下不改变桌面高亮形态');
      expect(node.hasPrimaryFocus, isTrue);
      expect(bgOf(tester, key), focusBg, reason: '指针聚焦不是键盘交互，不应点亮 focusVisible');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('传统高亮形态下指针聚焦仍不出焦点环', (tester) async {
    const key = ValueKey('ptr-traditional');
    final node = FocusNode(debugLabel: 'ptr-traditional');
    addTearDown(node.dispose);
    // 反证：把形态钉在 traditional 是为了证明"指针聚焦不看高亮形态"，断言方向
    // 是不出环（negative），不是靠开关构造通过条件。
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    resetHighlightStrategy();

    await pump(tester, focusBox(node, key: key));
    await tester.tap(find.byKey(key), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();

    expect(node.hasPrimaryFocus, isTrue);
    expect(bgOf(tester, key), focusBg, reason: '判定按聚焦来源，不按高亮形态');
  });

  testWidgets('程序聚焦 requestFocus 不受 touch / traditional 影响，不出焦点环', (tester) async {
    const key = ValueKey('programmatic');
    final node = FocusNode(debugLabel: 'programmatic');
    addTearDown(node.dispose);
    resetHighlightStrategy();

    await pump(tester, focusBox(node, key: key));

    // 反证：touch / traditional 两种形态各跑一遍，都是为了证明"程序聚焦一律不亮"
    // （断言方向是 negative），不是靠开关凑绿。
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
    node.requestFocus();
    await tester.pump();
    expect(node.hasPrimaryFocus, isTrue);
    expect(bgOf(tester, key), focusBg, reason: '程序聚焦不自行开启焦点指示');

    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    await tester.pump();
    expect(bgOf(tester, key), focusBg, reason: '切到 traditional 也不得把程序聚焦补亮');
  });

  testWidgets('鼠标按下已键盘聚焦节点 → 收起焦点环且保留焦点', (tester) async {
    const key = ValueKey('kb-then-mouse');
    final node = FocusNode(debugLabel: 'kb-then-mouse');
    addTearDown(node.dispose);
    resetHighlightStrategy();

    await pump(tester, focusBox(node, key: key));
    await pressKey(tester, LogicalKeyboardKey.tab);
    expect(node.hasPrimaryFocus, isTrue);
    expect(bgOf(tester, key), ringBg, reason: 'Tab 聚焦先点亮焦点环');

    final primaryBeforeClick = FocusManager.instance.primaryFocus;
    expect(primaryBeforeClick, same(node));
    await tester.tap(find.byKey(key), kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(FocusManager.instance.primaryFocus, same(primaryBeforeClick), reason: '焦点本身不动');
    expect(node.hasPrimaryFocus, isTrue);
    expect(bgOf(tester, key), focusBg, reason: '指针按下立刻收起焦点环，只剩 onFocus');
  });

  testWidgets('触摸按下已键盘聚焦节点 → 收起焦点环', (tester) async {
    const key = ValueKey('kb-then-touch');
    final node = FocusNode(debugLabel: 'kb-then-touch');
    addTearDown(node.dispose);
    resetHighlightStrategy();

    await pump(tester, focusBox(node, key: key));
    await pressKey(tester, LogicalKeyboardKey.tab);
    expect(bgOf(tester, key), ringBg);

    await tester.tap(find.byKey(key), kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();

    expect(node.hasPrimaryFocus, isTrue);
    expect(bgOf(tester, key), focusBg, reason: '触摸按下同样收起焦点环');
  });

  testWidgets('方向键遍历换焦 → 点亮焦点环', (tester) async {
    const k1 = ValueKey('arrow-one');
    const k2 = ValueKey('arrow-two');
    final n1 = FocusNode(debugLabel: 'arrow-one');
    final n2 = FocusNode(debugLabel: 'arrow-two');
    addTearDown(n1.dispose);
    addTearDown(n2.dispose);
    resetHighlightStrategy();

    await pump(
      tester,
      Row(
        children: <Widget>[
          focusBox(n1, key: k1),
          focusBox(n2, key: k2),
        ],
      ),
    );

    await pressKey(tester, LogicalKeyboardKey.tab);
    expect(bgOf(tester, k1), ringBg);

    await pressKey(tester, LogicalKeyboardKey.arrowRight);
    expect(n2.hasPrimaryFocus, isTrue);
    expect(bgOf(tester, k2), ringBg, reason: '方向键遍历属于键盘导航');
    expect(bgOf(tester, k1), base);
  });

  testWidgets('Home / End / PageUp / PageDown 换焦 → 点亮焦点环', (tester) async {
    const k1 = ValueKey('nav-one');
    const k2 = ValueKey('nav-two');
    final n1 = FocusNode(debugLabel: 'nav-one');
    final n2 = FocusNode(debugLabel: 'nav-two');
    addTearDown(n1.dispose);
    addTearDown(n2.dispose);
    resetHighlightStrategy();

    // 组件（菜单/列表）通常在按键回调里自行 requestFocus，这里用同样形态的
    // 祖先 onKeyEvent 模拟：Home/PageUp → 第一项，End/PageDown → 第二项。
    // 该节点自身不参与遍历，只做按键分发。
    Widget harness() => Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.home || key == LogicalKeyboardKey.pageUp) {
          n1.requestFocus();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.end || key == LogicalKeyboardKey.pageDown) {
          n2.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Row(
        children: <Widget>[
          focusBox(n1, key: k1),
          focusBox(n2, key: k2),
        ],
      ),
    );

    await pump(tester, harness());
    await pressKey(tester, LogicalKeyboardKey.tab);
    expect(bgOf(tester, k1), ringBg);

    await pressKey(tester, LogicalKeyboardKey.end);
    expect(n2.hasPrimaryFocus, isTrue);
    expect(bgOf(tester, k2), ringBg, reason: 'End 换焦属于键盘导航');

    await pressKey(tester, LogicalKeyboardKey.home);
    expect(n1.hasPrimaryFocus, isTrue);
    expect(bgOf(tester, k1), ringBg, reason: 'Home 换焦属于键盘导航');

    await pressKey(tester, LogicalKeyboardKey.pageDown);
    expect(n2.hasPrimaryFocus, isTrue);
    expect(bgOf(tester, k2), ringBg, reason: 'PageDown 换焦属于键盘导航');

    await pressKey(tester, LogicalKeyboardKey.pageUp);
    expect(n1.hasPrimaryFocus, isTrue);
    expect(bgOf(tester, k1), ringBg, reason: 'PageUp 换焦属于键盘导航');
  });

  testWidgets('Alt / Meta 组合不算键盘导航，不点亮焦点环', (tester) async {
    const k1 = ValueKey('mod-one');
    const k2 = ValueKey('mod-two');
    final n1 = FocusNode(debugLabel: 'mod-one');
    final n2 = FocusNode(debugLabel: 'mod-two');
    addTearDown(n1.dispose);
    addTearDown(n2.dispose);
    resetHighlightStrategy();

    await pump(
      tester,
      Row(
        children: <Widget>[
          focusBox(n1, key: k1),
          focusBox(n2, key: k2),
        ],
      ),
    );
    await pressKey(tester, LogicalKeyboardKey.tab);
    expect(bgOf(tester, k1), ringBg);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    n2.requestFocus();
    await tester.pump();
    expect(n2.hasPrimaryFocus, isTrue);
    expect(bgOf(tester, k2), focusBg, reason: 'Alt 组合是导航/组合键，不是焦点遍历');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    n1.requestFocus();
    await tester.pump();
    expect(n1.hasPrimaryFocus, isTrue);
    expect(bgOf(tester, k1), focusBg, reason: 'Meta 组合同理');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
  });

  testWidgets('Enter / Escape / 普通字母键触发的聚焦不点亮焦点环', (tester) async {
    const key = ValueKey('plain-keys');
    final node = FocusNode(debugLabel: 'plain-keys');
    addTearDown(node.dispose);
    resetHighlightStrategy();

    await pump(tester, focusBox(node, key: key));

    for (final pressed in const <LogicalKeyboardKey>[
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.escape,
      LogicalKeyboardKey.keyA,
    ]) {
      node.unfocus();
      await tester.pump();
      expect(bgOf(tester, key), base);

      await tester.sendKeyDownEvent(pressed);
      node.requestFocus();
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);
      expect(bgOf(tester, key), focusBg, reason: '$pressed 只做激活/取消/输入，不算导航');
      await tester.sendKeyUpEvent(pressed);
      await tester.pump();
    }
  });

  testWidgets('失焦清位：Tab 前移后，前者 focus/focusVisible 一起清', (tester) async {
    const k1 = ValueKey('one');
    const k2 = ValueKey('two');
    final n1 = FocusNode(debugLabel: 'one');
    final n2 = FocusNode(debugLabel: 'two');
    addTearDown(n1.dispose);
    addTearDown(n2.dispose);

    await pump(
      tester,
      Row(
        children: [
          focusBox(n1, key: k1),
          focusBox(n2, key: k2),
        ],
      ),
    );

    await pressKey(tester, LogicalKeyboardKey.tab);
    expect(bgOf(tester, k1), ringBg);

    await pressKey(tester, LogicalKeyboardKey.tab);
    expect(n2.hasPrimaryFocus, isTrue);
    expect(bgOf(tester, k2), ringBg);
    expect(bgOf(tester, k1), base, reason: '失焦两位全清，回 base');
  });

  testWidgets('ElView.of 能观察 focusVisible 位翻转', (tester) async {
    const key = ValueKey('listen');
    final node = FocusNode(debugLabel: 'listen');
    addTearDown(node.dispose);
    bool? lastFocusVisible;

    await pump(
      tester,
      ElView(
        key: key,
        focusNode: node,
        style: const ElStyle(
          width: 80,
          height: 36,
          bgColor: base,
          onFocusVisible: ElStyle(bgColor: ringBg),
        ),
        child: Builder(
          builder: (context) {
            lastFocusVisible = ElView.of(context).hasFocusVisible;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(lastFocusVisible, isFalse);

    await pressKey(tester, LogicalKeyboardKey.tab);
    expect(lastFocusVisible, isTrue, reason: '键盘聚焦通知 focusVisible=true');

    node.unfocus();
    await tester.pump();
    await tester.pump();
    expect(lastFocusVisible, isFalse, reason: '失焦通知 focusVisible=false');
  });
}
