import 'package:flutter_base/flutter_base.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('只依赖 el_flutter 即可访问稳定根导航 key、context 和 state', (tester) async {
    final key = el.navigatorKey;
    expect(el.navigatorKey, same(key));
    expect(() => el.context, throwsFlutterError);
    expect(() => el.navigatorState, throwsFlutterError);
    await tester.pumpWidget(
      WidgetsApp(
        navigatorKey: key,
        color: Color(0xff000000),
        onGenerateRoute: (_) =>
            PageRouteBuilder<void>(pageBuilder: (context, _, _) => SizedBox()),
      ),
    );
    expect(el.navigatorState, same(key.currentState));
    expect(el.context, same(key.currentContext));
    final result = el.navigatorState.push<String>(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, _, _) => SizedBox(key: ValueKey('next')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('next')), findsOneWidget);
    el.navigatorState.pop('done');
    await tester.pumpAndSettle();
    expect(await result, 'done');
    await tester.pumpWidget(SizedBox());
    expect(() => el.navigatorState, throwsFlutterError);
    expect(el.navigatorKey, same(key));
  });
}
