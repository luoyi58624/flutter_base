import 'dart:ui' show CheckedState, SemanticsRole;

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 上下文菜单行为基座：焦点循环、字符定位、子菜单交接与关闭归还。
void main() {
  testWidgets('无品牌宿主时菜单图标与子菜单箭头仍走 ElStyle 字形通道', (tester) async {
    final icon = IconData(0x41, fontFamily: 'Ahem');
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Center(
          child: ElView(
            style: ElStyle(iconColor: Color(0xff123456)),
            child: Builder(
              builder: (context) => Row(
                mainAxisSize: .min,
                children: [
                  _HeadlessMenu().buildIcon(context, icon, size: 18)!,
                  _HeadlessMenu().buildTrailing(
                    context,
                    ElContextMenuItem(
                      label: '父项',
                      children: [ElContextMenuItem(label: '子项')],
                    ),
                  )!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final glyphs = find.byWidgetPredicate((widget) => widget is ElView && widget.child is IconData);
    expect(glyphs, findsNWidgets(2));
    expect(tester.getSize(glyphs.first), Size.square(18));
    expect(tester.getSize(glyphs.last), Size.square(15));
    for (final element in glyphs.evaluate()) {
      expect((element.renderObject as ElRenderView).committedResolvedStyle.inheritedBox.iconColor, Color(0xff123456));
    }
    expect(tester.takeException(), isNull);
  });

  const anchorKey = ValueKey<String>('anchor');

  Widget app(FocusNode anchorNode, {TextDirection direction = TextDirection.ltr}) {
    return Directionality(
      textDirection: direction,
      child: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (_) => Align(
              alignment: Alignment.topLeft,
              child: ElView(key: anchorKey, style: const ElStyle(width: 40, height: 40), focusNode: anchorNode),
            ),
          ),
        ],
      ),
    );
  }

  BuildContext anchorContext(WidgetTester tester) => tester.element(find.byKey(anchorKey));

  FocusNode itemNode(WidgetTester tester, int index, {int level = 0}) {
    return tester.widget<ElView>(find.byKey(contextMenuItemSurfaceKey(index, level: level))).focusNode!;
  }

  Future<ElContextMenuHandle> open(
    WidgetTester tester,
    FocusNode anchorNode,
    List<ElContextMenuItem> items, {
    TextDirection direction = TextDirection.ltr,
    ElContextMenu menu = const _HeadlessMenu(),
    Offset position = const Offset(50, 50),
  }) async {
    await tester.pumpWidget(app(anchorNode, direction: direction));
    anchorNode.requestFocus();
    await tester.pump();
    final entry = menu.open(anchorContext(tester), position: position, items: items)!;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    return entry;
  }

  Future<void> settleClose(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
  }

  testWidgets('空菜单仍捕获焦点，Tab 不返回触发器，Esc 关闭后归还', (tester) async {
    final anchorNode = FocusNode();
    addTearDown(anchorNode.dispose);
    final entry = await open(tester, anchorNode, []);
    // 弹层焦点隔离由 FocusScope 承担，调用方节点开关不被改动。
    final captured = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(entry.isOpen, isTrue);
    expect(FocusManager.instance.primaryFocus, same(captured));
    expect(anchorNode.hasPrimaryFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(entry.isOpen, isFalse);
    expect(anchorNode.hasPrimaryFocus, isTrue);
    await settleClose(tester);
  });

  testWidgets('打开聚焦首项；上下/Home/End 循环且禁用项可聚焦不可激活', (tester) async {
    final anchorNode = FocusNode();
    addTearDown(anchorNode.dispose);
    var disabledActivations = 0;
    final entry = await open(tester, anchorNode, [
      const ElContextMenuItem.divider(),
      const ElContextMenuItem(label: 'Alpha'),
      ElContextMenuItem(label: 'Disabled', enabled: false, onSelect: () => disabledActivations++),
      const ElContextMenuItem(label: 'Charlie'),
    ]);

    expect(itemNode(tester, 1).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(itemNode(tester, 2).hasPrimaryFocus, isTrue, reason: '禁用菜单项保留焦点可发现性');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(disabledActivations, 0);
    expect(entry.isOpen, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(itemNode(tester, 3).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(itemNode(tester, 1).hasPrimaryFocus, isTrue, reason: '末项向下回到首项');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(itemNode(tester, 3).hasPrimaryFocus, isTrue, reason: '首项向上回到末项');
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    expect(itemNode(tester, 1).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    expect(itemNode(tester, 3).hasPrimaryFocus, isTrue);
  });

  testWidgets('基座提供 menu / menuItem 语义角色，皮肤无需重复声明', (tester) async {
    final semantics = tester.ensureSemantics();
    final anchorNode = FocusNode();
    addTearDown(anchorNode.dispose);
    await open(tester, anchorNode, const [ElContextMenuItem(label: 'Action')]);

    final menu = find.byWidgetPredicate(
      (widget) => widget is ElView && widget.semantics?.properties.role == SemanticsRole.menu,
    );
    expect(menu, findsOneWidget);
    expect(tester.getSemantics(menu).getSemanticsData().role, SemanticsRole.menu);
    expect(
      tester.getSemantics(find.byKey(contextMenuItemSurfaceKey(0))).getSemanticsData().role,
      SemanticsRole.menuItem,
    );
    expect(find.semantics.byLabel('Action'), findsOne);
    semantics.dispose();
  });

  testWidgets('checked 菜单项由基座输出 checkbox 角色与勾选状态', (tester) async {
    final semantics = tester.ensureSemantics();
    final anchorNode = FocusNode();
    addTearDown(anchorNode.dispose);
    await open(tester, anchorNode, const [
      ElContextMenuItem(label: '显示隐藏文件', checked: true),
      ElContextMenuItem(label: '显示扩展名', checked: false),
    ]);

    final checked = tester.getSemantics(find.byKey(contextMenuItemSurfaceKey(0))).getSemanticsData();
    final unchecked = tester.getSemantics(find.byKey(contextMenuItemSurfaceKey(1))).getSemanticsData();
    expect(checked.role, SemanticsRole.menuItemCheckbox);
    expect(checked.flagsCollection.isChecked, CheckedState.isTrue);
    expect(unchecked.role, SemanticsRole.menuItemCheckbox);
    expect(unchecked.flagsCollection.isChecked, CheckedState.isFalse);
    semantics.dispose();
  });

  testWidgets('字符前缀从当前项之后循环定位，重复字符继续命中下一项', (tester) async {
    final anchorNode = FocusNode();
    addTearDown(anchorNode.dispose);
    await open(tester, anchorNode, const [
      ElContextMenuItem(label: 'Alpha'),
      ElContextMenuItem(label: 'Beta'),
      ElContextMenuItem(label: 'Bravo'),
    ]);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyB, character: 'b');
    expect(itemNode(tester, 1).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB, character: 'b');
    expect(itemNode(tester, 2).hasPrimaryFocus, isTrue);
  });

  testWidgets('方向键进入与退出子菜单，叶子激活关闭整链并归还原焦点', (tester) async {
    final anchorNode = FocusNode();
    addTearDown(anchorNode.dispose);
    var selected = 0;
    final entry = await open(tester, anchorNode, [
      ElContextMenuItem(
        label: 'Parent',
        children: [
          const ElContextMenuItem(label: 'First'),
          ElContextMenuItem(label: 'Last', onSelect: () => selected++),
        ],
      ),
      const ElContextMenuItem(label: 'Sibling'),
    ]);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(contextMenuSubmenuPanelKey(1)), findsOneWidget);
    expect(itemNode(tester, 0, level: 1).hasPrimaryFocus, isTrue);
    expect(entry.hasFocus, isTrue, reason: '菜单栏通过根句柄识别子菜单的焦点归属');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settleClose(tester);
    expect(find.byKey(contextMenuSubmenuPanelKey(1)), findsNothing);
    expect(itemNode(tester, 0).hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settleClose(tester);
    expect(selected, 1);
    expect(entry.isOpen, isFalse);
    expect(find.byKey(contextMenuPanelKey), findsNothing);
    expect(anchorNode.hasPrimaryFocus, isTrue);
  });

  testWidgets('多级子菜单逐层按实测尺寸翻转并在视口内钳制', (tester) async {
    final anchorNode = FocusNode();
    addTearDown(anchorNode.dispose);
    await open(
      tester,
      anchorNode,
      const [
        ElContextMenuItem(
          label: 'Parent',
          children: [
            ElContextMenuItem(
              label: 'First',
              children: [ElContextMenuItem(label: 'Nested')],
            ),
            ElContextMenuItem(label: 'Second'),
            ElContextMenuItem(label: 'Third'),
          ],
        ),
      ],
      position: const Offset(680, 560),
      menu: const _FixedHeadlessMenu(),
    );

    final parent = tester.getRect(find.byKey(contextMenuPanelKey));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump();
    final submenu = tester.getRect(find.byKey(contextMenuSubmenuPanelKey(1)));
    expect(submenu.right, lessThanOrEqualTo(parent.left));
    expect(submenu.left, greaterThanOrEqualTo(4));
    expect(submenu.top, greaterThanOrEqualTo(4));
    expect(submenu.bottom, lessThanOrEqualTo(596));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump();
    final nested = tester.getRect(find.byKey(contextMenuSubmenuPanelKey(2)));
    expect(nested.left, greaterThanOrEqualTo(4));
    expect(nested.right, lessThanOrEqualTo(796));
    expect(nested.top, greaterThanOrEqualTo(4));
    expect(nested.bottom, lessThanOrEqualTo(596));
  });

  testWidgets('ESC 分级关闭并归还父项与打开前焦点', (tester) async {
    final anchorNode = FocusNode();
    addTearDown(anchorNode.dispose);
    await open(tester, anchorNode, const [
      ElContextMenuItem(
        label: 'Parent',
        children: [ElContextMenuItem(label: 'Child')],
      ),
    ]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleClose(tester);
    expect(find.byKey(contextMenuSubmenuPanelKey(1)), findsNothing);
    expect(find.byKey(contextMenuPanelKey), findsOneWidget);
    expect(itemNode(tester, 0).hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleClose(tester);
    expect(find.byKey(contextMenuPanelKey), findsNothing);
    expect(anchorNode.hasPrimaryFocus, isTrue);
  });

  testWidgets('RTL 交换进入与退出子菜单方向键', (tester) async {
    final anchorNode = FocusNode();
    addTearDown(anchorNode.dispose);
    await open(tester, anchorNode, const [
      ElContextMenuItem(
        label: 'Parent',
        children: [ElContextMenuItem(label: 'Child')],
      ),
    ], direction: TextDirection.rtl);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.pump();
    expect(itemNode(tester, 0, level: 1).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settleClose(tester);
    expect(find.byKey(contextMenuSubmenuPanelKey(1)), findsNothing);
    expect(itemNode(tester, 0).hasPrimaryFocus, isTrue);
  });

  testWidgets('主面板可从末项起焦并把横向边界交给水平菜单栏', (tester) async {
    final anchorNode = FocusNode();
    addTearDown(anchorNode.dispose);
    var previous = 0;
    var next = 0;
    await tester.pumpWidget(app(anchorNode));
    anchorNode.requestFocus();
    await tester.pump();
    const _HeadlessMenu().openWithOptions(
      anchorContext(tester),
      position: const Offset(50, 50),
      items: const [
        ElContextMenuItem(label: 'First'),
        ElContextMenuItem(label: 'Last'),
      ],
      initialFocus: ContextMenuInitialFocus.last,
      onNavigatePrevious: () => previous++,
      onNavigateNext: () => next++,
    );
    await tester.pump();

    expect(itemNode(tester, 1).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(previous, 1);
    expect(next, 1);
  });

  testWidgets('退场菜单立即退出命中与语义树', (tester) async {
    final anchorNode = FocusNode();
    addTearDown(anchorNode.dispose);
    var selected = 0;
    final entry = await open(tester, anchorNode, [
      ElContextMenuItem(label: 'Action', onSelect: () => selected++),
    ], menu: const _FadingHeadlessMenu());
    final itemCenter = tester.getCenter(find.byKey(contextMenuItemSurfaceKey(0)));

    entry.close();
    await tester.tapAt(itemCenter);
    expect(selected, 0, reason: 'close() 返回后同帧即不再命中旧菜单');
    await tester.pump();
    final exiting = find.ancestor(
      of: find.byKey(contextMenuPanelKey),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is ElView &&
            widget.semantics?.exclude == true &&
            widget.style?.pointerEvents == ElPointerEvents.none,
      ),
    );
    expect(exiting, findsOneWidget);
    await settleClose(tester);
  });

  testWidgets('Tab 关闭菜单归还焦点，指针悬停同步当前项', (tester) async {
    final anchorNode = FocusNode();
    addTearDown(anchorNode.dispose);
    await open(tester, anchorNode, const [ElContextMenuItem(label: 'First'), ElContextMenuItem(label: 'Second')]);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(contextMenuItemSurfaceKey(1))));
    await tester.pump();
    expect(itemNode(tester, 1).hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await settleClose(tester);
    expect(find.byKey(contextMenuPanelKey), findsNothing);
    expect(anchorNode.hasPrimaryFocus, isTrue);
  });

  testWidgets('源控件卸载后关闭原生 Overlay 中的菜单', (tester) async {
    late StateSetter update;
    var visible = true;
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) => StatefulBuilder(
                builder: (_, setState) {
                  update = setState;
                  return Align(
                    alignment: .topLeft,
                    child: visible ? ElView(key: anchorKey, child: '源控件') : SizedBox.shrink(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    final menu = _FadingHeadlessMenu().open(
      anchorContext(tester),
      position: Offset(50, 50),
      items: [ElContextMenuItem(label: '复制')],
    )!;
    await tester.pump();
    update(() => visible = false);
    await tester.pump();
    await tester.pump();
    expect(menu.isOpen, isFalse);
    expect(find.byKey(contextMenuPanelKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('内容宿主禁用时关闭菜单，恢复后不会自行重开', (tester) async {
    late StateSetter update;
    var enabled = true;
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) => StatefulBuilder(
                builder: (_, setState) {
                  update = setState;
                  return SelectionChromeSlotHost(
                    enabled: enabled,
                    child: Align(
                      alignment: .topLeft,
                      child: ElView(key: anchorKey, child: '源控件'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    final menu = _HeadlessMenu().open(
      anchorContext(tester),
      position: Offset(50, 50),
      items: [ElContextMenuItem(label: '复制')],
    )!;
    await tester.pump();
    update(() => enabled = false);
    await tester.pump();
    await tester.pump();
    expect(menu.isOpen, isFalse);
    update(() => enabled = true);
    await tester.pump();
    expect(find.byKey(contextMenuPanelKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('外部作用域取得焦点时收起菜单且不抢回焦点', (tester) async {
    final anchorNode = FocusNode();
    final outsideNode = FocusNode();
    addTearDown(anchorNode.dispose);
    addTearDown(outsideNode.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) => Column(
                children: [
                  ElView(key: anchorKey, focusNode: anchorNode, child: '源控件'),
                  ElView(focusNode: outsideNode, child: '外部控件'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    anchorNode.requestFocus();
    await tester.pump();
    final menu = _HeadlessMenu().open(
      anchorContext(tester),
      position: Offset(50, 50),
      items: [ElContextMenuItem(label: '复制')],
    )!;
    await tester.pump();
    outsideNode.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(menu.isOpen, isFalse);
    expect(outsideNode.hasPrimaryFocus, isTrue);
    expect(find.byKey(contextMenuPanelKey), findsNothing);
  });

  testWidgets('首帧挂载前关闭菜单也能完整释放', (tester) async {
    final anchorNode = FocusNode();
    addTearDown(anchorNode.dispose);
    await tester.pumpWidget(app(anchorNode));
    final menu = _HeadlessMenu().open(
      anchorContext(tester),
      position: Offset(50, 50),
      items: [ElContextMenuItem(label: '复制')],
    )!;
    menu.close();
    await menu.closed;
    await tester.pump();
    expect(menu.isOpen, isFalse);
    expect(find.byKey(contextMenuPanelKey), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _HeadlessMenu extends ElContextMenu {
  const _HeadlessMenu();

  @override
  Duration get exitDuration => Duration.zero;

  @override
  Widget buildPanel(BuildContext context, List<Widget> children) {
    return Column(mainAxisSize: .min, crossAxisAlignment: .stretch, children: children);
  }

  @override
  ElStyle buildItemStyle(BuildContext context, ElContextMenuItem item) {
    return const ElStyle(width: 120, height: 24);
  }

  @override
  Widget buildDivider(BuildContext context) => const ElView(style: ElStyle(width: 120, height: 1));
}

class _FadingHeadlessMenu extends _HeadlessMenu {
  const _FadingHeadlessMenu();

  @override
  Duration get exitDuration => const Duration(milliseconds: 90);
}

class _FixedHeadlessMenu extends _HeadlessMenu {
  const _FixedHeadlessMenu();

  @override
  Widget buildPanel(BuildContext context, List<Widget> children) => ElView(
    style: const ElStyle(width: 120),
    child: Column(mainAxisSize: .min, crossAxisAlignment: .stretch, children: children),
  );
}
