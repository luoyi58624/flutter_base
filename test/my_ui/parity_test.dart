/// 参照：D:/project/html/my-ui/packages/vue/components/{Button,Tag,Switch,Card,Divider,Loading,Progress,Skeleton}.vue。
/// 尺寸来自 packages/core/my-ui.css；交互来自 packages/core/my-ui.js。
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/mobile.dart';

Widget shell(
  Widget child, {
  double viewport = 1200,
  bool reduced = true,
  MyThemeData? theme,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(viewport, 900),
      disableAnimations: reduced,
      platformBrightness: brightness,
    ),
    child: MyTheme(
      data: theme,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 320, child: child),
      ),
    ),
  ),
);

Finder views(Finder parent, bool Function(ElView) predicate) => find.descendant(
  of: parent,
  matching: find.byWidgetPredicate((w) => w is ElView && predicate(w)),
);
Finder textView(String text) =>
    find.byWidgetPredicate((w) => w is ElView && w.child == text);
Finder buttonHost() =>
    views(find.byType(MyButton), (v) => v.event?.onTap != null);
Finder switchHost() =>
    views(find.byType(MySwitch), (v) => v.style?.width == 47);

class StateProbe extends StatefulWidget {
  const StateProbe({super.key});
  @override
  State<StateProbe> createState() => ProbeState();
}

class ProbeState extends State<StateProbe> {
  int count = 0;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => count++),
    child: Text('count:$count'),
  );
}

