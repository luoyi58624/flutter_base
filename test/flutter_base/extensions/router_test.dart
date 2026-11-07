import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

class _MarkedTransitions extends PageTransitionsBuilder {
  @override
  Duration get transitionDuration => Duration(milliseconds: 123);

  @override
  Duration get reverseTransitionDuration => Duration(milliseconds: 79);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => KeyedSubtree(key: ValueKey('custom-transition'), child: child);
}

void main() {
  testWidgets('全局路由与上下文路由分别操作根栈和内层栈，并返回结果', (tester) async {
    late BuildContext innerContext;
    expect(() => el.router.canPop(), throwsFlutterError);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: el.navigatorKey,
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) {
              innerContext = context;
              return SizedBox(key: ValueKey('inner-home'));
            },
          ),
        ),
      ),
    );
    final inner = innerContext.elRouter;
    final innerResult = inner.pushPage<String>(SizedBox(key: ValueKey('inner-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('inner-next')), findsOneWidget);
    expect(el.router.canPop(), isFalse);
    expect(inner.canPop(), isTrue);
    inner.pop('inner');
    await tester.pumpAndSettle();
    expect(await innerResult, 'inner');

    final rootResult = el.router.pushPage<String>(SizedBox(key: ValueKey('root-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('root-next')), findsOneWidget);
    expect(el.router.canPop(), isTrue);
    expect(inner.canPop(), isFalse);
    el.router.pop('root');
    await tester.pumpAndSettle();
    expect(await rootResult, 'root');
    el.router.pop();
    expect(find.byKey(ValueKey('inner-home')), findsOneWidget);
  });

  testWidgets('页面便捷方法传递路由参数、使用指定过渡并返回替换结果', (tester) async {
    final previous = ElRouterServiceExt.instance;
    ElRouterServiceExt.instance = ElRouterService(pageTransitionsBuilder: _MarkedTransitions());
    addTearDown(() => ElRouterServiceExt.instance = previous);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: el.navigatorKey,
        home: SizedBox(key: ValueKey('home')),
      ),
    );

    final firstResult = el.router.pushPage<String>(
      SizedBox(key: ValueKey('first')),
      settings: RouteSettings(name: 'first', arguments: 42),
      fullscreenDialog: true,
      maintainState: false,
      allowSnapshotting: false,
    );
    await tester.pumpAndSettle();
    final route = ModalRoute.of(tester.element(find.byKey(ValueKey('first'))))! as PageRoute;
    expect(find.byKey(ValueKey('custom-transition')), findsOneWidget);
    expect(route.settings.name, 'first');
    expect(route.settings.arguments, 42);
    expect(route.fullscreenDialog, isTrue);
    expect(route.maintainState, isFalse);
    expect(route.allowSnapshotting, isFalse);
    expect(route.transitionDuration, Duration(milliseconds: 123));
    expect(route.reverseTransitionDuration, Duration(milliseconds: 79));

    final replacement = el.router.pushReplacementPage<int, String>(
      SizedBox(key: ValueKey('replacement')),
      result: 'replaced',
    );
    await tester.pumpAndSettle();
    expect(await firstResult, 'replaced');
    final last = el.router.pushPageAndRemoveUntil<int>(SizedBox(key: ValueKey('last')), (route) => route.isFirst);
    await tester.pumpAndSettle();
    expect(await replacement, isNull);
    expect(find.byKey(ValueKey('last')), findsOneWidget);
    el.router.popAll();
    await tester.pumpAndSettle();
    expect(await last, isNull);
    expect(find.byKey(ValueKey('home')), findsOneWidget);
    expect(el.router.canPop(), isFalse);
  });
}
