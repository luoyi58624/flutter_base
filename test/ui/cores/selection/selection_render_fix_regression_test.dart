import 'package:flutter_base/src/ui/cores/selection/docs/selection_view.dart';
// selection-render 修复批次的回归测试：
// 1. 拖选进行中（未松键）Ctrl+C 复制的是**当前**选区，不是拖动首帧的陈旧快照
//    （copySelection / keyC 分支改走 resolveSelectionInfo 刷脏）。
// 2. ElSelectionView.enabled 运行时翻转后重绑子树参与者：false→true 让禁用期
//    挂载的内容可被本 root 选中；SelectionIsland.enabled 关闭时注销手势岛。

import 'package:flutter_base/src/ui/cores/selection/common/selection_core.dart';

import 'package:flutter_base/src/ui/cores/view/view.dart';
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

void main() {
  group('copySelection during drag', () {
    testWidgets('Ctrl+C mid-drag copies the current dragged selection, not the first-frame snapshot', (tester) async {
      String? clipboardText;
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map<Object?, Object?>?)?['text'] as String?;
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

      final controller = ElSelectionController();
      const textKey = Key('mid-drag-copy-target');

      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const ElView(child: 'alpha beta gamma', key: textKey),
          ),
        ),
      );

      final topLeft = tester.getTopLeft(find.byKey(textKey));
      final bottomRight = tester.getBottomRight(find.byKey(textKey));
      final centerY = (topLeft.dy + bottomRight.dy) / 2;
      final start = Offset(topLeft.dx + 1, centerY);
      final end = Offset(bottomRight.dx - 1, centerY);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);

      await gesture.down(start);
      await tester.pump();
      // 首个 move 越过 dragThreshold：拖选确立，info 初始化为此刻的小段快照。
      await gesture.moveTo(start + const Offset(20, 0));
      await tester.pump();
      // 继续拖到行尾：拖动期 info 是 deferred 语义，只推脏标记不重建快照。
      await gesture.moveTo(end);
      await tester.pump();

      // 未松键先 Ctrl+C：必须刷脏后复制当前全量选区。
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(clipboardText, 'alpha beta gamma', reason: 'mid-drag copy must flush the deferred selection info');

      await gesture.up();
      await tester.pump();
    });
  });

  group('ElSelectionView.enabled runtime rebind', () {
    testWidgets('false→true rebinds participants mounted while disabled', (tester) async {
      final controller = ElSelectionController();
      var enabled = false;

      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElSelectionView(
                    enabled: enabled,
                    controller: controller,
                    child: const ElView(child: 'alpha beta'),
                  ),
                  TextButton(onPressed: () => setState(() => enabled = true), child: const Text('enable')),
                ],
              );
            },
          ),
        ),
      );

      // 禁用期：imperative 通道同样禁用。
      controller.selectAll();
      await tester.pump();
      expect(controller.text, isNull);

      await tester.tap(find.text('enable'));
      await tester.pump();

      // 重启用后禁用期挂载的文本必须可被本 root 选中。
      controller.selectAll();
      await tester.pump();
      expect(controller.text, 'alpha beta', reason: 're-enabled root must own participants mounted while disabled');
    });

    testWidgets('SelectionIsland.enabled true→false 立即注销外层手势岛', (tester) async {
      final outerController = ElSelectionController();
      var islandEnabled = true;
      const innerKey = ValueKey('inner-text');

      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElSelectionView(
                    controller: outerController,
                    child: SelectionIsland(
                      enabled: islandEnabled,
                      child: const ElView(key: innerKey, child: 'inner text'),
                    ),
                  ),
                  TextButton(onPressed: () => setState(() => islandEnabled = false), child: const Text('disable')),
                  TextButton(onPressed: () => setState(() => islandEnabled = true), child: const Text('enable')),
                ],
              );
            },
          ),
        ),
      );

      final rect = tester.getRect(find.byKey(innerKey));
      final blockedGesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(blockedGesture.removePointer);
      await blockedGesture.down(rect.centerLeft + const Offset(1, 0));
      await blockedGesture.moveTo(rect.centerRight - const Offset(1, 0));
      await blockedGesture.up();
      await tester.pump();
      expect(outerController.text, isNull, reason: '启用的选区岛内起手时外层弃权');

      await tester.tap(find.text('disable'));
      await tester.pump();

      final activeGesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(activeGesture.removePointer);
      await activeGesture.down(rect.centerLeft + const Offset(1, 0));
      await activeGesture.moveTo(rect.centerRight - const Offset(1, 0));
      await activeGesture.up();
      await tester.pump();
      expect(outerController.text, 'inner text', reason: '禁用后必须注销手势岛，外层可从块内起手');

      outerController.clear();
      await tester.tap(find.text('enable'));
      await tester.pump();
      final restoredGesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(restoredGesture.removePointer);
      await restoredGesture.down(rect.centerLeft + const Offset(1, 0));
      await restoredGesture.moveTo(rect.centerRight - const Offset(1, 0));
      await restoredGesture.up();
      await tester.pump();
      expect(outerController.text, isNull, reason: '重新启用后必须恢复选区岛');
    });
  });
}
