import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt;
import 'package:flutter_test/flutter_test.dart';

Widget _message(BuildContext context, ElMessage c) => ElOverlayTransition(
  duration: Duration(milliseconds: 100),
  reverseDuration: Duration(milliseconds: 50),
  builder: (context, animation) => FadeTransition(
    key: ValueKey('${c.child}'),
    opacity: animation,
    child: GestureDetector(onTap: c.onClose, child: Text('${c.child}')),
  ),
);

Widget _stack(BuildContext context, List<Widget> children) => Align(
  alignment: .topCenter,
  child: Column(mainAxisSize: .min, children: children),
);

Widget _app(Widget home, [ElComponents? components]) => MaterialApp(
  navigatorKey: el.navigatorKey,
  builder: (context, child) => ElComponentProvider(
    components: components ?? ElComponents(message: _message, messageStack: _stack),
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

Finder _copy(String text) =>
    find.byWidgetPredicate((w) => w is Text && w.data == text || w is ElView && w.child == text);

Future<void> _enter(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(SizedBox());
  await tester.pump();
}

void main() {
  testWidgets('多条消息同时存在，按显示先后交给 messageStack，各自计时退场后完成', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(_app(_source((c) => source = c)));
    var firstRemoved = false;
    el.message.show('第一条', context: source, duration: Duration(seconds: 1)).then((_) => firstRemoved = true);
    await _enter(tester);
    await tester.pump(Duration(milliseconds: 500));
    final second = el.message.show('第二条', context: source, duration: Duration(seconds: 1));
    await _enter(tester);
    await tester.pump(Duration(milliseconds: 100));
    expect(tester.getTopLeft(find.text('第二条')).dy, greaterThan(tester.getTopLeft(find.text('第一条')).dy));

    await tester.pump(Duration(milliseconds: 400));
    await tester.pump(Duration(milliseconds: 60));
    await tester.pump();
    expect(find.text('第一条'), findsNothing);
    expect(firstRemoved, isTrue);
    expect(find.text('第二条'), findsOneWidget);
    await tester.pump(Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await second;
    expect(find.text('第二条'), findsNothing);
  });

  testWidgets('onClose 只关闭对应消息，duration 为零时保留到关闭', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(_app(_source((c) => source = c)));
    final first = el.message.show('常驻', context: source, duration: Duration.zero);
    el.message.show('另一条', context: source, duration: Duration.zero);
    await _enter(tester);
    await tester.pump(Duration(seconds: 10));
    expect(find.text('常驻'), findsOneWidget);

    await tester.tap(find.text('常驻'));
    await tester.pumpAndSettle();
    expect(find.text('常驻'), findsNothing);
    expect(find.text('另一条'), findsOneWidget);
    await first;
    await _dispose(tester);
  });

  testWidgets('指针悬停期间暂停计时，移开后重新计时', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(_app(_source((c) => source = c)));
    el.message.show('悬停', context: source, duration: Duration(seconds: 1));
    await _enter(tester);
    await tester.pump(Duration(milliseconds: 500));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('悬停')));
    await tester.pump(Duration(seconds: 3));
    expect(find.text('悬停'), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump(Duration(milliseconds: 900));
    expect(find.text('悬停'), findsOneWidget);
    await tester.pump(Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('悬停'), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('之后打开的路由不会盖住消息', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(_app(_source((c) => source = c)));
    el.message.show('路由前', context: source, duration: Duration.zero);
    await _enter(tester);

    Navigator.of(source).push(MaterialPageRoute(builder: (_) => Scaffold(body: Text('新页面'))));
    await tester.pumpAndSettle();
    el.message.show('路由后', context: source, duration: Duration.zero);
    await _enter(tester);
    expect(find.text('新页面'), findsOneWidget);
    expect(find.text('路由前'), findsOneWidget);
    expect(find.text('路由后'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('省略 context 时挂到 el.navigatorKey 的 Overlay', (tester) async {
    await tester.pumpWidget(_app(SizedBox.expand()));
    el.message.show('全局');
    await _enter(tester);
    expect(find.text('全局'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('承载的 Overlay 卸载时消息随之结清', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(_app(_source((c) => source = c)));
    final shown = el.message.show('卸载', context: source, duration: Duration(seconds: 30));
    await _enter(tester);
    await _dispose(tester);
    await shown;
    await tester.pump(Duration(seconds: 31));
    expect(tester.takeException(), isNull);
  });

  testWidgets('桌面品牌自上而下排列，关闭上方消息后下方消息补位', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(_app(_source((c) => source = c), el.desktopComponents));
    el.message.show('上方', context: source, type: .success, duration: Duration.zero);
    el.message.show('下方', context: source, type: .error, duration: Duration.zero);
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(_copy('上方')).dy;
    expect(top, greaterThanOrEqualTo(20));
    expect(tester.getTopLeft(_copy('下方')).dy, greaterThan(tester.getBottomLeft(_copy('上方')).dy));

    await tester.tap(find.bySemanticsLabel('关闭消息').first);
    await tester.pumpAndSettle();
    expect(_copy('上方'), findsNothing);
    expect(tester.getTopLeft(_copy('下方')).dy, moreOrLessEquals(top));
    await _dispose(tester);
  });

  testWidgets('移动品牌为顶部通栏，新消息叠在旧消息上方，内容让出状态栏，点击关闭', (tester) async {
    tester.view.padding = FakeViewPadding(top: 40 * tester.view.devicePixelRatio);
    addTearDown(tester.view.reset);
    late BuildContext source;
    await tester.pumpWidget(_app(_source((c) => source = c), el.mobileComponents));
    el.message.show('旧消息', context: source, duration: Duration.zero);
    el.message.show('新消息', context: source, type: .error, duration: Duration.zero);
    await tester.pumpAndSettle();

    final width = tester.getSize(find.byType(Scaffold)).width;
    for (final text in ['旧消息', '新消息']) {
      final bar = tester.getRect(find.ancestor(of: _copy(text), matching: find.byType(SlideTransition)).first);
      expect(bar.top, 0);
      expect(bar.width, width);
      expect(tester.getTopLeft(_copy(text)).dy, greaterThanOrEqualTo(40));
    }
    // 平移层不进入命中路径，比对通栏自身的 ElView。
    RenderObject bar(String text) => tester.renderObject(
      find
          .descendant(
            of: find.ancestor(of: _copy(text), matching: find.byType(SlideTransition)).first,
            matching: find.byType(ElView),
          )
          .first,
    );
    final hit = tester.hitTestOnBinding(tester.getCenter(_copy('旧消息'))).path.map((entry) => entry.target);
    expect(hit, contains(bar('新消息')));
    expect(hit, isNot(contains(bar('旧消息'))));

    await tester.tapAt(tester.getCenter(_copy('新消息')));
    await tester.pumpAndSettle();
    expect(_copy('新消息'), findsNothing);
    expect(_copy('旧消息'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('桌面消息两侧的空白不拦截点击', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        GestureDetector(key: ValueKey('page'), behavior: .opaque, onTap: () => taps++, child: SizedBox.expand()),
        el.desktopComponents,
      ),
    );
    final page = tester.element(find.byKey(ValueKey('page')));
    el.message.show('保存成功', context: page, type: .success, duration: Duration.zero);
    await tester.pumpAndSettle();
    await tester.tapAt(Offset(10, tester.getCenter(_copy('保存成功')).dy));
    expect(taps, 1);
    await _dispose(tester);
  });

  testWidgets('桌面与移动布局互相切换后，旧品牌的消息按原排布退场，新消息按当前品牌排布', (tester) async {
    final mobile = ValueNotifier(false);
    addTearDown(mobile.dispose);
    late BuildContext source;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: el.navigatorKey,
        home: ValueListenableBuilder(
          valueListenable: mobile,
          builder: (context, value, _) => ElComponentProvider(
            components: value ? el.mobileComponents : el.desktopComponents,
            child: Scaffold(body: _source((c) => source = c)),
          ),
        ),
      ),
    );
    final width = tester.getSize(find.byType(Scaffold)).width;
    Rect bar(String text) =>
        tester.getRect(find.ancestor(of: _copy(text), matching: find.byType(SlideTransition)).first);

    el.message.show('桌面', context: source, duration: Duration.zero);
    await tester.pumpAndSettle();
    mobile.value = true;
    await tester.pump();
    el.message.show('移动一', context: source, duration: Duration.zero);
    el.message.show('移动二', context: source, duration: Duration.zero);
    await tester.pumpAndSettle();
    expect(_copy('桌面'), findsNothing);
    expect(bar('移动一').top, 0);
    expect(bar('移动二').top, 0);
    expect(bar('移动二').width, width);

    mobile.value = false;
    await tester.pump();
    el.message.show('桌面二', context: source, duration: Duration.zero);
    await tester.pumpAndSettle();
    expect(_copy('移动一'), findsNothing);
    expect(_copy('移动二'), findsNothing);
    final desktop = tester.getRect(find.ancestor(of: _copy('桌面二'), matching: find.byType(Opacity)).first);
    expect(desktop.width, lessThan(width));
    expect(desktop.center.dx, moreOrLessEquals(width / 2));
    await _dispose(tester);
  });
}
