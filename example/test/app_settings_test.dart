import 'package:example/main.dart';
import 'package:example/src/pages/settings/index.dart';
import 'package:example/src/router/index.dart';
import 'package:example/src/state/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugRepaintRainbowEnabled;
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('分组设置实际更新应用主题、语言、方向、文字和诊断开关', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(1440, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    routingConfig.isMobile = false;
    router.go('/settings');
    await tester.pumpWidget(App());
    await tester.pumpAndSettle();
    final page = find.byType(SettingPage);
    expect(page, findsOneWidget);
    final groups = tester.widgetList<ElListGroup>(find.byType(ElListGroup)).map((group) => group.title);
    expect(groups, containsAll(['主题与外观', '文字与缩放', '语言与方向', '动画', '性能与调试', '文档与滚动']));

    GlobalState.primaryColor.value = Color(0xff16a34a);
    GlobalState.globalScale.value = 1.2;
    GlobalState.globalFontWeight.value = 600;
    GlobalState.locale.value = Locale('zh', 'CN');
    GlobalState.rtl.value = true;
    GlobalState.closeAnimation.value = true;
    GlobalState.showFps.value = true;
    await tester.pumpAndSettle();
    var context = tester.element(page);
    expect(context.elTheme.primary, Color(0xff16a34a));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(MediaQuery.textScalerOf(context).scale(20), 24);
    expect(MediaQuery.disableAnimationsOf(context), isTrue);
    expect(Theme.of(context).textTheme.bodyMedium!.fontWeight, FontWeight.w600);
    expect(MaterialLocalizations.of(context).cancelButtonLabel, '取消');
    expect(find.byType(ElFps), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeAnimationDuration, Duration.zero);

    GlobalState.darkPrimaryColor.value = Color(0xffea580c);
    GlobalState.isDark.value = true;
    await tester.pumpAndSettle();
    context = tester.element(page);
    expect(context.elTheme.primary, Color(0xffea580c));
    GlobalState.slowAnimation.value = true;
    expect(timeDilation, 2);
    GlobalState.slowAnimation.value = false;
    expect(timeDilation, 1);
    GlobalState.enabledRepaintRainbow.value = true;
    expect(debugRepaintRainbowEnabled, isTrue);
    GlobalState.enabledRepaintRainbow.value = false;
    GlobalState.showFps.value = false;
    await tester.pump();
    expect(find.byType(ElFps), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
    await tester.pump(Duration(seconds: 1));
  });
}
