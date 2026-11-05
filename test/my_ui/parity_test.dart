/// 参照：D:/project/html/my-ui/packages/vue/components/{Button,Tag,Switch,Card,Divider,Loading,Progress,Skeleton}.vue。
/// 尺寸来自 packages/core/my-ui.css；交互来自 packages/core/my-ui.js。
library;

import 'dart:ui' show PointerDeviceKind, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/src/ui/mobile/components/button/index.dart' as skin;
import 'package:flutter_base/src/ui/mobile/components/tag/index.dart' as skin;
import 'package:flutter_base/src/ui/mobile/components/switch/index.dart' as skin;
import 'package:flutter_base/src/ui/mobile/components/loading/index.dart' as skin;
import 'package:flutter_base/src/ui/mobile/components/progress/index.dart' as skin;
import 'package:flutter_base/src/ui/mobile/components/skeleton/index.dart' as skin;
import 'package:flutter_base/src/ui/mobile/components/others/divider/index.dart' as skin;

Widget shell(
  Widget child, {
  double viewport = 1200,
  bool reduced = true,
  ElStyle? theme,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: Size(viewport, 900), disableAnimations: reduced, platformBrightness: brightness),
    child: ElComponentProvider(
      components: el.mobileComponents,
      child: ElView(
        style: theme,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 320, child: child),
        ),
      ),
    ),
  ),
);

Finder views(Finder parent, bool Function(ElView) predicate) =>
    find.descendant(of: parent, matching: find.byWidgetPredicate((w) => w is ElView && predicate(w)));
Finder textView(String text) => find.byWidgetPredicate((w) => w is ElView && w.child == text);
Finder buttonHost() => views(find.byType(skin.Button), (v) => v.event?.onTap != null);
Finder switchHost() => views(find.byType(skin.Switch), (v) => v.style?.width == 47);

class StateProbe extends StatefulWidget {
  const StateProbe({super.key});
  @override
  State<StateProbe> createState() => ProbeState();
}

class ProbeState extends State<StateProbe> {
  int count = 0;
  @override
  Widget build(BuildContext context) =>
      GestureDetector(onTap: () => setState(() => count++), child: Text('count:$count'));
}

