import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kTertiaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// ElLink 行为基元测试。
void main() {
  Widget shell(Widget child) => MaterialApp(
    home: Align(
      alignment: .topLeft,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 400, maxHeight: 400), child: child),
    ),
  );

  // 每个用例注入假跳转通道，记录 (uri, target)；结束后还原默认实现。
  late List<(Uri, LinkTarget)> opened;
  setUp(() {
    ElLinkStatusBar.reset();
    opened = [];
    ElLink.openHref = (uri, target) async => opened.add((uri, target));
  });
  tearDown(() => ElLink.openHref = ElLink.defaultOpenHref);

  group('semantics', () {
    testWidgets('exposes merged link node with linkUrl and tap action', (tester) async {
      const hostKey = ValueKey<String>('link');
      var presses = 0;

      await tester.pumpWidget(
        shell(ElLink(key: hostKey, href: 'https://example.com/a', onPressed: () => presses++, child: 'Docs')),
      );

      final semantics = tester.ensureSemantics();
      try {
        final node = tester.getSemantics(find.byKey(hostKey));
        expect(
          node,
          matchesSemantics(
            label: 'Docs',
            isLink: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
            isFocusable: true,
          ),
        );
        // linkUrl 进语义树（web 端语义 <a href> 的数据来源）。
        expect(node.getSemanticsData().linkUrl, Uri.parse('https://example.com/a'));
        // 读屏激活与指针/键盘同路径：回调 + 默认跳转都触发。
        node.owner!.performAction(node.id, SemanticsAction.tap);
        expect(presses, 1);
        expect(opened, [(Uri.parse('https://example.com/a'), LinkTarget.self)]);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('disabled link reports not enabled and drops focus and actions', (tester) async {
      const hostKey = ValueKey<String>('link-disabled');
      var presses = 0;

      await tester.pumpWidget(
        shell(
          ElLink(key: hostKey, href: 'https://example.com', onPressed: () => presses++, disabled: true, child: 'Nope'),
        ),
      );

      final view = tester.widget<ElLink>(find.byKey(hostKey));
      expect(view.focusNode, isNull);

      await tester.tap(find.byKey(hostKey), warnIfMissed: false);
      await tester.pump();
      expect(presses, 0);
      expect(opened, isEmpty);

      final semantics = tester.ensureSemantics();
      try {
        expect(
          tester.getSemantics(find.byKey(hostKey)),
          matchesSemantics(label: 'Nope', isLink: true, hasEnabledState: true, isEnabled: false),
        );
      } finally {
        semantics.dispose();
      }
    });
  });

  group('interaction', () {
    testWidgets('tap runs onPressed and caller onTap before default navigation', (tester) async {
      const hostKey = ValueKey<String>('link-tap');
      final log = <String>[];
      ElLink.openHref = (uri, target) async => log.add('open:$uri:$target');

      await tester.pumpWidget(
        shell(
          ElLink(
            key: hostKey,
            href: Uri.parse('https://example.com/b'),
            onPressed: () => log.add('pressed'),
            event: ElEvent(onTap: (_) => log.add('event')),
            child: 'Go',
          ),
        ),
      );

      await tester.tap(find.byKey(hostKey));
      await tester.pump();
      // <a onclick> 口径：先跑回调，未拦截才导航。
      expect(log, ['pressed', 'event', 'open:https://example.com/b:LinkTarget.self']);
    });

    testWidgets('preventDefault in caller onTap blocks navigation only', (tester) async {
      const hostKey = ValueKey<String>('link-prevent');
      var presses = 0;

      await tester.pumpWidget(
        shell(
          ElLink(
            key: hostKey,
            href: 'https://example.com',
            onPressed: () => presses++,
            event: ElEvent(onTap: (e) => e.preventDefault()),
            child: 'Stay',
          ),
        ),
      );

      await tester.tap(find.byKey(hostKey));
      await tester.pump();
      expect(presses, 1);
      expect(opened, isEmpty);
    });

    testWidgets('Enter activates on keydown and repeats; Space never activates', (tester) async {
      const hostKey = ValueKey<String>('link-key');
      var presses = 0;
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        shell(
          ElLink(key: hostKey, href: 'https://example.com', onPressed: () => presses++, focusNode: node, child: 'Go'),
        ),
      );

      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);

      // Enter：keydown 即触发，按住 repeat 连续触发，每次都带默认跳转。
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      expect(presses, 1);
      await tester.pump(Duration(milliseconds: 100));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      expect(presses, 2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      expect(presses, 2);
      expect(opened, hasLength(2));

      // Space：web 口径链接不响应空格——keydown / keyup 都不激活、不跳转。
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(presses, 2);
      expect(opened, hasLength(2));
    });

    testWidgets('Ctrl+click forces blank target; plain click keeps declared target', (tester) async {
      const hostKey = ValueKey<String>('link-ctrl');

      await tester.pumpWidget(shell(ElLink(key: hostKey, href: 'https://example.com/c', child: 'Go')));

      await tester.tap(find.byKey(hostKey));
      await tester.pump();
      expect(opened.single.$2, LinkTarget.self);

      opened.clear();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.byKey(hostKey));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(opened.single.$2, LinkTarget.blank);
    });

    testWidgets('middle click opens blank without firing onPressed (auxclick)', (tester) async {
      const hostKey = ValueKey<String>('link-middle');
      var presses = 0;

      await tester.pumpWidget(
        shell(ElLink(key: hostKey, href: 'https://example.com/m', onPressed: () => presses++, child: 'Go')),
      );

      await tester.tap(find.byKey(hostKey), buttons: kTertiaryButton, kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(presses, 0);
      expect(opened, [(Uri.parse('https://example.com/m'), LinkTarget.blank)]);
      // 中键同时建立鼠标悬停，断言后结清状态栏的延迟显示计时器。
      ElLinkStatusBar.reset();
    });

    testWidgets('caller onTertiaryTap runs first and can preventDefault middle-click navigation', (tester) async {
      const hostKey = ValueKey<String>('link-middle-prevent');
      var tertiaries = 0;

      await tester.pumpWidget(
        shell(
          ElLink(
            key: hostKey,
            href: 'https://example.com',
            event: ElEvent(
              onTertiaryTap: (e) {
                tertiaries++;
                e.preventDefault();
              },
            ),
            child: 'Go',
          ),
        ),
      );

      await tester.tap(find.byKey(hostKey), buttons: kTertiaryButton, kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(tertiaries, 1);
      expect(opened, isEmpty);
      ElLinkStatusBar.reset();
    });

    testWidgets('href-less link runs callbacks only and injects no tertiary handler', (tester) async {
      const hostKey = ValueKey<String>('link-no-href');
      var presses = 0;

      await tester.pumpWidget(shell(ElLink(key: hostKey, onPressed: () => presses++, child: 'Act')));

      final view = tester.widget<ElLink>(find.byKey(hostKey));
      expect(view.hrefUri, isNull);
      expect(view.event!.onTertiaryTap, isNull);

      await tester.tap(find.byKey(hostKey));
      await tester.tap(find.byKey(hostKey), buttons: kTertiaryButton, kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(presses, 1);
      expect(opened, isEmpty);
    });

    testWidgets('caller keyboard override disarms builtin Enter activation as a group', (tester) async {
      const hostKey = ValueKey<String>('link-key-override');
      var presses = 0;
      var customKeys = 0;
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        shell(
          ElLink(
            key: hostKey,
            href: 'https://example.com',
            onPressed: () => presses++,
            focusNode: node,
            event: ElEvent(onKeyDown: (_) => customKeys++),
            child: 'Go',
          ),
        ),
      );

      node.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      expect(customKeys, 1);
      expect(presses, 0);
      expect(opened, isEmpty);

      // 指针激活不受键盘让位影响，默认跳转仍在。
      await tester.tap(find.byKey(hostKey));
      await tester.pump();
      expect(presses, 1);
      expect(opened, hasLength(1));
    });
  });

  group('style', () {
    testWidgets('injects click cursor only; selection stays enabled', (tester) async {
      const hostKey = ValueKey<String>('link-style');

      await tester.pumpWidget(
        shell(
          ElLink(
            key: hostKey,
            href: 'https://example.com',
            style: ElStyle(backgroundColor: Color(0xff112233)),
            child: 'S',
          ),
        ),
      );

      final view = tester.widget<ElLink>(find.byKey(hostKey));
      expect(view.style!.backgroundColor, Color(0xff112233));
      // 行为性默认：<a href> 手型光标；调用方可覆盖。
      expect(view.style!.cursor, SystemMouseCursors.click);
      // 与按钮相反：链接文字参与文本选区，不注入 userSelect。
      expect(view.style!.userSelect, isNull);
      expect(view.style!.padding, isNull);
    });

    testWidgets('disabled link keeps caller style untouched (engine owns forbidden cursor)', (tester) async {
      const hostKey = ValueKey<String>('link-style-disabled');
      final style = ElStyle(backgroundColor: Color(0xff112233));

      await tester.pumpWidget(
        shell(ElLink(key: hostKey, href: 'https://example.com', style: style, disabled: true, child: 'S')),
      );

      final view = tester.widget<ElLink>(find.byKey(hostKey));
      expect(identical(view.style, style), isTrue);
    });

    testWidgets('href accepts String and Uri; unparsable input degrades to null', (tester) async {
      expect(ElLink(href: 'https://a.b/c').hrefUri, Uri.parse('https://a.b/c'));
      final uri = Uri.parse('https://a.b/d');
      expect(ElLink(href: uri).hrefUri, same(uri));
      expect(ElLink(href: 'ht tp://broken').hrefUri, isNull);
      expect(ElLink().hrefUri, isNull);
    });
  });
}
