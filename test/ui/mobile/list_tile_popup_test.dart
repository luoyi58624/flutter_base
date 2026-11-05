import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool animations = false, double width = 320}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: !animations),
    child: ElComponentProvider(
      components: el.mobileComponents,
      child: Align(
        alignment: .topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

Finder _text(String text) => find.byWidgetPredicate(
  (widget) => widget is ElView && widget.child == text || widget is Text && widget.data == text,
);
Finder _panel(Color color) => find.byWidgetPredicate(
  (widget) =>
      widget is ElView &&
      widget.style?.backgroundColor == color &&
      widget.style?.borderRadius == BorderRadius.circular(17),
);
Finder _focused() => find.byWidgetPredicate((widget) => widget is ElView && widget.focusNode?.hasPrimaryFocus == true);
Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('默认菜单从真实按压点定位，显式元素锚仍按配置定位', (tester) async {
    final color = Color(0xfff1e1df);
    await tester.pumpWidget(
      _host(
        ElListTile<int>.popup(
          title: Text('打开'),
          value: 1,
          popupStyle: ElStyle(backgroundColor: color),
          options: [ElLabelModel('候选一', 1), ElLabelModel('候选二', 2)],
        ),
      ),
    );
    final point = tester.getRect(find.byType(ElListTile<int>)).center;
    await tester.tapAt(point);
    await tester.pumpAndSettle();
    final portal = tester.widget<ElPortal>(find.byType(ElPortal));
    expect(portal.anchorPosition, point);
    expect(tester.getRect(_panel(color)).width, 236);
    expect(tester.getRect(_panel(color)).top, closeTo(point.dy + 4, .01));
    expect(portal.closeOnOutsidePointerDown, isTrue);
    expect(portal.closeOnScroll, isTrue);
  });

  testWidgets('菜单Tab逐项循环、跳过禁用项并支持Home End与字符查找', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final model = ValueNotifier<int>(1);
    addTearDown(model.dispose);
    await tester.pumpWidget(
      _host(
        ElListTile<int>.popup(
          title: Text('键盘打开'),
          focusNode: focus,
          modelValue: model,
          options: [
            ElMenuOption('Alpha', 1),
            ElMenuOption('Blocked', 2, disabled: true),
            ElMenuOption('Beta', 3),
            ElMenuOption('Charlie', 4),
          ],
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tester.widget<ElPortal>(find.byType(ElPortal)).anchorPosition, isNull);
    expect(find.descendant(of: _focused(), matching: _text('Alpha')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.descendant(of: _focused(), matching: _text('Beta')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(find.descendant(of: _focused(), matching: _text('Charlie')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.descendant(of: _focused(), matching: _text('Alpha')), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.descendant(of: _focused(), matching: _text('Charlie')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB, character: 'b');
    await tester.pumpAndSettle();
    expect(find.descendant(of: _focused(), matching: _text('Beta')), findsOneWidget);
    expect(model.value, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(model.value, 3);
    expect(focus.hasPrimaryFocus, isTrue);
  });

  testWidgets('长菜单先滚入当前项，菜单内部滚动不关闭', (tester) async {
    final color = Color(0xffe7ede2);
    await tester.pumpWidget(
      _host(
        ElListTile<int>.popup(
          title: Text('长菜单'),
          value: 32,
          popupMaxHeight: 180,
          popupStyle: ElStyle(backgroundColor: color),
          options: [for (var i = 0; i < 40; i++) ElLabelModel('候选第$i项', i)],
        ),
      ),
    );
    await _tap(tester, find.text('长菜单'));
    final panel = _panel(color);
    final selected = find.descendant(of: _focused(), matching: _text('候选第32项'));
    expect(selected, findsOneWidget);
    final rect = tester.getRect(panel), row = tester.getRect(selected);
    expect(row.top, greaterThanOrEqualTo(rect.top));
    expect(row.bottom, lessThanOrEqualTo(rect.bottom));
    await tester.drag(panel, Offset(0, 70));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
  });

  testWidgets('嵌套菜单保留父滚动、返回焦点及业务泛型，只有叶子提交', (tester) async {
    final model = ValueNotifier<int>(7);
    addTearDown(model.dispose);
    final color = Color(0xfff2e5ef);
    final changes = <int>[];
    await tester.pumpWidget(
      _host(
        ElListTile<int>.popup(
          title: Text('树菜单'),
          modelValue: model,
          onChanged: changes.add,
          popupMaxHeight: 260,
          popupStyle: ElStyle(backgroundColor: color),
          options: [
            for (var i = 0; i < 7; i++) ElMenuOption('根第$i项', i),
            ElMenuOption(
              '父分类',
              20,
              description: '分类说明',
              leading: Icons.folder,
              children: [ElMenuOption('子叶一', 21), ElMenuOption('子叶二', 22)],
            ),
            ElMenuOption('根尾项', 7),
          ],
        ),
      ),
    );
    await _tap(tester, find.text('树菜单'));
    final rootPanel = _panel(color);
    final scroll = tester
        .widget<SingleChildScrollView>(
          find.descendant(of: rootPanel, matching: find.byType(SingleChildScrollView)).first,
        )
        .controller!;
    await tester.ensureVisible(_text('父分类'));
    await tester.pumpAndSettle();
    final offset = scroll.offset;
    await _tap(tester, _text('父分类'));
    expect(_panel(color), findsNWidgets(2));
    expect(_text('子叶二'), findsOneWidget);
    expect(model.value, 7);
    expect(changes, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_panel(color), findsOneWidget);
    expect(scroll.offset, closeTo(offset, .01));
    expect(find.descendant(of: _focused(), matching: _text('父分类')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await _tap(tester, _text('子叶二'));
    expect(model.value, 22);
    expect(changes, [22]);
    expect(_panel(color), findsNothing);
    expect(_text('子叶二'), findsOneWidget);
  });

  testWidgets('通知前先关闭交互并归还焦点，打开另一根菜单只保留新菜单交互', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var closedBeforeChange = false;
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: .min,
          children: [
            ElListTile<int>.popup(
              title: Text('第一个'),
              value: 1,
              focusNode: focus,
              options: [ElLabelModel('旧一', 1), ElLabelModel('旧二', 2)],
              onChanged: (_) {
                final portals = tester.widgetList<ElPortal>(find.byType(ElPortal));
                closedBeforeChange = !portals.first.controller!.isOpen && focus.hasPrimaryFocus;
              },
            ),
            SizedBox(height: 200),
            ElListTile<int>.popup(
              title: Text('第二个'),
              value: 3,
              options: [ElLabelModel('新三', 3), ElLabelModel('新四', 4)],
            ),
          ],
        ),
      ),
    );
    await _tap(tester, find.text('第一个'));
    await _tap(tester, _text('旧二'));
    expect(closedBeforeChange, isTrue);
    await _tap(tester, find.text('第一个'));
    await _tap(tester, find.text('第二个'));
    expect(_text('旧一'), findsNothing);
    expect(_text('新四'), findsOneWidget);
    final portals = tester.widgetList<ElPortal>(find.byType(ElPortal)).toList();
    expect(portals.first.controller!.isOpen, isFalse);
    expect(portals.last.controller!.isOpen, isTrue);
  });

  testWidgets('动态移除分支恢复父层姿态和有效焦点，禁用全部选项仍可Escape关闭', (tester) async {
    final color = Color(0xffe2f0ec);
    final model = ValueNotifier<int>(1);
    addTearDown(model.dispose);
    var mode = 0;
    late StateSetter refresh;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            return ElListTile<int>.popup(
              title: Text('动态菜单'),
              modelValue: model,
              popupStyle: ElStyle(backgroundColor: color),
              options: mode == 0
                  ? [
                      ElMenuOption('原叶', 1),
                      ElMenuOption('旧分支', 20, children: [ElMenuOption('分支叶', 21)]),
                    ]
                  : [ElMenuOption('新叶', 3, disabled: mode == 2), ElMenuOption('禁用原叶', 1, disabled: true)],
            );
          },
        ),
      ),
    );
    await _tap(tester, find.text('动态菜单'));
    await _tap(tester, _text('旧分支'));
    expect(_panel(color), findsNWidgets(2));
    refresh(() => mode = 1);
    await tester.pumpAndSettle();
    expect(_panel(color), findsOneWidget);
    expect(_text('分支叶'), findsNothing);
    expect(find.descendant(of: _focused(), matching: _text('新叶')), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is Transform && (widget.transform.storage[0] - .94).abs() < .001),
      findsNothing,
    );
    refresh(() => mode = 2);
    await tester.pumpAndSettle();
    expect(_panel(color), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_panel(color), findsNothing);
    await _tap(tester, find.text('动态菜单'));
    expect(_panel(color), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_panel(color), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('退出期间快速重开创建新菜单会话，卸载不留下动画或旧回调', (tester) async {
    final color = Color(0xfff1edda);
    final model = ValueNotifier<int>(1);
    addTearDown(model.dispose);
    final changes = <int>[];
    await tester.pumpWidget(
      _host(
        ElListTile<int>.popup(
          title: Text('重开菜单'),
          modelValue: model,
          onChanged: changes.add,
          popupStyle: ElStyle(backgroundColor: color),
          options: [ElLabelModel('重开一', 1), ElLabelModel('重开二', 2)],
        ),
        animations: true,
      ),
    );
    await _tap(tester, find.text('重开菜单'));
    final portal = tester.widget<ElPortal>(find.byType(ElPortal)).controller!;
    portal.close();
    await tester.pump(Duration(milliseconds: 40));
    portal.open();
    await tester.pumpAndSettle();
    expect(portal.isOpen, isTrue);
    expect(_panel(color), findsOneWidget);
    await _tap(tester, _text('重开二'));
    expect(model.value, 2);
    expect(changes, [2]);
    await _tap(tester, find.text('重开菜单'));
    portal.close();
    await tester.pump();
    await tester.pumpWidget(SizedBox());
    await tester.pump(Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('子层长说明先整体上移，放得下时不提前变成滚动菜单', (tester) async {
    final color = Color(0xffefe6dc);
    await tester.pumpWidget(
      _host(
        ElListTile<int>.popup(
          title: Text('长说明菜单'),
          value: 0,
          popupMaxHeight: 260,
          popupStyle: ElStyle(backgroundColor: color),
          options: [
            for (var i = 0; i < 3; i++) ElMenuOption('普通$i', i),
            ElMenuOption('展开分类', 20, children: [ElMenuOption('说明子项', 21, description: '第一行说明\n第二行说明\n第三行说明')]),
          ],
        ),
      ),
    );
    await _tap(tester, find.text('长说明菜单'));
    final original = tester.getRect(_text('展开分类')).top;
    await _tap(tester, _text('展开分类'));
    final panels = _panel(color);
    expect(panels, findsNWidgets(2));
    final child = panels.last;
    final scroll = tester
        .widget<SingleChildScrollView>(find.descendant(of: child, matching: find.byType(SingleChildScrollView)))
        .controller!;
    expect(scroll.position.maxScrollExtent, closeTo(0, .01));
    expect(tester.getRect(child).top, lessThan(original));
    expect(tester.takeException(), isNull);
  });

  testWidgets('三级菜单系统返回逐层恢复，根层返回才关闭并归还触发焦点', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final color = Color(0xffe7ddeb);
    final changes = <int>[];
    await tester.pumpWidget(
      _host(
        ElListTile<int>.popup(
          title: Text('系统菜单'),
          value: 33,
          focusNode: focus,
          onChanged: changes.add,
          popupStyle: ElStyle(backgroundColor: color),
          options: [
            ElMenuOption(
              '第一层',
              11,
              children: [
                ElMenuOption('第二层', 22, children: [ElMenuOption('最终叶子', 33)]),
              ],
            ),
          ],
        ),
      ),
    );
    final navigator = Navigator.of(tester.element(find.text('系统菜单')));
    await _tap(tester, find.text('系统菜单'));
    await _tap(tester, _text('第一层').last);
    await _tap(tester, _text('第二层').last);
    expect(_panel(color), findsNWidgets(3));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(_panel(color), findsNWidgets(2));
    expect(find.descendant(of: _focused(), matching: _text('第二层')), findsOneWidget);
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(_panel(color), findsOneWidget);
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(_panel(color), findsNothing);
    expect(focus.hasPrimaryFocus, isTrue);
    expect(changes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('深树与短高度下返回标题可滚动，不挤出当前层', (tester) async {
    final color = Color(0xffe4e9db);
    ElMenuOption<int> branch = ElMenuOption('最终选项', 99);
    for (var i = 5; i >= 0; i--) {
      branch = ElMenuOption('深层$i', i, description: i == 4 ? '一行\n二行\n三行\n四行\n五行\n六行' : null, children: [branch]);
    }
    await tester.pumpWidget(
      _host(
        ElListTile<int>.popup(
          title: Text('深树入口'),
          value: 99,
          popupMaxHeight: 140,
          popupStyle: ElStyle(backgroundColor: color),
          options: [branch],
        ),
      ),
    );
    await _tap(tester, find.text('深树入口'));
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.descendant(of: _focused(), matching: _text('最终选项')), findsOneWidget);
    for (final element in _panel(color).evaluate()) {
      expect(tester.getRect(find.byWidget(element.widget)).height, lessThanOrEqualTo(140.01));
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('长菜单移入视口后仍从内部真实按压点展开', (tester) async {
    tester.view.physicalSize = Size(400, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final color = Color(0xfff0e2d9);
    await tester.pumpWidget(
      _host(
        Padding(
          padding: EdgeInsets.only(top: 190),
          child: ElListTile<int>.popup(
            title: Text('底部入口'),
            value: 0,
            popupMaxHeight: 244,
            popupStyle: ElStyle(backgroundColor: color),
            options: [for (var i = 0; i < 10; i++) ElLabelModel('边界$i', i)],
          ),
        ),
        animations: true,
      ),
    );
    final point = tester.getCenter(find.text('底部入口'));
    await tester.tapAt(point);
    await tester.pump();
    await tester.pump();
    await tester.pump(Duration(milliseconds: 80));
    final geometry = ElPortal.geometryOf(tester.element(_panel(color)))!;
    final transform = tester.widget<Transform>(
      find.byWidgetPredicate((widget) => widget is Transform && widget.origin != null),
    );
    expect(transform.origin!.dx, closeTo(point.dx - geometry.overlayRect.left, .01));
    expect(transform.origin!.dy, closeTo(point.dy - geometry.overlayRect.top, .01));
    expect(transform.origin!.dy, greaterThan(20));
    expect(transform.origin!.dy, lessThan(geometry.overlayRect.height - 10));
    tester.widget<ElPortal>(find.byType(ElPortal)).controller!.close();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('展开中关闭只淡出并冻结缩放，退出期间不可再次选择', (tester) async {
    final color = Color(0xffe0eaf1);
    final changes = <int>[];
    await tester.pumpWidget(
      _host(
        ElListTile<int>.popup(
          title: Text('动画菜单'),
          value: 1,
          onChanged: changes.add,
          popupStyle: ElStyle(backgroundColor: color),
          options: [ElLabelModel('动画一', 1), ElLabelModel('动画二', 2)],
        ),
        animations: true,
      ),
    );
    await tester.tap(find.text('动画菜单'));
    await tester.pump();
    await tester.pump();
    await tester.pump(Duration(milliseconds: 80));
    final transforms = find.byWidgetPredicate((widget) => widget is Transform && widget.origin != null);
    expect(transforms, findsOneWidget);
    final before = tester.widget<Transform>(transforms).transform.storage[0];
    expect(before, inExclusiveRange(0, 1));
    final down = await tester.startGesture(Offset(700, 500));
    await tester.pump();
    final frozen = tester.widget<Transform>(transforms).transform.storage[0];
    await tester.pump(Duration(milliseconds: 80));
    expect(tester.widget<Transform>(transforms).transform.storage[0], closeTo(frozen, .0001));
    expect(_panel(color), findsOneWidget);
    final target = tester.getCenter(_text('动画二'));
    await tester.tapAt(target);
    await down.up();
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(_panel(color), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
