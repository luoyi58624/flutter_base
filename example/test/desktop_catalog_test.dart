import 'package:example/main.dart';
import 'package:example/src/layout/index.dart';
import 'package:example/src/pages/components/basic/button/index.dart';
import 'package:example/src/pages/components/catalog.dart';
import 'package:example/src/pages/components/start/shadow/index.dart';
import 'package:example/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart' show ElNavMenu;
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _navLabel(String label) => find.descendant(
  of: find.byType(ElNavMenu<WidgetBuilder>),
  matching: find.byWidgetPredicate((widget) => widget is ElView && widget.child == label),
);

Future<void> _host(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(1280, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  GlobalState.boottomTabbarIndex.value = 1;
  addTearDown(() => GlobalState.boottomTabbarIndex.value = 0);
  await tester.pumpWidget(App());
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String label, {bool settle = true}) async {
  final row = find
      .ancestor(
        of: _navLabel(label),
        matching: find.byWidgetPredicate((widget) => widget is ElView && widget.event?.onTap != null),
      )
      .first;
  await tester.tap(row);
  await tester.pump(Duration(milliseconds: 250));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(Duration(milliseconds: 300));
  }
}

void main() {
  test('桌面组件直接复用移动目录，页面与 tab 映射覆盖所有条目并排除分组', () {
    expect(AppLayout.menus.map((menu) => menu.title), ['首页', '组件', '示例', '设置']);
    expect(AppLayout.menus[1].children, same(componentCatalog));
    expect(componentCatalog.map((group) => group.title), ['开始使用', '基础组件', '表单组件', '布局与容器', '列表组件', '数据展示', '反馈组件']);
    final pageKeys = AppLayout.pages.map((page) => page.key).toList();
    expect(pageKeys.toSet().length, pageKeys.length);
    expect(AppLayout.pages.every((page) => !page.group && page.children.isEmpty), isTrue);
    for (final group in componentCatalog) {
      for (final item in group.children) {
        expect(pageKeys, contains(item.key));
        expect(AppLayout.menuTabs[item.key], 1);
      }
    }
    expect(AppLayout.tabKeyOf(1), 'quick-start');
    expect(AppLayout.tabKeyOf(2), 'view');
    expect(pageKeys, isNot(contains('component-overview')));
  });

  testWidgets('桌面展开真实目录，按需在右侧打开共用页面，切换后保留页面状态', (tester) async {
    await _host(tester);
    expect(_navLabel('开始使用'), findsOneWidget);
    expect(_navLabel('基础组件'), findsOneWidget);
    expect(_navLabel('Button 按钮'), findsOneWidget);
    expect(find.byType(ShadowPage, skipOffstage: false), findsNothing);
    expect(find.byType(ButtonPage, skipOffstage: false), findsNothing);
    await _select(tester, '阴影设计');
    final shadowElement = tester.element(find.byType(ShadowPage));
    expect(GlobalState.boottomTabbarIndex.value, 1);
    expect(Navigator.of(shadowElement).canPop(), isFalse);
    tester.widget<ElSlider<double>>(find.byKey(ValueKey('shadow-width'))).currentValue = 240;
    await tester.pumpAndSettle();
    expect(tester.widget<ElCardView>(find.byKey(ValueKey('shadow-preview'))).style!.width, 240);
    await _select(tester, '首页');
    expect(GlobalState.boottomTabbarIndex.value, 0);
    await _select(tester, '阴影设计');
    expect(tester.element(find.byType(ShadowPage)), same(shadowElement));
    expect(tester.widget<ElCardView>(find.byKey(ValueKey('shadow-preview'))).style!.width, 240);
    expect(find.byType(ButtonPage, skipOffstage: false), findsNothing);
    // 按钮页演示持续旋转的 loading，等待有限帧即可验证路由。
    await _select(tester, 'Button 按钮', settle: false);
    expect(find.byType(ButtonPage), findsOneWidget);
    expect(GlobalState.boottomTabbarIndex.value, 1);
    await _select(tester, '首页', settle: false);
    expect(GlobalState.boottomTabbarIndex.value, 0);
    expect(find.byKey(ValueKey('example-page-home')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('未实现的条目可选中但只显示空页面，外部切换 tab 不丢失目录选中项', (tester) async {
    await _host(tester);
    // 表单项位于长菜单下方，通过菜单绑定模拟选择，独立验证页面与 tab 的联动。
    tester.widget<ElNavMenu<WidgetBuilder>>(find.byType(ElNavMenu<WidgetBuilder>)).onChanged!('slider');
    await tester.pumpAndSettle();
    final page = find.byKey(ValueKey('example-page-slider'));
    expect(page, findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Slider 滑块'), findsOneWidget);
    expect(GlobalState.boottomTabbarIndex.value, 1);
    expect(find.byType(ShadowPage, skipOffstage: false), findsNothing);
    GlobalState.boottomTabbarIndex.value = 0;
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '首页'), findsOneWidget);
    GlobalState.boottomTabbarIndex.value = 1;
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Slider 滑块'), findsOneWidget);
    expect(tester.widget<ElNavMenu<WidgetBuilder>>(find.byType(ElNavMenu<WidgetBuilder>)).value, 'slider');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
