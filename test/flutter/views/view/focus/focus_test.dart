import 'package:flutter_base/src/flutter/utils/internal/benchmark_probe.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// ElView 的最小焦点集成：节点挂到最近的 Flutter Focus、样式三态同步、
/// 指针 down 聚焦、语义、键盘回调转发。
///
/// 遍历（Tab / 方向键）、焦点恢复、区域归属都属于 Flutter 自己的职责，
/// 这里只锁 el 侧仍保留的行为。
void main() {
  const base = Color(0xFFFFFFFF);
  const focusBg = Color(0xFFDC2626);
  const ringBg = Color(0xFFEF4444);
  const withinBg = Color(0xFF16A34A);

  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );
  }

  /// Tab 默认遍历由 WidgetsApp 的快捷键分发，需要真实应用骨架。
  Future<void> pumpApp(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );
  }

  /// 显式焦点节点 + 焦点三态变体的标准盒子。
  ElView focusBox(
    FocusNode node, {
    Key? key,
    ElStyle style = const ElStyle(width: 80, height: 36, backgroundColor: base),
    ElEvent? event,
    bool disabled = false,
    Widget? child,
  }) {
    return ElView(
      key: key,
      style: style,
      event: disabled ? ((event) ?? ElEvent()).copyWith(disabled: true) : event,
      focusNode: node,
      child: child,
    );
  }

  ElStyle triStateStyle() => const ElStyle(
    width: 120,
    height: 64,
    backgroundColor: base,
    onFocusWithin: ElStyle(backgroundColor: withinBg),
    onFocus: ElStyle(backgroundColor: focusBg),
    onFocusVisible: ElStyle(backgroundColor: ringBg),
  );

  Color? bgOf(WidgetTester tester, Key key) =>
      tester.renderObject<ElRenderView>(find.byKey(key)).committedResolvedStyle.box.backgroundColor;

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  void resetHighlightStrategy() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  }

  group('样式焦点三态', () {
    testWidgets('focus / focusVisible 随主焦点与聚焦来源同步，失焦归零', (tester) async {
      const key = ValueKey('tristate');
      const otherKey = ValueKey('tristate-other');
      final node = FocusNode(debugLabel: 'tristate');
      final other = FocusNode(debugLabel: 'tristate-other');
      addTearDown(node.dispose);
      addTearDown(other.dispose);

      await pumpApp(
        tester,
        Row(
          children: <Widget>[
            ElView(key: key, focusNode: node, style: triStateStyle()),
            ElView(key: otherKey, focusNode: other, style: triStateStyle()),
          ],
        ),
      );
      expect(bgOf(tester, key), base);

      // 键盘遍历获得焦点才点亮 focusVisible。
      await press(tester, LogicalKeyboardKey.tab);
      expect(node.hasPrimaryFocus, isTrue);
      expect(bgOf(tester, key), ringBg, reason: '键盘 Tab 聚焦：focusVisible 压过 focus');
      expect(other.hasPrimaryFocus, isFalse);

      node.unfocus();
      await tester.pump();
      expect(bgOf(tester, key), base, reason: '失焦时 focus / focusVisible 一起清');

      // 程序聚焦不自行开启焦点指示，切高亮形态也不补亮（判定只看聚焦来源）。
      node.requestFocus();
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);
      expect(bgOf(tester, key), focusBg, reason: '程序聚焦只命中 onFocus');

      // 反证：把高亮形态钉在 traditional 是为了证明"判定不看形态"，断言方向仍是
      // 不出环（negative），不是靠开关构造通过条件。
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(resetHighlightStrategy);
      await tester.pump();
      expect(bgOf(tester, key), focusBg, reason: '传统高亮形态也不得把程序聚焦补亮');

      node.unfocus();
      await tester.pump();
      expect(bgOf(tester, key), base, reason: '失焦时 focus / focusVisible 一起清');
    });

    testWidgets('只要 onFocusWithin 的壳不成为指针落点', (tester) async {
      const key = ValueKey('shell');
      await pump(
        tester,
        ElView(
          key: key,
          style: const ElStyle(
            width: 80,
            height: 36,
            backgroundColor: base,
            onFocusWithin: ElStyle(backgroundColor: withinBg),
          ),
        ),
      );

      await tester.tap(find.byKey(key), kind: PointerDeviceKind.mouse);
      await tester.pump();

      expect(FocusManager.instance.primaryFocus, isNull);
      expect(bgOf(tester, key), base);
    });

    testWidgets('嵌套 ElView：后代持焦时父壳进入 focusWithin，移出后清位', (tester) async {
      const parentKey = ValueKey('within-parent');
      final child = FocusNode(debugLabel: 'within-child');
      final outside = FocusNode(debugLabel: 'within-outside');
      addTearDown(child.dispose);
      addTearDown(outside.dispose);

      await pump(
        tester,
        Row(
          children: [
            ElView(
              key: parentKey,
              style: const ElStyle(
                width: 120,
                height: 64,
                backgroundColor: base,
                onFocusWithin: ElStyle(backgroundColor: withinBg),
              ),
              child: focusBox(child),
            ),
            focusBox(outside),
          ],
        ),
      );

      child.requestFocus();
      await tester.pump();
      expect(bgOf(tester, parentKey), withinBg, reason: '子节点挂在最近的 ElView 节点下');

      outside.requestFocus();
      await tester.pump();
      expect(bgOf(tester, parentKey), base);
    });
  });

  group('指针聚焦', () {
    testWidgets('鼠标 down 把焦点交给可聚焦视图', (tester) async {
      const key = ValueKey('pointer');
      final node = FocusNode(debugLabel: 'pointer');
      addTearDown(node.dispose);

      final phases = <ElEventPhase>[];
      await pump(
        tester,
        focusBox(
          node,
          key: key,
          style: const ElStyle(
            width: 80,
            height: 36,
            backgroundColor: base,
            onFocus: ElStyle(backgroundColor: focusBg),
            onFocusVisible: ElStyle(backgroundColor: ringBg),
          ),
          event: ElEvent(onFocus: (event) => phases.add(event.phase)),
        ),
      );

      await tester.tap(find.byKey(key), kind: PointerDeviceKind.mouse);
      await tester.pump();

      expect(node.hasPrimaryFocus, isTrue);
      expect(phases, <ElEventPhase>[ElEventPhase.focus]);
      expect(bgOf(tester, key), focusBg);
    });

    testWidgets('无焦点来源的视图不参与指针聚焦；焦点变体自动建内部节点', (tester) async {
      const plainKey = ValueKey('plain');
      const focusKey = ValueKey('variant');

      await pump(
        tester,
        Row(
          children: [
            const ElView(
              key: plainKey,
              style: ElStyle(width: 80, height: 36, backgroundColor: base),
            ),
            const ElView(
              key: focusKey,
              style: ElStyle(
                width: 80,
                height: 36,
                backgroundColor: base,
                onFocus: ElStyle(backgroundColor: focusBg),
              ),
            ),
          ],
        ),
      );

      await tester.tap(find.byKey(plainKey), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNull, reason: '没有节点来源的视图不抢焦点');

      await tester.tap(find.byKey(focusKey), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'ElView');
      expect(bgOf(tester, focusKey), focusBg);
    });

    testWidgets('点内层可聚焦视图时外层不抢焦', (tester) async {
      const outerKey = ValueKey('nested-outer');
      const innerKey = ValueKey('nested-inner');
      final outer = FocusNode(debugLabel: 'nested-outer');
      final inner = FocusNode(debugLabel: 'nested-inner');
      addTearDown(outer.dispose);
      addTearDown(inner.dispose);

      await pump(
        tester,
        ElView(
          key: outerKey,
          focusNode: outer,
          style: const ElStyle(width: 200, height: 120, backgroundColor: base),
          child: focusBox(inner, key: innerKey, child: const SizedBox(width: 80, height: 36)),
        ),
      );

      // 先让外层持焦，再点内层：命中派发深→浅，外层必须让位。
      outer.requestFocus();
      await tester.pump();
      expect(outer.hasPrimaryFocus, isTrue);

      await tester.tap(find.byKey(innerKey), kind: PointerDeviceKind.mouse);
      await tester.pump();

      expect(inner.hasPrimaryFocus, isTrue);
      expect(outer.hasPrimaryFocus, isFalse);
    });
  });

  group('禁用', () {
    testWidgets('禁用压住外部节点的 canRequestFocus，恢复启用写回原值', (tester) async {
      final node = FocusNode(debugLabel: 'disabled');
      addTearDown(node.dispose);
      var disabled = false;
      late StateSetter setState;

      await pump(
        tester,
        StatefulBuilder(
          builder: (context, update) {
            setState = update;
            return focusBox(node, disabled: disabled);
          },
        ),
      );

      await tester.tap(find.byType(ElView), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);

      setState(() => disabled = true);
      await tester.pump();
      expect(node.canRequestFocus, isFalse);
      expect(node.hasPrimaryFocus, isFalse, reason: '禁用时持焦视图立即失焦');

      await tester.tap(find.byType(ElView), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(node.hasPrimaryFocus, isFalse, reason: '禁用期间点击不聚焦');

      setState(() => disabled = false);
      await tester.pump();
      expect(node.canRequestFocus, isTrue, reason: '恢复启用时写回调用方原值');
    });
  });

  group('语义', () {
    testWidgets('可聚焦视图暴露 focusable / focused', (tester) async {
      const key = ValueKey('semantics');
      final node = FocusNode(debugLabel: 'semantics');
      addTearDown(node.dispose);

      await pump(tester, focusBox(node, key: key));

      final handle = tester.ensureSemantics();
      try {
        expect(tester.getSemantics(find.byKey(key)), matchesSemantics(isFocusable: true, isFocused: false));
        node.requestFocus();
        await tester.pump();
        await tester.pump();
        expect(tester.getSemantics(find.byKey(key)), matchesSemantics(isFocusable: true, isFocused: true));
      } finally {
        handle.dispose();
      }
    });
  });

  group('键盘回调', () {
    testWidgets('持焦时把按键转发给 ElEvent 键盘回调', (tester) async {
      final node = FocusNode(debugLabel: 'keyboard');
      final log = <String>[];
      addTearDown(node.dispose);

      await pump(
        tester,
        focusBox(node, event: ElEvent(onKeyDown: (event) => log.add(event.logicalKey?.keyLabel ?? ''))),
      );

      node.requestFocus();
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyA);

      expect(log, <String>['A']);
    });

    testWidgets('preventDefault 后按键被判为已处理，Tab 不移动焦点', (tester) async {
      final first = FocusNode(debugLabel: 'first');
      final second = FocusNode(debugLabel: 'second');
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      await pumpApp(
        tester,
        Row(
          children: [
            focusBox(
              first,
              event: ElEvent(
                onKeyDown: (event) {
                  if (event.logicalKey == LogicalKeyboardKey.tab) event.preventDefault();
                },
              ),
            ),
            focusBox(second),
          ],
        ),
      );

      first.requestFocus();
      await tester.pump();
      await press(tester, LogicalKeyboardKey.tab);

      expect(first.hasPrimaryFocus, isTrue);
      expect(second.hasPrimaryFocus, isFalse);
    });

    testWidgets('外部节点自带的 onKeyEvent 不被覆盖', (tester) async {
      final log = <String>[];
      final node = FocusNode(
        debugLabel: 'external-handler',
        onKeyEvent: (node, event) {
          log.add(event.logicalKey.keyLabel);
          return KeyEventResult.handled;
        },
      );
      addTearDown(node.dispose);

      await pump(tester, focusBox(node));
      node.requestFocus();
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyA);

      // sendKeyEvent 依次派发按下与抬起，外部 handler 两次都收到。
      expect(log, <String>['A', 'A']);
    });
  });

  group('焦点事件', () {
    testWidgets('pointer / programmatic 原因与 focus / blur 相位', (tester) async {
      const key = ValueKey('reasons');
      final node = FocusNode(debugLabel: 'reasons');
      final reasons = <String>[];
      addTearDown(node.dispose);

      await pump(
        tester,
        focusBox(
          node,
          key: key,
          event: ElEvent(
            onFocus: (event) => reasons.add('focus:${event.focusReason?.name}'),
            onBlur: (event) => reasons.add('blur:${event.focusReason?.name}'),
          ),
        ),
      );

      await tester.tap(find.byKey(key), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(reasons, <String>['focus:pointer']);

      node.unfocus();
      await tester.pump();
      expect(reasons, <String>['focus:pointer', 'blur:programmatic']);

      reasons.clear();
      node.requestFocus();
      await tester.pump();
      expect(reasons, <String>['focus:programmatic']);
    });

    testWidgets('focus 事件沿 el 链从子冒泡到父', (tester) async {
      final node = FocusNode(debugLabel: 'child');
      final log = <String>[];
      addTearDown(node.dispose);

      await pump(
        tester,
        ElView(
          style: const ElStyle(width: 140, height: 80),
          event: ElEvent(onFocus: (_) => log.add('parent')),
          child: focusBox(node, event: ElEvent(onFocus: (_) => log.add('child'))),
        ),
      );

      node.requestFocus();
      await tester.pump();

      expect(log, <String>['child', 'parent']);
    });
  });

  group('按需创建', () {
    testWidgets('焦点对象随来源创建，更新不重建，换节点才更换，撤掉来源即释放', (tester) async {
      final key = ValueKey('lazy');
      final node = FocusNode(debugLabel: 'lazy');
      addTearDown(node.dispose);
      ElRenderView render() => tester.renderObject<ElRenderView>(find.byKey(key));
      ElStyle plain() => ElStyle(width: 80, height: 36, backgroundColor: base);
      ElStyle focusable() => plain().copyWith(onFocus: ElStyle(backgroundColor: focusBg));
      BenchmarkProbe.reset();

      // 只有点击、没有键盘回调的视图不是焦点来源。
      await pump(
        tester,
        ElView(
          key: key,
          style: plain(),
          event: ElEvent(onTap: (_) {}),
        ),
      );
      expect(BenchmarkProbe.focusStateInstantiateCount, 0);
      expect(render().requestFocusForEvent, isNull);

      await pump(tester, ElView(key: key, style: focusable()));
      expect(BenchmarkProbe.focusStateInstantiateCount, 1);
      expect(render().requestFocusForEvent, isNotNull);

      await pump(tester, ElView(key: key, style: focusable()));
      expect(BenchmarkProbe.focusStateInstantiateCount, 1, reason: '来源不变时更新只同步');

      await pump(tester, ElView(key: key, style: focusable(), focusNode: node));
      expect(BenchmarkProbe.focusStateInstantiateCount, 2, reason: '内部节点换成外部节点');
      expect(node.parent, isNotNull);

      await pump(tester, ElView(key: key, style: plain()));
      expect(BenchmarkProbe.focusStateInstantiateCount, 2);
      expect(node.parent, isNull, reason: '来源撤掉后摘下外部节点');
      expect(render().requestFocusForEvent, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('外部节点摘下再挂回：上层包过的按键链不会回环', (tester) async {
      final key = ValueKey('rebind');
      final node = FocusNode(debugLabel: 'rebind');
      final log = <String>[];
      addTearDown(node.dispose);
      ElView bound() => focusBox(
        node,
        key: key,
        event: ElEvent(onKeyDown: (_) => log.add('view')),
      );

      await pump(tester, bound());
      // 组件在视图安装的转发之上再包一层，并链回视图的转发。
      final inner = node.onKeyEvent!;
      node.onKeyEvent = (node, event) {
        log.add('outer');
        return inner(node, event);
      };

      await pump(tester, ElView(key: key, style: ElStyle(width: 80, height: 36)));
      await pump(tester, bound());
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);

      expect(tester.takeException(), isNull);
      // 按下、抬起各经过一次外层；旧挂接留在链里的转发已失效，只有当前挂接派发回调。
      expect(log, <String>['outer', 'view', 'outer']);
    });
  });

  testWidgets('外部节点归调用方所有：卸载后不被 ElView 释放', (tester) async {
    final node = FocusNode(debugLabel: 'external');
    addTearDown(node.dispose);

    await pump(tester, focusBox(node));
    expect(node.context, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);

    // 已释放的节点再次请求焦点会抛 FlutterError，这里必须保持可用。
    node.requestFocus();
    expect(tester.takeException(), isNull);
  });
}
