// 应用内部文件沿用相对路径约定。
// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart' show ElBottomTabbar;
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';
import '../lib/src/pages/components/basic/button/index.dart';
import '../lib/src/pages/examples.dart';
import '../lib/src/pages/examples/index.dart';
import '../lib/src/pages/view/base.dart';
import '../lib/src/router/index.dart';
import '../lib/src/router/pages.dart';
import '../lib/src/utils/router.dart';

void main() {
  testWidgets('启动深度链接直达按钮页，运行中接收链接且两端覆盖全部目录页面', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    tester.platformDispatcher.defaultRouteNameTestValue = 'flutter-base://example/components/button?source=adb#basic';
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(App());
    await tester.pumpAndSettle();
    expect(find.byType(ButtonPage), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/components/button');
    expect(router.routeInformationProvider.value.uri.query, 'source=adb');
    expect(router.routeInformationProvider.value.uri.fragment, 'basic');
    expect(find.byType(ElBottomTabbar), findsNothing);

    await router.routeInformationProvider.didPushRouteInformation(
      RouteInformation(uri: Uri.parse('flutter-base://example/examples/base')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ViewBasePage), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/examples/base');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ExamplesPage), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/examples');

    final paths = [
      for (final page in navigationPages) '/${page.key}',
      for (final page in RouterUtil.pages) '/components/${page.key}',
      for (final page in advancedExamples) '/examples/${page.key}',
    ];
    for (final width in [390.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      for (final path in paths) {
        final matches = router.configuration.findMatch(Uri.parse('flutter-base://example$path'));
        expect(matches.isError, isFalse, reason: '$width 下的 $path 应能直接匹配');
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
