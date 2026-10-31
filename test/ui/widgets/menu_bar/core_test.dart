import '../../support/portal.dart';

import 'dart:ui' show SemanticsRole;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show MaterialApp, Scaffold;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/dart.dart' show el;
import 'package:flutter_base/ui.dart';

void main() {
  /// Tab 遍历由 WidgetsApp 的快捷键分发，测试宿主需要真实应用骨架。
  Widget host(Widget menuBar, {FocusNode? before, FocusNode? after, TextDirection direction = .ltr}) => MaterialApp(
    home: Scaffold(
      body: Directionality(
        textDirection: direction,
        child: ElTestPortal(
          child: ElView(
            style: ElStyle(width: 520, height: 180, alignment: .topLeft),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                if (before != null) ElView(style: ElStyle(height: 28), focusNode: before, child: '菜单前'),
                menuBar,
                if (after != null) ElView(style: ElStyle(height: 28), focusNode: after, child: '菜单后'),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  setUp(() {
    el.globalContextMenus = {for (final platform in TargetPlatform.values) platform: _TestMenu()};
  });
  tearDown(() => el.globalContextMenus = {});

  Finder topItem(int index) => find.byKey(ValueKey<String>('el-menu-bar-item-$index'));

  Finder popupItem(String label) => find.byWidgetPredicate(
    (widget) =>
        widget is ElView &&
        widget.semantics?.properties.role == SemanticsRole.menuItem &&
        widget.semantics?.properties.label == label,
    description: 'popup menu item "$label"',
  );

  FocusNode itemFocus(WidgetTester tester, Finder finder) => tester.widget<ElView>(finder).focusNode!;

  void activatePopup(WidgetTester tester, String label) {
    tester.widget<ElView>(popupItem(label)).semantics?.properties.onTap?.call();
  }

  Future<void> openSettled(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Future<void> closeSettled(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(Duration(milliseconds: 120));
    await tester.pump();
  }

  testWidgets('打开后 hover 即时切换兄弟菜单，命令选择归还原焦点', (tester) async {
    final before = FocusNode(debugLabel: 'before-menu');
    addTearDown(before.dispose);
    var selected = 0;
    await tester.pumpWidget(
      host(
        ElMenuBar(
          itemStyle: ElStyle(height: 24, padding: .symmetric(horizontal: 7)),
          items: [
            ElMenuBarItem(
              label: '文件',
              items: [ElContextMenuItem(label: '新建')],
            ),
            ElMenuBarItem(
              label: '编辑',
              items: [ElContextMenuItem(label: '撤销', onSelect: () => selected++)],
            ),
          ],
        ),
        before: before,
      ),
    );
    before.requestFocus();
    await tester.pump();

    await tester.tap(topItem(0));
    await openSettled(tester);
    expect(popupItem('新建'), findsOneWidget);

    await tester.tap(topItem(0));
    await closeSettled(tester);
    expect(popupItem('新建'), findsNothing);
    await tester.tap(topItem(0));
    await openSettled(tester);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(topItem(0)));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(topItem(1)));
    await openSettled(tester);
    expect(popupItem('撤销'), findsOneWidget);
    await tester.pump(Duration(milliseconds: 120));
    expect(popupItem('新建'), findsNothing);

    activatePopup(tester, '撤销');
    await closeSettled(tester);
    expect(selected, 1);
    expect(before.hasPrimaryFocus, isTrue);
  });

  testWidgets('F10、方向键与 ESC 形成完整的顶级菜单模式', (tester) async {
    final before = FocusNode(debugLabel: 'before-menu');
    addTearDown(before.dispose);
    await tester.pumpWidget(
      host(
        ElMenuBar(
          itemStyle: ElStyle(height: 24, padding: .symmetric(horizontal: 7)),
          items: [
            ElMenuBarItem(
              label: '文件',
              items: [
                ElContextMenuItem(label: '新建'),
                ElContextMenuItem(label: '打开'),
              ],
            ),
            ElMenuBarItem(
              label: '编辑',
              items: [ElContextMenuItem(label: '撤销')],
            ),
          ],
        ),
        before: before,
      ),
    );
    before.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.pump();
    expect(itemFocus(tester, topItem(0)).hasPrimaryFocus, isTrue);
    expect(popupItem('新建'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(itemFocus(tester, topItem(1)).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await openSettled(tester);
    expect(popupItem('撤销'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await openSettled(tester);
    await tester.pump(Duration(milliseconds: 120));
    expect(popupItem('新建'), findsOneWidget);
    expect(popupItem('撤销'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await closeSettled(tester);
    expect(popupItem('新建'), findsNothing);
    expect(itemFocus(tester, topItem(0)).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(before.hasPrimaryFocus, isTrue);
  });

  testWidgets('Alt+助记键直接打开菜单，向上键从末项起焦', (tester) async {
    final before = FocusNode(debugLabel: 'before-menu');
    addTearDown(before.dispose);
    await tester.pumpWidget(
      host(
        ElMenuBar(
          itemStyle: ElStyle(height: 24, padding: .symmetric(horizontal: 7)),
          items: [
            ElMenuBarItem(
              label: 'File',
              accessKey: 'f',
              items: [ElContextMenuItem(label: 'New')],
            ),
            ElMenuBarItem(
              label: 'Edit',
              accessKey: 'e',
              items: [
                ElContextMenuItem(label: 'Undo'),
                ElContextMenuItem(label: 'Redo'),
              ],
            ),
          ],
        ),
        before: before,
      ),
    );
    before.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE, character: 'e');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await openSettled(tester);
    expect(popupItem('Undo'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await closeSettled(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await openSettled(tester);
    expect(itemFocus(tester, popupItem('Redo')).hasPrimaryFocus, isTrue);
  });

  testWidgets('弹层内 Tab 关闭菜单并继续离开菜单栏', (tester) async {
    final before = FocusNode(debugLabel: 'before-menu');
    final after = FocusNode(debugLabel: 'after-menu');
    addTearDown(before.dispose);
    addTearDown(after.dispose);
    await tester.pumpWidget(
      host(
        ElMenuBar(
          itemStyle: ElStyle(height: 24, padding: .symmetric(horizontal: 7)),
          items: [
            ElMenuBarItem(
              label: '文件',
              items: [ElContextMenuItem(label: '新建')],
            ),
          ],
        ),
        before: before,
        after: after,
      ),
    );
    before.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await openSettled(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await closeSettled(tester);
    await tester.pump();
    expect(after.hasPrimaryFocus, isTrue);
  });

  testWidgets('命令异步移焦不会被关闭归焦抢回', (tester) async {
    final before = FocusNode(debugLabel: 'before-menu');
    final after = FocusNode(debugLabel: 'after-command');
    addTearDown(before.dispose);
    addTearDown(after.dispose);
    await tester.pumpWidget(
      host(
        ElMenuBar(
          itemStyle: ElStyle(height: 24, padding: .symmetric(horizontal: 7)),
          items: [
            ElMenuBarItem(
              label: '文件',
              items: [
                ElContextMenuItem(
                  label: '打开页面',
                  onSelect: () => WidgetsBinding.instance.addPostFrameCallback((_) => after.requestFocus()),
                ),
              ],
            ),
          ],
        ),
        before: before,
        after: after,
      ),
    );
    before.requestFocus();
    await tester.pump();
    await tester.tap(topItem(0));
    await openSettled(tester);
    // 真实点击需要等入场透明度结束，语义激活不受这一绘制阶段影响。
    await tester.pump(const Duration(milliseconds: 100));
    final menuItem = popupItem('打开页面');
    final itemRender = tester.renderObject<ElRenderView>(menuItem);
    expect(tester.hitTestOnBinding(tester.getCenter(menuItem)).path.any((entry) => entry.target == itemRender), isTrue);
    await tester.tap(menuItem, kind: PointerDeviceKind.mouse);
    await closeSettled(tester);
    expect(after.hasPrimaryFocus, isTrue);
    expect(before.hasPrimaryFocus, isFalse);
  });

  testWidgets('打开期间刷新视觉模型与回调，旧退场菜单立即停止交互', (tester) async {
    StateSetter? rebuild;
    var useNewCallback = false;
    var longLabel = false;
    var oldActivations = 0;
    var newActivations = 0;
    final oldLabel = '用于覆盖旧菜单退场区域的较长命令';
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ElMenuBar(
              itemStyle: ElStyle(height: 24, padding: .symmetric(horizontal: 7)),
              items: [
                ElMenuBarItem(
                  label: '文件',
                  items: [
                    ElContextMenuItem(
                      label: longLabel ? oldLabel : '执行命令',
                      onSelect: useNewCallback ? () => newActivations++ : () => oldActivations++,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.tap(topItem(0));
    await openSettled(tester);
    rebuild!(() => useNewCallback = true);
    await tester.pump();
    activatePopup(tester, '执行命令');
    await closeSettled(tester);
    expect(oldActivations, 0);
    expect(newActivations, 1, reason: '视觉不变时已打开菜单也应调用最新回调');

    rebuild!(() {
      longLabel = true;
      useNewCallback = false;
    });
    await tester.pump();
    await tester.tap(topItem(0));
    await openSettled(tester);
    final oldRect = tester.getRect(popupItem(oldLabel));
    rebuild!(() {
      longLabel = false;
      useNewCallback = true;
    });
    await tester.pump();
    await tester.pump();
    final exitingOldMenu = find.ancestor(
      of: popupItem(oldLabel),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is ElView &&
            widget.semantics?.exclude == true &&
            widget.style?.pointerEvents == ElPointerEvents.none,
      ),
    );
    expect(exitingOldMenu, findsOneWidget);
    expect(popupItem('执行命令'), findsOneWidget);
    final newRect = tester.getRect(popupItem('执行命令'));
    expect(oldRect.right - 2, greaterThan(newRect.right));
    expect(oldRect.right - 2, lessThan(520));
    await tester.tapAt(Offset(oldRect.right - 2, oldRect.center.dy));
    await tester.pump();
    expect(oldActivations, 0);
    expect(newActivations, 1, reason: '旧菜单淡出区域必须立即指针穿透');
  });
  testWidgets('主指针 down 即打开，up 不重复切换，右键不打开', (tester) async {
    await tester.pumpWidget(
      host(
        ElMenuBar(
          itemStyle: ElStyle(height: 24, padding: .symmetric(horizontal: 7)),
          items: [
            ElMenuBarItem(
              label: '文件',
              items: [ElContextMenuItem(label: '打开')],
            ),
          ],
        ),
      ),
    );
    final position = tester.getCenter(topItem(0));
    final secondary = await tester.startGesture(position, kind: .mouse, buttons: kSecondaryButton);
    await openSettled(tester);
    expect(popupItem('打开'), findsNothing);
    await secondary.up();
    final primary = await tester.startGesture(position, kind: .mouse);
    await openSettled(tester);
    expect(popupItem('打开'), findsOneWidget);
    await primary.up();
    await openSettled(tester);
    expect(popupItem('打开'), findsOneWidget);
    final toggle = await tester.startGesture(position, kind: .mouse);
    await closeSettled(tester);
    expect(popupItem('打开'), findsNothing);
    await toggle.up();
    await openSettled(tester);
    expect(popupItem('打开'), findsNothing);
  });

  testWidgets('空面板锁定焦点，按住 Esc 只退出弹层一级', (tester) async {
    final before = FocusNode();
    addTearDown(before.dispose);
    await tester.pumpWidget(
      host(
        ElMenuBar(
          itemStyle: ElStyle(height: 24, padding: .symmetric(horizontal: 7)),
          items: [ElMenuBarItem(label: '空菜单', items: [])],
        ),
        before: before,
      ),
    );
    before.requestFocus();
    await tester.pump();
    await tester.tap(topItem(0));
    await openSettled(tester);
    // 弹层焦点隔离由 FocusScope 承担，调用方的节点开关不被改动；
    // 这里只锁"焦点被弹层捕获、Tab 不回到触发器"。
    final captured = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(captured));
    expect(before.hasPrimaryFocus, isFalse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    expect(itemFocus(tester, topItem(0)).hasPrimaryFocus, isTrue, reason: 'Esc 归焦不等待退场动画');
    await closeSettled(tester);
    expect(itemFocus(tester, topItem(0)).hasPrimaryFocus, isTrue);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(itemFocus(tester, topItem(0)).hasPrimaryFocus, isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await closeSettled(tester);
    expect(before.hasPrimaryFocus, isTrue);
  });

  for (final direction in TextDirection.values) {
    testWidgets('$direction 顶级导航跳过禁用项，右向进入子菜单后可继续切换顶级菜单', (tester) async {
      await tester.pumpWidget(
        host(
          ElMenuBar(
            itemStyle: ElStyle(height: 24, padding: .symmetric(horizontal: 7)),
            items: [
              ElMenuBarItem(
                label: '文件',
                items: [
                  ElContextMenuItem(
                    label: '最近',
                    children: [ElContextMenuItem(label: '文档')],
                  ),
                ],
              ),
              ElMenuBarItem(label: '禁用', disabled: true, items: []),
              ElMenuBarItem(
                label: '编辑',
                items: [ElContextMenuItem(label: '撤销')],
              ),
            ],
          ),
          direction: direction,
        ),
      );
      final next = direction == .ltr ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft;
      final previous = direction == .ltr ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight;
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyEvent(next);
      await tester.pump();
      expect(itemFocus(tester, topItem(2)).hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(itemFocus(tester, topItem(0)).hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(itemFocus(tester, topItem(2)).hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(next);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await openSettled(tester);
      await tester.sendKeyEvent(next);
      await openSettled(tester);
      expect(itemFocus(tester, popupItem('文档')).hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(previous);
      await closeSettled(tester);
      expect(itemFocus(tester, popupItem('最近')).hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(next);
      await openSettled(tester);
      await tester.sendKeyEvent(next);
      await closeSettled(tester);
      expect(popupItem('最近'), findsNothing);
      expect(popupItem('文档'), findsNothing);
      expect(itemFocus(tester, popupItem('撤销')).hasPrimaryFocus, isTrue);
    });
  }

  testWidgets('关闭全局快捷键仍保留局部 Enter、Esc 和 Shift+Tab 契约', (tester) async {
    final before = FocusNode();
    addTearDown(before.dispose);
    await tester.pumpWidget(
      host(
        ElMenuBar(
          globalShortcuts: false,
          itemStyle: ElStyle(height: 24, padding: .symmetric(horizontal: 7)),
          items: [
            ElMenuBarItem(
              label: '文件',
              items: [ElContextMenuItem(label: '打开')],
            ),
          ],
        ),
        before: before,
      ),
    );
    before.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    expect(before.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await openSettled(tester);
    expect(popupItem('打开'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await closeSettled(tester);
    expect(itemFocus(tester, topItem(0)).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await openSettled(tester);
    expect(popupItem('打开'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await closeSettled(tester);
    expect(before.hasPrimaryFocus, isTrue);
  });

  testWidgets(
    '宿主快捷键优先级控制归属，被其他弹层阻断时不抢 F10',
    (tester) async {
      final before = FocusNode();
      addTearDown(before.dispose);
      Widget bar(String label, int priority) => ElMenuBar(
        key: ValueKey(label),
        shortcutPriority: (_, _) => priority,
        itemStyle: ElStyle(height: 24, padding: .symmetric(horizontal: 7)),
        items: [ElMenuBarItem(label: label, items: [])],
      );
      await tester.pumpWidget(host(Column(children: [bar('优先', 1), bar('后备', 0)]), before: before));
      before.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.pump();
      final preferred = find.descendant(of: find.byKey(ValueKey('优先')), matching: topItem(0));
      expect(itemFocus(tester, preferred).hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await closeSettled(tester);
      final context = tester.element(preferred);
      final other = ElTestPortal.of(context).show(builder: (_) => ElView(style: ElStyle(width: 100, height: 100)));
      await openSettled(tester);
      final captured = FocusManager.instance.primaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(captured));
      expect(other.isOpen, isTrue);
      other.close();
      await closeSettled(tester);

      await tester.tap(preferred);
      await openSettled(tester);
      final aboveMenu = ElTestPortal.of(context).show(
        closeOnEscape: true,
        builder: (_) => ElView(key: ValueKey('above-menu'), style: ElStyle(width: 100, height: 100)),
      );
      await openSettled(tester);
      final aboveMenuScope = FocusScope.of(tester.element(find.byKey(ValueKey('above-menu'))));
      final capturedAboveMenu = FocusManager.instance.primaryFocus;
      expect(aboveMenuScope.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(capturedAboveMenu));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await closeSettled(tester);
      expect(aboveMenu.isOpen, isFalse);
      expect(aboveMenuScope.hasFocus, isFalse);
      // 新弹窗夺焦时旧菜单已经收起，弹窗关闭后不会重新出现。
      expect(itemFocus(tester, preferred).hasPrimaryFocus, isTrue);
    },
  );

  testWidgets('动态禁用、清空模型和移除组件会释放菜单与快捷键', (tester) async {
    late StateSetter update;
    var disabled = false;
    var empty = false;
    var removed = false;
    final before = FocusNode();
    addTearDown(before.dispose);
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return removed
                ? ElView()
                : ElMenuBar(
                    disabled: disabled,
                    itemStyle: ElStyle(height: 24, padding: .symmetric(horizontal: 7)),
                    items: empty
                        ? []
                        : [
                            ElMenuBarItem(
                              label: '文件',
                              items: [ElContextMenuItem(label: '打开')],
                            ),
                          ],
                  );
          },
        ),
        before: before,
      ),
    );
    before.requestFocus();
    await tester.pump();
    await tester.tap(topItem(0));
    await openSettled(tester);
    update(() => disabled = true);
    await tester.pumpAndSettle();
    expect(popupItem('打开'), findsNothing);
    expect(before.canRequestFocus, isTrue);
    update(() {
      disabled = false;
      empty = true;
    });
    await tester.pump();
    expect(topItem(0), findsNothing);
    expect(tester.takeException(), isNull, reason: '空菜单栏不声明要求非空子项的 menuBar 角色');
    update(() => empty = false);
    await tester.pump();
    await tester.tap(topItem(0));
    await openSettled(tester);
    update(() => removed = true);
    await tester.pumpAndSettle();
    expect(popupItem('打开'), findsNothing);
    before.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    expect(before.hasPrimaryFocus, isTrue);
  });
}

class _TestMenu extends ElContextMenu {
  @override
  Widget buildPanel(BuildContext context, List<Widget> children) => ElView(
    style: ElStyle(backgroundColor: Color(0xffffffff), padding: .all(2)),
    child: IntrinsicWidth(
      child: Column(mainAxisSize: .min, crossAxisAlignment: .stretch, children: children),
    ),
  );

  @override
  ElStyle buildItemStyle(BuildContext context, ElContextMenuItem item) =>
      ElStyle(height: 24, minWidth: 120, fontSize: 12, padding: .symmetric(horizontal: 8));

  @override
  Widget buildDivider(BuildContext context) => ElView(style: ElStyle(height: 1));
}
