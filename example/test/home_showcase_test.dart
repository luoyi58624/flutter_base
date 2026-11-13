// ignore_for_file: avoid_relative_lib_imports
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/src/pages/home/index.dart';
import '../lib/src/pages/home/showcase/panel.dart';

Finder copy(String value) =>
    find.byWidgetPredicate((w) => w is Text && w.data == value || w is ElView && w.child == value);
Finder section(String id) =>
    find.byWidgetPredicate((widget) => widget is ShowcaseSection && widget.id == id, skipOffstage: false);
final capture = Platform.environment['HOME_SCREENSHOTS'] == '1';
final boundary = GlobalKey();

Future<void> host(
  WidgetTester tester, {
  double width = 390,
  double height = 900,
  bool dark = false,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ElView(
      themeMode: ElThemeMode(brightness: dark ? .dark : .light),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(key: boundary, child: HomePage()),
      ),
    ),
  );
  await tester.runAsync(() async {
    for (final asset in [
      'assets/showcase/lake.png',
      'assets/showcase/avatar-lan.png',
      'assets/recycler_cards/takeaway-food.webp',
    ]) {
      await precacheImage(AssetImage(asset), boundary.currentContext!);
    }
  });
  await tester.pump();
  await tester.pump(Duration(milliseconds: 600));
}

Future<void> reveal(WidgetTester tester, String id) async {
  final scope = tester.widget<ShowcaseScope>(find.byType(ShowcaseScope).first);
  scope.onNavigate(id);
  await tester.pump();
  // 定位布局完成后，下一帧为滚动动画建立起点。
  await tester.pump();
  await tester.pump(Duration(milliseconds: 400));
  await tester.pump();
}

