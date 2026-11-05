import 'package:flutter_base/src/flutter/views/selection/docs/selection_view.dart';
// onSelection 伪类 per-participant 着色接线（Phase 2a）：
//
// - 文本宿主：声明节点用自己的色，未声明邻段回退 root 平台默认 → 混排双色
// - vars 通道：onSelection.backgroundColor 引用 '--key' 经宿主 vars 表折算
// - 状态流入：onHover 嵌套 onSelection 随真实 hover 激活/退场
// - 图片宿主：ElImageView.style.onSelection.backgroundColor 生效

import 'dart:typed_data';

import 'package:flutter_base/src/flutter/views/image/image_view.dart';
import 'package:flutter_base/src/flutter/views/image/render/render_image_view.dart';

import 'package:flutter_base/src/flutter/views/view/view.dart';
import 'package:flutter_base/src/flutter/views/view/render/render_view.dart';
import 'package:flutter_base/src/flutter/views/view/style/style.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 1×1 透明 png（与 selection_test.dart 同款字节）。
final Uint8List _transparentPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
]);

Widget _app(Widget child) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

const _styledKey = Key('styled-text');
const _plainKey = Key('plain-text');

Future<void> _dragSelectAll(WidgetTester tester, Rect from, Rect to) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(gesture.removePointer);
  await gesture.down(from.centerLeft + const Offset(1, 0));
  await gesture.moveTo(to.centerRight - const Offset(1, 0));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('声明节点用自己的 onSelection 色，未声明邻段回退 root（混排双色）', (tester) async {
    final controller = ElSelectionController();
    await tester.pumpWidget(
      _app(
        ElSelectionView(
          controller: controller,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElView(
                key: _styledKey,
                child: 'styled segment',
                style: ElStyle(
                  onSelection: ElStyle(backgroundColor: Color(0xFF123456), color: Color(0xFFFEDCBA)),
                ),
              ),
              ElView(key: _plainKey, child: 'plain segment'),
            ],
          ),
        ),
      ),
    );

    await _dragSelectAll(tester, tester.getRect(find.byKey(_styledKey)), tester.getRect(find.byKey(_plainKey)));
    expect(controller.text, 'styled segment\nplain segment');

    final styled = tester.renderObject<ElRenderView>(find.byKey(_styledKey));
    final plain = tester.renderObject<ElRenderView>(find.byKey(_plainKey));
    expect(styled.selectionColor, const Color(0xFF123456));
    expect(styled.selectionTextColor, const Color(0xFFFEDCBA));
    // 未声明邻段回退 root 兜底（与声明节点不同色 = 混排双色语义）。
    expect(plain.selectionColor, isNot(const Color(0xFF123456)));
    expect(plain.selectionColor, styled.selectionParticipant!.selectionColor, reason: '回退值即 root 推送色');
  });

  testWidgets('onSelection 只声明 backgroundColor 时 color=null（整对脱离 root，不继承兜底字色）', (tester) async {
    // Windows 平台默认 = 实底蓝 + 白字兜底，验证声明节点不吃兜底白字。
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final controller = ElSelectionController();
      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const ElView(
              key: _styledKey,
              child: 'only bg',
              style: ElStyle(onSelection: ElStyle(backgroundColor: Color(0xFF123456))),
            ),
          ),
        ),
      );

      final rect = tester.getRect(find.byKey(_styledKey));
      await _dragSelectAll(tester, rect, rect);
      final styled = tester.renderObject<ElRenderView>(find.byKey(_styledKey));
      expect(styled.selectionColor, const Color(0xFF123456));
      expect(styled.selectionTextColor, isNull, reason: '声明 bgColor 即脱离 root 对，字色保留原色');
      expect(styled.selectionParticipant!.selectionTextColor, const Color(0xFFFFFFFF), reason: 'root 兜底字色仍是白');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('onHover 嵌套 onSelection：hover 激活换色，移出恢复', (tester) async {
    final controller = ElSelectionController();
    await tester.pumpWidget(
      _app(
        ElSelectionView(
          controller: controller,
          child: const ElView(
            key: _styledKey,
            child: 'hover nested',
            style: ElStyle(
              onSelection: ElStyle(backgroundColor: Color(0xFF111111)),
              onHover: ElStyle(onSelection: ElStyle(backgroundColor: Color(0xFF999999))),
            ),
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byKey(_styledKey));
    // 拖选后立即移除指针：抬起的鼠标指针仍停留原地悬停，会叠加干扰 hover 断言。
    final drag = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await drag.down(rect.centerLeft + const Offset(1, 0));
    await drag.moveTo(rect.centerRight - const Offset(1, 0));
    await tester.pump();
    await drag.up();
    await drag.removePointer();
    await tester.pump();
    final styled = tester.renderObject<ElRenderView>(find.byKey(_styledKey));
    expect(styled.selectionColor, const Color(0xFF111111));

    final hover = await tester.createGesture(kind: PointerDeviceKind.mouse, pointer: 9);
    addTearDown(hover.removePointer);
    await hover.addPointer(location: rect.center);
    await tester.pump();
    expect(styled.selectionColor, const Color(0xFF999999), reason: 'hover 位流入 extract');

    await hover.moveTo(rect.bottomRight + const Offset(100, 100));
    await tester.pump();
    expect(styled.selectionColor, const Color(0xFF111111), reason: '退出 hover 恢复 base 声明');
  });

  testWidgets('ElImageView.style.onSelection.backgroundColor 生效', (tester) async {
    final controller = ElSelectionController();
    const imageKey = Key('sel-image');
    await tester.pumpWidget(
      _app(
        ElSelectionView(
          controller: controller,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ElView(key: _plainKey, child: 'before image'),
              ElImageView.memory(
                _transparentPng,
                key: imageKey,
                src: 'https://example.test/image.png',
                alt: 'diagram',
                width: 40,
                height: 24,
                style: const ElStyle(onSelection: ElStyle(backgroundColor: Color(0x55336699))),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await _dragSelectAll(tester, tester.getRect(find.byKey(_plainKey)), tester.getRect(find.byKey(imageKey)));

    final image = tester.renderObject<RenderImageView>(find.byKey(imageKey));
    expect(image.currentSelectionRange, isNotNull, reason: '图片被扫进选区');
    expect(image.selectionParticipant!.effectiveSelectionBgColor, const Color(0x55336699));
  });
}
