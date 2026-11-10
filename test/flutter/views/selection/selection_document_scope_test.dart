import 'dart:convert';

import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/views/selection/common/selection_core.dart';
import 'package:flutter_base/src/flutter/views/selection/docs/selection_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Align(
    alignment: .topLeft,
    child: SizedBox(width: 360, height: 240, child: child),
  ),
);

Widget _line(String text, {Key? key}) => ElView(
  key: key,
  style: ElStyle(fontSize: 20, lineHeight: 1, fontFamily: 'Ahem'),
  child: text,
);

Future<void> _drag(WidgetTester tester, Offset start, Offset end) async {
  final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await pointer.down(start);
  await tester.pump(Duration(milliseconds: 16));
  await pointer.moveTo(end);
  await tester.pump(Duration(milliseconds: 16));
  await pointer.up();
  await tester.pump();
  await pointer.removePointer();
}

void main() {
  testWidgets('单文档全选统一包含El文本、官方Text、RichText和图片替代文字', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        ElSelectionView(
          controller: controller,
          child: Column(
            crossAxisAlignment: .start,
            children: [
              _line('own'),
              Text('native'),
              Builder(
                builder: (context) => RichText(
                  text: TextSpan(text: 'rich'),
                  selectionRegistrar: SelectionContainer.maybeOf(context),
                  selectionColor: Colors.blue,
                ),
              ),
              ElImageView.memory(
                base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4AWMAAQAABQABDQottAAAAABJRU5ErkJggg==',
                ),
                width: 24,
                height: 24,
                alt: 'picture',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.selectAll();
    await tester.pump();
    expect(controller.text, 'own\nnative\nrich\npicture');
    expect(controller.hasSelection, isTrue);
    controller.clear();
    await tester.pump();
    expect(controller.text, isNull);
  });

  testWidgets('显式嵌套根各自独立，禁用内根不把内容移交外根', (tester) async {
    final outer = ElSelectionController();
    final inner = ElSelectionController();
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    Widget build(bool enabled) => _host(
      ElSelectionView(
        controller: outer,
        child: Column(
          children: [
            _line('outer'),
            ElSelectionView(controller: inner, enabled: enabled, child: _line('inner')),
          ],
        ),
      ),
    );
    await tester.pumpWidget(build(true));
    outer.selectAll();
    inner.selectAll();
    await tester.pump();
    expect(outer.text, 'outer');
    expect(inner.text, 'inner');
    await tester.pumpWidget(build(false));
    outer.selectAll();
    await tester.pump();
    expect(outer.text, 'outer');
    expect(inner.text, isNull);
  });

  testWidgets('显式文档不继承其他根上方的userSelect none', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        ElView(
          style: ElStyle(userSelect: ElUserSelect.none),
          child: ElSelectionView(
            controller: controller,
            child: Column(children: [_line('own'), Text('native')]),
          ),
        ),
      ),
    );
    controller.selectAll();
    await tester.pump();
    expect(controller.text, 'own\nnative');
  });

  for (final nativeFirst in [false, true]) {
    testWidgets('跨El文本与官方Text鼠标拖选走同一范围 nativeFirst=$nativeFirst', (tester) async {
      final controller = ElSelectionController();
      addTearDown(controller.dispose);
      final first = GlobalKey();
      final last = GlobalKey();
      Widget native(String text, Key key) => Text(
        text,
        key: key,
        style: TextStyle(fontSize: 20, fontFamily: 'Ahem', height: 1),
      );
      await tester.pumpWidget(
        _host(
          ElSelectionView(
            controller: controller,
            child: Column(
              crossAxisAlignment: .start,
              children: [
                nativeFirst ? native('first', first) : _line('first', key: first),
                nativeFirst ? _line('last', key: last) : native('last', last),
              ],
            ),
          ),
        ),
      );
      final a = tester.getRect(find.byKey(first));
      final b = tester.getRect(find.byKey(last));
      await _drag(tester, a.centerLeft + Offset(1, 0), b.centerRight - Offset(1, 0));
      expect(controller.text, 'first\nlast');
    });
  }

  testWidgets('桌面双击选词、三击选段并在抬手后保留范围', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      _host(
        ElSelectionView(
          controller: controller,
          child: Align(
            alignment: .topLeft,
            child: _line('first last', key: key),
          ),
        ),
      ),
    );
    final point = tester.getTopLeft(find.byKey(key)) + Offset(30, 10);
    for (var count = 0; count < 3; count++) {
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.down(point);
      await tester.pump(Duration(milliseconds: 20));
      await pointer.up();
      await tester.pump(Duration(milliseconds: 40));
      await pointer.removePointer();
      if (count == 1) expect(controller.text, 'first');
      if (count == 2) expect(controller.text, 'first last');
    }
  });

  testWidgets('触摸长按与句柄拖动共享官方范围', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      _host(
        SelectionView(
          controller: controller,
          controls: AndroidSelectionControls(
            longPressDelay: Duration.zero,
            longPressHaptics: false,
            handleHaptics: false,
            showMagnifier: false,
            showToolbar: false,
          ),
          child: Align(
            alignment: .topLeft,
            child: _line('first last', key: key),
          ),
        ),
      ),
    );
    final pointer = await tester.createGesture(kind: PointerDeviceKind.touch);
    await pointer.down(tester.getTopLeft(find.byKey(key)) + Offset(30, 10));
    await tester.pump();
    expect(controller.text, 'first');
    await pointer.up();
    await tester.pump();
    await pointer.removePointer();
    final root = tester.allRenderObjects.whereType<RenderSelectionView>().toSet().single;
    final end = root.endpoints!.end.globalBottom;
    root.beginHandleDrag(SelectionHandleSide.end, end);
    root.updateHandleDrag(end + Offset(100, 0));
    await tester.pump();
    root.endHandleDrag();
    expect(controller.text, 'first last');
    expect(root.dragInfoListenable.value, isNull);
  });

  testWidgets('触摸重复选中同一词仍会显示句柄，几何不变也同步交互形态', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      _host(
        SelectionView(
          controller: controller,
          controls: AndroidSelectionControls(
            longPressDelay: Duration.zero,
            longPressHaptics: false,
            showMagnifier: false,
            showToolbar: false,
          ),
          child: Align(
            alignment: .topLeft,
            child: _line('word', key: key),
          ),
        ),
      ),
    );
    controller.selectAll();
    await tester.pumpAndSettle();
    expect(find.byKey(selectionHandleVisualKey), findsNothing);
    final pointer = await tester.createGesture(kind: PointerDeviceKind.touch);
    await pointer.down(tester.getTopLeft(find.byKey(key)) + Offset(30, 10));
    await tester.pump();
    await pointer.up();
    await pointer.removePointer();
    await tester.pumpAndSettle();
    expect(controller.text, 'word');
    expect(find.byKey(selectionHandleVisualKey), findsNWidgets(2));
  });

  testWidgets('根焦点Ctrl+A/C与Escape只作用于当前文档', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    String? clipboard;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(_host(ElSelectionView(controller: controller, child: _line('document'))));
    final root = tester.allRenderObjects.whereType<RenderSelectionView>().toSet().single;
    root.rootFocusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.text, 'document');
    expect(clipboard, 'document');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(controller.text, isNull);
  });

  testWidgets('根卸载会解绑控制器和在途句柄路由', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(ElSelectionView(controller: controller, child: _line('document'))));
    controller.selectAll();
    await tester.pump();
    final root = tester.allRenderObjects.whereType<RenderSelectionView>().toSet().single;
    root.beginHandleDrag(SelectionHandleSide.end, root.endpoints!.end.globalBottom, pointer: 88);
    await tester.pumpWidget(SizedBox());
    await tester.pump();
    expect(controller.text, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('没有替代文字的图片仍有选区，文本结果为空字符串', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        ElSelectionView(
          controller: controller,
          child: ElImageView.memory(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4AWMAAQAABQABDQottAAAAABJRU5ErkJggg==',
            ),
            width: 24,
            height: 24,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.selectAll();
    await tester.pump();
    expect(controller.hasSelection, isTrue);
    expect(controller.text, '');
  });

  testWidgets('userSelect all 双击使用当前文档官方范围整选文本', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      _host(
        ElSelectionView(
          controller: controller,
          child: Align(
            alignment: .topLeft,
            child: ElView(
              key: key,
              style: ElStyle(fontSize: 20, fontFamily: 'Ahem', userSelect: .all),
              child: 'first last',
            ),
          ),
        ),
      ),
    );
    final point = tester.getTopLeft(find.byKey(key)) + Offset(30, 10);
    for (var count = 0; count < 2; count++) {
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.down(point);
      await tester.pump(Duration(milliseconds: 20));
      await pointer.up();
      await tester.pump(Duration(milliseconds: 40));
      await pointer.removePointer();
    }
    expect(controller.text, 'first last');
  });

  testWidgets('鼠标拖选到滚动边缘会推进视口，抬手结束自动滚动', (tester) async {
    final controller = ElSelectionController();
    final scroll = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scroll.dispose);
    final first = GlobalKey();
    await tester.pumpWidget(
      _host(
        ElSelectionView(
          controller: controller,
          child: ElScroll(
            controller: scroll,
            children: [for (var i = 0; i < 40; i++) _line('row $i', key: i == 0 ? first : null)],
          ),
        ),
      ),
    );
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.down(tester.getTopLeft(find.byKey(first)) + Offset(1, 10));
    await pointer.moveTo(Offset(80, 238));
    await tester.pump(Duration(milliseconds: 20));
    await tester.pump(Duration(milliseconds: 100));
    expect(scroll.offset, greaterThan(0));
    expect(controller.text, isNotEmpty);
    await pointer.up();
    await pointer.removePointer();
    await tester.pump();
    final offset = scroll.offset;
    await tester.pump(Duration(milliseconds: 100));
    expect(scroll.offset, offset);
  });
}
