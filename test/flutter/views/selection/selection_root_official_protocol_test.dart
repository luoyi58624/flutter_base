import 'package:flutter_base/src/flutter/views/selection/docs/selection_view.dart';

import 'dart:convert';

import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/views/selection/common/selection_core.dart'
    show SelectionHandleSide, DesktopSelectionControls;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 320, height: 180, child: child),
  ),
);

Future<void> _drag(WidgetTester tester, Offset start, Offset end) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.down(start);
  await tester.pump(Duration(milliseconds: 16));
  await gesture.moveTo(end);
  await tester.pump(Duration(milliseconds: 16));
  await gesture.up();
  await tester.pump();
  await gesture.removePointer();
}

void main() {
  testWidgets('自动滚动宿主区分触摸与精确指针，不递归调用自身', (tester) async {
    await tester.pumpWidget(_host(SelectionView(child: Text('native'))));
    final root = tester.allRenderObjects.whereType<RenderSelectionView>().toSet().single;
    final touchKinds = {
      PointerDeviceKind.touch,
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
      PointerDeviceKind.unknown,
    };
    for (final kind in PointerDeviceKind.values) {
      expect(root.isTouchSelectionPointer(kind), touchKinds.contains(kind), reason: kind.name);
    }
  });

  testWidgets('原地替换等宽内容更新复制快照，缩短内容裁剪当前范围', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    Widget build(String text) => _host(
      SelectionView(
        controller: controller,
        child: ElView(
          key: ValueKey('same-node'),
          style: ElStyle(fontFamily: 'Ahem', fontSize: 20),
          child: text,
        ),
      ),
    );
    await tester.pumpWidget(build('alpha'));
    controller.selectAll();
    await tester.pump();
    expect(controller.text, 'alpha');
    await tester.pumpWidget(build('bravo'));
    await tester.pump();
    expect(controller.text, 'bravo');
    await tester.pumpWidget(build('new'));
    await tester.pump();
    expect(controller.text, 'new');
    expect(controller.hasSelection, isTrue);
  });

  testWidgets('零延迟长按遇同步取消时不会在微任务中恢复旧选区', (tester) async {
    final controller = ElSelectionController();
    final key = GlobalKey();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        SelectionView(
          controller: controller,
          controls: DesktopSelectionControls(longPressDelay: Duration.zero, longPressHaptics: false),
          child: Text('native', key: key),
        ),
      ),
    );
    final point = tester.getCenter(find.byKey(key));
    tester.binding.handlePointerEvent(PointerDownEvent(pointer: 41, kind: PointerDeviceKind.touch, position: point));
    tester.binding.handlePointerEvent(PointerCancelEvent(pointer: 41, kind: PointerDeviceKind.touch, position: point));
    await tester.pump();
    expect(controller.text, isNull);
    final root = tester.allRenderObjects.whereType<RenderSelectionView>().toSet().single;
    expect(root.isPointerDragging, isFalse);
    expect(root.dragInfoListenable.value, isNull);
  });

  testWidgets('普通 ElSelectionView 直接全选混合文本和图片，仅返回纯文本', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        SelectionView(
          controller: controller,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElView(child: 'own'),
              Text('native'),
              ElImageView.memory(
                base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4AWMAAQAABQABDQottAAAAABJRU5ErkJggg==',
                ),
                alt: 'picture',
                width: 24,
                height: 24,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.selectAll();
    await tester.pump();
    expect(controller.text, 'own\nnative\npicture');
    controller.clear();
    expect(controller.text, isNull);
  });

  for (final nativeFirst in [false, true]) {
    testWidgets('桌面跨 El 与官方 Text 连续拖选 nativeFirst=$nativeFirst', (tester) async {
      final controller = ElSelectionController();
      final firstKey = GlobalKey();
      final lastKey = GlobalKey();
      addTearDown(controller.dispose);
      Widget own(Key key, String text) => ElView(
        key: key,
        style: ElStyle(fontFamily: 'Ahem', fontSize: 20, lineHeight: 1),
        child: text,
      );
      Widget native(Key key, String text) => Text(
        text,
        key: key,
        style: TextStyle(fontFamily: 'Ahem', fontSize: 20, height: 1),
      );
      await tester.pumpWidget(
        _host(
          SelectionView(
            controller: controller,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                nativeFirst ? native(firstKey, 'first') : own(firstKey, 'first'),
                nativeFirst ? own(lastKey, 'last') : native(lastKey, 'last'),
              ],
            ),
          ),
        ),
      );
      final first = tester.getRect(find.byKey(firstKey));
      final last = tester.getRect(find.byKey(lastKey));
      await _drag(tester, first.centerLeft + Offset(1, 0), last.centerRight - Offset(1, 0));
      expect(controller.text, 'first\nlast');
      await tester.pump(Duration(milliseconds: 400));
      await _drag(tester, last.centerRight - Offset(1, 0), first.centerLeft + Offset(1, 0));
      expect(controller.text, 'first\nlast');
    });
  }

  testWidgets('官方 Text 的长按、放大镜状态和手柄调整使用同一文档范围', (tester) async {
    final controller = ElSelectionController();
    final textKey = GlobalKey();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        SelectionView(
          controller: controller,
          controls: const DesktopSelectionControls(longPressDelay: Duration.zero),
          child: Text(
            'native text',
            key: textKey,
            style: TextStyle(fontFamily: 'Ahem', fontSize: 20, height: 1),
          ),
        ),
      ),
    );
    final root = tester.allRenderObjects.whereType<RenderSelectionView>().toSet().single;
    final rect = tester.getRect(find.byKey(textKey));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
    await gesture.down(rect.topLeft + Offset(20, 10));
    await tester.pump();
    expect(controller.text, 'native');
    expect(root.dragInfoListenable.value, isNotNull);
    expect(root.magnifierLineGeometryForDrag(), isNotNull);
    await gesture.up();
    await tester.pump();
    await gesture.removePointer();

    controller.selectAll();
    await tester.pump();
    final original = root.endpoints!.end.globalPosition;
    root.beginHandleDrag(SelectionHandleSide.end, original);
    root.updateHandleDrag(original - Offset(40, 0));
    await tester.pump();
    expect(controller.text!.length, lessThan('native text'.length));
    expect(controller.text, isNotEmpty);
    root.endHandleDrag();
    await tester.pumpWidget(SizedBox());
    expect(controller.text, isNull);
  });

  testWidgets('官方 Text 桌面双击选词、三击选段，抬手保留范围', (tester) async {
    final controller = ElSelectionController();
    final key = GlobalKey();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        SelectionView(
          controller: controller,
          child: Text(
            'first last',
            key: key,
            style: TextStyle(fontFamily: 'Ahem', fontSize: 20, height: 1),
          ),
        ),
      ),
    );
    final point = tester.getTopLeft(find.byKey(key)) + Offset(30, 10);
    for (var tap = 0; tap < 3; tap++) {
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.down(point);
      await tester.pump(Duration(milliseconds: 20));
      await gesture.up();
      await tester.pump(Duration(milliseconds: 40));
      await gesture.removePointer();
      if (tap == 1) expect(controller.text, 'first');
      if (tap == 2) expect(controller.text, 'first last');
    }
  });

  testWidgets('官方 Text 随普通滚动更新手柄与裁剪，不改变仍挂载的选中内容', (tester) async {
    final controller = ElSelectionController();
    final scroll = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _host(
        SelectionView(
          controller: controller,
          child: ElScroll(
            controller: scroll,
            children: List.generate(
              20,
              (index) => Text('line $index', style: TextStyle(fontFamily: 'Ahem', fontSize: 20, height: 1)),
            ),
          ),
        ),
      ),
    );
    controller.selectAll();
    await tester.pump();
    final root = tester.allRenderObjects.whereType<RenderSelectionView>().toSet().single;
    final before = root.endpoints!.start.globalPosition;
    final text = controller.text;
    scroll.jumpTo(40);
    await tester.pump();
    await tester.pump();
    expect(root.endpoints!.start.globalPosition.dy, closeTo(before.dy - 40, .01));
    expect(root.endpoints!.start.visible, isFalse);
    expect(controller.text, text);
  });

  testWidgets('禁用的官方范围和独立对象框选不进入外层文档', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        SelectionView(
          controller: controller,
          child: Column(
            children: [
              Text('selected', style: TextStyle(fontSize: 20)),
              SelectionContainer.disabled(child: Text('disabled', style: TextStyle(fontSize: 20))),
              SizedBox(height: 32, child: ElBoxSelectionView(child: Text('box only'))),
            ],
          ),
        ),
      ),
    );
    controller.selectAll();
    await tester.pump();
    expect(controller.text, 'selected');
  });
}
