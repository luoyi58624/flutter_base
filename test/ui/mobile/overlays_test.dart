import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
  home: ElComponentProvider(
    components: el.mobileComponents,
    child: Scaffold(body: Center(child: child)),
  ),
);
Finder copy(String text) =>
    find.byWidgetPredicate((w) => w is Text && w.data == text || w is ElView && w.child == text);

void main() {
  testWidgets('提示随承载页面卸载取消计时，不访问已释放的 Overlay', (tester) async {
    Future<void>? closed;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => ElButton(
            key: ValueKey('toast'),
            child: '提示',
            onPressed: () => closed = el.toast(context, '保存成功', duration: Duration(seconds: 30)),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('toast')));
    await tester.pump();
    expect(find.byType(ElToast), findsOneWidget);
    await tester.pumpWidget(SizedBox());
    await tester.pump();
    await closed;
    await tester.pump(Duration(seconds: 31));
    expect(tester.takeException(), isNull);
  });
  testWidgets('固定高度的移动卡片将约束传给内嵌滚动内容', (tester) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 320,
          child: ElCard(
            style: ElStyle(height: 280),
            child: Column(
              children: [
                Text('标题'),
                Expanded(child: ListView(children: [for (var i = 0; i < 20; i++) Text('内容 $i')])),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ListView)).height, lessThan(280));
    await tester.drag(find.byType(ListView), Offset(0, -100));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('文字提示点击展示，禁用和事件阻止默认动作生效', (tester) async {
    await tester.pumpWidget(
      host(
        ElTooltip(
          content: '提示内容',
          child: ElButton(key: ValueKey('target'), child: '打开'),
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('target')));
    await tester.pumpAndSettle();
    expect(copy('提示内容'), findsOneWidget);
    await tester.tapAt(Offset(10, 10));
    await tester.pumpAndSettle();
    expect(copy('提示内容'), findsNothing);
    await tester.pumpWidget(
      host(
        ElTooltip(
          key: ValueKey('blocked'),
          content: '禁止提示',
          event: ElEvent(onTap: (e) => e.preventDefault()),
          child: ElButton(key: ValueKey('target'), child: '阻止'),
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('target')));
    await tester.pumpAndSettle();
    expect(copy('禁止提示'), findsNothing);
    await tester.pumpWidget(
      host(
        ElTooltip(
          key: ValueKey('disabled'),
          content: '禁用提示',
          disabled: true,
          child: ElButton(key: ValueKey('target'), child: '禁用'),
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('target')));
    await tester.pumpAndSettle();
    expect(copy('禁用提示'), findsNothing);
    await tester.pumpWidget(SizedBox());
    await tester.pump(Duration(seconds: 4));
  });

  testWidgets('左右抽屉按打开方向拖动关闭并保留取消返回值', (tester) async {
    for (final placement in [ElPopupPlacement.left, ElPopupPlacement.right]) {
      Future<String?>? result;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => ElButton(
              key: ValueKey('open'),
              child: '打开',
              onPressed: () =>
                  result = el.drawer<String>(context, placement: placement, title: '抽屉', child: Text('内容')),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(ValueKey('open')));
      await tester.pumpAndSettle();
      expect(find.byType(ElDrawer), findsOneWidget);
      await tester.drag(find.byType(ElDrawer), Offset(placement == .left ? -500 : 500, 0));
      await tester.pumpAndSettle();
      expect(await result, isNull);
      expect(find.byType(ElDrawer), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
    }
  });

  testWidgets('标题栏两侧操作宽度不同仍保持标题居中', (tester) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 390,
          child: ElAppBar(
            title: '收藏',
            back: true,
            actions: [
              ElButton(child: '搜索'),
              ElButton(child: '更多'),
            ],
          ),
        ),
      ),
    );
    final bar = tester.getRect(find.byType(ElAppBar));
    final title = tester.getRect(copy('收藏').last);
    expect(title.center.dx, closeTo(bar.center.dx, 1));
    expect(tester.takeException(), isNull);
  });
}
