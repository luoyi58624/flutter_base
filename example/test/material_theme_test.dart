import 'package:example/main.dart';
import 'package:example/src/mobile/app.dart';
import 'package:example/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('当前入口使用移动主题生成 Material 样式，路由沿用主题', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    GlobalState.boottomTabbarIndex.value = 0;
    await tester.pumpWidget(App());
    await tester.pumpAndSettle();
    expect(find.byType(ElMobileTheme), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, ElMobileTheme.lightVars[ElTheme.$primary]);
    final context = tester.element(find.byType(AppBar));
    expect(Theme.of(context).appBarTheme.backgroundColor, context.elTheme.cardColor);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => Scaffold(body: Text('新路由'))));
    await tester.pumpAndSettle();
    final routeContext = tester.element(find.text('新路由'));
    expect(Theme.of(routeContext).colorScheme.primary, routeContext.elTheme.primary);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('旧入口的官方样式与同一份 ElView 主题保持一致', (tester) async {
    await tester.pumpWidget(ElExampleApp(networkDelay: Duration.zero, replyDelay: Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byType(ElMobileTheme), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final context = tester.element(find.byType(Navigator).first);
    expect(app.theme!.colorScheme.primary, context.elTheme.primary);
    expect(app.theme!.textTheme.bodyMedium!.fontWeight, FontWeight.w400);
    expect(app.theme!.textTheme.bodyMedium!.fontVariations, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
