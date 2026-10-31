import 'package:flutter_base/desktop.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, Brightness brightness) => Directionality(
  textDirection: .ltr,
  child: ElDesktopTheme(
    themeMode: ElThemeMode(brightness: brightness),
    child: ElView(
      style: ElStyle(alignment: .center),
      child: child,
    ),
  ),
);
ElRenderView _render(WidgetTester tester, String key) =>
    tester.renderObject<ElRenderView>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(ElButtonView),
      ),
    );
List<Object?> _colors(ElRenderView render) => [
  render.committedResolvedStyle.box.backgroundColor,
  render.committedResolvedStyle.inheritedText.color,
];

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('$brightness toggle 未选中保持默认变体，选中使用实心主题基色', (tester) async {
      for (final (type, bg, plain, ghost, text) in <(ElThemeType?, Color?, bool, bool, bool)>[
        (.primary, null, false, false, false),
        (.success, null, false, false, false),
        (null, Color(0xff009688), false, false, false),
        (null, Color(0xffffe08a), false, false, false),
        (null, null, true, false, false),
        (.success, null, true, false, false),
        (null, null, false, true, false),
        (.warning, null, false, true, false),
        (null, null, false, false, true),
        (.error, null, false, false, true),
      ]) {
        final model = ValueNotifier(false);
        final solid = !plain && !ghost && !text;
        await tester.pumpWidget(
          _host(
            Column(
              mainAxisSize: .min,
              children: [
                ElButton(
                  key: ValueKey('off'),
                  type: solid ? null : type,
                  bgColor: solid ? null : bg,
                  plain: plain,
                  ghost: ghost,
                  text: text,
                  child: '按钮',
                ),
                ElButton(key: ValueKey('on'), type: type ?? .primary, bgColor: bg, child: '按钮'),
                ElButton.toggle(
                  key: ValueKey('toggle'),
                  modelValue: model,
                  type: type,
                  bgColor: bg,
                  plain: plain,
                  ghost: ghost,
                  text: text,
                  child: '按钮',
                ),
              ],
            ),
            brightness,
          ),
        );
        await tester.pumpAndSettle();
        final off = _colors(_render(tester, 'off'));
        final on = _colors(_render(tester, 'on'));
        expect(_colors(_render(tester, 'toggle')), off);
        final size = _render(tester, 'toggle').size;
        model.value = true;
        await tester.pumpAndSettle();
        expect(_colors(_render(tester, 'toggle')), on);
        expect(_render(tester, 'toggle').size, size, reason: '切换只改变配色，不改变占位');
        model.value = false;
        await tester.pumpAndSettle();
        expect(_colors(_render(tester, 'toggle')), off);
        await tester.pumpWidget(ElView());
        model.dispose();
      }
    }, variant: TargetPlatformVariant({TargetPlatform.windows, TargetPlatform.android}));
  }

  testWidgets('选中主题色不被悬停覆盖，指针与 Space 按压均使用实心按压色', (tester) async {
    final model = ValueNotifier(true);
    addTearDown(model.dispose);
    await tester.pumpWidget(
      _host(
        ElButton.toggle(
          key: ValueKey('toggle'),
          modelValue: model,
          type: .primary,
          child: '按钮',
        ),
        .dark,
      ),
    );
    await tester.pumpAndSettle();
    final render = _render(tester, 'toggle');
    final base = _colors(render);
    final active = Color(0xff409eff).elLightOf(.dark, 2);
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    await pointer.moveTo(tester.getCenter(find.byKey(ValueKey('toggle'))));
    await tester.pumpAndSettle();
    expect(_colors(render), base);
    await pointer.down(tester.getCenter(find.byKey(ValueKey('toggle'))));
    await tester.pumpAndSettle();
    expect(render.committedResolvedStyle.box.backgroundColor, active);
    await pointer.up();
    await tester.pumpAndSettle();
    expect(model.value, isFalse);
    model.value = true;
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(render.committedResolvedStyle.box.backgroundColor, active);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(model.value, isFalse);
    await pointer.removePointer();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('选中后禁用使用主题禁用色，加载期间不响应按压配色', (tester) async {
    Widget scene({bool disabled = false, bool loading = false}) => _host(
      Column(
        mainAxisSize: .min,
        children: [
          ElButton(
            key: ValueKey('reference'),
            type: .success,
            disabled: disabled,
            child: '按钮',
          ),
          ElButton.toggle(
            key: ValueKey('toggle'),
            value: true,
            type: .success,
            ghost: true,
            disabled: disabled,
            loading: loading,
            child: '按钮',
          ),
        ],
      ),
      .light,
    );
    await tester.pumpWidget(scene(disabled: true));
    await tester.pumpAndSettle();
    expect(
      _colors(_render(tester, 'toggle')),
      _colors(_render(tester, 'reference')),
    );
    await tester.pumpWidget(scene(loading: true));
    await tester.pump(Duration(milliseconds: 300));
    final before = _colors(_render(tester, 'toggle'));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ValueKey('toggle'))),
    );
    await tester.pump(Duration(milliseconds: 300));
    expect(_colors(_render(tester, 'toggle')), before);
    await gesture.up();
    await tester.pump(Duration(milliseconds: 300));
    expect(
      tester.widget<ElButton>(find.byKey(ValueKey('toggle'))).selected,
      isTrue,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('用户选中样式仍优先于 toggle 默认主题色', (tester) async {
    final custom = Color(0xff552277);
    await tester.pumpWidget(
      _host(
        ElButton.toggle(
          key: ValueKey('toggle'),
          value: true,
          type: .primary,
          style: ElStyle().merge(ElStyle(backgroundColor: custom)),
          child: '按钮',
        ),
        .light,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      _render(tester, 'toggle').committedResolvedStyle.box.backgroundColor,
      custom,
    );
  });
}
