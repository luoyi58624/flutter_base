import 'package:flutter_base/dart.dart' show el;
import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/ui/views/menu/context_menu.dart' show contextMenuItemKey;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 找最近的官方 `Overlay` 祖先，用来断言浮层挂在根宿主还是最近宿主。
Element? _nearestOverlayOf(Element element) {
  Element? found;
  element.visitAncestorElements((ancestor) {
    if (ancestor.widget is Overlay) {
      found = ancestor;
      return false;
    }
    return true;
  });
  return found;
}

class _TestContextMenu extends ElContextMenu {
  @override
  Duration get exitDuration => Duration.zero;

  @override
  Widget buildPanel(BuildContext context, List<Widget> children) {
    return SizedBox(width: 100, height: 80, child: Column(children: children));
  }

  @override
  ElStyle buildItemStyle(BuildContext context, ElContextMenuItem item) {
    return const ElStyle(width: 100, height: 30);
  }

  @override
  Widget buildItemContent(BuildContext context, ElContextMenuItem item) {
    return ElView(key: ValueKey<String>('menu-action-${item.label}'), child: item.label);
  }

  @override
  Widget buildDivider(BuildContext context) => const SizedBox(width: 100, height: 1);
}

void main() {
  testWidgets('ElPortal 开启期 rootOverlay 变化不迁移 entry，下次打开使用新选择', (tester) async {
    final rootOverlayKey = GlobalKey();
    final innerOverlayKey = GlobalKey();
    final controller = ElPortalController();
    final flag = ValueNotifier<bool>(true);
    addTearDown(flag.dispose);
    addTearDown(controller.dispose);

    Widget portal() => ValueListenableBuilder<bool>(
      valueListenable: flag,
      builder: (_, rootOverlay, _) => ElPortal(
        controller: controller,
        rootOverlay: rootOverlay,
        overlayBuilder: (_) => const SizedBox(key: ValueKey('portal-panel'), width: 40, height: 30),
        child: const SizedBox(key: ValueKey('portal-source'), width: 20, height: 20),
      ),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          key: rootOverlayKey,
          initialEntries: [
            OverlayEntry(
              builder: (_) => Overlay(
                key: innerOverlayKey,
                initialEntries: [OverlayEntry(builder: (_) => portal())],
              ),
            ),
          ],
        ),
      ),
    );

    controller.open();
    await tester.pump();
    await tester.pump();
    final panel = find.byKey(const ValueKey('portal-panel'));
    final host = _nearestOverlayOf(tester.element(panel));
    expect(host, isNotNull);

    // 开启期改选择不迁移：面板 element 与宿主都不变。
    flag.value = false;
    await tester.pump();
    await tester.pump();
    expect(tester.element(panel), same(tester.element(panel)));
    expect(_nearestOverlayOf(tester.element(panel)), same(host));

    controller.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    controller.open();
    await tester.pump();
    await tester.pump();
    expect(panel, findsOneWidget);
    expect(_nearestOverlayOf(tester.element(panel)), isNotNull);
  });

  testWidgets('context menu 主面板与子面板共用 rootOverlay', (tester) async {
    final rootOverlayKey = GlobalKey();
    final innerOverlayKey = GlobalKey();
    final sourceKey = GlobalKey();
    final menu = _TestContextMenu();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          key: rootOverlayKey,
          initialEntries: [
            OverlayEntry(
              builder: (_) => Overlay(
                key: innerOverlayKey,
                initialEntries: [OverlayEntry(builder: (_) => SizedBox(key: sourceKey, width: 200, height: 160))],
              ),
            ),
          ],
        ),
      ),
    );

    el.showContextMenu(
      sourceKey.currentContext!,
      position: const Offset(10, 10),
      items: const [
        ElContextMenuItem(
          label: '更多',
          children: [ElContextMenuItem(label: '子项')],
        ),
      ],
      menu: menu,
      rootOverlay: true,
    );
    await tester.pump();
    await tester.pump();
    final mainItem = find.byKey(contextMenuItemKey(0));
    expect(mainItem, findsOneWidget);
    final mainHost = _nearestOverlayOf(tester.element(mainItem));
    expect(mainHost, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    // 子菜单与主面板必须落在同一宿主，保证层序一致。
    final subItem = find.byKey(const ValueKey('menu-action-子项'));
    expect(subItem, findsOneWidget);
    expect(_nearestOverlayOf(tester.element(subItem)), same(mainHost));
  });
}
