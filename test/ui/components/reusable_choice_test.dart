import 'dart:convert';

import 'package:flutter/material.dart' show MaterialApp, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt;
import 'package:flutter_base/src/flutter/utils/internal/reuse_animation.dart';
import 'package:flutter_base/src/ui/material/index.dart' show materialComponents;
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {required bool mobile, bool material = false}) => MaterialApp(
  home: Scaffold(
    body: ElComponentProvider(
      components: material ? materialComponents(mobile: mobile) : (mobile ? el.mobileComponents : el.desktopComponents),
      child: Center(child: child),
    ),
  ),
);

Set<Element> _elements(Element root) {
  final elements = <Element>{};
  void visit(Element element) {
    elements.add(element);
    element.visitChildren(visit);
  }

  visit(root);
  return elements;
}

Map<String, int> _counts(Element root) {
  final elements = _elements(root);
  return {
    'elements': elements.length,
    'stateful_elements': elements.whereType<StatefulElement>().length,
    'render_objects': elements.whereType<RenderObjectElement>().length,
  };
}

void main() {
  for (final mobile in [true, false]) {
    for (final radio in [false, true]) {
      final description = '${mobile ? '移动' : '桌面'}${radio ? '单选' : '复选'}';
      testWidgets('$description视觉只有公共层触发一次命令，同记录交互保留过渡', (tester) async {
        final key = GlobalKey();
        final model = ValueNotifier(false);
        addTearDown(model.dispose);
        var changes = 0;
        final control = radio
            ? ElRadio.toggle(key: key, modelValue: model, onChanged: (_) => changes++)
            : ElCheckbox.toggle(key: key, modelValue: model, onChanged: (_) => changes++);
        await tester.pumpWidget(_host(control, mobile: mobile));
        await tester.pumpAndSettle();
        final initial = _elements(key.currentContext! as Element);
        await tester.tap(find.byKey(key));
        await tester.pump();
        expect(model.value, isTrue);
        expect(changes, 1);
        expect(tester.binding.transientCallbackCount, greaterThan(0));
        final changed = _elements(key.currentContext! as Element);
        expect(changed.difference(initial), isEmpty);
        expect(initial.difference(changed), isEmpty);
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
      });

      testWidgets('$description异记录换绑保留全部 Element 并直接提交选中外观', (tester) async {
        final key = GlobalKey();
        final scopeKey = GlobalKey();
        final reuse = ReuseAnimationState();
        final model = ValueNotifier(false);
        addTearDown(model.dispose);
        final control = radio
            ? ElRadio.toggle(key: key, modelValue: model)
            : ElCheckbox.toggle(key: key, modelValue: model);
        await tester.pumpWidget(
          _host(
            ReuseAnimationScope(key: scopeKey, state: reuse, child: control),
            mobile: mobile,
          ),
        );
        await tester.pumpAndSettle();
        final before = _elements(key.currentContext! as Element);
        reuse.runRebind(() {
          model.value = true;
          final scope = scopeKey.currentContext! as Element;
          scope.owner!.buildScope(scope);
        });
        await tester.pump();
        final after = _elements(key.currentContext! as Element);
        expect(after.difference(before), isEmpty);
        expect(before.difference(after), isEmpty);
        expect(tester.binding.transientCallbackCount, 0);
        final renders = after
            .whereType<RenderObjectElement>()
            .map((element) => element.renderObject)
            .whereType<ElRenderView>();
        expect(renders.every((render) => !render.hasActiveAnimationsForTest), isTrue);
        await tester.pump();
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    }

    testWidgets('${mobile ? '移动' : '桌面'}选择皮肤不改变分组限制和禁用行为', (tester) async {
      final choices = ValueNotifier(<int>[1]);
      final radio = ValueNotifier<int?>(1);
      addTearDown(choices.dispose);
      addTearDown(radio.dispose);
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: .min,
            children: [
              ElCheckboxGroup<int>(
                modelValue: choices,
                max: 1,
                child: Column(
                  children: [
                    ElCheckbox(key: ValueKey('check-1'), value: 1, label: '第一项'),
                    ElCheckbox(key: ValueKey('check-2'), value: 2, label: '第二项'),
                  ],
                ),
              ),
              ElRadioGroup<int>(
                modelValue: radio,
                child: Column(
                  children: [
                    ElRadio<int>(key: ValueKey('radio-1'), value: 1, label: '单选一'),
                    ElRadio<int>(key: ValueKey('radio-2'), value: 2, label: '单选二'),
                    ElRadio<int>(key: ValueKey('radio-3'), value: 3, label: '禁用', disabled: true),
                  ],
                ),
              ),
            ],
          ),
          mobile: mobile,
        ),
      );
      await tester.tap(find.byKey(ValueKey('check-2')));
      await tester.pumpAndSettle();
      expect(choices.value, [1]);
      await tester.tap(find.byKey(ValueKey('check-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('check-2')));
      await tester.pumpAndSettle();
      expect(choices.value, [2]);
      await tester.tap(find.byKey(ValueKey('radio-2')));
      await tester.pumpAndSettle();
      expect(radio.value, 2);
      await tester.tap(find.byKey(ValueKey('radio-3')));
      await tester.pumpAndSettle();
      expect(radio.value, 2);
    });
  }

  testWidgets('选择控件单实例 Element 与 State 数量对比 Material 回退', (tester) async {
    for (final mobile in [true, false]) {
      for (final radio in [false, true]) {
        final measurements = <String, Map<String, int>>{};
        for (final material in [true, false]) {
          final key = GlobalKey();
          final control = radio ? ElRadio.toggle(key: key, value: true) : ElCheckbox.toggle(key: key, value: true);
          await tester.pumpWidget(_host(control, mobile: mobile, material: material));
          await tester.pumpAndSettle();
          measurements[material ? 'material' : 'brand'] = _counts(key.currentContext! as Element);
        }
        final original = measurements['material']!;
        final brand = measurements['brand']!;
        expect(brand['elements']!, lessThan(original['elements']!));
        expect(brand['stateful_elements']!, lessThan(original['stateful_elements']!));
        // 数量为结构证据，不能换算成真机帧耗时或帧率。
        debugPrint('CHOICE_STRUCTURE ${jsonEncode({'mobile': mobile, 'radio': radio, ...measurements})}');
      }
    }
  });
}
