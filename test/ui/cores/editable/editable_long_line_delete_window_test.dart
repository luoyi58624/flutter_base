import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ASCII 超长行首帧即可换窗，跨段删除后窗口与文档保持一致', (tester) async {
    const segment = 25000;
    final controller = EditableController(singleLine: true, text: '${'A' * segment}${'B' * segment}${'C' * segment}');
    final horizontal = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(horizontal.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: .topLeft,
          child: SizedBox(
            width: 240,
            height: 60,
            child: EditableView(
              controller: controller,
              horizontalScrollController: horizontal,
              style: EditableConfiguration(
                softWrap: false,
                cacheExtent: 0,
                scrollbar: ElNoScrollBar(),
                textStyle: TextStyle(fontFamily: 'Ahem', fontSize: 10, height: 1),
              ),
            ),
          ),
        ),
      ),
    );

    void expectWindow(int offset) {
      final render = tester.renderObjectList<RenderEditableLine>(find.byType(EditableLineView)).first;
      final window = render.layoutWindow!;
      expect(window.isVisual, isFalse, reason: '纯 ASCII 使用逻辑窗口，不等待无需生成的 BiDi 分片');
      expect(window.placeholder, isFalse);
      expect(render.scope.debugPendingLongLineBidiResolveCount, 0);
      expect(render.windowPainter, isNotNull);
      expect(window.text.length, lessThan(64 * 1024));
      expect(window.textStart, lessThanOrEqualTo(offset));
      expect(window.textStart + window.text.length, greaterThan(offset));
      expect(
        window.text,
        controller.document.lineAt(0).substring(window.textStart, window.textStart + window.text.length),
      );
    }

    expectWindow(0);
    horizontal.jumpTo((segment - 2) * 10);
    await tester.pump();
    await tester.pump();
    expectWindow(segment);
    controller.collapseTo(segment - 2);
    controller.deleteRange(segment - 2, segment + 2);
    await tester.pump();
    horizontal.jumpTo((segment - 2) * 10);
    await tester.pump();
    await tester.pump();
    expectWindow(segment - 2);
    expect(controller.document.lineAt(0).substring(segment - 3, segment + 1), 'ABBB');
    expect(tester.takeException(), isNull);
  });
}
