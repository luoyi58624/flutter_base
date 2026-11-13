import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
  home: ElComponentProvider(
    components: el.mobileComponents,
    child: Scaffold(body: Center(child: child)),
  ),
);
Finder copy(String text) =>
    find.byWidgetPredicate((w) => w is Text && w.data == text || w is ElView && w.child == text);

void main() {
  testWidgets('提示随承载页面卸载取消计时，不访问已释放的 Overlay', (tester) async {
    Future<void>? closed;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => ElButton(
            key: ValueKey('toast'),
            child: '提示',
            onPressed: () => closed = el.toast(context, '保存成功', duration: Duration(seconds: 30)),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('toast')));
    await tester.pump();
    expect(find.byType(ElToast), findsOneWidget);
    await tester.pumpWidget(SizedBox());
    await tester.pump();
    await closed;
    await tester.pump(Duration(seconds: 31));
    expect(tester.takeException(), isNull);
  });
  testWidgets('固定高度的移动卡片将约束传给内嵌滚动内容', (tester) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 320,
          child: ElCard(
            style: ElStyle(height: 280),
            child: Column(
              children: [
                Text('标题'),
                Expanded(child: ListView(children: [for (var i = 0; i < 20; i++) Text('内容 $i')])),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ListView)).height, lessThan(280));
    await tester.drag(find.byType(ListView), Offset(0, -100));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('文字提示点击展示，禁用和事件阻止默认动作生效', (tester) async {
    await tester.pumpWidget(
      host(
        ElTooltip(
          content: '提示内容',
          child: ElButton(key: ValueKey('target'), child: '打开'),
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('target')));
    await tester.pumpAndSettle();
    expect(copy('提示内容'), findsOneWidget);
    await tester.tapAt(Offset(10, 10));
    await tester.pumpAndSettle();
    expect(copy('提示内容'), findsNothing);
    await tester.pumpWidget(
      host(
        ElTooltip(
          key: ValueKey('blocked'),
          content: '禁止提示',
          event: ElEvent(onTap: (e) => e.preventDefault()),
          child: ElButton(key: ValueKey('target'), child: '阻止'),
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('target')));
    await tester.pumpAndSettle();
    expect(copy('禁止提示'), findsNothing);
    await tester.pumpWidget(
      host(
        ElTooltip(
          key: ValueKey('disabled'),
          content: '禁用提示',
          disabled: true,
          child: ElButton(key: ValueKey('target'), child: '禁用'),
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('target')));
    await tester.pumpAndSettle();
    expect(copy('禁用提示'), findsNothing);
    await tester.pumpWidget(SizedBox());
    await tester.pump(Duration(seconds: 4));
  });

  testWidgets('四向抽屉贴合对应边缘，从遮罩起手也能跟手回弹', (tester) async {
    final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
    for (final (placement, delta) in [
      (ElPopupPlacement.left, Offset(-500, 0)),
      (ElPopupPlacement.right, Offset(500, 0)),
      (ElPopupPlacement.top, Offset(0, -500)),
      (ElPopupPlacement.bottom, Offset(0, 500)),
    ]) {
      Future<String?>? result;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => ElButton(
              key: ValueKey('open'),
              child: '打开',
              onPressed: () => result = el.drawer<String>(
                context,
                placement: placement,
                title: '抽屉',
                child: Text('内容'),
                footer: SizedBox(key: ValueKey('footer'), height: 30),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(ValueKey('open')));
      await tester.pumpAndSettle();
      final drawer = find.byType(ElDrawer);
      final frame = tester.getRect(drawer);
      expect(frame, switch (placement) {
        .left => Rect.fromLTWH(0, 0, 360, viewport.height),
        .right => Rect.fromLTWH(viewport.width - 360, 0, 360, viewport.height),
        .top => Rect.fromLTWH(0, 0, viewport.width, 420),
        .bottom => Rect.fromLTWH(0, viewport.height - 420, viewport.width, 420),
        .center => throw StateError('仅测试四个方向'),
      });
      expect(tester.getRect(find.byKey(ValueKey('footer'))).bottom, frame.bottom - 20);
      final outside = switch (placement) {
        .left => Offset(viewport.width - 8, frame.center.dy),
        .right => Offset(8, frame.center.dy),
        .top => Offset(frame.center.dx, viewport.height - 8),
        .bottom => Offset(frame.center.dx, 8),
        .center => throw StateError('仅测试四个方向'),
      };
      final shift = delta * .048;
      final shortDrag = await tester.startGesture(outside);
      await shortDrag.moveBy(shift);
      await tester.pump();
      expect(tester.getRect(drawer), frame.shift(shift));
      await shortDrag.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(drawer), frame);
      await tester.drag(drawer, delta);
      await tester.pumpAndSettle();
      expect(await result, isNull);
      expect(find.byType(ElDrawer), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
    }
  });

  testWidgets('底部面板可从两侧遮罩拖动，遮罩和模糊与位移逐帧同步', (tester) async {
    final tint = Color(0x80223658);
    final opener = find.byKey(ValueKey('open'));
    Future<void>? closed;
    await tester.pumpWidget(
      host(
        ElView(
          style: ElStyle(vars: {ElTokens.$overlayColor: tint, ElTokens.$overlayBackdropBlur: 4}),
          child: Builder(
            builder: (context) => ElButton(
              key: ValueKey('open'),
              child: '打开',
              onPressed: () => closed = el.popup<void>(context, showClose: false, child: SizedBox(height: 240)),
            ),
          ),
        ),
      ),
    );
    final popup = find.byType(ElPopup);
    final backdrop = find.byType(BackdropFilter);
    final shade = find.descendant(of: backdrop, matching: find.byType(ColoredBox));
    void expectBackdrop(double visible) {
      final sigma = 7 * visible;
      expect(tester.widget<BackdropFilter>(backdrop).filter, ImageFilter.blur(sigmaX: sigma, sigmaY: sigma));
      expect(tester.widget<ColoredBox>(shade).color.a, closeTo(tint.a * visible, 1e-9));
    }

    await tester.tap(opener);
    await tester.pump();
    final route = ModalRoute.of(tester.element(popup))!;
    for (final time in [Duration(milliseconds: 50), Duration(milliseconds: 75)]) {
      await tester.pump(time);
      expectBackdrop(Cubic(.174, 0, .185, 1).transform(route.animation!.value));
    }
    await tester.pumpAndSettle();
    final frame = tester.getRect(popup);
    expectBackdrop(1);

    final side = Offset(frame.left / 2, frame.center.dy);
    final shortDrag = await tester.startGesture(side);
    await shortDrag.moveBy(Offset(0, 30));
    await tester.pump();
    expect(tester.getRect(popup), frame.shift(Offset(0, 30)));
    expectBackdrop(.875);
    await shortDrag.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(popup), frame);
    expectBackdrop(1);

    final opposite = Offset(frame.right + 8, frame.center.dy);
    await tester.dragFrom(opposite, Offset(0, -110));
    await tester.pumpAndSettle();
    expect(tester.getRect(popup), frame);

    await tester.dragFrom(opposite, Offset(0, 110));
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    await closed;

    await tester.tap(opener);
    await tester.pumpAndSettle();
    await tester.tapAt(side);
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('面板从正文顶部向外滑动时跟手，正文有滚动空间时优先滚动', (tester) async {
    Future<void>? closed;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => ElButton(
            key: ValueKey('open'),
            child: '打开',
            onPressed: () => closed = el.popup<void>(
              context,
              title: '长内容',
              child: Column(children: [for (var i = 0; i < 30; i++) SizedBox(height: 40, child: Text('内容 $i'))]),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('open')));
    await tester.pumpAndSettle();
    final popup = find.byType(ElPopup);
    final frame = tester.getRect(popup);
    final scroll = find.descendant(of: popup, matching: find.byType(Scrollable));
    final position = tester.state<ScrollableState>(scroll).position;
    final point = tester.getCenter(scroll);

    position.jumpTo(160);
    await tester.pump();
    final contentDrag = await tester.startGesture(point);
    await contentDrag.moveBy(Offset(0, 60));
    await tester.pump();
    expect(position.pixels, lessThan(160));
    expect(tester.getRect(popup), frame);
    await contentDrag.cancel();
    await tester.pumpAndSettle();

    position.jumpTo(0);
    await tester.pump();
    final shortDrag = await tester.startGesture(point);
    await shortDrag.moveBy(Offset(0, 32));
    await tester.pump(Duration(milliseconds: 160));
    expect(tester.getTopLeft(popup).dy, closeTo(frame.top + 32, .01));
    expect(position.pixels, 0);
    await shortDrag.cancel();
    await tester.pumpAndSettle();
    expect(tester.getRect(popup), frame);

    final dismiss = await tester.startGesture(point);
    await dismiss.moveBy(Offset(0, 100));
    await tester.pump();
    await dismiss.up();
    await tester.pumpAndSettle();
    await closed;
    expect(popup, findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(ValueKey('open')));
    await tester.pumpAndSettle();
    final flick = await tester.createGesture();
    await flick.down(point, timeStamp: Duration(seconds: 1));
    await flick.moveBy(Offset(0, 30), timeStamp: Duration(milliseconds: 1020));
    await flick.up(timeStamp: Duration(milliseconds: 1025));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 230));
    await tester.pump();
    expect(popup, findsNothing);
    await closed;
  });

  testWidgets('底部面板限制宽度，避开键盘并沿用调用位置的遮罩颜色', (tester) async {
    final color = Color(0x80223658);
    tester.view.viewInsets = FakeViewPadding(bottom: 140 * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
    Future<String?>? result;
    await tester.pumpWidget(
      host(
        ElView(
          style: ElStyle(vars: {ElTokens.$overlayColor: color, ElTokens.$overlayBackdropBlur: 0}),
          child: Builder(
            builder: (context) => ElButton(
              key: ValueKey('open'),
              child: '打开',
              onPressed: () => result = el.popup<String>(
                context,
                title: '内容',
                draggable: false,
                dismissible: false,
                child: Builder(
                  builder: (context) => ElButton(child: '保存', onPressed: () => Navigator.of(context).pop('已保存')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('open')));
    await tester.pumpAndSettle();
    final popup = find.byType(ElPopup);
    final frame = tester.getRect(popup);
    expect(frame.width, 400);
    expect(frame.center.dx, viewport.width / 2);
    expect(frame.bottom, viewport.height - 140 - 16);
    final backdrop = find.byType(BackdropFilter);
    expect(tester.widget<BackdropFilter>(backdrop).enabled, isFalse);
    expect(
      find.descendant(of: backdrop, matching: find.byWidgetPredicate((w) => w is ColoredBox && w.color == color)),
      findsOneWidget,
    );
    await tester.tapAt(Offset(8, 8));
    await tester.pumpAndSettle();
    expect(popup, findsOneWidget);
    await tester.dragFrom(Offset(8, 8), Offset(0, 120));
    await tester.pumpAndSettle();
    expect(tester.getRect(popup), frame);
    await tester.tap(copy('保存'));
    await tester.pumpAndSettle();
    expect(await result, '已保存');
  });

  testWidgets('标题栏两侧操作宽度不同仍保持标题居中', (tester) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 390,
          child: ElAppBar(
            title: '收藏',
            back: true,
            actions: [
              ElButton(child: '搜索'),
              ElButton(child: '更多'),
            ],
          ),
        ),
      ),
    );
    final bar = tester.getRect(find.byType(ElAppBar));
    final title = tester.getRect(copy('收藏').last);
    expect(title.center.dx, closeTo(bar.center.dx, 1));
    expect(tester.takeException(), isNull);
  });
}
