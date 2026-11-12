// 测试沿用项目内部相对路径约定。
// ignore_for_file: avoid_relative_lib_imports

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/src/pages/examples/preview/index.dart';

class _Routes extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}

Future<void> _pumpPage(WidgetTester tester, {bool desktop = false, NavigatorObserver? observer}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = desktop ? Size(1100, 800) : Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(home: PreviewPage(), navigatorObservers: [?observer]),
    ),
  );
  await tester.pump();
  // 真实解码不在 fake-async 中推进，预热后再验证动画和手势。
  await tester.runAsync(() async {
    final context = tester.element(find.byType(PreviewPage));
    for (final src in previewImages.toSet()) {
      await precacheImage(ElImageView(src).image, context);
    }
  });
}

void main() {
  testWidgets('保留图片点击事件并尊重 preventDefault，入口卸载同时释放覆盖层', (tester) async {
    await _pumpPage(tester);
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    var prevented = true;
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: visible,
          builder: (context, show, _) => Center(
            child: show
                ? ElImagePreview(
                    key: ValueKey('entry'),
                    child: ElImageView(
                      previewImages.first,
                      width: 120,
                      height: 80,
                      event: ElEvent(
                        onTap: (event) {
                          taps++;
                          if (prevented) event.preventDefault();
                        },
                      ),
                    ),
                  )
                : SizedBox(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('entry')));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.byType(ElPreviewView), findsNothing);
    prevented = false;
    await tester.tap(find.byKey(ValueKey('entry')));
    await tester.pumpAndSettle();
    expect(taps, 2);
    expect(find.byType(ElPreviewView), findsOneWidget);
    visible.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(ElPreviewView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('覆盖层不增加路由，系统返回仅关闭预览并恢复缩略图', (tester) async {
    final routes = _Routes();
    await _pumpPage(tester, observer: routes);
    final pushes = routes.pushes;
    await tester.tap(find.byKey(ValueKey('preview-thumb-0')));
    await tester.pumpAndSettle();
    expect(routes.pushes, pushes);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ElPreviewView), findsNothing);
    expect(find.byType(PreviewPage), findsOneWidget);
    final opacity = find.descendant(of: find.byKey(ValueKey('preview-thumb-0')), matching: find.byType(Opacity));
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Windows 工具栏切图旋转，滚轮缩放与鼠标拖拽，Esc 关闭', (tester) async {
    await _pumpPage(tester, desktop: true);
    await tester.tap(find.byKey(ValueKey('preview-thumb-0')));
    await tester.pumpAndSettle();
    final preview = tester.widget<ElPreviewView>(find.byType(ElPreviewView));
    final controller = preview.controller!;
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left)).onPressed, isNull);
    await tester.tap(find.byTooltip('下一张'));
    await tester.pumpAndSettle();
    expect(controller.index, 1);
    await tester.tap(find.byTooltip('向右旋转'));
    await tester.pumpAndSettle();
    expect(controller.rotation, closeTo(math.pi / 2, 0.001));
    await tester.tap(find.byTooltip('还原'));
    await tester.pumpAndSettle();
    expect(controller.rotation, 0);
    final center = tester.getCenter(find.byType(ElPreviewView));
    await tester.sendEventToBinding(
      PointerScrollEvent(position: center, scrollDelta: Offset(0, -300), kind: PointerDeviceKind.mouse),
    );
    await tester.pumpAndSettle();
    expect(controller.scale, greaterThan(1));
    final gesture = await tester.startGesture(center, kind: PointerDeviceKind.mouse);
    await gesture.moveBy(Offset(60, 40));
    await gesture.moveBy(Offset(50, 30));
    expect(controller.translation.distance, greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ElPreviewView), findsNothing);
    for (final opacity in tester.widgetList<Opacity>(
      find.descendant(of: find.byType(ElImagePreview), matching: find.byType(Opacity)),
    )) {
      expect(opacity.opacity, 1);
    }
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('缩略图打开画廊，横滑切到下一张，计数栏随当前项更新', (tester) async {
    await _pumpPage(tester);
    await tester.tap(find.byKey(ValueKey('preview-thumb-1')));
    await tester.pumpAndSettle();
    expect(find.byType(ElPreviewView), findsOneWidget);
    expect(find.text('2 / ${previewImages.length}'), findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElPreviewView)));
    for (var i = 0; i < 15; i++) {
      await gesture.moveBy(Offset(-20, 0), timeStamp: Duration(milliseconds: i * 16));
    }
    await gesture.moveBy(Offset.zero, timeStamp: Duration(milliseconds: 600));
    await gesture.up(timeStamp: Duration(milliseconds: 616));
    await tester.pumpAndSettle();
    expect(find.text('3 / ${previewImages.length}'), findsOneWidget);
  });

  testWidgets('单击切换外观，下拉超过阈值关闭画廊', (tester) async {
    await _pumpPage(tester);
    await tester.tap(find.byKey(ValueKey('preview-thumb-0')));
    await tester.pumpAndSettle();
    final center = tester.getCenter(find.byType(ElPreviewView));

    await tester.tapAt(center);
    await tester.pump(Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 0);

    final gesture = await tester.startGesture(center);
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(0, 20), timeStamp: Duration(milliseconds: i * 16));
    }
    await gesture.moveBy(Offset.zero, timeStamp: Duration(milliseconds: 600));
    await gesture.up(timeStamp: Duration(milliseconds: 616));
    await tester.pumpAndSettle();
    expect(find.byType(ElPreviewView), findsNothing);
    expect(find.byKey(ValueKey('preview-thumb-0')), findsOneWidget);
  });
}
