// 测试沿用项目内部相对路径约定。
// ignore_for_file: avoid_relative_lib_imports

// 官方手势原型：缩放视图只用官方识别器，贴边余量经祖先 ScrollPosition.drag 交给翻页。
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/src/pages/examples/official_gesture/zoom_pager.dart';
import '../lib/src/pages/examples/official_gesture/zoom_view.dart';

const _pageWidth = 400.0;

Future<(PageController, List<GlobalKey<OfficialZoomViewState>>)> _pump(
  WidgetTester tester, {
  double scale = 1,
  Offset offset = Offset.zero,
}) async {
  final controller = PageController();
  addTearDown(controller.dispose);
  final keys = List.generate(3, (_) => GlobalKey<OfficialZoomViewState>());
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: _pageWidth,
          height: 400,
          child: PageView(
            controller: controller,
            children: [
              for (var i = 0; i < 3; i++)
                OfficialZoomView(
                  key: keys[i],
                  initialScale: i == 0 ? scale : 1,
                  initialOffset: i == 0 ? offset : Offset.zero,
                  child: SizedBox.expand(child: ColoredBox(color: Color(0xFF000000 + i * 0x404040))),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  return (controller, keys);
}

void main() {
  testWidgets('已缩放贴右边缘：同一手势里图片 → 翻页 → 收回翻页 → 图片 → 再翻页，松手吸附回本页', (tester) async {
    // 2 倍缩放、右边缘可见：offset.dx 下限 = 400 * (1 - 2) = -400。
    final (controller, keys) = await _pump(tester, scale: 2, offset: Offset(-400, -200));
    final zoom = keys[0].currentState!;
    final center = tester.getCenter(find.byKey(keys[0]));
    var t = 0;
    Duration next() => Duration(milliseconds: t += 16);

    final gesture = await tester.startGesture(center);
    await gesture.moveBy(Offset(-30, 0), timeStamp: next());
    await tester.pump();
    final p0 = controller.position.pixels;
    expect(zoom.offset.dx, -400, reason: '右边缘无法继续左移，越过起手阈值后的余量交给翻页');

    await gesture.moveBy(Offset(-100, 0), timeStamp: next());
    await tester.pump();
    expect(controller.position.pixels, moreOrLessEquals(p0 + 100));
    expect(zoom.offset.dx, -400);

    // 反向：先收回翻页偏移，再平移图片。
    await gesture.moveBy(Offset(150, 0), timeStamp: next());
    await tester.pump();
    expect(controller.position.pixels, moreOrLessEquals(0));
    expect(zoom.offset.dx, moreOrLessEquals(-400 + 150 - (p0 + 100)));

    // 再次正向：图片先回到边缘，余量重新交给翻页。
    final imageRoom = zoom.offset.dx + 400;
    await gesture.moveBy(Offset(-80, 0), timeStamp: next());
    await tester.pump();
    expect(zoom.offset.dx, moreOrLessEquals(-400));
    expect(controller.position.pixels, moreOrLessEquals(80 - imageRoom));

    // 停住后再松手：速度为零，未过半页吸附回本页。
    await gesture.moveBy(Offset.zero, timeStamp: Duration(milliseconds: t += 300));
    await gesture.up(timeStamp: Duration(milliseconds: t += 16));
    await tester.pumpAndSettle();
    expect(controller.position.pixels, 0);
    expect(zoom.scale, 2, reason: '翻页交接不改变缩放');
  });

  testWidgets('已缩放贴右边缘快速左滑：松手速度交给翻页物理，翻到下一页', (tester) async {
    final (controller, keys) = await _pump(tester, scale: 2, offset: Offset(-400, -200));
    var t = 0;
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(keys[0])));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(Offset(-30, 0), timeStamp: Duration(milliseconds: t += 10));
      await tester.pump();
    }
    await gesture.up(timeStamp: Duration(milliseconds: t += 10));
    await tester.pumpAndSettle();
    expect(controller.position.pixels, _pageWidth);
    expect(controller.page, 1);
  });

  testWidgets('已缩放未贴边：先平移图片，到边缘后同一手势继续翻页', (tester) async {
    final (controller, keys) = await _pump(tester, scale: 2, offset: Offset(-300, -200));
    final zoom = keys[0].currentState!;
    var t = 0;
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(keys[0])));
    await gesture.moveBy(Offset(-30, 0), timeStamp: Duration(milliseconds: t += 16));
    await tester.pump();
    expect(controller.position.pixels, 0, reason: '图片尚有行程时翻页不动');
    final room = zoom.offset.dx + 400;

    await gesture.moveBy(Offset(-room - 50, 0), timeStamp: Duration(milliseconds: t += 16));
    await tester.pump();
    expect(zoom.offset.dx, moreOrLessEquals(-400));
    expect(controller.position.pixels, moreOrLessEquals(50));
    await gesture.up(timeStamp: Duration(milliseconds: t += 300));
    await tester.pumpAndSettle();
  });

  testWidgets('未缩放单指横滑：缩放视图不参与，官方翻页直接接手', (tester) async {
    final (controller, keys) = await _pump(tester);
    final zoom = keys[0].currentState!;
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(keys[0])));
    // PageView 使用 DragStartBehavior.start，越过起手阈值那次移动的位移不计入，需连续移动。
    for (var i = 0; i < 15; i++) {
      await gesture.moveBy(Offset(-20, 0));
      await tester.pump();
    }
    expect(controller.position.pixels, greaterThan(200));
    expect(zoom.scale, 1);
    expect(zoom.offset, Offset.zero, reason: '未缩放时单指位移全部交给翻页');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.page, 1);
  });

  testWidgets('双指同时起手捏合：缩放视图接手，翻页不动', (tester) async {
    final (controller, keys) = await _pump(tester);
    final center = tester.getCenter(find.byKey(keys[0]));
    final a = await tester.startGesture(center - Offset(50, 0), pointer: 1);
    final b = await tester.startGesture(center + Offset(50, 0), pointer: 2);
    for (var i = 0; i < 5; i++) {
      await a.moveBy(Offset(-10, 0));
      await b.moveBy(Offset(10, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(keys[0].currentState!.scale, greaterThan(1.5));
    expect(controller.position.pixels, 0);
  });

  testWidgets('已知降级：翻页先接住第一指后，第二指落下无法再接管为捏合', (tester) async {
    final (controller, keys) = await _pump(tester);
    final center = tester.getCenter(find.byKey(keys[0]));
    final a = await tester.startGesture(center - Offset(50, 0), pointer: 1);
    await a.moveBy(Offset(-20, 0));
    await a.moveBy(Offset(-20, 0));
    await tester.pump();
    expect(controller.position.pixels, greaterThan(0), reason: '第一指已被官方翻页识别器接受');

    final b = await tester.startGesture(center + Offset(50, 0), pointer: 2);
    for (var i = 0; i < 5; i++) {
      await b.moveBy(Offset(15, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(keys[0].currentState!.scale, 1, reason: '官方竞技场里第一指归属不可转移，捏合需双指同时起手');
  });

  testWidgets('示例页可在官方原型与当前 ElPreviewView 之间切换', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(home: OfficialZoomPagerPage()),
      ),
    );
    await tester.pump();
    expect(find.byType(OfficialZoomView), findsWidgets);
    expect(find.textContaining('1 / ${officialZoomPagerImages.length}'), findsOneWidget);

    await tester.drag(find.byType(PageView), Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 / ${officialZoomPagerImages.length}'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.byType(ElPreviewView), findsOneWidget);
    expect(find.byType(OfficialZoomView), findsNothing);
  });

  testWidgets('双击放大到目标倍数，再次双击还原', (tester) async {
    final (_, keys) = await _pump(tester);
    final zoom = keys[0].currentState!;
    final center = tester.getCenter(find.byKey(keys[0]));
    await tester.tapAt(center);
    await tester.pump(Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(zoom.scale, 2.5);
    await tester.pump(Duration(milliseconds: 500));
    await tester.tapAt(center);
    await tester.pump(Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(zoom.scale, 1);
    expect(zoom.offset, Offset.zero);
  });
}