Future<void> screenshot(WidgetTester tester, String name) async {
  if (!capture) return;
  await tester.runAsync(() async {
    final image = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/home-redesign');
    if (!dir.existsSync()) dir.createSync();
    await File('${dir.path}/flutter-$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

/// 截图与跨断点验证共用同一套文字和图标字形。
Future<void> loadShowcaseFonts() async {
  final icons = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  final font = File('C:/Windows/Fonts/msyh.ttc');
  if (font.existsSync()) {
    final loader = FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
    await loader.load();
  }
}

void main() {
  setUpAll(loadShowcaseFonts);
  testWidgets('完整首页手机、宽屏、暗色与大字无布局异常', (tester) async {
    debugDisableShadows = false;
    try {
      final report = FlutterError.onError!;
      FlutterError.onError = (details) {
        debugPrint(details.toString());
        report(details);
      };
      for (final config in [
        (390.0, false, 1.0, '390'),
        (1440.0, false, 1.0, '1440'),
        (390.0, true, 1.0, 'dark'),
        (320.0, false, 1.5, 'large'),
      ]) {
        debugPrint('布局检查：${config.$4}');
        await host(tester, width: config.$1, dark: config.$2, scale: config.$3);
        final initialSections = tester.widgetList<ShowcaseSection>(find.byType(ShowcaseSection, skipOffstage: false));
        expect(initialSections.every((section) => section.id == 'actions'), isTrue, reason: '首屏只挂载视口和缓存所需章节');
        expect(section('scenarios'), findsNothing);
        expect(tester.takeException(), isNull);
        await screenshot(tester, '${config.$4}-hero');
        for (final id in [
          'actions',
          'control-fields',
          'control-dates',
          'surface-cards',
          'feedback-prompts',
          'scenario-form',
          'takeaway',
        ]) {
          await reveal(tester, id);
          expect(tester.takeException(), isNull, reason: '${config.$4}: $id');
          await screenshot(tester, '${config.$4}-$id');
        }
        await tester.pumpWidget(SizedBox());
        await tester.pump(Duration(seconds: 4));
      }
    } finally {
      debugDisableShadows = true;
    }
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets('首次导航即可定位未挂载完整示例和外卖，宽度 $width', (tester) async {
      for (final id in ['scenarios', 'takeaway']) {
        await host(tester, width: width);
        final scope = tester.widget<ShowcaseScope>(find.byType(ShowcaseScope).first);
        expect(scope.anchors[id]!.currentContext, isNull);
        expect(section('controls'), findsNothing);
        expect(section('surfaces'), findsNothing);

        if (id == 'scenarios') {
          await tester.tap(find.byKey(ValueKey('showcase-chapters')));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(PopupMenuItem<String>, '完整示例'));
          await tester.pump();
          await tester.pump(Duration(milliseconds: 350));
        } else {
          final button = find.byWidgetPredicate((widget) => widget is ElButton && widget.child == '外卖示例');
          await tester.ensureVisible(button);
          await tester.pump();
          await tester.tap(button);
        }
        await tester.pump();
        await tester.pump();
        await tester.pump(Duration(milliseconds: 400));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final target = find.byKey(scope.anchors[id]!);
        expect(target, findsOneWidget);
        final scroll = find.byKey(ValueKey('showcase-scroll'));
        final position = tester.widget<ElScrollView>(scroll).controller!.position;
        final rect = tester.getRect(target);
        final location = '$id: offset=${position.pixels}, max=${position.maxScrollExtent}, target=$rect';
        expect(rect.overlaps(tester.getRect(scroll)), isTrue, reason: location);
        if (id == 'scenarios') {
          expect(rect.top, closeTo(tester.getRect(scroll).top + 20, 2), reason: location);
        } else {
          expect(find.byKey(ValueKey('home-takeaway-cart')).hitTestable(), findsOneWidget, reason: location);
        }
        expect(section('controls'), findsNothing, reason: '远跳不先构建经过的交互章节');
        expect(section('surfaces'), findsNothing, reason: '远跳不先构建经过的内容章节');
        await tester.pumpWidget(SizedBox());
        await tester.pump(Duration(seconds: 4));
      }
    });
  }

  testWidgets('章节定位、收藏、资料校验和外卖分类使用真实状态', (tester) async {
    await host(tester);
    await tester.tap(find.byKey(ValueKey('showcase-explore')));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 400));
    final scope = tester.widget<ShowcaseScope>(find.byType(ShowcaseScope).first);
    final scroll = find.byKey(ValueKey('showcase-scroll'));
    expect(tester.getTopLeft(find.byKey(scope.anchors['actions']!)).dy, closeTo(tester.getRect(scroll).top + 20, 2));
    await reveal(tester, 'actions-buttons');
    await tester.tap(find.byKey(ValueKey('showcase-favorite')));
    await tester.pump();
    expect(copy('已加入收藏'), findsWidgets);
    await tester.pump(Duration(seconds: 3));
    await tester.pump();
    await reveal(tester, 'feedback-state');
    final openShared = find.byWidgetPredicate((widget) => widget is ElButton && widget.child == '打开另一页');
    await tester.ensureVisible(openShared);
    await tester.pump();
    await tester.tap(openShared);
    await tester.pumpAndSettle();
    final sharedBar = find.widgetWithText(AppBar, '跨页共享状态');
    expect(sharedBar, findsOneWidget);
    await tester.tap(find.descendant(of: sharedBar, matching: find.byType(BackButton)));
    await tester.pumpAndSettle();
    await reveal(tester, 'scenario-form');
    await tester.ensureVisible(find.byKey(ValueKey('profile-save')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('profile-save')));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 400));
    expect(copy('请输入联系邮箱'), findsWidgets);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    ElForm.of(tester.element(find.byKey(ValueKey('profile-save')))).patch('email', 'demo@example.com');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(ValueKey('profile-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('profile-save')));
    await tester.pump();
    expect(tester.widget<ElButton>(find.byKey(ValueKey('profile-save'))).loading, isTrue);
    await tester.pump(Duration(seconds: 1));
    await tester.pump();
    expect(copy('小蓝同学，资料与偏好已在本页保存 · 第 1 次'), findsOneWidget);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(Duration(seconds: 3));
    await tester.pump();
    await reveal(tester, 'takeaway');
    final takeawayPosition = tester.widget<ElScrollView>(find.byKey(ValueKey('showcase-scroll'))).controller!.position;
    expect(
      find.byKey(ValueKey('home-takeaway-category-0')).hitTestable(),
      findsOneWidget,
      reason:
          'takeaway: offset=${takeawayPosition.pixels}, max=${takeawayPosition.maxScrollExtent}, '
          'category=${tester.getRect(find.byKey(ValueKey('home-takeaway-category-0')))}',
    );
    await tester.tap(find.byKey(ValueKey('home-takeaway-category-0')));
    await tester.pump();
    expect(copy('125 家'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('home-dish-0-0')));
    await tester.pump();
    final total = tester.widget<Text>(find.byKey(ValueKey('home-takeaway-total'))).data;
    expect(total, isNot('¥0.0'));
    await tester.tap(find.byKey(ValueKey('home-takeaway-cart')));
    await tester.pumpAndSettle();
    expect(find.byType(ElInputNumber).hitTestable(), findsOneWidget);
    final stepper = tester.widget<ElInputNumber>(find.byType(ElInputNumber).hitTestable());
    expect(stepper.value, 1);
    await tester.tapAt(Offset(8, 8));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
    await tester.pump(Duration(seconds: 4));
  });
}
