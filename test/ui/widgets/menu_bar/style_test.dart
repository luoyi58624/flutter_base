import '../../support/overlay.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Finder item(int index) => find.byKey(ValueKey('el-menu-bar-item-$index'));
  ElRenderView render(WidgetTester tester, int index) => tester.renderObject<ElRenderView>(item(index));
  Color? background(WidgetTester tester, int index) => render(tester, index).committedResolvedStyle.box.bgColor;
  Widget host(Widget child) => Directionality(
    textDirection: .ltr,
    child: ElTestOverlay(child: child),
  );

  testWidgets('根、公共条目、单项样式依次合并，重建后读取新的实际样式值', (tester) async {
    late StateSetter update;
    var color = Color(0xff112233);
    ElMenuBar bar() => ElMenuBar(
      style: ElStyle(height: 40),
      itemStyle: ElStyle(height: 28, width: 72, bgColor: color),
      items: [
        ElMenuBarItem(label: '文件', items: []),
        ElMenuBarItem(
          label: '编辑',
          style: ElStyle(width: 96, bgColor: Color(0xffabcdef)),
          items: [],
        ),
      ],
    );
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return ElView(
              style: ElStyle(alignment: .topLeft),
              child: bar(),
            );
          },
        ),
      ),
    );
    expect(tester.getSize(find.byType(ElMenuBar)).height, 40);
    expect(tester.getSize(item(0)), Size(72, 28));
    expect(tester.getSize(item(1)), Size(96, 28));
    expect(background(tester, 0), color);
    expect(background(tester, 1), Color(0xffabcdef));
    update(() => color = Color(0xff778899));
    await tester.pump();
    expect(background(tester, 0), color);
    expect(background(tester, 1), Color(0xffabcdef));
  });

  testWidgets('程序聚焦和指针打开不显示焦点环，F10 与方向导航才显示', (tester) async {
    final base = Color(0xff112233);
    final ring = Color(0xff00ff00);
    await tester.pumpWidget(
      host(
        ElView(
          style: ElStyle(alignment: .topLeft),
          child: ElMenuBar(
            menu: _Menu(),
            itemStyle: ElStyle(
              height: 28,
              width: 72,
              bgColor: base,
              onFocusVisible: ElStyle(bgColor: ring),
            ),
            items: [
              ElMenuBarItem(
                label: '文件',
                items: [ElContextMenuItem(label: '打开')],
              ),
              ElMenuBarItem(label: '编辑', items: []),
            ],
          ),
        ),
      ),
    );
    final node = tester.widget<ElView>(item(0)).focusNode!;
    node.requestFocus();
    await tester.pump();
    expect(background(tester, 0), base);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(background(tester, 1), ring);
    await tester.tap(item(0));
    await tester.pump();
    await tester.pump();
    expect(background(tester, 0), base);
    final popup = find.byKey(contextMenuItemSurfaceKey(0));
    expect(tester.renderObject<ElRenderView>(popup).internalStateHas(ViewState.focusVisible), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // 先恢复指针模式，验证 F10 本身就能声明一次真实键盘导航。
    await tester.tapAt(Offset(400, 200));
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.pump();
    expect(background(tester, 0), ring);
  });
}

class _Menu extends ElContextMenu {
  @override
  Widget buildPanel(BuildContext context, List<Widget> children) => ElView(
    style: ElStyle(width: 160),
    child: Column(mainAxisSize: .min, children: children),
  );

  @override
  ElStyle buildItemStyle(BuildContext context, ElContextMenuItem item) => ElStyle(width: 160, height: 24);

  @override
  Widget buildDivider(BuildContext context) => ElView(style: ElStyle(height: 1));
}
