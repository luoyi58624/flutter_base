import 'package:example/main.dart';
import 'package:example/src/pages/components/index.dart';
import 'package:example/src/router/index.dart';
import 'package:example/src/widgets/docs_page/index.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _open(WidgetTester tester, {double width = 1280, String path = '/components/view-selection'}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  routingConfig.isMobile = width <= 640;
  router.go(path);
  await tester.pumpWidget(App());
  await tester.pumpAndSettle();
}

ElSelectionController _controller(WidgetTester tester) =>
    tester.widget<ElSelectionView>(_key('selection-area')).controller!;

void main() {
  testWidgets('View 位于 Event 上方，窄屏目录能打开文本选择并读取示例源码', (tester) async {
    final viewIndex = componentCatalog.indexWhere((group) => group.title == 'View 视图');
    final eventIndex = componentCatalog.indexWhere((group) => group.title == 'Event 事件');
    expect(viewIndex, greaterThanOrEqualTo(0));
    expect(eventIndex, viewIndex + 1);
    await _open(tester, width: 320, path: '/components');
    final catalog = find.byKey(PageStorageKey('component-catalog'));
    final scrollable = find.descendant(of: catalog, matching: find.byType(Scrollable));
    final position = tester.state<ScrollableState>(scrollable.first).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(_key('component-view-selection'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/components/view-selection');
    final page = tester.widget<DocsPage>(find.byType(DocsPage));
    expect(page.title, 'Selection 文本选择');
    final source = (await tester.runAsync(() => rootBundle.loadString(page.sections.single.source!)))!;
    expect(source, contains('ElSelectionView('));
    await tester.ensureVisible(_key('el-code-example-toggle'));
    await tester.pumpAndSettle();
    await tester.tap(_key('el-code-example-toggle'));
    await tester.pumpAndSettle();
    expect(find.text(source), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('鼠标跨段拖选同步显示文字，松手保留选区且可清空', (tester) async {
    await _open(tester);
    final controller = _controller(tester);
    expect(controller.text, isNull);
    final first = tester.getRect(_key('selection-paragraph-1'));
    final second = tester.getRect(_key('selection-paragraph-2'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.down(first.topLeft + Offset(2, 8));
    await tester.pump();
    await gesture.moveTo(first.center);
    await gesture.moveTo(second.bottomRight - Offset(2, 4));
    await tester.pump();
    final selected = controller.text;
    expect(selected, contains('沿湖的步道'));
    expect(selected, contains('走到木桥'));
    expect(tester.widget<Text>(_key('selection-result')).data, selected);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.text, selected);
    await tester.tap(_key('selection-clear'));
    await tester.pumpAndSettle();
    expect(controller.text, isNull);
    expect(tester.widget<Text>(_key('selection-result')).data, '尚未选中文字');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('触屏长按选中文字，继续拖动扩展选区，松手仍保留', (tester) async {
    await _open(tester, width: 390);
    final controller = _controller(tester);
    final first = tester.getRect(_key('selection-paragraph-1'));
    final second = tester.getRect(_key('selection-paragraph-2'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);
    await gesture.down(first.topLeft + Offset(8, 8));
    await tester.pump(Duration(milliseconds: 650));
    final initial = controller.text;
    expect(initial, isNotEmpty);
    await gesture.moveTo(second.topLeft + Offset(80, 8));
    await tester.pump();
    final selected = controller.text;
    expect(selected, isNot(initial));
    expect(selected, contains('走到'));
    expect(tester.widget<Text>(_key('selection-result')).data, selected);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.text, selected);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
