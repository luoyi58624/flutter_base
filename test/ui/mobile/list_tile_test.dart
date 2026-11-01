import 'dart:ui' show CheckedState, PointerDeviceKind;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool cupertino = false, double width = 320, ElStyle? style}) {
  final body = MediaQuery(
    data: MediaQueryData(disableAnimations: true),
    child: MyTheme(
      style: style,
      child: Align(
        alignment: .topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
  return cupertino ? CupertinoApp(home: body) : MaterialApp(home: body);
}

Finder _text(String text) => find.byWidgetPredicate(
  (widget) => (widget is Text && widget.data == text) || (widget is ElView && widget.child == text),
);

Finder _icon(IconData icon) => find.byWidgetPredicate(
  (widget) => (widget is Icon && widget.icon == icon) || (widget is ElView && widget.child == icon),
);

Finder _views(bool Function(ElView view) predicate, {Finder? parent}) {
  final matching = find.byWidgetPredicate((widget) => widget is ElView && predicate(widget));
  return parent == null ? matching : find.descendant(of: parent, matching: matching);
}

Finder _divider() => find.byWidgetPredicate(
  (widget) => (widget is SizedBox && widget.height == .5) || (widget is ElView && widget.style?.height == .5),
);

Future<void> _tap(WidgetTester tester, Finder finder, {bool warnIfMissed = true}) async {
  await tester.tap(finder, warnIfMissed: warnIfMissed);
  await tester.pumpAndSettle();
}

enum _Preference { system, dark }

class _Item {
  _Item(this.id);

  final int id;

  @override
  bool operator ==(Object other) => other is _Item && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

void main() {
  testWidgets('独立行保留上下16及无前缀16、有前缀56的内容起点', (tester) async {
    final rowKey = GlobalKey();
    await tester.pumpWidget(_host(ElListTile(key: rowKey, title: Text('独立行'), trailing: null)));
    final row = find.byKey(rowKey);
    expect(tester.getTopLeft(_text('独立行')).dx - tester.getTopLeft(row).dx, 16);
    expect(tester.getSize(row).height - tester.getSize(_text('独立行')).height, 32);
    expect(_divider(), findsNothing);
    expect(tester.takeException(), isNull);

    final prefixKey = GlobalKey();
    await tester.pumpWidget(
      _host(
        ElListTile(
          key: rowKey,
          title: Text('有前缀'),
          leading: SizedBox(key: prefixKey, width: 24, height: 24),
          trailing: null,
        ),
      ),
    );
    expect(tester.getTopLeft(_text('有前缀')).dx - tester.getTopLeft(row).dx, 56);
    expect(tester.getCenter(find.byKey(prefixKey)).dx - tester.getTopLeft(row).dx, 28);
  });

  testWidgets('分组沿用圆角16容器和内缩分隔线，最后一行不画线', (tester) async {
    final groupKey = GlobalKey();
    final card = Color(0xfffaf8f3);
    await tester.pumpWidget(
      _host(
        ElListTileGroup(
          key: groupKey,
          title: Text('分组标题'),
          children: [
            ElListTile(title: Text('第一行'), leading: SizedBox.square(dimension: 24), trailing: null),
            ElListTile(title: Text('最后一行'), trailing: null),
          ],
        ),
        style: ElStyle(vars: {ElTheme.$cardColor: card}),
      ),
    );
    expect(_text('分组标题'), findsOneWidget);
    final container = _views(
      (view) => view.style?.borderRadius == BorderRadius.circular(16),
      parent: find.byKey(groupKey),
    );
    expect(container, findsOneWidget);
    expect(tester.widget<ElView>(container).style?.clipBehavior, Clip.hardEdge);
    expect(tester.renderObject<ElRenderView>(container).committedResolvedStyle.box.backgroundColor, card);
    expect(_divider(), findsOneWidget);
    final divider = tester.getRect(_divider());
    final body = tester.getRect(container);
    expect(divider.height, .5);
    expect(divider.left - body.left, 56);
    expect(body.right - divider.right, 16);
  });

  testWidgets('默认后缀严格跟随App类型，null移除而自定义后缀保留', (tester) async {
    for (final cupertino in [false, true]) {
      await tester.pumpWidget(_host(ElListTile(title: Text('默认后缀')), cupertino: cupertino));
      expect(_icon(cupertino ? CupertinoIcons.chevron_forward : Icons.chevron_right), findsOneWidget);
      expect(_icon(cupertino ? Icons.chevron_right : CupertinoIcons.chevron_forward), findsNothing);
      await tester.pumpWidget(_host(ElListTile(title: Text('无后缀'), trailing: null), cupertino: cupertino));
      expect(_icon(Icons.chevron_right), findsNothing);
      expect(_icon(CupertinoIcons.chevron_forward), findsNothing);
    }
    await tester.pumpWidget(_host(ElListTile(title: Text('自定义后缀'), trailing: Text('自定义'))));
    expect(_text('自定义'), findsOneWidget);
    expect(_icon(Icons.chevron_right), findsNothing);
  });

  testWidgets('标题说明与尾部当前值支持Widget和窄宽换行', (tester) async {
    final titleKey = GlobalKey();
    final subtitleKey = GlobalKey();
    final valueKey = GlobalKey();
    await tester.pumpWidget(
      _host(
        ElListTile(
          title: Text('主标题', key: titleKey),
          subtitle: Text('这里是一段足够长的说明，需要在窄行宽中自然换行', key: subtitleKey),
          trailingText: Text('当前值', key: valueKey),
          trailing: null,
        ),
        width: 220,
      ),
    );
    expect(tester.getTopLeft(find.byKey(subtitleKey)).dy, greaterThan(tester.getTopLeft(find.byKey(titleKey)).dy));
    expect(tester.getSize(find.byKey(subtitleKey)).height, greaterThan(tester.getSize(find.byKey(titleKey)).height));
    expect(tester.getTopLeft(find.byKey(valueKey)).dx, greaterThan(tester.getTopLeft(find.byKey(titleKey)).dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('普通行支持外借焦点键盘激活，事件取消和禁用拦截默认动作', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var calls = 0;
    await tester.pumpWidget(_host(ElListTile(title: Text('键盘行'), focusNode: focus, onTap: () => calls++)));
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(calls, 2);

    await tester.pumpWidget(
      _host(
        ElListTile(
          title: Text('取消行'),
          onTap: () => calls++,
          event: ElEvent(onTap: (event) => event.preventDefault()),
        ),
      ),
    );
    await _tap(tester, _text('取消行'));
    expect(calls, 2);
    await tester.pumpWidget(_host(ElListTile(title: Text('禁用行'), disabled: true, onTap: () => calls++)));
    await _tap(tester, _text('禁用行'), warnIfMissed: false);
    expect(calls, 2);
  });

  testWidgets('按压取消恢复外观且不激活，默认鼠标悬停不改变手机外观', (tester) async {
    final rowKey = GlobalKey();
    final base = Color(0xff123456);
    final pressed = Color(0xff654321);
    var calls = 0;
    await tester.pumpWidget(
      _host(
        ElListTile(
          key: rowKey,
          title: Text('按压行'),
          onTap: () => calls++,
          style: ElStyle(
            backgroundColor: base,
            onTap: ElStyle(backgroundColor: pressed),
          ),
        ),
      ),
    );
    final host = _views((view) => view.event?.onTap != null, parent: find.byKey(rowKey)).first;
    final render = tester.renderObject<ElRenderView>(host);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset(600, 500));
    await mouse.moveTo(tester.getCenter(host));
    await tester.pumpAndSettle();
    expect(render.committedResolvedStyle.box.backgroundColor, base);
    final touch = await tester.startGesture(tester.getCenter(host), kind: PointerDeviceKind.touch);
    await tester.pump(Duration(milliseconds: 80));
    expect(render.committedResolvedStyle.box.backgroundColor, pressed);
    await touch.cancel();
    await tester.pumpAndSettle();
    expect(render.committedResolvedStyle.box.backgroundColor, base);
    expect(calls, 0);
  });

  testWidgets('开关行和末端开关各只切换一次，并接收外部模型变化', (tester) async {
    final model = ValueNotifier(false);
    addTearDown(model.dispose);
    final changes = <bool>[];
    await tester.pumpWidget(
      _host(ElListTile<bool>.switcher(title: Text('通知'), modelValue: model, onChanged: changes.add)),
    );
    await _tap(tester, _text('通知'));
    expect(model.value, isTrue);
    expect(changes, [true]);
    final switcher = _views((view) => view.style?.width == 47 && view.style?.height == 28);
    expect(switcher, findsOneWidget);
    await tester.tapAt(tester.getCenter(switcher));
    await tester.pumpAndSettle();
    expect(model.value, isFalse);
    expect(changes, [true, false]);
    model.value = true;
    await tester.pumpAndSettle();
    expect(changes, [true, false, true]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('开关行的事件取消、禁用和加载都阻止切换', (tester) async {
    final model = ValueNotifier(false);
    addTearDown(model.dispose);
    final changes = <bool>[];
    for (final mode in ['cancel', 'disabled', 'loading']) {
      await tester.pumpWidget(
        _host(
          ElListTile<bool>.switcher(
            title: Text('受限开关'),
            modelValue: model,
            onChanged: changes.add,
            disabled: mode == 'disabled',
            loading: mode == 'loading',
            event: mode == 'cancel' ? ElEvent(onTap: (event) => event.preventDefault()) : null,
          ),
        ),
      );
      await _tap(tester, _text('受限开关'), warnIfMissed: mode == 'cancel');
      await tester.tapAt(tester.getCenter(_views((view) => view.style?.width == 47 && view.style?.height == 28)));
      await tester.pumpAndSettle();
      expect(model.value, isFalse);
      expect(changes, isEmpty);
    }
  });

  testWidgets('单选组使用枚举值和默认前置标记，禁用项不改变选择', (tester) async {
    final model = ValueNotifier<_Preference?>(null);
    addTearDown(model.dispose);
    final changes = <_Preference?>[];
    final semantics = tester.ensureSemantics();
    try {
      final groupKey = GlobalKey();
      await tester.pumpWidget(
        _host(
          ElListTileGroup<_Preference?>.single(
            key: groupKey,
            modelValue: model,
            onChanged: changes.add,
            children: [
              ElListTile<_Preference>(value: _Preference.system, title: Text('跟随系统'), semanticLabel: '系统选项'),
              ElListTile<_Preference>(
                value: _Preference.dark,
                title: Text('禁用深色'),
                disabled: true,
                semanticLabel: '深色选项',
              ),
            ],
          ),
        ),
      );
      expect(tester.getTopLeft(_text('跟随系统')).dx - tester.getTopLeft(find.byKey(groupKey)).dx, 56);
      expect(_icon(Icons.chevron_right), findsNothing);
      await _tap(tester, _text('跟随系统'));
      expect(model.value, _Preference.system);
      expect(changes, [_Preference.system]);
      expect(tester.getSemantics(find.bySemanticsLabel('系统选项')).flagsCollection.isChecked, CheckedState.isTrue);
      await _tap(tester, _text('跟随系统'));
      expect(changes, [_Preference.system]);
      await _tap(tester, _text('禁用深色'), warnIfMissed: false);
      expect(model.value, _Preference.system);
      model.value = _Preference.dark;
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.bySemanticsLabel('深色选项')).flagsCollection.isChecked, CheckedState.isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('单选方向键跳过禁用项并循环，Space与Enter沿官方RadioGroup激活', (tester) async {
    final model = ValueNotifier<int?>(null);
    addTearDown(model.dispose);
    final changes = <int?>[];
    final first = FocusNode();
    final disabled = FocusNode();
    final last = FocusNode();
    addTearDown(first.dispose);
    addTearDown(disabled.dispose);
    addTearDown(last.dispose);
    await tester.pumpWidget(
      _host(
        ElListTileGroup<int?>.single(
          modelValue: model,
          onChanged: changes.add,
          children: [
            ElListTile<int>(value: 1, title: Text('键盘第一项'), focusNode: first),
            ElListTile<int>(value: 2, title: Text('键盘禁用项'), focusNode: disabled, disabled: true),
            ElListTile<int>(value: 3, title: Text('键盘最后项'), focusNode: last),
          ],
        ),
      ),
    );
    first.requestFocus();
    await tester.pump();
    expect(first.hasPrimaryFocus, isTrue);
    expect(model.value, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(model.value, 1);
    expect(changes, [1]);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(last.hasPrimaryFocus, isTrue);
    expect(disabled.hasFocus, isFalse);
    expect(model.value, 3);
    expect(changes, [1, 3]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(first.hasPrimaryFocus, isTrue);
    expect(model.value, 1);
    expect(changes, [1, 3, 1]);

    model.value = null;
    await tester.pumpAndSettle();
    changes.clear();
    last.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(last.hasPrimaryFocus, isTrue);
    expect(model.value, 3);
    expect(changes, [3]);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(model.value, 3);
    expect(changes, [3]);
  });

  testWidgets('选择行事件可取消选择，子项onTap在单选多选中每次激活只通知一次', (tester) async {
    for (final multiple in [false, true]) {
      final singleModel = ValueNotifier<int?>(null);
      final multiModel = ValueNotifier<List<int>>([]);
      addTearDown(singleModel.dispose);
      addTearDown(multiModel.dispose);
      final singleChanges = <int?>[];
      final multiChanges = <List<int>>[];
      var cancellations = 0;
      var calls = 0;
      final children = [
        ElListTile<int>(
          value: 1,
          title: Text('取消选择'),
          event: ElEvent(
            onTap: (event) {
              cancellations++;
              event.preventDefault();
            },
          ),
          onTap: () => calls++,
        ),
        ElListTile<int>(value: 2, title: Text('正常选择'), onTap: () => calls++),
      ];
      await tester.pumpWidget(
        _host(
          multiple
              ? ElListTileGroup<List<int>>.multi(
                  modelValue: multiModel,
                  onChanged: multiChanges.add,
                  children: children,
                )
              : ElListTileGroup<int?>.single(modelValue: singleModel, onChanged: singleChanges.add, children: children),
        ),
      );
      await _tap(tester, _text('取消选择'));
      expect(cancellations, 1);
      expect(calls, 0);
      expect(singleModel.value, isNull);
      expect(multiModel.value, isEmpty);
      expect(singleChanges, isEmpty);
      expect(multiChanges, isEmpty);

      await _tap(tester, _text('正常选择'));
      expect(calls, 1);
      if (multiple) {
        expect(multiModel.value, [2]);
        expect(multiChanges, [
          [2],
        ]);
      } else {
        expect(singleModel.value, 2);
        expect(singleChanges, [2]);
      }
      await _tap(tester, _text('正常选择'));
      expect(calls, 2);
      if (multiple) {
        expect(multiModel.value, isEmpty);
        expect(multiChanges, [
          [2],
          <int>[],
        ]);
      } else {
        expect(singleModel.value, 2);
        expect(singleChanges, [2]);
      }
    }
  });

  testWidgets('单选外借焦点驱动焦点变体，用户键盘通知不阻断官方方向键', (tester) async {
    final model = ValueNotifier<int?>(1);
    addTearDown(model.dispose);
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final keys = <LogicalKeyboardKey?>[];
    final changes = <int?>[];
    final outline = ElOutline(outlineWidth: 2, outlineColor: Color(0xff146382));
    await tester.pumpWidget(
      _host(
        ElListTileGroup<int?>.single(
          modelValue: model,
          onChanged: changes.add,
          children: [
            ElListTile<int>(
              value: 1,
              title: Text('焦点第一项'),
              focusNode: first,
              style: ElStyle(onFocusVisible: ElStyle(outline: outline)),
              event: ElEvent(onKeyDown: (event) => keys.add(event.logicalKey)),
            ),
            ElListTile<int>(value: 2, title: Text('焦点第二项'), focusNode: second),
          ],
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(first.hasPrimaryFocus, isTrue);
    final host = _views((view) => view.focusNode == first);
    expect(host, findsOneWidget);
    expect(tester.renderObject<ElRenderView>(host).committedResolvedStyle.box.outline, outline);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(keys, contains(LogicalKeyboardKey.arrowDown));
    expect(second.hasPrimaryFocus, isTrue);
    expect(model.value, 2);
    expect(changes, [2]);
  });

  testWidgets('多选组使用值相等对象及后置标记，按新List更新并保留原集合', (tester) async {
    final initial = <_Item>[_Item(1)];
    final model = ValueNotifier<List<_Item>>(initial);
    addTearDown(model.dispose);
    final changes = <List<_Item>>[];
    final semantics = tester.ensureSemantics();
    try {
      final groupKey = GlobalKey();
      await tester.pumpWidget(
        _host(
          ElListTileGroup<List<_Item>>.multi(
            key: groupKey,
            modelValue: model,
            onChanged: changes.add,
            leading: false,
            children: [
              ElListTile<_Item>(value: _Item(1), title: Text('第一项'), semanticLabel: '第一选项'),
              ElListTile<_Item>(value: _Item(2), title: Text('第二项'), semanticLabel: '第二选项'),
            ],
          ),
        ),
      );
      expect(tester.getTopLeft(_text('第二项')).dx - tester.getTopLeft(find.byKey(groupKey)).dx, 16);
      expect(tester.getSemantics(find.bySemanticsLabel('第一选项')).flagsCollection.isChecked, CheckedState.isTrue);
      await _tap(tester, _text('第二项'));
      expect(model.value, [_Item(1), _Item(2)]);
      expect(model.value, isA<List<_Item>>());
      expect(model.value, isNot(same(initial)));
      expect(initial, [_Item(1)]);
      expect(changes.length, 1);
      await _tap(tester, _text('第一项'));
      expect(model.value, [_Item(2)]);
      expect(changes.length, 2);
      expect(initial, [_Item(1)]);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('弹窗选择更新同一泛型模型和行文案，默认选择后关闭', (tester) async {
    final model = ValueNotifier<_Preference>(_Preference.system);
    addTearDown(model.dispose);
    final changes = <_Preference>[];
    await tester.pumpWidget(
      _host(
        ElListTile<_Preference>.popup(
          title: Text('主题菜单'),
          modelValue: model,
          onChanged: changes.add,
          options: [ElLabelModel('跟随系统', _Preference.system), ElLabelModel('深色', _Preference.dark)],
        ),
      ),
    );
    expect(_text('跟随系统'), findsOneWidget);
    await _tap(tester, _text('主题菜单'));
    expect(_text('深色'), findsOneWidget);
    await _tap(tester, _text('深色'));
    expect(model.value, _Preference.dark);
    expect(changes, [_Preference.dark]);
    expect(_text('跟随系统'), findsNothing);
    expect(_text('深色'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('带ValueKey的分组行重排后保留已打开弹窗及原模型', (tester) async {
    final model = ValueNotifier<int>(1);
    addTearDown(model.dispose);
    final changes = <int>[];
    final panelColor = Color(0xfffcf1d5);
    final popup = ElListTile<int>.popup(
      key: ValueKey('reorder-popup'),
      title: Text('重排菜单'),
      modelValue: model,
      onChanged: changes.add,
      popupStyle: ElStyle(backgroundColor: panelColor),
      options: [ElLabelModel('候选一', 1), ElLabelModel('候选二', 2)],
    );
    final ordinary = ElListTile(key: ValueKey('reorder-ordinary'), title: Text('重排普通行'));
    var reversed = false;
    late StateSetter reorder;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            reorder = setState;
            return ElListTileGroup(children: reversed ? [ordinary, popup] : [popup, ordinary]);
          },
        ),
      ),
    );
    final originalTop = tester.getTopLeft(_text('重排菜单')).dy;
    await _tap(tester, _text('重排菜单'));
    final panel = _views((view) => view.style?.backgroundColor == panelColor);
    expect(panel, findsOneWidget);
    expect(_text('候选二'), findsOneWidget);

    reorder(() => reversed = true);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_text('重排菜单')).dy, greaterThan(originalTop));
    expect(panel, findsOneWidget);
    expect(model.value, 1);
    expect(changes, isEmpty);
    await _tap(tester, find.descendant(of: panel, matching: _text('候选二')));
    expect(model.value, 2);
    expect(changes, [2]);
    expect(panel, findsNothing);
    expect(_text('候选二'), findsOneWidget);
    expect(_text('重排普通行'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('键盘打开菜单先聚焦当前项，方向键只移动焦点而确认键才提交', (tester) async {
    final model = ValueNotifier<int>(2);
    addTearDown(model.dispose);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final changes = <int>[];
    final panelColor = Color(0xffe8f3ee);
    await tester.pumpWidget(
      _host(
        ElListTile<int>.popup(
          title: Text('键盘菜单'),
          modelValue: model,
          onChanged: changes.add,
          focusNode: focus,
          popupStyle: ElStyle(backgroundColor: panelColor),
          options: [ElLabelModel('第一候选', 1), ElLabelModel('第二候选', 2), ElLabelModel('第三候选', 3)],
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final panel = _views((view) => view.style?.backgroundColor == panelColor);
    Finder focusedRow() => _views((view) => view.focusNode?.hasPrimaryFocus == true);
    expect(panel, findsOneWidget);
    expect(find.descendant(of: focusedRow(), matching: _text('第二候选')), findsOneWidget);
    expect(model.value, 2);
    expect(changes, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.descendant(of: focusedRow(), matching: _text('第三候选')), findsOneWidget);
    expect(model.value, 2);
    expect(changes, isEmpty);
    expect(panel, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(model.value, 3);
    expect(changes, [3]);
    expect(panel, findsNothing);
    expect(focus.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.descendant(of: focusedRow(), matching: _text('第三候选')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(find.descendant(of: focusedRow(), matching: _text('第二候选')), findsOneWidget);
    expect(model.value, 3);
    expect(changes, [3]);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(model.value, 2);
    expect(changes, [3, 2]);
    expect(panel, findsNothing);
    expect(focus.hasPrimaryFocus, isTrue);
  });

  testWidgets('弹窗保留自定义样式定位与选后不关闭，外点和Escape可以关闭', (tester) async {
    final model = ValueNotifier<int>(1);
    addTearDown(model.dispose);
    final rowKey = GlobalKey();
    final panelColor = Color(0xffddf0e8);
    await tester.pumpWidget(
      _host(
        ElListTile<int>.popup(
          key: rowKey,
          title: Text('保持打开'),
          modelValue: model,
          closeOnSelect: false,
          options: [ElLabelModel('一', 1), ElLabelModel('二', 2), ElLabelModel('三', 3)],
          popupAnchor: ElOverlayAnchor(placement: .bottomStart, offset: 6, matchWidth: true),
          popupMaxHeight: 96,
          popupStyle: ElStyle(backgroundColor: panelColor),
          optionStyle: ElStyle(fontSize: 18),
        ),
      ),
    );
    await _tap(tester, _text('保持打开'));
    final panel = _views((view) => view.style?.backgroundColor == panelColor);
    expect(panel, findsOneWidget);
    final rowRect = tester.getRect(find.byKey(rowKey));
    final panelRect = tester.getRect(panel);
    expect(panelRect.width, closeTo(rowRect.width, .01));
    expect(panelRect.top - rowRect.bottom, closeTo(6, .01));
    expect(panelRect.height, lessThanOrEqualTo(96));
    await _tap(tester, find.descendant(of: panel, matching: _text('二')));
    expect(model.value, 2);
    expect(panel, findsOneWidget);
    await tester.tapAt(Offset(600, 500));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    await _tap(tester, _text('保持打开'));
    expect(panel, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
  });
}
