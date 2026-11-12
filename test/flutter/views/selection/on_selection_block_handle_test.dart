import 'dart:convert';
// 图片选中外观与各端点的独立句柄色。

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
  testWidgets('图片的 onSelection.backgroundColor 决定选中底色', (tester) async {
    final controller = ElSelectionController();
    const blockKey = Key('styled-block');
    const textKey = Key('lead-text');
    await tester.pumpWidget(
      _app(
        ElSelectionView(
          controller: controller,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElView(key: textKey, child: 'lead text'),
              ElImageView.memory(
                base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4AWMAAQAABQABDQottAAAAABJRU5ErkJggg==',
                ),
                key: blockKey,
                alt: 'picture',
                width: 60,
                height: 30,
                style: ElStyle(onSelection: ElStyle(backgroundColor: Color(0x33FF8800))),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.down(tester.getRect(find.byKey(textKey)).centerLeft + const Offset(1, 0));
    await gesture.moveTo(tester.getRect(find.byKey(blockKey)).centerRight - const Offset(1, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final block = tester.renderObject<ElRenderImage>(find.byKey(blockKey));
    expect(block.currentSelectionRange, isNotNull);
    expect(selectionParticipantOf(block)!.effectiveSelectionBgColor, const Color(0x33FF8800));
  });

  testWidgets('端点 handle 各用各 participant 色（不透明版），未声明端用 root 色', (tester) async {
    await tester.pumpWidget(
      _app(
        const ElSelectionView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElView(
                child: 'first segment',
                style: ElStyle(onSelection: ElStyle(backgroundColor: Color(0x55123456))),
              ),
              ElView(child: 'second segment'),
            ],
          ),
        ),
      ),
    );
    // 经 render 层控制器通道全选（selectAll 是 imperative 入口，无需手势）。
    final render = _selectionRender(tester);
    render.selectAllSelection();
    await tester.pump();

    final info = render.endpoints;
    expect(info, isNotNull);
    expect(info!.start.handleColor, const Color(0xFF123456), reason: 'start 端 = 声明节点色的不透明版');
    // 未声明端 = root 平台默认色的不透明版（与声明端不同即证明端点独立取色）。
    expect(info.end.handleColor, isNotNull);
    expect(info.end.handleColor, isNot(const Color(0xFF123456)));
  });
}
