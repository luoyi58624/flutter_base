import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt;
import 'package:flutter_base/src/flutter/widgets/popup/arrow.dart' show PopupArrow;
import 'package:flutter_test/flutter_test.dart';

Widget _app(ElComponents components, Widget child, {Alignment alignment = Alignment.center}) => MaterialApp(
  builder: (context, child) => ElComponentProvider(components: components, child: child!),
  home: Scaffold(
    body: Padding(
      padding: EdgeInsets.all(20),
      child: Align(alignment: alignment, child: child),
    ),
  ),
);

Widget _target([String label = '目标']) => SizedBox(
  key: ValueKey(label),
  width: 80,
  height: 32,
  child: Center(child: Text(label)),
);

Finder _copy(String text) =>
    find.byWidgetPredicate((w) => w is Text && w.data == text || w is ElView && w.child == text);

// 面板最外层是品牌的进退场淡入，尺寸与面板一致。
Rect _panel(WidgetTester tester, String text) =>
    tester.getRect(find.ancestor(of: _copy(text), matching: find.byType(FadeTransition)).first);

Future<TestGesture> _mouse(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset(1, 1));
  addTearDown(gesture.removePointer);
  return gesture;
}

void main() {
  group('桌面 tooltip', () {
    testWidgets('悬停满 waitDuration 才显示，移到提示上保持，离开后淡出', (tester) async {
      await tester.pumpWidget(
        _app(
          el.desktopComponents,
          ElTooltip(content: '提示文字', waitDuration: Duration(milliseconds: 300), child: _target()),
        ),
      );
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('目标')));
      await tester.pump(Duration(milliseconds: 200));
      expect(_copy('提示文字'), findsNothing);
      await tester.pump(Duration(milliseconds: 120));
      await tester.pumpAndSettle();
      expect(_copy('提示文字'), findsOneWidget);

      // 默认在上方，箭头占用间距。
      final target = tester.getRect(find.byKey(ValueKey('目标')));
      final panel = _panel(tester, '提示文字');
      expect(panel.bottom, closeTo(target.top - 10, .01));
      expect(panel.center.dx, closeTo(target.center.dx, .01));
      expect(find.byType(PopupArrow), findsOneWidget);

      await mouse.moveTo(panel.center);
      await tester.pump(Duration(milliseconds: 500));
      expect(_copy('提示文字'), findsOneWidget);

      await mouse.moveTo(Offset(5, 590));
      await tester.pump(Duration(milliseconds: 120));
      await tester.pumpAndSettle();
      expect(_copy('提示文字'), findsNothing);
    });

    testWidgets('快速掠过不显示；disabled 不显示；字符串内容写入语义', (tester) async {
      var disabled = false;
      late StateSetter setState;
      await tester.pumpWidget(
        _app(
          el.desktopComponents,
          StatefulBuilder(
            builder: (context, set) {
              setState = set;
              return ElTooltip(content: '提示文字', disabled: disabled, child: _target());
            },
          ),
        ),
      );
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.tooltip == '提示文字'), findsOneWidget);
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('目标')));
      await tester.pump(Duration(milliseconds: 100));
      await mouse.moveTo(Offset(5, 590));
      await tester.pump(Duration(seconds: 1));
      expect(_copy('提示文字'), findsNothing);

      setState(() => disabled = true);
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.text('目标')));
      await tester.pump(Duration(seconds: 1));
      expect(_copy('提示文字'), findsNothing);
    });

    testWidgets('下方空间不足时翻到上方，箭头随方位换边', (tester) async {
      ElOverlayAnchorGeometry? geometry;
      await tester.pumpWidget(
        _app(
          el.desktopComponents,
          ElTooltip(
            placement: .bottom,
            content: Builder(
              builder: (context) {
                geometry = ElPopup.geometryOf(context);
                return SizedBox(width: 60, height: 40);
              },
            ),
            child: _target(),
          ),
          alignment: Alignment.bottomCenter,
        ),
      );
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('目标')));
      await tester.pump(Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(geometry?.placement, ElPlacement.top);
      expect(geometry!.overlayRect.bottom, closeTo(tester.getRect(find.byKey(ValueKey('目标'))).top - 10, .01));
    });
  });

  group('移动 tooltip', () {
    testWidgets('点击显示 showDuration 后自动关闭，再次点击关闭，长按显示', (tester) async {
      await tester.pumpWidget(
        _app(el.mobileComponents, ElTooltip(content: '提示文字', showDuration: Duration(seconds: 2), child: _target())),
      );
      await tester.tap(find.text('目标'));
      await tester.pumpAndSettle();
      expect(_copy('提示文字'), findsOneWidget);
      await tester.pump(Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(_copy('提示文字'), findsNothing);

      await tester.tap(find.text('目标'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('目标'));
      await tester.pumpAndSettle();
      expect(_copy('提示文字'), findsNothing);

      await tester.longPress(find.text('目标'));
      await tester.pumpAndSettle();
      expect(_copy('提示文字'), findsOneWidget);
      await tester.pump(Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(_copy('提示文字'), findsNothing);
    });

    testWidgets('不响应鼠标悬停；目标所在列表滚动时关闭', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ElComponentProvider(components: el.mobileComponents, child: child!),
          home: Scaffold(
            body: ListView(
              children: [
                SizedBox(height: 200),
                Center(
                  child: ElTooltip(content: '提示文字', child: _target()),
                ),
                SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      );
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('目标')));
      await tester.pump(Duration(seconds: 1));
      expect(_copy('提示文字'), findsNothing);

      await tester.tap(find.text('目标'));
      await tester.pumpAndSettle();
      expect(_copy('提示文字'), findsOneWidget);
      await tester.drag(find.byType(ListView), Offset(0, -100));
      await tester.pumpAndSettle();
      expect(_copy('提示文字'), findsNothing);
    });
  });

  for (final (brand, components) in [('桌面', el.desktopComponents), ('移动', el.mobileComponents)]) {
    group('$brand popover', () {
      testWidgets('点击切换，显示标题与正文，内容可交互，外部点击关闭', (tester) async {
        final opened = <bool>[];
        var taps = 0;
        await tester.pumpWidget(
          _app(
            components,
            ElPopover(
              title: '标题',
              content: Column(
                mainAxisSize: .min,
                children: [
                  Text('正文'),
                  GestureDetector(onTap: () => taps++, child: Text('内部按钮')),
                ],
              ),
              onOpenChanged: opened.add,
              child: _target(),
            ),
          ),
        );
        await tester.tap(find.text('目标'));
        await tester.pumpAndSettle();
        expect(_copy('标题'), findsOneWidget);
        expect(find.text('正文'), findsOneWidget);

        final target = tester.getRect(find.byKey(ValueKey('目标')));
        final panel = _panel(tester, '标题');
        expect(panel.top, greaterThan(target.bottom));
        expect(panel.center.dx, closeTo(target.center.dx, .01));
        expect(find.byType(PopupArrow), findsOneWidget);

        await tester.tap(find.text('内部按钮'));
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(_copy('标题'), findsOneWidget);

        await tester.tapAt(Offset(5, 5));
        await tester.pumpAndSettle();
        expect(_copy('标题'), findsNothing);
        expect(opened, [true, false]);

        await tester.tap(find.text('目标'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('目标'));
        await tester.pumpAndSettle();
        expect(_copy('标题'), findsNothing);
      });

      testWidgets('控制器开闭；preventDefault 阻止点击打开；不显示箭头', (tester) async {
        final controller = ElPopupController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _app(
            components,
            ElPopover(
              content: '正文',
              controller: controller,
              showArrow: false,
              event: ElEvent(onTap: (e) => e.preventDefault()),
              child: _target(),
            ),
          ),
        );
        await tester.tap(find.text('目标'));
        await tester.pumpAndSettle();
        expect(_copy('正文'), findsNothing);

        controller.open();
        await tester.pumpAndSettle();
        expect(controller.isOpen, isTrue);
        expect(_copy('正文'), findsOneWidget);
        expect(find.byType(PopupArrow), findsNothing);
        controller.close();
        await tester.pumpAndSettle();
        expect(_copy('正文'), findsNothing);
      });

      testWidgets('悬停触发按 hoverIntent 延迟打开，移入卡片保持，离开后关闭', (tester) async {
        await tester.pumpWidget(
          _app(
            components,
            ElPopover(
              content: '正文',
              trigger: {.hover},
              hoverIntent: ElHoverIntent(
                openDelay: Duration(milliseconds: 300),
                closeDelay: Duration(milliseconds: 200),
              ),
              child: _target(),
            ),
          ),
        );
        final mouse = await _mouse(tester);
        await mouse.moveTo(tester.getCenter(find.text('目标')));
        await tester.pump(Duration(milliseconds: 250));
        expect(_copy('正文'), findsNothing);
        await tester.pump(Duration(milliseconds: 60));
        await tester.pumpAndSettle();
        expect(_copy('正文'), findsOneWidget);

        await mouse.moveTo(_panel(tester, '正文').center);
        await tester.pump(Duration(milliseconds: 400));
        expect(_copy('正文'), findsOneWidget);

        await mouse.moveTo(Offset(5, 590));
        await tester.pump(Duration(milliseconds: 210));
        await tester.pumpAndSettle();
        expect(_copy('正文'), findsNothing);
      });

      testWidgets('右侧放不下翻到左侧，宽度声明生效', (tester) async {
        await tester.pumpWidget(
          _app(
            components,
            ElPopover(content: '正文', placement: .right, width: 240, child: _target()),
            alignment: Alignment.centerRight,
          ),
        );
        await tester.tap(find.text('目标'));
        await tester.pumpAndSettle();
        final target = tester.getRect(find.byKey(ValueKey('目标')));
        final panel = _panel(tester, '正文');
        expect(panel.width, 240);
        expect(panel.right, lessThan(target.left));
        expect(panel.center.dy, closeTo(target.center.dy, .01));
      });
    });
  }
}
