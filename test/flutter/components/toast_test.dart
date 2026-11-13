import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _toast(BuildContext context, ElToast c) => ElOverlayTransition(
  duration: Duration(milliseconds: 100),
  reverseDuration: Duration(milliseconds: 50),
  builder: (context, animation) =>
      FadeTransition(key: ValueKey('${c.child}'), opacity: animation, child: Text('${c.child}')),
);

Widget _app(Widget home) => MaterialApp(
  navigatorKey: el.navigatorKey,
  builder: (context, child) => ElComponentProvider(
    components: ElComponents(toast: _toast),
    child: child!,
  ),
  home: Scaffold(body: home),
);

Widget _source(void Function(BuildContext context) capture) => Builder(
  builder: (context) {
    capture(context);
    return SizedBox.expand();
  },
);

double _opacity(WidgetTester tester, String text) =>
    tester.widget<FadeTransition>(find.byKey(ValueKey(text))).opacity.value;

Future<void> _enter(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(SizedBox());
  await tester.pump();
}

void main() {
  testWidgets('从内层 Overlay 调用时显示在根 Overlay，按品牌时长进场、停留、退场后移除', (tester) async {
    late BuildContext inner;
    await tester.pumpWidget(_app(Overlay(initialEntries: [OverlayEntry(builder: (_) => _source((c) => inner = c))])));
    var removed = false;
    el.toast.show('已保存', context: inner).then((_) => removed = true);

    await _enter(tester);
    expect(_opacity(tester, '已保存'), 0);
    final overlay = find.ancestor(of: find.text('已保存'), matching: find.byType(Overlay)).first;
    expect(tester.state<OverlayState>(overlay), same(el.navigatorKey.currentState!.overlay));
    await tester.pump(Duration(milliseconds: 50));
    expect(_opacity(tester, '已保存'), inExclusiveRange(0, 1));
    await tester.pump(Duration(milliseconds: 50));
    expect(_opacity(tester, '已保存'), 1);

    await tester.pump(Duration(milliseconds: 1900));
    await tester.pump(Duration(milliseconds: 25));
    expect(_opacity(tester, '已保存'), inExclusiveRange(0, 1));
    expect(removed, isFalse);
    await tester.pumpAndSettle();
    expect(find.text('已保存'), findsNothing);
    expect(removed, isTrue);
  });

  testWidgets('新提示出现时当前提示同时退场', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(_app(_source((c) => source = c)));
    el.toast.show('第一条', context: source);
    await _enter(tester);
    await tester.pump(Duration(milliseconds: 100));

    el.toast.show('第二条', context: source);
    await _enter(tester);
    await tester.pump(Duration(milliseconds: 25));
    expect(_opacity(tester, '第一条'), inExclusiveRange(0, 1));
    expect(_opacity(tester, '第二条'), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(find.text('第一条'), findsNothing);
    expect(_opacity(tester, '第二条'), 1);
    await _dispose(tester);
  });

  testWidgets('duration 为零时保留到 close，close 在退场移除后完成', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(_app(_source((c) => source = c)));
    final shown = el.toast.show('同步中', context: source, duration: Duration.zero);
    await _enter(tester);
    await tester.pump(Duration(seconds: 10));
    expect(find.text('同步中'), findsOneWidget);

    var closed = false;
    el.toast.close().then((_) => closed = true);
    await tester.pumpAndSettle();
    expect(find.text('同步中'), findsNothing);
    expect(closed, isTrue);
    await shown;
  });

  testWidgets('提示不拦截点击', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(GestureDetector(key: ValueKey('page'), behavior: .opaque, onTap: () => taps++, child: SizedBox.expand())),
    );
    el.toast.show('已保存', context: tester.element(find.byKey(ValueKey('page'))));
    await _enter(tester);
    await tester.pump(Duration(milliseconds: 100));
    await tester.tapAt(tester.getCenter(find.text('已保存')));
    expect(taps, 1);
    await _dispose(tester);
  });

  testWidgets('省略 context 时挂到 el.navigatorKey 的 Overlay', (tester) async {
    await tester.pumpWidget(_app(SizedBox.expand()));
    el.toast.show('全局');
    await _enter(tester);
    expect(find.text('全局'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('调用处注入的 Builder 随提示带到根 Overlay', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(
      _app(
        ElComponentProvider(
          components: ElComponents(toast: (context, c) => Text('局部:${c.child}')),
          child: _source((c) => source = c),
        ),
      ),
    );
    el.toast.show('A', context: source);
    await tester.pump();
    expect(find.text('局部:A'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('直接放在页面里的 ElToast 显示终态', (tester) async {
    await tester.pumpWidget(_app(ElToast(child: '页面内')));
    expect(_opacity(tester, '页面内'), 1);
  });

  testWidgets('承载的 Overlay 卸载时提示随之结清', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(_app(_source((c) => source = c)));
    final shown = el.toast.show('卸载', context: source, duration: Duration(seconds: 30));
    await _enter(tester);
    await _dispose(tester);
    await shown;
    await tester.pump(Duration(seconds: 31));
    expect(tester.takeException(), isNull);
  });
}
