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
ElRenderView _render(WidgetTester tester, String key) => tester.renderObject<ElRenderView>(
  find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(ElButtonView)),
);
List<Object?> _colors(ElRenderView render) => [
  render.committedResolvedStyle.box.backgroundColor,
  render.committedResolvedStyle.inheritedText.color,
];

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('$brightness toggle 未选中保持默认变体，选中使用实心主题基色', (tester) async {
      for (final (type, variant) in <(ElThemeType?, ElButtonVariant)>[
        (.primary, .solid),
        (.success, .solid),
        (null, .outline),
        (.success, .outline),
        (null, .text),
        (.error, .text),
      ]) {
        final model = ValueNotifier(false);
        final solid = variant == .solid;
        await tester.pumpWidget(
          _host(
            Column(
              mainAxisSize: .min,
              children: [
                ElButton(key: ValueKey('off'), type: solid ? null : type, variant: variant, child: '按钮'),
                ElButton(key: ValueKey('on'), type: type ?? .primary, child: '按钮'),
                ElToggleButton(key: ValueKey('toggle'), modelValue: model, type: type, variant: variant, child: '按钮'),
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
      _host(ElToggleButton(key: ValueKey('toggle'), modelValue: model, type: .primary, child: '按钮'), .dark),
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

  testWidgets('选中后禁用使用主题禁用色', (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: .min,
          children: [
            ElButton(key: ValueKey('reference'), type: .success, disabled: true, child: '按钮'),
            ElToggleButton(
              key: ValueKey('toggle'),
              value: true,
              type: .success,
              variant: .outline,
              disabled: true,
              child: '按钮',
            ),
          ],
        ),
        .light,
      ),
    );
    await tester.pumpAndSettle();
    expect(_colors(_render(tester, 'toggle')), _colors(_render(tester, 'reference')));
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('用户选中样式仍优先于 toggle 默认主题色', (tester) async {
    final custom = Color(0xff552277);
    await tester.pumpWidget(
      _host(
        ElToggleButton(
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
    expect(_render(tester, 'toggle').committedResolvedStyle.box.backgroundColor, custom);
  });
}
