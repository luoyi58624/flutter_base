import 'package:example/src/layout/mobile/pages/2.dart';
import 'package:example/src/pages/components/basic/button/index.dart';
import 'package:example/src/pages/components/start/shadow/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('组件目录按第三项页面跳转，返回后仍显示目录', (tester) async {
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: Builder(
          builder: (context) => MaterialApp(theme: context.elMaterialThemeData, home: ComponentPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('component-quick-start')));
    await tester.pumpAndSettle();
    expect(find.byType(ComponentPage), findsOneWidget);
    expect(find.byType(ShadowPage), findsNothing);

    await tester.tap(find.byKey(ValueKey('component-shadow-design')));
    await tester.pumpAndSettle();
    expect(find.byType(ShadowPage), findsOneWidget);
    expect(find.widgetWithText(AppBar, '阴影'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ShadowPage), findsNothing);
    expect(find.byKey(ValueKey('component-shadow-design')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('移动目录沿用共用的按钮页面入口', (tester) async {
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: Builder(
          builder: (context) => MaterialApp(theme: context.elMaterialThemeData, home: ComponentPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('component-button')));
    // 示例含持续旋转的 loading，只等待页面过渡完成。
    await tester.pump();
    await tester.pump(Duration(milliseconds: 500));
    expect(find.byType(ButtonPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ButtonPage), findsNothing);
    expect(find.byKey(ValueKey('component-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
