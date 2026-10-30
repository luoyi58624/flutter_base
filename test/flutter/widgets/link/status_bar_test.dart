import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/widgets/link/status_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(ElLinkStatusBar.reset);
  tearDown(ElLinkStatusBar.reset);

  testWidgets('link 官方 Overlay 预览保留源明暗并响应切换', (tester) async {
    late BuildContext source;
    late StateSetter update;
    var dark = true;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return ElView(
              themeMode: ElThemeMode(brightness: dark ? .dark : .light),
              child: Builder(
                builder: (context) {
                  source = context;
                  return SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );
    ElLinkStatusBar.hoverEnter(source, Uri.parse('https://example.com/theme'));
    await tester.pump(ElLinkStatusBar.showDelay);
    await tester.pump();
    await tester.pump();
    ElRenderView panel() => tester.renderObject<ElRenderView>(find.byKey(linkStatusBarPanelKey));
    expect(panel().effectiveThemeMode?.brightness, Brightness.dark);
    update(() => dark = false);
    await tester.pump();
    await tester.pump();
    expect(panel().effectiveThemeMode?.brightness, Brightness.light);
    ElLinkStatusBar.reset();
    await tester.pump();
  });

  testWidgets('link 悬停在官方 Overlay 左下角预览，延时退出并完成淡出', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: ElLink(href: 'https://example.com/preview', child: 'Preview'),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset(700, 500));
    await mouse.moveTo(tester.getCenter(find.byType(ElLink)));
    await tester.pump(ElLinkStatusBar.showDelay - Duration(milliseconds: 1));
    expect(ElLinkStatusBar.isShown, isFalse);
    await tester.pump(Duration(milliseconds: 1));
    await tester.pump();
    await tester.pump();
    expect(ElLinkStatusBar.isShown, isTrue);
    expect(find.byKey(linkStatusBarPanelKey), findsOneWidget);
    final rect = tester.getRect(find.byKey(linkStatusBarPanelKey));
    expect(rect.left, 0);
    expect(rect.bottom, 600);
    await mouse.moveTo(Offset(700, 500));
    await tester.pump(ElLinkStatusBar.hideDelay);
    expect(ElLinkStatusBar.isShown, isFalse);
    expect(find.byKey(linkStatusBarPanelKey), findsOneWidget);
    await tester.pump(ElLinkStatusBar.hideFadeDuration);
    await tester.pump();
    expect(find.byKey(linkStatusBarPanelKey), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('link 没有官方 Overlay 时静默降级，仅 debug 告警一次', (tester) async {
    late BuildContext source;
    final messages = <String>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    try {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              source = context;
              return SizedBox();
            },
          ),
        ),
      );
      ElLinkStatusBar.hoverEnter(source, Uri.parse('https://example.com/one'));
      ElLinkStatusBar.hoverEnter(source, Uri.parse('https://example.com/two'));
      await tester.pump(ElLinkStatusBar.showDelay);
      expect(ElLinkStatusBar.isShown, isFalse);
      expect(find.byKey(linkStatusBarPanelKey), findsNothing);
      expect(messages.where((message) => message.contains('找不到官方 Overlay')), hasLength(1));
    } finally {
      debugPrint = previous;
    }
  });

  testWidgets('link 已显示时换址复用面板，旧链接退出不关闭新地址', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            source = context;
            return SizedBox();
          },
        ),
      ),
    );
    final first = Uri.parse('https://example.com/one');
    final second = Uri.parse('https://example.com/two');
    ElLinkStatusBar.hoverEnter(source, first);
    await tester.pump(ElLinkStatusBar.showDelay);
    await tester.pump();
    await tester.pump();
    final element = tester.element(find.byKey(linkStatusBarPanelKey));
    ElLinkStatusBar.hoverExit(first);
    ElLinkStatusBar.hoverEnter(source, second);
    ElLinkStatusBar.hoverExit(first);
    await tester.pump(ElLinkStatusBar.hideDelay);
    expect(ElLinkStatusBar.isShown, isTrue);
    expect(tester.element(find.byKey(linkStatusBarPanelKey)), same(element));
    final view = tester.widget<ElView>(find.byKey(linkStatusBarPanelKey));
    expect(view.child, second.toString());
    ElLinkStatusBar.reset();
    await tester.pump();
  });

  testWidgets('link 预览不拦截点击和 ESC，根 Overlay 销毁会清理状态', (tester) async {
    late BuildContext source;
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            source = context;
            return GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++, child: SizedBox.expand());
          },
        ),
      ),
    );
    ElLinkStatusBar.hoverEnter(source, Uri.parse('https://example.com/pass'));
    await tester.pump(ElLinkStatusBar.showDelay);
    await tester.pump();
    await tester.pump();
    await tester.tapAt(Offset(10, 590));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(taps, 1);
    expect(ElLinkStatusBar.isShown, isTrue);
    await tester.pumpWidget(SizedBox());
    expect(ElLinkStatusBar.isShown, isFalse);
    await tester.pump(ElLinkStatusBar.expandDelay);
    expect(tester.takeException(), isNull);
  });

  testWidgets('link 显示等待期内触发物卸载不挂载预览', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            source = context;
            return SizedBox();
          },
        ),
      ),
    );
    ElLinkStatusBar.hoverEnter(source, Uri.parse('https://example.com/gone'));
    await tester.pumpWidget(SizedBox());
    await tester.pump(ElLinkStatusBar.showDelay);
    expect(ElLinkStatusBar.isShown, isFalse);
    expect(tester.takeException(), isNull);
  });
}
