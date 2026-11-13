import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt;
import 'package:flutter_test/flutter_test.dart';

Widget _app(ElComponents components, Widget child, {Alignment alignment = Alignment.topCenter}) => MaterialApp(
  builder: (context, child) => ElComponentProvider(components: components, child: child!),
  home: Scaffold(
    body: Padding(
      padding: EdgeInsets.all(20),
      child: Align(alignment: alignment, child: child),
    ),
  ),
);

Widget _target([double width = 80, double height = 32]) => SizedBox(
  key: ValueKey('目标'),
  width: width,
  height: height,
  child: Center(child: Text('目标')),
);

Rect _targetRect(WidgetTester tester) => tester.getRect(find.byKey(ValueKey('目标')));

Finder _copy(String text) =>
    find.byWidgetPredicate((w) => w is Text && w.data == text || w is ElView && w.child == text);

// 面板最外层是品牌的进退场淡入，尺寸与面板一致。
Rect _panel(WidgetTester tester, String text) =>
    tester.getRect(find.ancestor(of: _copy(text), matching: find.byType(FadeTransition)).first);

// 文字所在的 ElView 不单独命中，点击落在所在行上。
Future<void> _tap(WidgetTester tester, String label) => tester.tapAt(tester.getCenter(_copy(label)));

Future<TestGesture> _mouse(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset(1, 1));
  addTearDown(gesture.removePointer);
  return gesture;
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final (brand, components) in [('桌面', el.desktopComponents), ('移动', el.mobileComponents)]) {
    group('$brand popup menu', () {
      testWidgets('点击展开，选择后整条关闭再回调；禁用条目不触发；分隔线不是条目', (tester) async {
        final selected = <String>[];
        final opened = <bool>[];
        await tester.pumpWidget(
          _app(
            components,
            ElPopupMenu(
              onOpenChanged: opened.add,
              items: [
                ElContextMenuItem(label: '复制', shortcut: 'Ctrl+C', onSelect: () => selected.add('复制')),
                ElContextMenuItem(label: '粘贴', enabled: false, onSelect: () => selected.add('粘贴')),
                ElContextMenuItem.divider(),
                ElContextMenuItem(label: '删除', icon: Icons.delete, onSelect: () => selected.add('删除')),
              ],
              child: _target(),
            ),
          ),
        );
        await tester.tap(find.text('目标'));
        await tester.pumpAndSettle();
        expect(_copy('复制'), findsOneWidget);
        expect(_copy('Ctrl+C'), findsOneWidget);

        // 默认在下方左缘对齐。
        final target = _targetRect(tester);
        final panel = _panel(tester, '复制');
        expect(panel.left, closeTo(target.left, .01));
        expect(panel.top, greaterThan(target.bottom));

        // 各条目同宽，悬停和按压背景铺满整行。
        expect(
          tester.getSize(find.ancestor(of: _copy('复制'), matching: find.byType(Row)).first).width,
          tester.getSize(find.ancestor(of: _copy('删除'), matching: find.byType(Row)).first).width,
        );

        await _tap(tester, '粘贴');
        await tester.pumpAndSettle();
        expect(selected, isEmpty);
        expect(_copy('复制'), findsOneWidget);

        await _tap(tester, '删除');
        await tester.pump();
        expect(selected, ['删除']);
        await tester.pumpAndSettle();
        expect(_copy('复制'), findsNothing);
        expect(opened, [true, false]);
      });

      testWidgets('cover 时覆盖目标，从目标所在位置展开', (tester) async {
        await tester.pumpWidget(
          _app(
            components,
            ElPopupMenu(
              cover: true,
              placement: .bottomEnd,
              items: [
                ElContextMenuItem(label: '刷新'),
                ElContextMenuItem(label: '设置'),
              ],
              child: _target(40, 40),
            ),
            alignment: Alignment.topRight,
          ),
        );
        await tester.tap(find.text('目标'));
        await tester.pumpAndSettle();
        final target = _targetRect(tester);
        final panel = _panel(tester, '刷新');
        expect(panel.top, closeTo(target.top, .01));
        expect(panel.right, closeTo(target.right, .01));
      });

      testWidgets('右下角放不下时翻到上方并改为右缘对齐', (tester) async {
        await tester.pumpWidget(
          _app(
            components,
            ElPopupMenu(
              items: [for (var i = 0; i < 4; i++) ElContextMenuItem(label: '较长的菜单条目 $i')],
              child: _target(),
            ),
            alignment: Alignment.bottomRight,
          ),
        );
        await tester.tap(find.text('目标'));
        await tester.pumpAndSettle();
        final target = _targetRect(tester);
        final panel = _panel(tester, '较长的菜单条目 0');
        expect(panel.bottom, lessThan(target.top));
        expect(panel.right, closeTo(target.right, .01));
      });

      testWidgets('超长菜单限制在视口安全区内，内部可滚动到末项', (tester) async {
        final selected = <int>[];
        await tester.pumpWidget(
          _app(
            components,
            ElPopupMenu(
              items: [for (var i = 0; i < 40; i++) ElContextMenuItem(label: '条目 $i', onSelect: () => selected.add(i))],
              child: _target(),
            ),
          ),
        );
        await tester.tap(find.text('目标'));
        await tester.pumpAndSettle();
        final panel = _panel(tester, '条目 0');
        expect(panel.top, greaterThan(_targetRect(tester).bottom));
        expect(panel.bottom, lessThanOrEqualTo(592));

        await tester.dragFrom(tester.getCenter(_copy('条目 5')), Offset(0, -3000));
        await tester.pumpAndSettle();
        final last = tester.getRect(_copy('条目 39'));
        expect(last.bottom, lessThanOrEqualTo(panel.bottom));
        await _tap(tester, '条目 39');
        await tester.pumpAndSettle();
        expect(selected, [39]);
      });

      testWidgets('右键菜单在指针位置展开，长按同样展开', (tester) async {
        await tester.pumpWidget(
          _app(
            components,
            ElPopupMenu(
              trigger: {.contextMenu},
              items: [ElContextMenuItem(label: '重命名')],
              child: _target(300, 200),
            ),
            alignment: Alignment.center,
          ),
        );
        // 左键点击不打开。
        await tester.tap(find.text('目标'));
        await tester.pumpAndSettle();
        expect(_copy('重命名'), findsNothing);

        final point = _targetRect(tester).topLeft + Offset(40, 30);
        await tester.tapAt(point, buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
        final panel = _panel(tester, '重命名');
        expect(panel.left, closeTo(point.dx, .01));
        expect(panel.top, greaterThan(point.dy));
        expect(panel.top, lessThan(point.dy + 8));

        await tester.tapAt(Offset(5, 5));
        await tester.pumpAndSettle();
        expect(_copy('重命名'), findsNothing);

        final other = _targetRect(tester).topLeft + Offset(200, 100);
        await tester.longPressAt(other);
        await tester.pumpAndSettle();
        expect(_panel(tester, '重命名').left, closeTo(other.dx, .01));
      });

      testWidgets('子菜单在旁侧展开，选择子项后整条关闭', (tester) async {
        final selected = <String>[];
        await tester.pumpWidget(
          _app(
            components,
            ElPopupMenu(
              items: [
                ElContextMenuItem(label: '新建'),
                ElContextMenuItem(
                  label: '导出为',
                  children: [
                    ElContextMenuItem(label: 'PDF', onSelect: () => selected.add('PDF')),
                    ElContextMenuItem(label: '图片', onSelect: () => selected.add('图片')),
                  ],
                ),
              ],
              child: _target(),
            ),
            alignment: Alignment.topLeft,
          ),
        );
        await tester.tap(find.text('目标'));
        await tester.pumpAndSettle();
        await _tap(tester, '导出为');
        await tester.pumpAndSettle();
        expect(_copy('PDF'), findsOneWidget);
        expect(_panel(tester, 'PDF').left, greaterThan(_panel(tester, '导出为').right));

        await _tap(tester, '图片');
        await tester.pumpAndSettle();
        expect(selected, ['图片']);
        expect(_copy('新建'), findsNothing);
        expect(_copy('PDF'), findsNothing);
      });

      testWidgets('disabled 时不打开，已打开时关闭', (tester) async {
        var disabled = false;
        late StateSetter setState;
        await tester.pumpWidget(
          _app(
            components,
            StatefulBuilder(
              builder: (context, set) {
                setState = set;
                return ElPopupMenu(
                  disabled: disabled,
                  items: [ElContextMenuItem(label: '复制')],
                  child: _target(),
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('目标'));
        await tester.pumpAndSettle();
        expect(_copy('复制'), findsOneWidget);
        setState(() => disabled = true);
        await tester.pumpAndSettle();
        expect(_copy('复制'), findsNothing);
        await tester.tap(find.text('目标'));
        await tester.pumpAndSettle();
        expect(_copy('复制'), findsNothing);
      });
    });
  }

  group('桌面 popup menu 键盘与悬停', () {
    List<ElContextMenuItem> items(List<String> selected) => [
      ElContextMenuItem(label: '剪切', onSelect: () => selected.add('剪切')),
      ElContextMenuItem(label: '复制', enabled: false),
      ElContextMenuItem.divider(),
      ElContextMenuItem(label: '粘贴', onSelect: () => selected.add('粘贴')),
      ElContextMenuItem(
        label: '更多',
        children: [
          ElContextMenuItem(label: '全选', onSelect: () => selected.add('全选')),
          ElContextMenuItem(label: '反选', onSelect: () => selected.add('反选')),
        ],
      ),
    ];

    testWidgets('上下键跳过禁用项循环切换，回车选择，Esc 关闭并交还焦点', (tester) async {
      final selected = <String>[];
      final trigger = FocusNode();
      addTearDown(trigger.dispose);
      await tester.pumpWidget(
        _app(
          el.desktopComponents,
          ElPopupMenu(
            items: items(selected),
            child: Focus(focusNode: trigger, child: _target()),
          ),
        ),
      );
      trigger.requestFocus();
      await tester.tap(find.text('目标'));
      await tester.pumpAndSettle();
      expect(trigger.hasPrimaryFocus, isFalse);

      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, ['粘贴']);
      expect(_copy('剪切'), findsNothing);
      expect(trigger.hasPrimaryFocus, isTrue);

      // 从作用域起按上键落到最后一项，再按下键回到第一项。
      await tester.tap(find.text('目标'));
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, ['粘贴', '剪切']);

      await tester.tap(find.text('目标'));
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_copy('剪切'), findsNothing);
      expect(trigger.hasPrimaryFocus, isTrue);
    });

    testWidgets('右键展开子菜单并聚焦第一项，左键收起回到父条目，Esc 逐级关闭', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(_app(el.desktopComponents, ElPopupMenu(items: items(selected), child: _target())));
      await tester.tap(find.text('目标'));
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_copy('全选'), findsOneWidget);

      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(_copy('全选'), findsNothing);
      expect(_copy('剪切'), findsOneWidget);

      // 焦点回到「更多」，回车再次展开。
      await _key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, ['反选']);
      expect(_copy('剪切'), findsNothing);

      await tester.tap(find.text('目标'));
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_copy('全选'), findsNothing);
      expect(_copy('剪切'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_copy('剪切'), findsNothing);
    });

    testWidgets('悬停子菜单行 150 毫秒展开，经过兄弟行时切换，斜向移入子菜单不收起', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        _app(
          el.desktopComponents,
          ElPopupMenu(
            items: [
              ...items(selected),
              ElContextMenuItem(
                label: '分享',
                children: [ElContextMenuItem(label: '微信')],
              ),
            ],
            child: _target(),
          ),
          alignment: Alignment.topLeft,
        ),
      );
      await tester.tap(find.text('目标'));
      await tester.pumpAndSettle();
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(_copy('更多')));
      await tester.pump(Duration(milliseconds: 100));
      expect(_copy('全选'), findsNothing);
      await tester.pump(Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(_copy('全选'), findsOneWidget);

      // 沿对角线移向子菜单，途中经过的区域在安全区内。
      final row = tester.getRect(_copy('更多'));
      final submenu = _panel(tester, '全选');
      await mouse.moveTo(Offset(submenu.left - 10, row.center.dy + 4));
      await tester.pump(Duration(milliseconds: 100));
      await mouse.moveTo(tester.getCenter(_copy('反选')));
      await tester.pump(Duration(milliseconds: 300));
      expect(_copy('反选'), findsOneWidget);

      await mouse.moveTo(tester.getCenter(_copy('分享')));
      await tester.pump(Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(_copy('微信'), findsOneWidget);
      expect(_copy('全选'), findsNothing);
      expect(_copy('剪切'), findsOneWidget);
    });

    testWidgets('悬停触发的菜单延迟打开且不抢焦点，移开后关闭', (tester) async {
      final field = FocusNode();
      addTearDown(field.dispose);
      await tester.pumpWidget(
        _app(
          el.desktopComponents,
          Column(
            mainAxisSize: .min,
            children: [
              Focus(focusNode: field, child: SizedBox(width: 10, height: 10)),
              ElPopupMenu(
                trigger: {.hover},
                hoverIntent: ElHoverIntent(openDelay: Duration(milliseconds: 250)),
                items: [ElContextMenuItem(label: '个人中心')],
                child: _target(),
              ),
            ],
          ),
        ),
      );
      field.requestFocus();
      await tester.pump();
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('目标')));
      await tester.pump(Duration(milliseconds: 200));
      expect(_copy('个人中心'), findsNothing);
      await tester.pump(Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(_copy('个人中心'), findsOneWidget);
      expect(field.hasPrimaryFocus, isTrue);

      await mouse.moveTo(Offset(790, 590));
      await tester.pump(Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(_copy('个人中心'), findsNothing);
    });

    testWidgets('含勾选项时所有条目预留勾选列', (tester) async {
      await tester.pumpWidget(
        _app(
          el.desktopComponents,
          ElPopupMenu(
            items: [
              ElContextMenuItem(label: '显示网格', checked: true),
              ElContextMenuItem(label: '显示标尺'),
            ],
            child: _target(),
          ),
        ),
      );
      await tester.tap(find.text('目标'));
      await tester.pumpAndSettle();
      // 未声明勾选的条目也让出勾选列，文字左缘对齐。
      expect(tester.getRect(_copy('显示网格')).left, tester.getRect(_copy('显示标尺')).left);
    });
  });
}
