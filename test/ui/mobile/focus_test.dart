import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: ElComponentProvider(
      components: el.mobileComponents,
      child: Center(child: SizedBox(width: 320, child: child)),
    ),
  ),
);

void main() {
  final samples = <String, Widget Function()>{
    '按钮': () => ElButton(onPressed: () {}, child: '按钮'),
    '切换按钮': () => ElButton.toggle(child: '切换'),
    '开关': () => ElSwitch(semanticLabel: '开关'),
    '标签': () => ElTag.toggle(closable: true, onClose: () {}, child: '标签'),
    '卡片': () => ElCard(onTap: () {}, child: Text('卡片')),
    '列表行': () => ElListTile(title: Text('列表行'), onTap: () {}),
    '单选列表': () => ElListGroup<int>.single(value: 1, children: [ElListTile<int>(value: 1, title: Text('选项'))]),
    '滑块': () => ElSlider<double>(value: 50),
    '底部导航': () => ElBottomTabbar(
      destinations: [NavigationDestination(icon: Icon(Icons.home), label: '首页')],
      onDestinationSelected: (_) {},
    ),
  };
  for (final sample in samples.entries) {
    testWidgets('移动端${sample.key}默认不抢占焦点或参与Tab导航', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final key = ValueKey('subject');
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: .min,
            children: [
              Focus(focusNode: focus, child: SizedBox()),
              KeyedSubtree(key: key, child: sample.value()),
            ],
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(focus.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focus.hasPrimaryFocus, isTrue);
    });
  }

  testWidgets('移动端按钮通过用户焦点变体启用焦点和键盘激活', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _host(
        ElButton(
          style: ElStyle(onFocus: ElStyle(opacity: 0.4)),
          onPressed: () => calls++,
          child: '显式焦点',
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      tester
          .renderObjectList<ElRenderView>(find.byType(ElView))
          .any((render) => render.committedResolvedStyle.box.opacity == 0.4),
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('默认弹出菜单打开和选择都保留原焦点', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final model = ValueNotifier<int>(1);
    addTearDown(model.dispose);
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: .min,
          children: [
            Focus(focusNode: focus, child: SizedBox()),
            ElListTile<int>.popup(
              title: Text('打开菜单'),
              modelValue: model,
              options: [ElLabelModel('第一项', 1), ElLabelModel('第二项', 2)],
            ),
          ],
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.tap(find.text('打开菜单'));
    await tester.pumpAndSettle();
    expect(focus.hasPrimaryFocus, isTrue);
    expect(tester.widget<ElPortal>(find.byType(ElPortal)).captureFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(focus));
    await tester.tap(find.byWidgetPredicate((widget) => widget is ElView && widget.child == '第二项'));
    await tester.pumpAndSettle();
    expect(model.value, 2);
    expect(focus.hasPrimaryFocus, isTrue);
  });

  testWidgets('撤掉用户焦点配置时清理未释放的键盘按压', (tester) async {
    final enabled = ValueNotifier(true);
    addTearDown(enabled.dispose);
    var calls = 0;
    final key = ValueKey('changing-focus');
    await tester.pumpWidget(
      _host(
        ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (_, value, _) => ElButton(
            key: key,
            style: ElStyle(onFocus: value ? ElStyle() : null, onTap: ElStyle(opacity: 0.3)),
            onPressed: () => calls++,
            child: '切换焦点配置',
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    enabled.value = false;
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    final views = find.descendant(of: find.byKey(key), matching: find.byType(ElView));
    expect(tester.widgetList<ElView>(views).map((view) => view.focusNode), everyElement(isNull));
    expect(
      tester.renderObjectList<ElRenderView>(views).map((render) => render.committedResolvedStyle.box.opacity),
      isNot(contains(0.3)),
    );
    expect(calls, 0);
  });
}
