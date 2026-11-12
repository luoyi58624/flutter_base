import 'package:flutter_base/src/flutter/views/selection/docs/selection_view.dart';
// ElSelectionView.enabled 开关 + eager 淘汰后的选区会话清理集成验证。

import 'package:flutter_base/src/flutter/views/scroll/scroll.dart';
import 'package:flutter_base/src/flutter/views/selection/common/selection_core.dart';

import 'package:flutter_base/src/flutter/views/view/view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

RenderSelectionView _selectionRender(WidgetTester tester) {
  return tester.allRenderObjects.whereType<RenderSelectionView>().first;
}

void main() {
  group('ElSelectionView.enabled', () {
    testWidgets('enabled=false: touch long press does NOT enter selection', (tester) async {
      final hapticCalls = <Object?>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') hapticCalls.add(call.arguments);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

      final controller = ElSelectionController();
      const textKey = Key('disabled-selection-touch-target');

      await tester.pumpWidget(
        _app(
          SelectionView(
            enabled: false,
            controller: controller,
            child: const ElView(child: 'alpha beta gamma', key: textKey),
          ),
        ),
      );

      final center = tester.getCenter(find.byKey(textKey));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);

      await gesture.down(center);
      await tester.pump(const Duration(milliseconds: 600));

      expect(controller.text, isNull, reason: 'disabled selection root ignores long press');
      expect(hapticCalls, isEmpty, reason: 'no haptic if long press did not fire');
      expect(_selectionRender(tester).isSelectionDragging, isFalse);
      expect(_selectionRender(tester).selectionEnabled, isFalse);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('runtime true→false clears an active selection immediately', (tester) async {
      final controller = ElSelectionController();
      const textKey = Key('runtime-toggle-selection-target');
      var enabled = true;

      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectionView(
                    enabled: enabled,
                    controller: controller,
                    child: const ElView(child: 'alpha beta gamma', key: textKey),
                  ),
                  TextButton(onPressed: () => setState(() => enabled = false), child: const Text('disable')),
                ],
              );
            },
          ),
        ),
      );

      // 先建立一个选中——鼠标三击选段。
      final center = tester.getCenter(find.byKey(textKey));
      await tester.tapAt(center, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center, kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(controller.text, isNotNull, reason: 'triple click should select a paragraph');
      expect(_selectionRender(tester).selectionEnabled, isTrue);

      // 切 enabled=false。
      await tester.tap(find.text('disable'));
      await tester.pump();

      expect(controller.text, isNull, reason: 'disabling must drop the active selection');
      expect(_selectionRender(tester).selectionEnabled, isFalse);
    });
  });

  group('selection integrates with eager membership cleanup', () {
    testWidgets('滚动先认领会取消长按候选并释放 Selection 自有 pointer 状态', (tester) async {
      // touch 拖出后滚动先认领，Selection 随即失去该 pointer 的事件资格；事件层
      // 必须同步取消它的 longPress 候选并让 Selection 释放自有会话状态，不能依赖
      // loser 继续收到 raw move/up 收尾。第二轮静止长按用来证明状态没有卡死。
      final hapticCalls = <Object?>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') hapticCalls.add(call.arguments);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

      final controller = ElSelectionController();
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      const firstRowKey = Key('scroll-vs-selection-row-0');

      // 足够多的行保证可滚动。
      final rows = List<Widget>.generate(30, (index) {
        return SizedBox(
          height: 36,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ElView(child: 'row $index text', key: index == 0 ? firstRowKey : ValueKey('row-$index')),
          ),
        );
      });

      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 240,
            height: 120,
            child: SelectionView(
              controller: controller,
              controls: const DesktopSelectionControls(longPressHaptics: true),
              child: ElScrollView(controller: scrollController, physics: ClampingScrollPhysics(), children: rows),
            ),
          ),
        ),
      );

      final rowCenter = tester.getCenter(find.byKey(firstRowKey));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);

      // 第一轮：滚动先胜出，等待超过长按延时也不得建立选区。
      await gesture.down(rowCenter);
      await gesture.moveBy(Offset(0, -(kTouchSlop + 12)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.text, isNull, reason: 'longPress must not enter selection after drag-threshold exceeded');
      expect(hapticCalls, isEmpty, reason: 'no haptic implies no selection entered');
      expect(_selectionRender(tester).isSelectionDragging, isFalse);

      await gesture.up();
      await tester.pump();

      // 第二轮：同一 Selection 能重新接住静止长按，证明 loser 清理没有遗留
      // `_activePointer` / waitingLongPress 状态。
      final next = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(next.removePointer);
      await next.down(rowCenter);
      await tester.pump(const Duration(milliseconds: 450));
      expect(controller.text, isNotNull);
      expect(_selectionRender(tester).isSelectionDragging, isTrue);
      expect(hapticCalls, hasLength(1));
      await next.up();
      await tester.pump();
    });
  });
}
