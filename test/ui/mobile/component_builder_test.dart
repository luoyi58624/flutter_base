import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  MyThemeData? data,
  ElComponentBuilders? builders,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: true),
    child: MyTheme(
      data: data,
      componentBuilders: builders,
      child: Align(
        alignment: .topLeft,
        child: SizedBox(width: 320, child: child),
      ),
    ),
  ),
);

Finder _view(bool Function(ElView view) test) =>
    find.byWidgetPredicate((widget) => widget is ElView && test(widget));

void main() {
  test('移动端只注册已有实现，不为缺失组件填充桌面或占位实现', () {
    expect(myComponentBuilders.buttonBuilder, isNotNull);
    expect(myComponentBuilders.tagBuilder, isNotNull);
    expect(myComponentBuilders.switchBuilder, isNotNull);
    expect(myComponentBuilders.textBuilder, isNotNull);
    expect(myComponentBuilders.inputBuilder, isNull);
    expect(myComponentBuilders.checkboxBuilder, isNull);
    expect(myComponentBuilders.radioBuilder, isNull);
    expect(myComponentBuilders.buttonGroupBuilder, isNull);
  });

  testWidgets('通用按钮保留载荷、颜色、布局、外借焦点和单次模型切换', (tester) async {
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
          leftIcon: Text('左'),
          rightIcon: Text('右'),
          bgColor: Color(0xff123456),
          block: true,
          round: true,
          focusNode: focus,
          semanticLabel: '保存',
          style: ElStyle(minHeight: 50),
          child: Text('主'),
        ),
      ),
    );
    expect(find.text('左'), findsOneWidget);
    expect(find.text('主'), findsOneWidget);
    expect(find.text('右'), findsOneWidget);
    expect(
      _view((view) => view.style?.bgColor == Color(0xff123456)),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(MyButton)).width, 320);
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

  testWidgets('按钮事件可以取消默认切换，加载保留焦点而禁用动作', (tester) async {
    final model = ValueNotifier(false);
    final focus = FocusNode();
    addTearDown(model.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _host(
        ElButton.toggle(
          modelValue: model,
          event: ElEvent(onTap: (event) => event.preventDefault()),
          child: Text('取消动作'),
        ),
      ),
    );
    await tester.tap(find.text('取消动作'));
    await tester.pump();
    expect(model.value, isFalse);
    await tester.pumpWidget(
      _host(
        ElButton.toggle(
          modelValue: model,
          loading: true,
          focusNode: focus,
          child: Text('加载动作'),
        ),
      ),
    );
    expect(find.byType(MyLoading), findsOneWidget);
    expect(focus.canRequestFocus, isTrue);
    await tester.tap(find.text('加载动作'));
    await tester.pump();
    expect(model.value, isFalse);
  });

  testWidgets('通用正圆按钮在覆盖高度后仍保持宽高相等', (tester) async {
    await tester.pumpWidget(
      _host(
        ElButton(circle: true, style: ElStyle(height: 60), child: Icons.add),
      ),
    );
    expect(
      tester.getSize(
        _view((view) => view.style?.width == 60 && view.style?.height == 60),
      ),
      Size(60, 60),
    );
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
    expect(find.byType(MyTag), findsNothing);
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
        ElTag.toggle(
          modelValue: model,
          disabled: true,
          closable: true,
          onClose: () => closes++,
          child: Text('标签禁用'),
        ),
      ),
    );
    await tester.tap(_view((view) => view.child == '×'), warnIfMissed: false);
    await tester.pump();
    expect(closes, 0);
    expect(model.value, isFalse);
  });

  testWidgets('标签的effect与round独立于选中值生效', (tester) async {
    final backgrounds = <ElTagEffect, Color?>{};
    for (final effect in ElTagEffect.values) {
      await tester.pumpWidget(
        _host(ElTag.toggle(value: true, effect: effect, child: Text('效果'))),
      );
      final skin = tester.widget<ElView>(
        _view((view) => view.style?.minHeight == 32),
      );
      backgrounds[effect] = skin.style?.bgColor;
    }
    expect(backgrounds.values.toSet().length, 3);
    for (final round in [false, true]) {
      await tester.pumpWidget(_host(ElTag(round: round, child: Text('圆角'))));
      final skin = tester.widget<ElView>(
        _view((view) => view.style?.minHeight == 28),
      );
      expect(skin.style?.borderRadius, BorderRadius.circular(round ? 999 : 8));
    }
  });

  testWidgets('通用开关默认关闭，内容、尺寸、颜色、样式和无滑动配置生效', (tester) async {
    await tester.pumpWidget(_host(ElSwitch(semanticLabel: '默认开关')));
    final semantics = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(
            _view(
              (view) =>
                  view.semantics?.properties.label == '默认开关' &&
                  view.semantics?.properties.toggled != null,
            ),
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
          activeColor: Color(0xff112233),
          inactiveColor: Color(0xff445566),
          activeContent: Text('开启'),
          inactiveContent: Text('关闭'),
          activeActionContent: Text('一'),
          inactiveActionContent: Text('零'),
          height: 40,
          gap: 4,
          widthAspect: 3,
          slide: false,
          style: ElStyle(margin: EdgeInsets.only(left: 5)),
          trackStyle: ElStyle(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('开启'), findsOneWidget);
    expect(find.text('一'), findsOneWidget);
    final track = _view((view) => view.style?.bgColor == Color(0xff112233));
    expect(track, findsOneWidget);
    expect(tester.getSize(track), Size(120, 40));
    expect(
      tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).duration,
      Duration.zero,
    );
    await tester.tap(find.text('开启'));
    await tester.pump();
    expect(model.value, isFalse);
    expect(find.text('关闭'), findsOneWidget);
    expect(find.text('零'), findsOneWidget);
    expect(
      _view((view) => view.style?.bgColor == Color(0xff445566)),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('开关单次通知、外借焦点、取消事件与加载阻止激活', (tester) async {
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
    await tester.tap(
      _view(
        (view) =>
            view.semantics?.properties.toggled != null &&
            view.event?.onTap != null,
      ),
    );
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
          event: ElEvent(onTap: (event) => event.preventDefault()),
          semanticLabel: '通知开关',
        ),
      ),
    );
    await tester.tap(
      _view(
        (view) =>
            view.semantics?.properties.toggled != null &&
            view.event?.onTap != null,
      ),
    );
    await tester.pump();
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
    expect(find.byType(MyLoading), findsOneWidget);
    expect(focus.canRequestFocus, isTrue);
    await tester.tap(
      _view(
        (view) =>
            view.semantics?.properties.toggled != null &&
            view.event?.onTap != null,
      ),
    );
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
                child: ElSwitch(
                  key: ValueKey('form-switch'),
                  onChanged: changes.add,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(
      _view(
        (view) =>
            view.semantics?.properties.toggled != null &&
            view.event?.onTap != null,
      ),
    );
    await tester.pump();
    expect(form.formData['enabled'], isTrue);
    expect(changes, [true]);
    form.updateFormData({'enabled': false});
    await tester.pump();
    expect(changes, [true, false]);
  });

  testWidgets('文本参数保持原样，局部 Builder 覆写只覆盖指定组件', (tester) async {
    await tester.pumpWidget(
      _host(
        ElText(
          '内容',
          maxLines: 2,
          overflow: .ellipsis,
          style: TextStyle(fontSize: 19),
        ),
      ),
    );
    final text = tester.widget<Text>(find.text('内容'));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.style?.fontSize, 19);
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            ElText('内容'),
            ElButton(child: Text('按钮')),
          ],
        ),
        builders: ElComponentBuilders(
          textBuilder: (context, component) => Text('覆写${component.data}'),
        ),
      ),
    );
    expect(find.text('覆写内容'), findsOneWidget);
    expect(find.byType(MyButton), findsOneWidget);
  });
}
