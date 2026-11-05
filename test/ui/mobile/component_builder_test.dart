import 'dart:ui' show SemanticsRole, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {ElStyle? style}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: true),
    child: ElMobileTheme(
      style: style,
      child: Align(
        alignment: .topLeft,
        child: SizedBox(width: 320, child: child),
      ),
    ),
  ),
);

Finder _view(bool Function(ElView view) test) => find.byWidgetPredicate((widget) => widget is ElView && test(widget));

void main() {
  testWidgets('移动端只注册已有实现，不为缺失组件填充桌面或占位实现', (tester) async {
    late ElComponents builders;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            builders = ElComponentProvider.of(context);
            return SizedBox();
          },
        ),
      ),
    );
    expect(builders.button, isNotNull);
    expect(builders.tag, isNotNull);
    expect(builders.switcher, isNotNull);
    expect(builders.icon, isNotNull);
    expect(builders.card, isNotNull);
    expect(builders.loadingIndicator, isNotNull);
    expect(builders.progress, isNotNull);
    expect(builders.skeleton, isNotNull);
    expect(builders.input, isNull);
    expect(builders.checkbox, isNull);
    expect(builders.radio, isNull);
    expect(builders.buttonGroup, isNull);
  });

  testWidgets('通用卡片加载期间保留正文实例并阻止整卡激活', (tester) async {
    final contentKey = GlobalKey();
    final cardKey = ValueKey('card');
    final child = SizedBox(key: contentKey, height: 60, child: Text('卡片正文'));
    var activations = 0;
    Widget card(bool loading) =>
        _host(ElCard(key: cardKey, loading: loading, onTap: () => activations++, child: child));
    await tester.pumpWidget(card(false));
    final content = tester.element(find.byKey(contentKey));
    expect(find.byType(ElCardView), findsOneWidget);
    await tester.tap(find.byKey(cardKey));
    await tester.pump();
    expect(activations, 1);

    await tester.pumpWidget(card(true));
    expect(find.text('卡片正文'), findsNothing);
    expect(tester.element(find.byKey(contentKey, skipOffstage: false)), same(content));
    expect(_view((view) => view.semantics?.properties.role == SemanticsRole.loadingSpinner), findsOneWidget);
    await tester.tap(find.byKey(cardKey));
    await tester.pump();
    expect(activations, 1);

    await tester.pumpWidget(card(false));
    expect(tester.element(find.byKey(contentKey)), same(content));
    await tester.tap(find.byKey(cardKey));
    await tester.pump();
    expect(activations, 2);
  });

  testWidgets('通用切换按钮保留载荷、样式宽度、外借焦点和单次模型切换', (tester) async {
    final model = ValueNotifier(false);
    final focus = FocusNode();
    addTearDown(model.dispose);
    addTearDown(focus.dispose);
    final changes = <bool>[];
    await tester.pumpWidget(
      _host(
        ElButton.toggle(
          key: ValueKey('button'),
          modelValue: model,
          onChanged: changes.add,
          icon: Text('左'),
          focusNode: focus,
          semanticLabel: '保存',
          style: ElStyle(minHeight: 50, width: '100%', backgroundColor: Color(0xff123456)),
          child: Text('主'),
        ),
      ),
    );
    expect(find.text('左'), findsOneWidget);
    expect(find.text('主'), findsOneWidget);
    expect(_view((view) => view.style?.backgroundColor == Color(0xff123456)), findsOneWidget);
    expect(tester.getSize(find.byKey(ValueKey('button'))).width, 320);
    await tester.tap(find.text('主'));
    await tester.pump();
    expect(model.value, isTrue);
    expect(changes, [true]);
    expect(focus.hasFocus, isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(changes, [true, false]);
  });

  testWidgets('按钮加载保留焦点而禁用动作', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var presses = 0;
    await tester.pumpWidget(
      _host(ElButton(onPressed: () => presses++, loading: true, focusNode: focus, child: Text('加载动作'))),
    );
    expect(_view((view) => view.semantics?.properties.role == SemanticsRole.loadingSpinner), findsOneWidget);
    expect(focus.canRequestFocus, isTrue);
    await tester.tap(find.text('加载动作'));
    await tester.pump();
    expect(presses, 0);
  });

  testWidgets('通用图标按钮是方形，正圆由样式圆角表达', (tester) async {
    await tester.pumpWidget(
      _host(
        ElButton(
          style: ElStyle(borderRadius: .circular(999)),
          child: Icons.add,
        ),
      ),
    );
    expect(tester.getSize(_view((view) => view.style?.width == 44 && view.style?.height == 44)), Size(44, 44));
  });

  testWidgets('通用标签仅由公共宿主切换，关闭不冒泡到主动作', (tester) async {
    final model = ValueNotifier(false);
    addTearDown(model.dispose);
    final changes = <bool>[];
    var closes = 0;
    await tester.pumpWidget(
      _host(
        ElTag.toggle(
          modelValue: model,
          onChanged: changes.add,
          closable: true,
          onClose: () => closes++,
          closeSemanticLabel: '关闭测试',
          effect: .plain,
          type: .success,
          hit: true,
          round: true,
          closeStyle: ElStyle(width: 22),
          child: Text('标签切换'),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    await tester.tap(find.text('标签切换'));
    await tester.pump();
    expect(model.value, isTrue);
    expect(changes, [true]);
    await tester.tap(find.bySemanticsLabel('关闭测试'));
    await tester.pump();
    expect(closes, 1);
    expect(changes, [true]);
    expect(model.value, isTrue);
    semantics.dispose();
  });

  testWidgets('通用标签事件取消切换，禁用同时阻止关闭', (tester) async {
    final model = ValueNotifier(false);
    addTearDown(model.dispose);
    var closes = 0;
    await tester.pumpWidget(
      _host(
        ElTag.toggle(
          modelValue: model,
          event: ElEvent(onTap: (event) => event.preventDefault()),
          child: Text('标签取消'),
        ),
      ),
    );
    await tester.tap(find.text('标签取消'));
    await tester.pump();
    expect(model.value, isFalse);
    await tester.pumpWidget(
      _host(
        ElTag.toggle(modelValue: model, disabled: true, closable: true, onClose: () => closes++, child: Text('标签禁用')),
      ),
    );
    await tester.tap(find.bySemanticsLabel('关闭标签'), warnIfMissed: false);
    await tester.pump();
    expect(closes, 0);
    expect(model.value, isFalse);
  });

  testWidgets('标签的effect与round独立于选中值生效', (tester) async {
    final backgrounds = <ElTagEffect, Color?>{};
    for (final effect in ElTagEffect.values) {
      await tester.pumpWidget(_host(ElTag.toggle(value: true, effect: effect, child: Text('效果'))));
      final skin = tester.widget<ElView>(_view((view) => view.style?.minHeight == 32));
      backgrounds[effect] = skin.style?.backgroundColor;
    }
    expect(backgrounds.values.toSet().length, 3);
    for (final round in [false, true]) {
      await tester.pumpWidget(_host(ElTag(round: round, child: Text('圆角'))));
      final skin = tester.widget<ElView>(_view((view) => view.style?.minHeight == 28));
      expect(skin.style?.borderRadius, BorderRadius.circular(round ? 999 : 8));
    }
  });

  testWidgets('通用开关默认关闭，用户样式合并在默认样式之后', (tester) async {
    await tester.pumpWidget(_host(ElSwitch(semanticLabel: '默认开关')));
    final semantics = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(
            _view((view) => view.semantics?.properties.label == '默认开关' && view.semantics?.properties.toggled != null),
          )
          .flagsCollection
          .isToggled,
      Tristate.isFalse,
    );
    final model = ValueNotifier(true);
    addTearDown(model.dispose);
    await tester.pumpWidget(
      _host(
        ElSwitch(
          modelValue: model,
          semanticLabel: '配置开关',
          style: ElStyle(width: 60, backgroundColor: Color(0xff112233)),
        ),
      ),
    );
    await tester.pump();
    final track = _view((view) => view.style?.backgroundColor == Color(0xff112233));
    expect(tester.getSize(track), Size(60, 28));
    await tester.tap(track);
    await tester.pump();
    expect(model.value, isFalse);
    semantics.dispose();
  });

  testWidgets('开关单次通知、外借焦点与加载阻止激活', (tester) async {
    final model = ValueNotifier(false);
    final focus = FocusNode();
    addTearDown(model.dispose);
    addTearDown(focus.dispose);
    final changes = <bool>[];
    await tester.pumpWidget(
      _host(
        ElSwitch(
          key: ValueKey('switch'),
          modelValue: model,
          onChanged: changes.add,
          semanticLabel: '通知开关',
          focusNode: focus,
        ),
      ),
    );
    await tester.tap(_view((view) => view.semantics?.properties.toggled != null && view.event?.onTap != null));
    await tester.pump();
    expect(changes, [true]);
    expect(focus.hasFocus, isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    expect(changes, [true]);
    await tester.pumpWidget(
      _host(
        ElSwitch(
          key: ValueKey('switch'),
          modelValue: model,
          onChanged: changes.add,
          loading: true,
          focusNode: focus,
          semanticLabel: '通知开关',
        ),
      ),
    );
    expect(_view((view) => view.semantics?.properties.role == SemanticsRole.loadingSpinner), findsOneWidget);
    expect(focus.canRequestFocus, isTrue);
    await tester.tap(_view((view) => view.semantics?.properties.toggled != null && view.event?.onTap != null));
    await tester.pump();
    expect(changes, [true]);
  });

  testWidgets('通用开关接入 Form bool 字段，外部字段替换按公共模型通知一次', (tester) async {
    late ElFormState form;
    final changes = <bool>[];
    await tester.pumpWidget(
      _host(
        ElForm(
          value: {'enabled': false},
          child: Builder(
            builder: (context) {
              form = ElForm.of(context);
              return ElFormItem(
                prop: 'enabled',
                child: ElSwitch(key: ValueKey('form-switch'), onChanged: changes.add),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(_view((view) => view.semantics?.properties.toggled != null && view.event?.onTap != null));
    await tester.pump();
    expect(form.formData['enabled'], isTrue);
    expect(changes, [true]);
    form.updateFormData({'enabled': false});
    await tester.pump();
    expect(changes, [true, false]);
  });
}