void main() {
  test('明暗默认变量保留原配色、阴影精度与只读集合', () {
    final light = el.mobileComponents.token!.vars!, dark = el.mobileComponents.token!.onDark!.vars!;
    // 移动端语义色以设计稿为准（#1076FD）；Web 原型 --primary 仍是 #2454c6，两者不再逐值对齐。
    expect(light[ElTokens.$primary], Color(0xff1076fd));
    expect(light[ElTokens.$bgColor], Color(0xffeeeeee));
    expect(light[ElTokens.$textColor], Color(0xff17191e));
    expect(dark[ElTokens.$primary], Color(0xffaac8ff));
    expect(dark[ElTokens.$primaryText], Color(0xff000000));
    expect(dark[ElTokens.$borderColor], Color(0xff596576));
    final lightShadow = light[ElTokens.$shadowMd] as List<BoxShadow>;
    final darkShadow = dark[ElTokens.$shadowMd] as List<BoxShadow>;
    expect(lightShadow.first.color.a, closeTo(.065, .000001));
    expect(darkShadow.first.color.a, closeTo(.24, .000001));
    expect(() => lightShadow.add(BoxShadow()), throwsUnsupportedError);
  });

  testWidgets('系统暗色与局部主题同步到ElView', (tester) async {
    Brightness? seenBrightness;
    Color? seenPrimary;
    await tester.pumpWidget(
      shell(
        Builder(
          builder: (context) {
            seenBrightness = ElView.of(context).brightness;
            seenPrimary = context.elTheme.primary;
            return skin.Button(child: '主题');
          },
        ),
        brightness: Brightness.dark,
      ),
    );
    expect(seenBrightness, Brightness.dark);
    expect(tester.widget<ElView>(buttonHost()).style!.backgroundColor, seenPrimary);
    await tester.pumpWidget(
      shell(
        skin.Button(child: '主题'),
        theme: ElStyle(vars: {ElTokens.$primary: Color(0xff008877)}),
      ),
    );
    expect(tester.widget<ElView>(buttonHost()).style!.backgroundColor, Color(0xff008877));
    expect(tester.takeException(), null);
  });

  for (final variant in skin.ButtonVariant.values) {
    testWidgets('Button ${variant.name} 默认高度与图标尺寸', (tester) async {
      final fixed = [skin.ButtonVariant.icon, skin.ButtonVariant.bare, skin.ButtonVariant.round].contains(variant);
      await tester.pumpWidget(shell(skin.Button(variant: variant, icon: 'plus', child: fixed ? null : '按钮')));
      final expected = variant == skin.ButtonVariant.round ? 46.0 : 44.0;
      expect(tester.getSize(buttonHost()).height, expected + (variant == skin.ButtonVariant.link ? 24 : 0));
      if (fixed) expect(tester.getSize(buttonHost()).width, expected);
      final iconSize = switch (variant) {
        skin.ButtonVariant.icon || skin.ButtonVariant.bare => 19.0,
        skin.ButtonVariant.round => 17.0,
        skin.ButtonVariant.link => 14.0,
        _ => 16.0,
      };
      final glyph = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == 'Glyph');
      expect(tester.getSize(glyph), Size.square(iconSize));
      expect(tester.takeException(), null);
    });
  }

  testWidgets('Button click立即派发，loading保留尺寸焦点并禁止操作', (tester) async {
    var calls = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    Widget button({bool loading = false, bool disabled = false}) => skin.Button(
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
            skin.Button(focusNode: focus, child: '键盘', onClick: (_) => calls++),
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

  for (final entry in <String, Widget Function(FocusNode)>{
    'Button': (focus) => skin.Button(focusNode: focus, child: '手机按钮'),
    'Tag': (focus) => skin.Tag(value: false, focusNode: focus, child: '手机标签'),
    'Card': (_) => ElCard(onTap: () {}, child: SizedBox(height: 60)),
    'Switch': (focus) => skin.Switch(value: false, focusNode: focus, label: '手机开关'),
  }.entries) {
    testWidgets('${entry.key} 默认悬停和键盘聚焦保持手机外观', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(shell(KeyedSubtree(key: key, child: entry.value(focus))));
      final target = find.byKey(key);
      final action = find
          .descendant(
            of: target,
            matching: find.byWidgetPredicate(
              (widget) => widget is ElView && widget.focusNode != null && widget.event?.onTap != null,
            ),
          )
          .first;
      List<Object> appearance() => tester
          .renderObjectList<ElRenderView>(find.descendant(of: target, matching: find.byType(ElView)))
          .map((render) => render.committedResolvedStyle)
          .toList();
      final targetFocus = tester.widget<ElView>(action).focusNode!;
      final initial = appearance();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset(2, 2));
      await mouse.moveTo(tester.getCenter(action));
      await tester.pumpAndSettle();
      expect(appearance(), initial, reason: '鼠标进入不添加手机默认悬停外观');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      targetFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(targetFocus.hasPrimaryFocus, isTrue);
      expect(appearance(), initial, reason: '保留键盘聚焦能力但不添加默认焦点环');
    });
  }

  for (final entry in <String, Widget>{
    'Button': skin.Button(child: '按压'),
    'Tag': skin.Tag(value: false, child: '按压'),
    'Card': ElCard(onTap: () {}, child: SizedBox(height: 60)),
  }.entries) {
    testWidgets('${entry.key} 保留触摸按压外观并在取消后恢复', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(shell(KeyedSubtree(key: key, child: entry.value)));
      final target = find.byKey(key);
      final action = find
          .descendant(
            of: target,
            matching: find.byWidgetPredicate(
              (widget) => widget is ElView && widget.focusNode != null && widget.event?.onTap != null,
            ),
          )
          .first;
      List<Object> appearance() => tester
          .renderObjectList<ElRenderView>(find.descendant(of: target, matching: find.byType(ElView)))
          .map((render) => render.committedResolvedStyle)
          .toList();
      final initial = appearance();
      final touch = await tester.startGesture(tester.getCenter(action), kind: PointerDeviceKind.touch);
      await tester.pump(Duration(milliseconds: 80));
      expect(appearance(), isNot(initial), reason: '手机按压反馈仍然生效');
      await touch.cancel();
      await tester.pumpAndSettle();
      expect(appearance(), initial);
    });
  }

  testWidgets('显式声明的悬停和焦点变体仍由 ElView 生效', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final outline = ElOutline(outlineWidth: 2, outlineColor: Color(0xff123456));
    await tester.pumpWidget(
      shell(
        skin.Button(
          focusNode: focus,
          style: ElStyle(
            onHover: ElStyle(backgroundColor: Color(0xff654321)),
            onFocusVisible: ElStyle(outline: outline),
          ),
          child: '自定义外观',
        ),
      ),
    );
    final render = tester.renderObject<ElRenderView>(buttonHost());
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(buttonHost()));
    await tester.pumpAndSettle();
    expect(render.committedResolvedStyle.box.backgroundColor, Color(0xff654321));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(render.committedResolvedStyle.box.outline, outline);
  });

  testWidgets('skin.Tag 显式悬停和焦点变体使用真实交互宿主', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final outline = ElOutline(outlineWidth: 2, outlineColor: Color(0xff123456));
    await tester.pumpWidget(
      shell(
        skin.Tag(
          value: false,
          focusNode: focus,
          style: ElStyle(
            onHover: ElStyle(backgroundColor: Color(0xff654321)),
            onFocusVisible: ElStyle(outline: outline),
          ),
          child: '自定义标签',
        ),
      ),
    );
    final action = views(find.byType(skin.Tag), (view) => view.focusNode == focus && view.event?.onTap != null);
    final visual = tester.renderObject<ElRenderView>(
      views(find.byType(skin.Tag), (view) => view.style?.minHeight == 32),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(action));
    await tester.pumpAndSettle();
    expect(visual.committedResolvedStyle.box.backgroundColor, Color(0xff654321));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(focus.hasPrimaryFocus, isTrue);
    expect(visual.committedResolvedStyle.box.outline, outline);
  });

  testWidgets('skin.Tag 嵌套暗色悬停与焦点变体遵循 ElView 完整级联', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final outline = ElOutline(outlineWidth: 3, outlineColor: Color(0xff123456));
    await tester.pumpWidget(
      shell(
        skin.Tag(
          value: false,
          focusNode: focus,
          style: ElStyle(
            onHover: ElStyle(
              backgroundColor: Color(0xff654321),
              onFocusVisible: ElStyle(outline: outline),
            ),
            onDark: ElStyle(onHover: ElStyle(backgroundColor: Color(0xff246813))),
          ),
          child: '嵌套标签',
        ),
        brightness: Brightness.dark,
      ),
    );
    final action = views(find.byType(skin.Tag), (view) => view.focusNode == focus && view.event?.onTap != null);
    final render = tester.renderObject<ElRenderView>(action);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(action));
    await tester.pumpAndSettle();
    expect(render.committedResolvedStyle.box.backgroundColor, Color(0xff246813));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(focus.hasPrimaryFocus, isTrue);
    expect(render.committedResolvedStyle.box.backgroundColor, Color(0xff246813));
    expect(render.committedResolvedStyle.box.outline, outline);
    await mouse.moveTo(tester.getBottomRight(action) + Offset(30, 30));
    await tester.pumpAndSettle();
    expect(render.committedResolvedStyle.box.outline, isNull);
    expect(render.committedResolvedStyle.box.backgroundColor, isNot(Color(0xff246813)));
  });

  testWidgets('Button submit/reset与preventDefault', (tester) async {
    var clicks = 0, saved = 0, reset = 0;
    Widget form(skin.ButtonType type, {bool prevent = false}) => Form(
      child: Column(
        children: [
          FormField<String>(
            initialValue: 'a',
            onSaved: (_) => saved++,
            onReset: () => reset++,
            builder: (_) => SizedBox(),
          ),
          skin.Button(
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
    await tester.pumpWidget(shell(form(skin.ButtonType.submit)));
    await tester.tap(buttonHost());
    expect(saved, 1);
    await tester.pump(Duration(milliseconds: 120));
    await tester.pumpWidget(shell(form(skin.ButtonType.reset)));
    await tester.tap(buttonHost());
    expect(reset, 1);
    await tester.pump(Duration(milliseconds: 120));
    await tester.pumpWidget(shell(form(skin.ButtonType.submit, prevent: true)));
    await tester.tap(buttonHost());
    expect(saved, 1);
    expect(clicks, 3);
  });

  testWidgets('Tag展示28选择32，change先于click，外部同步不回调', (tester) async {
    final model = ValueNotifier(false);
    addTearDown(model.dispose);
    final events = <String>[];
    await tester.pumpWidget(shell(skin.Tag(child: '展示')));
    expect(tester.getSize(views(find.byType(skin.Tag), (v) => v.style?.minHeight == 28)).height, 28);
    await tester.pumpWidget(
      shell(
        skin.Tag(
          modelValue: model,
          child: '选择',
          onChanged: (v) => events.add('change:$v'),
          onClick: (_) => events.add('click'),
        ),
      ),
    );
    expect(tester.getSize(views(find.byType(skin.Tag), (v) => v.style?.minHeight == 32)).height, 32);
    await tester.tap(views(find.byType(skin.Tag), (v) => v.event?.onTap != null));
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
      shell(skin.Switch(modelValue: model, label: '通知', focusNode: focus, onChanged: (_) => changes++)),
    );
    expect(tester.getSize(switchHost()), Size(47, 28));
    final thumb = views(find.byType(skin.Switch), (v) => v.style?.width == 22);
    expect(tester.getSize(thumb), Size(22, 22));
    final before = tester.widget<ElView>(thumb).style!.transform;
    await tester.tap(switchHost());
    await tester.pump();
    expect(model.value, true);
    expect(changes, 1);
    expect(tester.widget<ElView>(thumb).style!.transform, isNot(before));
    expect(tester.widget<ElView>(thumb).style!.transform, ElTransform.translate(19, 0));
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
    await tester.pumpWidget(shell(skin.Switch(value: true, label: '通知', disabled: true, onChanged: (_) => calls++)));
    await tester.tap(switchHost());
    expect(calls, 0);
    expect(tester.widget<ElView>(switchHost()).style!.opacity, null);
    expect(
      tester.getSemantics(switchHost()),
      matchesSemantics(label: '通知', hasToggledState: true, isToggled: true, hasEnabledState: true, isEnabled: false),
    );
  });

  for (final width in [1200.0, 1000.0, 760.0, 400.0]) {
    testWidgets('Card viewport=$width 保持手机几何', (tester) async {
      final childKey = UniqueKey();
      await tester.pumpWidget(
        shell(
          ElCard(child: SizedBox(key: childKey, height: 20)),
          viewport: width,
        ),
      );
      final rootView = views(find.byType(ElCard), (v) => v.style?.width == '100%').first;
      expect(tester.widget<ElView>(rootView).style!.padding, EdgeInsets.fromLTRB(23, 25, 23, 26));
      expect(tester.getSize(rootView).width, 320);
      expect(tester.getTopLeft(find.byKey(childKey)).dx - tester.getTopLeft(rootView).dx, 23);
      expect(tester.widget<ElView>(rootView).style!.borderRadius, BorderRadius.circular(26));
      expect(tester.takeException(), null);
    });
  }

  testWidgets('交互Card内部按钮只激活自身', (tester) async {
    var card = 0, button = 0;
    await tester.pumpWidget(
      shell(
        ElCard(
          onTap: () => card++,
          child: Column(
            children: [
              skin.Button(child: '内部', onClick: (_) => button++),
              SizedBox(height: 70),
            ],
          ),
        ),
      ),
    );
    await tester.tap(buttonHost());
    expect(button, 1);
    expect(card, 0);
    await tester.pump(Duration(milliseconds: 120));
    final cardView = views(find.byType(ElCard), (v) => v.style?.width == '100%').first;
    await tester.tapAt(tester.getBottomLeft(cardView) + Offset(35, -30));
    expect(card, 1);
  });

  testWidgets('Divider默认水平41高，竖线13高含双侧12间距', (tester) async {
    await tester.pumpWidget(shell(skin.Divider()));
    expect(tester.getSize(find.byType(skin.Divider)), Size(320, 41));
    await tester.pumpWidget(shell(skin.Divider(vertical: true)));
    expect(tester.getSize(find.byType(skin.Divider)).height, 13);
    final line = views(find.byType(skin.Divider), (v) => v.style?.border?.borderLeft != null).last;
    expect(tester.getSize(line), Size(1, 13));
  });

  testWidgets('Divider长Widget插槽与start/end均无溢出', (tester) async {
    for (final align in skin.DividerAlign.values) {
      await tester.pumpWidget(shell(skin.Divider(align: align, dashed: true, child: Text('很长的分割说明' * 8))));
      expect(find.byType(Text), findsOneWidget);
      expect(tester.takeException(), null);
    }
  });

  for (final size in skin.LoadingSize.values) {
    testWidgets('Loading ${size.name} 尺寸与status语义', (tester) async {
      await tester.pumpWidget(shell(skin.Loading(size: size)));
      final icon = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == 'Glyph');
      expect(tester.getSize(icon), Size.square(size.pixels));
      final node = tester.getSemantics(find.byType(skin.Loading));
      expect(node.getSemanticsData().role, SemanticsRole.loadingSpinner);
      expect(node.label, '加载中');
    });
  }

  testWidgets('Skeleton默认123高、42%标题、66%末行、首行gap18', (tester) async {
    await tester.pumpWidget(shell(skin.Skeleton()));
    expect(tester.getSize(find.byType(skin.Skeleton)), Size(320, 123));
    final title = views(find.byType(skin.Skeleton), (v) => v.style?.width == '42%');
    final lines = views(find.byType(skin.Skeleton), (v) => v.style?.height == 13);
    expect(tester.getSize(title).width, closeTo(134.4, .01));
    expect(tester.getSize(lines.last).width, closeTo(211.2, .01));
    expect(tester.getTopLeft(lines.first).dy - tester.getBottomLeft(title).dy, 18);
  });

  for (final entry in <num, int>{0: 3, double.nan: 3, -5: 1, 1.9: 1, 99: 10, double.infinity: 10}.entries) {
    testWidgets('Skeleton rows=${entry.key} 按Web归一化', (tester) async {
      await tester.pumpWidget(shell(skin.Skeleton(rows: entry.key)));
      expect(views(find.byType(skin.Skeleton), (v) => v.style?.height == 13), findsNWidgets(entry.value));
    });
  }

  testWidgets('Skeleton loading来回切换保留正文State及计数', (tester) async {
    final probe = GlobalKey<ProbeState>();
    Widget skeleton(bool loading) => skin.Skeleton(
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
    skin.ProgressValue? seen;
    await tester.pumpWidget(
      shell(
        skin.Progress(
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
    var data = tester.getSemantics(find.byType(skin.Progress)).getSemanticsData();
    expect(data.role, SemanticsRole.progressBar);
    expect(data.value, '100%');
    expect(data.hint, '已缓冲 100%');
    await tester.pumpWidget(shell(skin.Progress(value: double.nan)));
    data = tester.getSemantics(find.byType(skin.Progress)).getSemanticsData();
    expect(data.value, '进行中');
    expect(textView('0%'), findsOneWidget);
  });

  testWidgets('Progress圆环96px，隐藏/换类型保留插槽State', (tester) async {
    final probe = GlobalKey<ProbeState>();
    Widget progress(skin.ProgressType type, bool show) => skin.Progress(
      value: 25,
      type: type,
      showText: show,
      textBuilder: (_, value) => StateProbe(key: probe),
    );
    await tester.pumpWidget(shell(progress(skin.ProgressType.line, true)));
    final state = probe.currentState;
    await tester.pumpWidget(shell(progress(skin.ProgressType.circle, true)));
    expect(tester.getSize(views(find.byType(skin.Progress), (v) => v.style?.width == 96)), Size(96, 96));
    expect(probe.currentState, same(state));
    await tester.pumpWidget(shell(progress(skin.ProgressType.circle, false)));
    expect(probe.currentState, same(state));
    expect(find.text('count:0'), findsNothing);
    expect(tester.takeException(), null);
  });

  testWidgets('减少动画不循环调帧，普通模式卸载释放ticker', (tester) async {
    Widget group() => Column(children: [skin.Loading(), skin.Skeleton(), skin.Progress()]);
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
        skin.Button(
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
    await tester.pumpWidget(shell(skin.Button(child: '保存', loading: true, selected: true)));
    final node = tester.getSemantics(buttonHost()).getSemanticsData();
    expect(node.label, '保存');
    expect(node.flagsCollection.isToggled, Tristate.isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);
  });

  testWidgets('Card键盘Enter不响应repeat，Space失焦取消', (tester) async {
    late FocusNode focus;
    final other = FocusNode();
    addTearDown(other.dispose);
    var calls = 0;
    await tester.pumpWidget(
      shell(
        Column(
          children: [
            ElCard(onTap: () => calls++, child: SizedBox(height: 30)),
            Focus(focusNode: other, child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
    focus = tester.widget<ElView>(views(find.byType(ElCard), (view) => view.focusNode != null).first).focusNode!;
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
    final theme = el.mobileComponents.token!.vars!;
    final accents = [
      (theme[ElTokens.$primary] as Color),
      (theme[ElTokens.$success] as Color),
      (theme[ElTokens.$warning] as Color),
      (theme[ElTokens.$error] as Color),
      (theme[ElTokens.$textSecondary] as Color),
    ];
    for (var i = 0; i < skin.TagTone.values.length; i++) {
      await tester.pumpWidget(shell(skin.Tag(tone: skin.TagTone.values[i], child: '标签')));
      final view = tester.widget<ElView>(views(find.byType(skin.Tag), (v) => v.style?.minHeight == 28));
      expect(view.style!.color, accents[i]);
      expect(view.style!.backgroundColor, Color.lerp((theme[ElTokens.$cardColor] as Color), accents[i], .1));
    }
    var calls = 0;
    await tester.pumpWidget(
      shell(skin.Tag(value: false, disabled: true, child: '禁用', onChanged: (_) => calls++, onClick: (_) => calls++)),
    );
    await tester.tap(views(find.byType(skin.Tag), (v) => v.event?.onTap != null));
    expect(calls, 0);
  });

  testWidgets('组件主题变量有真实消费者', (tester) async {
    final theme = ElStyle(
      vars: {
        skin.Switch.$thumbBackground: Color(0xff123456),
        skin.Divider.$height: 31,
        skin.Divider.$spacing: 4,
        skin.Progress.$size: 80,
        skin.Progress.$thickness: 9,
      },
    );
    await tester.pumpWidget(
      shell(
        Column(
          children: [
            ElCard(
              style: ElStyle(padding: EdgeInsets.all(6), borderRadius: .circular(11)),
              child: SizedBox(height: 10),
            ),
            skin.Switch(value: false, label: '开关'),
            skin.Divider(vertical: true),
            skin.Progress(value: 50, type: skin.ProgressType.circle),
          ],
        ),
        theme: theme,
      ),
    );
    expect(
      tester.widget<ElView>(views(find.byType(ElCard), (v) => v.style?.width == '100%').first).style!.padding,
      EdgeInsets.all(6),
    );
    expect(
      tester.widget<ElView>(views(find.byType(skin.Switch), (v) => v.style?.width == 22)).style!.backgroundColor,
      Color(0xff123456),
    );
    expect(tester.getSize(find.byType(skin.Divider)).height, 31);
    expect(tester.getSize(views(find.byType(skin.Progress), (v) => v.style?.width == 80)), Size(80, 80));
  });

  testWidgets('Skeleton隐藏正文退出焦点并保留可重新聚焦节点', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    Widget skeleton(bool loading) => skin.Skeleton(
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
    expect(views(find.byType(skin.Skeleton), (v) => v.style?.width == 42), findsOneWidget);
    await tester.pumpWidget(shell(skeleton(false)));
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, true);
  });

  testWidgets('Progress确定值用200ms CSS ease过渡，语义同步目标值', (tester) async {
    Finder paint() => find.descendant(of: find.byType(skin.Progress), matching: find.byType(CustomPaint));
    await tester.pumpWidget(shell(skin.Progress(value: 20), reduced: false));
    await tester.pumpWidget(shell(skin.Progress(value: 80), reduced: false));
    dynamic painter = tester.widget<CustomPaint>(paint()).painter;
    expect(painter.ratio, closeTo(.2, .001));
    await tester.pump(Duration(milliseconds: 100));
    painter = tester.widget<CustomPaint>(paint()).painter;
    expect(painter.ratio, closeTo(.2 + .6 * Curves.ease.transform(.5), .001));
    expect(tester.getSemantics(find.byType(skin.Progress)).value, '80%');
    await tester.pump(Duration(milliseconds: 100));
    painter = tester.widget<CustomPaint>(paint()).painter;
    expect(painter.ratio, closeTo(.8, .001));
    await tester.pumpWidget(shell(SizedBox()));
  });

  testWidgets('Button最短反馈从按下起算，短于down延迟不补播', (tester) async {
    var pressed = false, clicks = 0;
    await tester.pumpWidget(
      shell(
        skin.Button(
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
                ElComponentProvider(
                  components: el.mobileComponents,
                  child: ElView(
                    style: ElStyle(vars: {ElTokens.$primary: color}),
                    child: skin.Button(key: nested, child: '局部'),
                  ),
                ),
                skin.Button(key: sibling, child: '默认'),
              ],
            );
          },
        ),
      ),
    );
    Color? background(Key key) =>
        tester.widget<ElView>(views(find.byKey(key), (v) => v.event?.onTap != null)).style!.backgroundColor;
    expect(background(nested), color);
    expect(background(sibling), Color(0xff1076fd));
    update(() => color = Color(0xff554433));
    await tester.pump();
    expect(background(nested), color);
    expect(background(sibling), Color(0xff1076fd));
  });

  testWidgets('Card内部Flutter按钮与输入不触发整卡', (tester) async {
    var card = 0, inner = 0;
    await tester.pumpWidget(
      shell(
        ElCard(
          onTap: () => card++,
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
          child: ElCard(
            onTap: () => card++,
            child: skin.Button(child: '操作', onClick: (_) => button++),
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
        ElCard(
          onTap: () => card++,
          child: skin.Button(disabled: true, child: '禁用'),
        ),
      ),
    );
    await tester.tap(buttonHost());
    expect(card, 0);
  });

  testWidgets('Progress条形默认21高，隐藏读数时仅轨道6高', (tester) async {
    await tester.pumpWidget(shell(skin.Progress(value: 40)));
    expect(tester.getSize(find.byType(skin.Progress)), Size(320, 21));
    await tester.pumpWidget(shell(skin.Progress(value: 40, showText: false)));
    expect(tester.getSize(find.byType(skin.Progress)), Size(320, 6));
  });
}
