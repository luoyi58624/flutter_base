import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _pageKey = ValueKey<String>('decouple-page');
const _scrollTextKey = ValueKey<String>('decouple-scroll-text');

class _ChromeControls extends SelectionControls {
  const _ChromeControls()
    : super(
        longPressDelay: const Duration(milliseconds: 10),
        longPressSelection: LongPressSelection.paragraph,
        showHandles: true,
        showMagnifier: false,
        showToolbar: false,
      );
}

void _setAndroid() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  addTearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
}

Future<void> _longPress(WidgetTester tester, Finder target) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
  addTearDown(gesture.removePointer);
  await gesture.down(tester.getTopLeft(target) + const Offset(16, 8));
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump();
  await gesture.up();
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('无旧浮层宿主：滚动视口外的句柄可真实拖动并扩缩选区', (tester) async {
    _setAndroid();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final selection = ElSelectionController();
    addTearDown(selection.dispose);
    final scrollKey = ValueKey('decouple-scroll');

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: .ltr,
          child: Align(
            alignment: .topLeft,
            child: SizedBox(
              width: 320,
              height: 200,
              child: SelectionChromeSlotHost(
                child: Column(
                  children: [
                    SizedBox(
                      key: scrollKey,
                      height: 16,
                      child: ElScrollView(
                        controller: controller,
                        children: [
                          SelectionView(
                            controller: selection,
                            controls: AndroidSelectionControls(
                              longPressDelay: Duration(milliseconds: 10),
                              longPressSelection: .paragraph,
                              showMagnifier: false,
                              showToolbar: false,
                              // 单独验证溢出命中，避免视口外的手指触发边缘自滚。
                              touchAutoScroll: SelectionAutoScrollConfig(
                                beltExtent: 0,
                                speedRampExtent: 150,
                                maxFrameDelta: 0,
                              ),
                            ),
                            child: ElView(
                              key: _scrollTextKey,
                              style: ElStyle(width: 260, height: 16, fontSize: 12, lineHeight: 1.5),
                              child: 'alpha beta gamma',
                            ),
                          ),
                          ElView(style: ElStyle(height: 900)),
                        ],
                      ),
                    ),
                    Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _longPress(tester, find.byKey(_scrollTextKey));
    expect(find.byKey(selectionHandleVisualKey), findsWidgets);

    final handle = find.byKey(selectionHandleVisualKey).last;
    expect(
      find.ancestor(of: handle, matching: find.byType(SelectionChromeSlotHost)),
      findsOneWidget,
      reason: 'chrome 必须挂在页面 slot 层',
    );
    expect(
      find.ancestor(of: handle, matching: find.byType(ElScrollView)),
      findsNothing,
      reason: 'chrome 不得落在滚动容器内部（会被裁剪）',
    );
    final handleRect = tester.getRect(handle);
    expect(handleRect.center.dy, greaterThan(tester.getRect(find.byKey(scrollKey)).bottom));
    final before = selection.text!;
    RenderObject? selectionRender = tester.renderObject(find.byKey(_scrollTextKey));
    while (selectionRender is! RenderSelectionView) {
      selectionRender = selectionRender!.parent;
    }
    final render = selectionRender;
    final drag = await tester.startGesture(handleRect.center, kind: .touch);
    addTearDown(drag.removePointer);
    await tester.pump();
    expect(render.isHandleDragInProgress, isTrue, reason: '滚动裁剪以外的句柄仍可认领触摸');
    await drag.moveBy(Offset(-96, 0));
    await tester.pump(Duration(milliseconds: 16));
    expect(selection.text!.length, lessThan(before.length), reason: '真实句柄移动必须改变选区');
    await drag.up();
    await tester.pump();
    expect((render.isHandleDragInProgress || render.isSelectionDragging), isFalse);
    expect(controller.offset, 0);
  });

  testWidgets('提升后的句柄响应 controls 动态更新，选区内容保持', (tester) async {
    _setAndroid();
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    var showHandles = true;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: SelectionChromeSlotHost(
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Align(
                alignment: .topLeft,
                child: SelectionView(
                  controller: controller,
                  controls: AndroidSelectionControls(
                    longPressDelay: Duration(milliseconds: 10),
                    longPressSelection: .paragraph,
                    showHandles: showHandles,
                    showMagnifier: false,
                    showToolbar: false,
                  ),
                  child: ElView(
                    key: _scrollTextKey,
                    style: ElStyle(width: 260, height: 40, fontSize: 12),
                    child: 'alpha beta gamma',
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await _longPress(tester, find.byKey(_scrollTextKey));
    final selected = controller.text;
    expect(selected, isNotEmpty);
    expect(find.byKey(selectionHandleVisualKey), findsNWidgets(2));

    update(() => showHandles = false);
    await tester.pumpAndSettle();
    expect(find.byKey(selectionHandleVisualKey), findsNothing);
    expect(controller.text, selected);

    update(() => showHandles = true);
    await tester.pumpAndSettle();
    expect(find.byKey(selectionHandleVisualKey), findsNWidgets(2));
    expect(controller.text, selected);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Flutter Dialog 中编辑器句柄提升到独立宿主，关闭 dialog 后清理', (tester) async {
    _setAndroid();
    final controller = ElEditableController(text: 'alpha beta gamma delta epsilon');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SelectionControlsScope(
          controls: const _ChromeControls(),
          child: ElView(
            key: _pageKey,
            style: ElStyle(width: 320, height: 220, alignment: .topLeft),
          ),
        ),
      ),
    );

    final dialog = showDialog<void>(
      context: tester.element(find.byKey(_pageKey)),
      builder: (_) => Dialog(
        child: SelectionChromeSlotHost(
          child: SizedBox(
            width: 260,
            height: 140,
            child: ElEditableView(
              controller: controller,
              style: ElEditableStyle(
                view: ElStyle(fontSize: 12, lineHeight: 20),
                contentPadding: EdgeInsets.zero,
                selectionControls: _ChromeControls(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ElEditableView), findsOneWidget);
    await _longPress(tester, find.byType(ElEditableView));
    expect(find.byKey(selectionHandleVisualKey), findsWidgets);

    expect(
      find.ancestor(of: find.byKey(selectionHandleVisualKey).first, matching: find.byType(Dialog)),
      findsOneWidget,
      reason: '句柄留在 Flutter Dialog 内容树内，随 dialog 管理生命周期',
    );
    expect(
      find.ancestor(of: find.byKey(selectionHandleVisualKey).first, matching: find.byType(SelectionChromeSlotHost)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: find.byKey(selectionHandleVisualKey).first, matching: find.byType(ElEditableView)),
      findsNothing,
      reason: '句柄已提升出编辑器子树',
    );
    final navigator = Navigator.of(tester.element(find.byType(ElEditableView)));
    navigator.pop();
    await tester.pumpAndSettle();
    await dialog;
    expect(find.byKey(selectionHandleVisualKey), findsNothing);
    expect(find.byType(ElEditableView), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
