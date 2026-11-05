import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart'
    show InkRipple, Material, Theme, ThemeData, ColorScheme, ButtonStyle, TextButton, OutlinedButton, ElevatedButton;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ElRenderView button(WidgetTester tester) => tester.renderObject<ElRenderView>(find.byType(ElButtonView));

  Widget build({
    VoidCallback? onPressed,
    bool disabled = false,
    ElStyle? style,
    FocusNode? focusNode,
    Object? child,
    Color color = const Color(0xff204080),
  }) => Directionality(
    textDirection: .ltr,
    child: ElView(
      style: ElStyle(alignment: .center, color: color),
      child: ElRippleTap(
        onPressed: onPressed,
        disabled: disabled,
        semanticLabel: '波纹按钮',
        focusNode: focusNode,
        style: style ?? ElStyle(width: 120, height: 60, padding: .all(12), alignment: .center),
        child: child ?? '点击',
      ),
    ),
  );

  testWidgets('悬停为 currentColor 的 8%，离开即消失且不生成波纹', (tester) async {
    await tester.pumpWidget(build());
    final mouse = await tester.createGesture(kind: .mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(ElRippleTap)));
    await tester.pump();
    expect(button(tester), paints..rect(rect: Rect.fromLTWH(0, 0, 120, 60), color: Color(0x14204080)));
    expect(button(tester), paintsExactlyCountTimes(#drawCircle, 0));

    await tester.pumpWidget(build(color: Color(0xff80a0c0)));
    expect(button(tester), paints..rect(color: Color(0x1480a0c0)));
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(button(tester), paintsExactlyCountTimes(#drawRect, 0));
    await mouse.removePointer();
  });

  testWidgets('纯 Widget 内容的波纹继承并跟随文字色', (tester) async {
    Widget shell(Color color) => build(
      color: color,
      style: ElStyle(width: 120, height: 60),
      child: ElView(child: '点击'),
    );
    await tester.pumpWidget(shell(Color(0xff204080)));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElRippleTap)));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 100));
    expect(button(tester), paints..circle(color: Color(0x1a204080)));
    await tester.pumpWidget(shell(Color(0xff80a0c0)));
    expect(button(tester), paints..circle(color: Color(0x1a80a0c0)));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final foreground in [Color(0xff204080), Color(0x80204080), Color(0x00204080)]) {
      testWidgets('反馈颜色跟随官方 M2 按钮：$brightness，前景色 $foreground', (tester) async {
        late List<ButtonStyle> defaults;
        await tester.pumpWidget(
          Theme(
            data: ThemeData(
              useMaterial3: false,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Color(0xff204080),
                brightness: brightness,
              ).copyWith(primary: foreground, onPrimary: foreground),
            ),
            child: Builder(
              builder: (context) {
                defaults = [
                  TextButton(onPressed: () {}, child: ElView()).defaultStyleOf(context),
                  OutlinedButton(onPressed: () {}, child: ElView()).defaultStyleOf(context),
                  ElevatedButton(onPressed: () {}, child: ElView()).defaultStyleOf(context),
                ];
                return build(onPressed: () {}, color: foreground);
              },
            ),
          ),
        );
        final hovered = defaults.first.overlayColor!.resolve({WidgetState.hovered})!;
        final pressed = defaults.first.overlayColor!.resolve({WidgetState.pressed})!;
        for (final style in defaults) {
          expect(style.splashFactory, same(InkRipple.splashFactory));
          expect(style.overlayColor!.resolve({WidgetState.hovered}), hovered);
          expect(style.overlayColor!.resolve({WidgetState.pressed}), pressed);
          expect(style.overlayColor!.resolve({WidgetState.focused}), pressed);
        }

        final mouse = await tester.createGesture(kind: .mouse);
        await mouse.addPointer(location: Offset.zero);
        final center = tester.getCenter(find.byType(ElRippleTap));
        await mouse.moveTo(center);
        await tester.pump();
        expect(button(tester), paints..rect(color: hovered));
        await mouse.down(center);
        await tester.pump();
        await tester.pump(Duration(milliseconds: 100));
        expect(_circleOf(button(tester)).color.toARGB32(), pressed.toARGB32(), reason: '官方用状态 alpha 覆盖原色，不额外乘以前景透明度');
        await mouse.up();
        await tester.pumpAndSettle();
        await mouse.removePointer();
      });
    }
  }

  testWidgets('小按钮快速点击后 225ms 仍保持波纹，随后 150ms 淡出', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      build(
        onPressed: () => taps++,
        style: ElStyle(width: 64, height: 32, padding: .all(4), margin: .all(10), alignment: .center),
      ),
    );
    final render = button(tester);
    final gesture = await tester.startGesture(render.localToGlobal(render.boxOrigin + Offset(4, 8)));
    await tester.pump();
    expect(render, paints..circle(x: 4, y: 8, color: Color(0x00204080)));
    expect(taps, 0);
    await gesture.up();
    await tester.pump();
    expect(taps, 1);
    await tester.pump(Duration(milliseconds: 75));
    expect(render, paints..circle(color: Color(0x1a204080)));
    final intermediate = _circleOf(render);
    expect(intermediate.center.dx, inExclusiveRange(4, 32));
    expect(intermediate.radius, lessThan(Offset(64, 32).distance / 2 + 5));
    await tester.pump(Duration(milliseconds: 150));
    expect(render, paints..circle(x: 32, y: 16, color: Color(0x1a204080)));
    await tester.pump(Duration(milliseconds: 75));
    expect(render, paints..circle(color: Color(0x0d204080)));
    await tester.pumpAndSettle();
    expect(render, paintsExactlyCountTimes(#drawCircle, 0));
  });

  for (final size in [Size(64, 32), Size(240, 64)]) {
    for (final canceled in [false, true]) {
      testWidgets('与官方 InkRipple 逐帧一致：size=$size，cancel=$canceled', (tester) async {
        final materialKey = GlobalKey();
        final referenceKey = GlobalKey();
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: ElView(
              style: ElStyle(alignment: .center),
              child: Row(
                mainAxisSize: .min,
                children: [
                  ElRippleTap(
                    onPressed: () {},
                    style: ElStyle(width: size.width, height: size.height, color: Color(0xff204080)),
                    child: '按钮',
                  ),
                  Material(
                    key: materialKey,
                    child: ElView(
                      key: referenceKey,
                      style: ElStyle(width: size.width, height: size.height),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        final position = Offset(6, 8);
        final actual = button(tester);
        final gesture = await tester.startGesture(actual.localToGlobal(position));
        var removed = false;
        final reference = InkRipple(
          controller: Material.of(tester.element(find.byKey(referenceKey))),
          referenceBox: tester.renderObject<RenderBox>(find.byKey(referenceKey)),
          position: position,
          color: TextButton.styleFrom(foregroundColor: Color(0xff204080)).overlayColor!.resolve({WidgetState.pressed})!,
          textDirection: .ltr,
          containedInkWell: true,
          onRemoved: () => removed = true,
        );
        addTearDown(() {
          if (!removed) reference.dispose();
        });
        void compareFrame() {
          if (removed) {
            expect(actual, paintsExactlyCountTimes(#drawCircle, 0));
            return;
          }
          final expected = _circleOf(tester.renderObject(find.byKey(materialKey)));
          final current = _circleOf(actual);
          expect(current.center.dx, closeTo(expected.center.dx, 0.000001));
          expect(current.center.dy, closeTo(expected.center.dy, 0.000001));
          expect(current.radius, closeTo(expected.radius, 0.000001));
          expect(current.color, expected.color);
        }

        await tester.pump();
        compareFrame();
        for (final elapsed in [20, 55, 40]) {
          await tester.pump(Duration(milliseconds: elapsed));
          compareFrame();
        }
        if (canceled) {
          await gesture.cancel();
          reference.cancel();
        } else {
          await gesture.up();
          reference.confirm();
        }
        await tester.pump();
        compareFrame();
        for (final elapsed in [30, 50, 100, 45, 75, 76]) {
          await tester.pump(Duration(milliseconds: elapsed));
          compareFrame();
        }
        expect(removed, isTrue);
      });
    }
  }

  testWidgets('快速连点保留各自波纹，取消不触发点击', (tester) async {
    var taps = 0;
    await tester.pumpWidget(build(onPressed: () => taps++));
    await tester.tap(find.byType(ElRippleTap));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 30));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElRippleTap)));
    await tester.pump();
    expect(button(tester), paintsExactlyCountTimes(#drawCircle, 2));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(button(tester), paintsExactlyCountTimes(#drawCircle, 0));
  });

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    for (final outsideDelay in [Duration.zero, Duration(milliseconds: 100)]) {
      testWidgets('同次按压移回直接恢复最终态：$kind，离开 $outsideDelay', (tester) async {
        var taps = 0;
        await tester.pumpWidget(build(onPressed: () => taps++));
        final center = tester.getCenter(find.byType(ElRippleTap));
        final gesture = await tester.startGesture(center, kind: kind);
        await tester.pump();
        await tester.pump(Duration(milliseconds: 40));
        final finalRadius = Offset(120, 60).distance / 2 + 5;
        expect(_circleOf(button(tester)).radius, lessThan(finalRadius));

        for (var i = 0; i < 2; i++) {
          await gesture.moveTo(center + Offset(150, 0));
          await tester.pump();
          await tester.pump(outsideDelay);
          if (outsideDelay > Duration.zero) expect(button(tester), paintsExactlyCountTimes(#drawCircle, 0));
          await gesture.moveTo(center + Offset(20, 0));
          await tester.pump();
          expect(button(tester), paintsExactlyCountTimes(#drawCircle, 1));
          expect(button(tester), paints..circle(x: 60, y: 30, radius: finalRadius, color: Color(0x1a204080)));
          await tester.pump(Duration(milliseconds: 200));
          expect(button(tester), paints..circle(x: 60, y: 30, radius: finalRadius, color: Color(0x1a204080)));
          expect(tester.binding.transientCallbackCount, 0);
          expect(taps, 0);
        }

        await gesture.up();
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(button(tester), paintsExactlyCountTimes(#drawCircle, 0));
        final next = await tester.startGesture(center, kind: kind);
        await tester.pump();
        expect(_circleOf(button(tester)).radius, lessThan(finalRadius));
        await next.cancel();
        await tester.pumpAndSettle();
      });
    }
  }

  for (final cancel in [false, true]) {
    testWidgets('移出后${cancel ? '取消' : '松手'}再移回不恢复按压态', (tester) async {
      var taps = 0;
      await tester.pumpWidget(build(onPressed: () => taps++));
      final center = tester.getCenter(find.byType(ElRippleTap));
      final gesture = await tester.startGesture(center, kind: .mouse);
      await tester.pump();
      await tester.pump(Duration(milliseconds: 40));
      await gesture.moveTo(center + Offset(150, 0));
      if (cancel) {
        await gesture.cancel();
      } else {
        await gesture.up();
      }
      await gesture.moveTo(center);
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(button(tester), paintsExactlyCountTimes(#drawCircle, 0));
      await gesture.down(center);
      await tester.pump();
      expect(_circleOf(button(tester)).radius, lessThan(Offset(120, 60).distance / 2 + 5));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  }

  testWidgets('圆角与文本色在动画中动态更新，波纹始终留在按钮盒内', (tester) async {
    ElStyle style(double radius) => ElStyle(
      width: 120,
      height: 60,
      padding: .all(12),
      alignment: .center,
      borderRadius: .all(Radius.circular(radius)),
    );
    await tester.pumpWidget(build(style: style(12)));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElRippleTap)));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 100));
    expect(
      button(tester),
      paints..clipRRect(rrect: RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 120, 60), Radius.circular(12))),
    );
    await tester.pumpWidget(build(style: style(24), color: Color(0xff80a0c0)));
    expect(
      button(tester),
      paints
        ..clipRRect(rrect: RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 120, 60), Radius.circular(24)))
        ..circle(color: Color(0x1a80a0c0)),
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('波纹尊重直接子 ElView 的圆角和盒位置', (tester) async {
    await tester.pumpWidget(
      build(
        style: const ElStyle(width: 120, height: 60, alignment: .center),
        child: ElView(
          style: const ElStyle(width: 80, height: 40, borderRadius: .all(Radius.circular(8))),
          child: '点击',
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElRippleTap)));
    await tester.pump();
    expect(
      button(tester),
      paints
        ..clipRect(rect: const Rect.fromLTWH(0, 0, 120, 60))
        ..clipRRect(rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(20, 10, 80, 40), Radius.circular(8))),
    );
    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('Space 跨重建保持按压，Enter 和辅助技术从中心触发', (tester) async {
    var taps = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    Widget shell() => build(onPressed: () => taps++, focusNode: focus);
    await tester.pumpWidget(shell());
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 0);
    expect(button(tester), paints..circle(x: 60, y: 30));
    await tester.pumpWidget(shell());
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 1);
    expect(button(tester), paintsExactlyCountTimes(#drawCircle, 1));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(button(tester), paintsExactlyCountTimes(#drawCircle, 0));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 2);
    expect(button(tester), paints..circle(x: 60, y: 30));
    await tester.pumpAndSettle();

    final semantics = tester.ensureSemantics();
    final node = tester.getSemantics(find.byType(ElButtonView));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.label, '波纹按钮');
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(taps, 3);
    expect(button(tester), paints..circle(x: 60, y: 30));
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('禁用和卸载清理动画，禁用期间没有反馈或点击', (tester) async {
    var taps = 0;
    await tester.pumpWidget(build(onPressed: () => taps++));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElRippleTap)));
    await tester.pump();
    await tester.pumpWidget(build(onPressed: () => taps++, disabled: true));
    expect(button(tester), paintsExactlyCountTimes(#drawCircle, 0));
    await gesture.up();
    await tester.tap(find.byType(ElRippleTap));
    await tester.pumpAndSettle();
    expect(taps, 0);
    await tester.pumpWidget(build(onPressed: () => taps++));
    await tester.tap(find.byType(ElRippleTap));
    await tester.pump();
    await tester.pumpWidget(ElView());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enter 按住与重复键每次只生成一个中心波纹，释放不再激活', (tester) async {
    var taps = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(build(onPressed: () => taps++, focusNode: focus));
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
    expect(button(tester), paintsExactlyCountTimes(#drawCircle, 1));
    for (var index = 0; index < 3; index++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.pump(Duration(milliseconds: 20));
      expect(taps, index + 2);
      expect(button(tester), paintsExactlyCountTimes(#drawCircle, index + 2));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    expect(taps, 4);
    await tester.pumpAndSettle();
    expect(button(tester), paintsExactlyCountTimes(#drawCircle, 0));
  });

  for (final cancel in ['blur', 'disabled', 'unmount']) {
    testWidgets('Space 波纹在 $cancel 时取消，释放不点击也不遗留动画', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var taps = 0;
      await tester.pumpWidget(build(onPressed: () => taps++, focusNode: focus));
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(button(tester), paintsExactlyCountTimes(#drawCircle, 1));
      if (cancel == 'blur') {
        focus.unfocus();
      } else {
        await tester.pumpWidget(cancel == 'disabled' ? build(disabled: true, focusNode: focus) : SizedBox());
      }
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(taps, 0);
      if (cancel != 'unmount') expect(button(tester), paintsExactlyCountTimes(#drawCircle, 0));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('变换后的点击坐标准确，逐帧反馈不重新布局内容', (tester) async {
    var layouts = 0;
    final childKey = GlobalKey();
    await tester.pumpWidget(
      build(
        style: ElStyle(width: 120, height: 60, padding: .all(12), alignment: .center, transform: .scale(0.75)),
        child: _LayoutProbe(
          onLayout: () => layouts++,
          child: ElView(key: childKey, style: ElStyle(width: 20, height: 20)),
        ),
      ),
    );
    final initialLayouts = layouts;
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(childKey)));
    await tester.pump();
    expect(button(tester), paints..circle(x: 60, y: 30));
    for (var i = 0; i < 5; i++) {
      await tester.pump(Duration(milliseconds: 16));
    }
    expect(layouts, initialLayouts);
    await gesture.up();
    await tester.pumpAndSettle();
  });
}

({Offset center, double radius, Color color}) _circleOf(RenderObject render) {
  late ({Offset center, double radius, Color color}) circle;
  expect(
    render,
    paints..something((method, arguments) {
      if (method != #drawCircle) return false;
      circle = (center: arguments[0] as Offset, radius: arguments[1] as double, color: (arguments[2] as Paint).color);
      return true;
    }),
  );
  return circle;
}

class _LayoutProbe extends SingleChildRenderObjectWidget {
  const _LayoutProbe({required this.onLayout, required super.child});

  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) => _LayoutRender(onLayout);
}

class _LayoutRender extends RenderProxyBox {
  _LayoutRender(this.onLayout);

  final VoidCallback onLayout;

  @override
  void performLayout() {
    onLayout();
    super.performLayout();
  }
}