void main() {
  test('明暗token、精确透明阴影、只读集合和组件变量清除', () {
    final light = MyThemeData(),
        dark = MyThemeData(brightness: Brightness.dark);
    expect(light.primary, Color(0xff2454c6));
    expect(light.background, Color(0xfff2f3f5));
    expect(light.text, Color(0xff17191e));
    expect(dark.primary, Color(0xffaac8ff));
    expect(dark.primaryText, Color(0xff000000));
    expect(dark.border, Color(0xff596576));
    expect(light.shadow.first.color.a, closeTo(.045, .000001));
    expect(dark.shadow.first.color.a, closeTo(.16, .000001));
    expect(() => light.shadow.add(BoxShadow()), throwsUnsupportedError);
    final override = light.copyWith(cardRadius: 18, primary: Color(0xff008877));
    expect(override.cardRadius, 18);
    expect(override.copyWith(cardRadius: null).cardRadius, null);
    expect(override.copyWith(cardRadius: null).primary, Color(0xff008877));
  });

  testWidgets('系统暗色与局部主题同步到ElView', (tester) async {
    MyThemeData? seen;
    await tester.pumpWidget(
      shell(
        Builder(
          builder: (context) {
            seen = MyTheme.of(context);
            return MyButton(child: '主题');
          },
        ),
        brightness: Brightness.dark,
      ),
    );
    expect(seen!.brightness, Brightness.dark);
    expect(tester.widget<ElView>(buttonHost()).style!.bgColor, seen!.primary);
    await tester.pumpWidget(
      shell(
        MyButton(child: '主题'),
        theme: MyThemeData(primary: Color(0xff008877)),
      ),
    );
    expect(
      tester.widget<ElView>(buttonHost()).style!.bgColor,
      Color(0xff008877),
    );
    expect(tester.takeException(), null);
  });

  for (final variant in MyButtonVariant.values) {
    testWidgets('Button ${variant.name} 默认高度与图标尺寸', (tester) async {
      final fixed = [
        MyButtonVariant.icon,
        MyButtonVariant.bare,
        MyButtonVariant.round,
      ].contains(variant);
      await tester.pumpWidget(
        shell(
          MyButton(variant: variant, icon: 'plus', child: fixed ? null : '按钮'),
        ),
      );
      final expected = variant == MyButtonVariant.round ? 46.0 : 44.0;
      expect(
        tester.getSize(buttonHost()).height,
        expected + (variant == MyButtonVariant.link ? 24 : 0),
      );
      if (fixed) expect(tester.getSize(buttonHost()).width, expected);
      final iconSize = switch (variant) {
        MyButtonVariant.icon || MyButtonVariant.bare => 19.0,
        MyButtonVariant.round => 17.0,
        MyButtonVariant.link => 14.0,
        _ => 16.0,
      };
      expect(
        views(
          find.byType(MyButton),
          (v) => v.style?.width == iconSize && v.style?.height == iconSize,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
    });
  }

  testWidgets('Button click立即派发，loading保留尺寸焦点并禁止操作', (tester) async {
    var calls = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    Widget button({bool loading = false, bool disabled = false}) => MyButton(
      child: '保存内容',
      icon: 'check',
      loading: loading,
      disabled: disabled,
      focusNode: focus,
      onClick: (_) => calls++,
    );
    await tester.pumpWidget(shell(button()));
    final size = tester.getSize(buttonHost());
    await tester.tap(buttonHost());
    expect(calls, 1);
    await tester.pump(Duration(milliseconds: 120));
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, true);
    await tester.pumpWidget(shell(button(loading: true)));
    expect(tester.getSize(buttonHost()), size);
    expect(focus.hasFocus, true);
    await tester.tap(buttonHost());
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, 1);
    await tester.pump(Duration(milliseconds: 120));
    await tester.pumpWidget(shell(button(disabled: true)));
    await tester.tap(buttonHost());
    expect(calls, 1);
  });

  testWidgets('Button Space松开激活、失焦取消、Enter按下激活', (tester) async {
    final focus = FocusNode(), other = FocusNode();
    addTearDown(focus.dispose);
    addTearDown(other.dispose);
    var calls = 0;
    await tester.pumpWidget(
      shell(
        Column(
          children: [
            MyButton(focusNode: focus, child: '键盘', onClick: (_) => calls++),
            Focus(focusNode: other, child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    expect(calls, 0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    expect(calls, 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    other.requestFocus();
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    expect(calls, 1);
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, 2);
  });

  testWidgets('Button submit/reset与preventDefault', (tester) async {
    var clicks = 0, saved = 0, reset = 0;
    Widget form(MyButtonType type, {bool prevent = false}) => Form(
      child: Column(
        children: [
          FormField<String>(
            initialValue: 'a',
            onSaved: (_) => saved++,
            onReset: () => reset++,
            builder: (_) => SizedBox(),
          ),
          MyButton(
            type: type,
            child: '表单',
            onClick: (e) {
              clicks++;
              if (prevent) e.preventDefault();
            },
          ),
        ],
      ),
    );
    await tester.pumpWidget(shell(form(MyButtonType.submit)));
    await tester.tap(buttonHost());
    expect(saved, 1);
    await tester.pump(Duration(milliseconds: 120));
    await tester.pumpWidget(shell(form(MyButtonType.reset)));
    await tester.tap(buttonHost());
    expect(reset, 1);
    await tester.pump(Duration(milliseconds: 120));
    await tester.pumpWidget(shell(form(MyButtonType.submit, prevent: true)));
    await tester.tap(buttonHost());
    expect(saved, 1);
    expect(clicks, 3);
  });

  testWidgets('Tag展示28选择32，change先于click，外部同步不回调', (tester) async {
    final model = ValueNotifier(false);
    addTearDown(model.dispose);
    final events = <String>[];
    await tester.pumpWidget(shell(MyTag(child: '展示')));
    expect(
      tester
          .getSize(views(find.byType(MyTag), (v) => v.style?.minHeight == 28))
          .height,
      28,
    );
    await tester.pumpWidget(
      shell(
        MyTag(
          modelValue: model,
          child: '选择',
          onChanged: (v) => events.add('change:$v'),
          onClick: (_) => events.add('click'),
        ),
      ),
    );
    expect(
      tester
          .getSize(views(find.byType(MyTag), (v) => v.style?.minHeight == 32))
          .height,
      32,
    );
    await tester.tap(views(find.byType(MyTag), (v) => v.event?.onTap != null));
    await tester.pump();
    expect(model.value, true);
    expect(events, ['change:true', 'click']);
    model.value = false;
    await tester.pump();
    expect(events.length, 2);
    await tester.pumpWidget(shell(SizedBox()));
    model.value = true;
    expect(tester.takeException(), null);
  });

  testWidgets('Switch 47×28、拇指22位移19、Space切换且Enter不切换', (tester) async {
    final focus = FocusNode();
    final model = ValueNotifier(false);
    addTearDown(focus.dispose);
    addTearDown(model.dispose);
    var changes = 0;
    await tester.pumpWidget(
      shell(
        MySwitch(
          modelValue: model,
          label: '通知',
          focusNode: focus,
          onChanged: (_) => changes++,
        ),
      ),
    );
    expect(tester.getSize(switchHost()), Size(47, 28));
    final thumb = views(find.byType(MySwitch), (v) => v.style?.width == 22);
    expect(tester.getSize(thumb), Size(22, 22));
    final before = tester.widget<ElView>(thumb).style!.transform;
    await tester.tap(switchHost());
    await tester.pump();
    expect(model.value, true);
    expect(changes, 1);
    expect(tester.widget<ElView>(thumb).style!.transform, isNot(before));
    expect(
      tester.widget<ElView>(thumb).style!.transform,
      ElTransform.translate(19, 0),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(changes, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(changes, 2);
    model.value = true;
    await tester.pump();
    expect(changes, 2);
  });

  testWidgets('Switch禁用无多余透明度且保留开关语义', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      shell(
        MySwitch(
          value: true,
          label: '通知',
          disabled: true,
          onChanged: (_) => calls++,
        ),
      ),
    );
    await tester.tap(switchHost());
    expect(calls, 0);
    expect(tester.widget<ElView>(switchHost()).style!.opacity, null);
    expect(
      tester.getSemantics(switchHost()),
      matchesSemantics(
        label: '通知',
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
  });

  for (final width in [1200.0, 1000.0, 760.0, 400.0]) {
    testWidgets('Card viewport=$width 使用原CSS断点', (tester) async {
      final childKey = UniqueKey();
      await tester.pumpWidget(
        shell(
          MyCard(
            title: '标题',
            description: '说明',
            sample: '01',
            child: SizedBox(key: childKey, height: 20),
          ),
          viewport: width,
        ),
      );
      final rootView = views(
        find.byType(MyCard),
        (v) => v.style?.width == '100%',
      ).first;
      expect(
        tester.widget<ElView>(rootView).style!.padding,
        width <= 760
            ? EdgeInsets.fromLTRB(23, 25, 23, 26)
            : width <= 1100
            ? EdgeInsets.fromLTRB(29, 30, 29, 31)
            : EdgeInsets.fromLTRB(30, 29, 30, 30),
      );
      expect(tester.getSize(rootView).width, 320);
      expect(
        tester.getTopLeft(find.byKey(childKey)).dx -
            tester.getTopLeft(rootView).dx,
        width <= 760
            ? 23
            : width <= 1100
            ? 29
            : 30,
      );
      expect(tester.takeException(), null);
    });
  }

  testWidgets('交互Card隐藏标题，内部按钮只激活自身', (tester) async {
    var card = 0, button = 0;
    await tester.pumpWidget(
      shell(
        MyCard(
          title: '只作名称',
          interactive: true,
          onActivate: (_) => card++,
          child: Column(
            children: [
              MyButton(child: '内部', onClick: (_) => button++),
              SizedBox(height: 70),
            ],
          ),
        ),
      ),
    );
    expect(textView('只作名称'), findsNothing);
    await tester.tap(buttonHost());
    expect(button, 1);
    expect(card, 0);
    await tester.pump(Duration(milliseconds: 120));
    final cardView = views(
      find.byType(MyCard),
      (v) => v.style?.width == '100%',
    ).first;
    await tester.tapAt(tester.getBottomLeft(cardView) + Offset(35, -30));
    expect(card, 1);
  });

  testWidgets('Divider默认水平41高，竖线13高含双侧12间距', (tester) async {
    await tester.pumpWidget(shell(MyDivider()));
    expect(tester.getSize(find.byType(MyDivider)), Size(320, 41));
    await tester.pumpWidget(shell(MyDivider(vertical: true)));
    expect(tester.getSize(find.byType(MyDivider)).height, 13);
    final line = views(
      find.byType(MyDivider),
      (v) => v.style?.border?.left != null,
    ).last;
    expect(tester.getSize(line), Size(1, 13));
  });

  testWidgets('Divider长Widget插槽与start/end均无溢出', (tester) async {
    for (final align in MyDividerAlign.values) {
      await tester.pumpWidget(
        shell(
          MyDivider(align: align, dashed: true, child: Text('很长的分割说明' * 8)),
        ),
      );
      expect(find.byType(Text), findsOneWidget);
      expect(tester.takeException(), null);
    }
  });

  for (final size in MyLoadingSize.values) {
    testWidgets('Loading ${size.name} 尺寸与status语义', (tester) async {
      await tester.pumpWidget(shell(MyLoading(size: size)));
      final icon = views(
        find.byType(MyLoading),
        (v) => v.style?.width == size.pixels,
      );
      expect(tester.getSize(icon), Size.square(size.pixels));
      final node = tester.getSemantics(find.byType(MyLoading));
      expect(node.getSemanticsData().role, SemanticsRole.loadingSpinner);
      expect(node.label, '加载中');
    });
  }

  testWidgets('Skeleton默认123高、42%标题、66%末行、首行gap18', (tester) async {
    await tester.pumpWidget(shell(MySkeleton()));
    expect(tester.getSize(find.byType(MySkeleton)), Size(320, 123));
    final title = views(
      find.byType(MySkeleton),
      (v) => v.style?.width == '42%',
    );
    final lines = views(find.byType(MySkeleton), (v) => v.style?.height == 13);
    expect(tester.getSize(title).width, closeTo(134.4, .01));
    expect(tester.getSize(lines.last).width, closeTo(211.2, .01));
    expect(
      tester.getTopLeft(lines.first).dy - tester.getBottomLeft(title).dy,
      18,
    );
  });

  for (final entry in <num, int>{
    0: 3,
    double.nan: 3,
    -5: 1,
    1.9: 1,
    99: 10,
    double.infinity: 10,
  }.entries) {
    testWidgets('Skeleton rows=${entry.key} 按Web归一化', (tester) async {
      await tester.pumpWidget(shell(MySkeleton(rows: entry.key)));
      expect(
        views(find.byType(MySkeleton), (v) => v.style?.height == 13),
        findsNWidgets(entry.value),
      );
    });
  }

  testWidgets('Skeleton loading来回切换保留正文State及计数', (tester) async {
    final probe = GlobalKey<ProbeState>();
    Widget skeleton(bool loading) => MySkeleton(
      loading: loading,
      child: StateProbe(key: probe),
    );
    await tester.pumpWidget(shell(skeleton(false)));
    await tester.tap(find.text('count:0'));
    await tester.pump();
    final state = probe.currentState;
    await tester.pumpWidget(shell(skeleton(true)));
    expect(find.text('count:1'), findsNothing);
    expect(probe.currentState, same(state));
    await tester.pumpWidget(shell(skeleton(false)));
    expect(find.text('count:1'), findsOneWidget);
    expect(probe.currentState, same(state));
  });

  testWidgets('Progress非法值归一化、buffer下限与辅助读数', (tester) async {
    MyProgressValue? seen;
    await tester.pumpWidget(
      shell(
        MyProgress(
          value: 120,
          max: 0,
          buffer: 2,
          textBuilder: (_, data) {
            seen = data;
            return Text(data.percentage.toString());
          },
        ),
      ),
    );
    expect(seen!.value, 100);
    expect(seen!.max, 100);
    expect(seen!.percentage, 100);
    var data = tester.getSemantics(find.byType(MyProgress)).getSemanticsData();
    expect(data.role, SemanticsRole.progressBar);
    expect(data.value, '100%');
    expect(data.hint, '已缓冲 100%');
    await tester.pumpWidget(shell(MyProgress(value: double.nan)));
    data = tester.getSemantics(find.byType(MyProgress)).getSemanticsData();
    expect(data.value, '进行中');
    expect(textView('0%'), findsOneWidget);
  });

  testWidgets('Progress圆环96px，隐藏/换类型保留插槽State', (tester) async {
    final probe = GlobalKey<ProbeState>();
    Widget progress(MyProgressType type, bool show) => MyProgress(
      value: 25,
      type: type,
      showText: show,
      textBuilder: (_, value) => StateProbe(key: probe),
    );
    await tester.pumpWidget(shell(progress(MyProgressType.line, true)));
    final state = probe.currentState;
    await tester.pumpWidget(shell(progress(MyProgressType.circle, true)));
    expect(
      tester.getSize(
        views(find.byType(MyProgress), (v) => v.style?.width == 96),
      ),
      Size(96, 96),
    );
    expect(probe.currentState, same(state));
    await tester.pumpWidget(shell(progress(MyProgressType.circle, false)));
    expect(probe.currentState, same(state));
    expect(find.text('count:0'), findsNothing);
    expect(tester.takeException(), null);
  });

  testWidgets('减少动画不循环调帧，普通模式卸载释放ticker', (tester) async {
    Widget group() =>
        Column(children: [MyLoading(), MySkeleton(), MyProgress()]);
    await tester.pumpWidget(shell(group()));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, false);
    await tester.pumpWidget(shell(group(), reduced: false));
    await tester.pump(Duration(milliseconds: 200));
    await tester.pumpWidget(shell(SizedBox()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
  });

  testWidgets('Button触摸延迟只控制反馈、不拖延click，取消不激活', (tester) async {
    var clicks = 0;
    await tester.pumpWidget(
      shell(
        MyButton(
          child: '触摸',
          onClick: (_) => clicks++,
          delayTouchDown: Duration(milliseconds: 80),
          delayTouchUp: Duration(milliseconds: 160),
        ),
        reduced: false,
      ),
    );
    var point = tester.getCenter(buttonHost());
    var gesture = await tester.startGesture(point);
    await tester.pump(Duration(milliseconds: 30));
    await gesture.up();
    expect(clicks, 1);
    await tester.pump(Duration(milliseconds: 200));
    gesture = await tester.startGesture(point);
    await tester.pump(Duration(milliseconds: 90));
    await gesture.cancel();
    await tester.pump(Duration(milliseconds: 200));
    expect(clicks, 1);
    expect(tester.takeException(), null);
  });

  testWidgets('Button loading保留可访问名称且selected是可选语义', (tester) async {
    await tester.pumpWidget(
      shell(MyButton(child: '保存', loading: true, selected: true)),
    );
    final node = tester.getSemantics(buttonHost()).getSemanticsData();
    expect(node.label, '保存');
    expect(node.flagsCollection.isToggled, Tristate.isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);
  });

  testWidgets('Card键盘Enter不响应repeat，Space失焦取消', (tester) async {
    final focus = FocusNode(), other = FocusNode();
    addTearDown(focus.dispose);
    addTearDown(other.dispose);
    var calls = 0;
    await tester.pumpWidget(
      shell(
        Column(
          children: [
            MyCard(
              interactive: true,
              focusNode: focus,
              title: '卡片',
              onActivate: (_) => calls++,
              child: SizedBox(height: 30),
            ),
            Focus(focusNode: other, child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    expect(calls, 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    other.requestFocus();
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    expect(calls, 1);
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(calls, 2);
  });

  testWidgets('Tag五色遵守CSS混色，disabled不回调', (tester) async {
    final theme = MyThemeData();
    final accents = [
      theme.primary,
      theme.success,
      theme.warning,
      theme.danger,
      theme.textSecondary,
    ];
    for (var i = 0; i < MyTagTone.values.length; i++) {
      await tester.pumpWidget(
        shell(MyTag(tone: MyTagTone.values[i], child: '标签')),
      );
      final view = tester.widget<ElView>(
        views(find.byType(MyTag), (v) => v.style?.minHeight == 28),
      );
      expect(view.style!.color, accents[i]);
      expect(
        view.style!.bgColor,
        Color.lerp(theme.cardBackground, accents[i], .1),
      );
    }
    var calls = 0;
    await tester.pumpWidget(
      shell(
        MyTag(
          value: false,
          disabled: true,
          child: '禁用',
          onChanged: (_) => calls++,
          onClick: (_) => calls++,
        ),
      ),
    );
    await tester.tap(views(find.byType(MyTag), (v) => v.event?.onTap != null));
    expect(calls, 0);
  });

  testWidgets('组件主题变量有真实消费者', (tester) async {
    final theme = MyThemeData(
      cardPadding: EdgeInsets.all(5),
      cardRadius: 11,
      switchThumbBackground: Color(0xff123456),
      dividerHeight: 31,
      dividerSpacing: 4,
      progressSize: 80,
      progressThickness: 9,
    );
    await tester.pumpWidget(
      shell(
        Column(
          children: [
            MyCard(child: SizedBox(height: 10)),
            MySwitch(value: false, label: '开关'),
            MyDivider(vertical: true),
            MyProgress(value: 50, type: MyProgressType.circle),
          ],
        ),
        theme: theme,
      ),
    );
    expect(
      tester
          .widget<ElView>(
            views(find.byType(MyCard), (v) => v.style?.width == '100%').first,
          )
          .style!
          .padding,
      EdgeInsets.all(6),
    );
    expect(
      tester
          .widget<ElView>(
            views(find.byType(MySwitch), (v) => v.style?.width == 22),
          )
          .style!
          .bgColor,
      Color(0xff123456),
    );
    expect(tester.getSize(find.byType(MyDivider)).height, 31);
    expect(
      tester.getSize(
        views(find.byType(MyProgress), (v) => v.style?.width == 80),
      ),
      Size(80, 80),
    );
  });

  testWidgets('Skeleton隐藏正文退出焦点并保留可重新聚焦节点', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    Widget skeleton(bool loading) => MySkeleton(
      loading: loading,
      avatar: true,
      child: Focus(focusNode: focus, child: SizedBox(height: 20)),
    );
    await tester.pumpWidget(shell(skeleton(false)));
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, true);
    await tester.pumpWidget(shell(skeleton(true)));
    await tester.pump();
    expect(focus.hasFocus, false);
    expect(focus.canRequestFocus, false);
    expect(
      views(find.byType(MySkeleton), (v) => v.style?.width == 42),
      findsOneWidget,
    );
    await tester.pumpWidget(shell(skeleton(false)));
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, true);
  });

  testWidgets('Progress确定值用200ms CSS ease过渡，语义同步目标值', (tester) async {
    Finder paint() => find.descendant(
      of: find.byType(MyProgress),
      matching: find.byType(CustomPaint),
    );
    await tester.pumpWidget(shell(MyProgress(value: 20), reduced: false));
    await tester.pumpWidget(shell(MyProgress(value: 80), reduced: false));
    dynamic painter = tester.widget<CustomPaint>(paint()).painter;
    expect(painter.ratio, closeTo(.2, .001));
    await tester.pump(Duration(milliseconds: 100));
    painter = tester.widget<CustomPaint>(paint()).painter;
    expect(painter.ratio, closeTo(.2 + .6 * Curves.ease.transform(.5), .001));
    expect(tester.getSemantics(find.byType(MyProgress)).value, '80%');
    await tester.pump(Duration(milliseconds: 100));
    painter = tester.widget<CustomPaint>(paint()).painter;
    expect(painter.ratio, closeTo(.8, .001));
    await tester.pumpWidget(shell(SizedBox()));
  });

  testWidgets('Button最短反馈从按下起算，短于down延迟不补播', (tester) async {
    var pressed = false, clicks = 0;
    await tester.pumpWidget(
      shell(
        MyButton(
          delayTouchDown: Duration(milliseconds: 80),
          delayTouchUp: Duration(milliseconds: 160),
          onClick: (_) => clicks++,
          child: Builder(
            builder: (context) {
              pressed = ElView.of(context).hasTap;
              return Text('反馈');
            },
          ),
        ),
        reduced: false,
      ),
    );
    final point = tester.getCenter(buttonHost());
    var gesture = await tester.startGesture(point);
    await tester.pump(Duration(milliseconds: 30));
    expect(pressed, false);
    await gesture.up();
    expect(clicks, 1);
    await tester.pump(Duration(milliseconds: 180));
    expect(pressed, false);
    gesture = await tester.startGesture(point);
    await tester.pump(Duration(milliseconds: 90));
    expect(pressed, true);
    await gesture.up();
    expect(clicks, 2);
    await tester.pump(Duration(milliseconds: 50));
    expect(pressed, true);
    await tester.pump(Duration(milliseconds: 30));
    expect(pressed, false);
    await tester.pumpWidget(shell(SizedBox()));
    await tester.pumpAndSettle();
  });

  testWidgets('局部主题与兄弟隔离，更新能影响已挂载按钮', (tester) async {
    final nested = ValueKey('nested'), sibling = ValueKey('sibling');
    var color = Color(0xff123456);
    late StateSetter update;
    await tester.pumpWidget(
      shell(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Column(
              children: [
                MyTheme(
                  data: MyThemeData(primary: color),
                  child: MyButton(key: nested, child: '局部'),
                ),
                MyButton(key: sibling, child: '默认'),
              ],
            );
          },
        ),
      ),
    );
    Color? background(Key key) => tester
        .widget<ElView>(views(find.byKey(key), (v) => v.event?.onTap != null))
        .style!
        .bgColor;
    expect(background(nested), color);
    expect(background(sibling), Color(0xff2454c6));
    update(() => color = Color(0xff554433));
    await tester.pump();
    expect(background(nested), color);
    expect(background(sibling), Color(0xff2454c6));
  });

  testWidgets('Card内部Flutter按钮与输入不触发整卡', (tester) async {
    var card = 0, inner = 0;
    await tester.pumpWidget(
      shell(
        MyCard(
          interactive: true,
          onActivate: (_) => card++,
          child: Column(
            children: [
              TextButton(onPressed: () => inner++, child: Text('原生子按钮')),
              Material(child: TextField()),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextButton));
    expect(inner, 1);
    expect(card, 0);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(card, 0);
    await tester.enterText(find.byType(TextField), '输入');
    expect(card, 0);
  });

  testWidgets('按钮冒泡保留普通祖先通知，整卡跳过子操作', (tester) async {
    var ancestor = 0, card = 0, button = 0;
    await tester.pumpWidget(
      shell(
        ElView(
          event: ElEvent(onTap: (_) => ancestor++),
          child: MyCard(
            interactive: true,
            onActivate: (_) => card++,
            child: MyButton(child: '操作', onClick: (_) => button++),
          ),
        ),
      ),
    );
    await tester.tap(buttonHost());
    expect(button, 1);
    expect(card, 0);
    expect(ancestor, 1);
  });

  testWidgets('Card内部禁用按钮不会激活整卡', (tester) async {
    var card = 0;
    await tester.pumpWidget(
      shell(
        MyCard(
          interactive: true,
          onActivate: (_) => card++,
          child: MyButton(disabled: true, child: '禁用'),
        ),
      ),
    );
    await tester.tap(buttonHost());
    expect(card, 0);
  });

  testWidgets('Progress条形默认21高，隐藏读数时仅轨道6高', (tester) async {
    await tester.pumpWidget(shell(MyProgress(value: 40)));
    expect(tester.getSize(find.byType(MyProgress)), Size(320, 21));
    await tester.pumpWidget(shell(MyProgress(value: 40, showText: false)));
    expect(tester.getSize(find.byType(MyProgress)), Size(320, 6));
  });
}
