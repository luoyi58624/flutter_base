import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/utils/internal/benchmark_probe.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 只检查 TextSpan 选区的覆盖层缓存，不以无头测试推断设备帧耗时。
final _text = '重复采样文本用于撑大富文本段落，' * 100;
const _key = ValueKey('native-span-selection');

Future<ElRenderView> _pumpRich(WidgetTester tester, ElSelectionController controller, Color color) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: ElSelectionView(
          controller: controller,
          child: ElView(
            key: _key,
            style: ElStyle(fontSize: 14, lineHeight: 1.5, onSelection: ElStyle(color: Colors.white)),
            child: TextSpan(
              children: [
                TextSpan(
                  text: '关键词',
                  style: TextStyle(color: color),
                ),
                TextSpan(text: '\n$_text\n$_text'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return tester.renderObject<ElRenderView>(find.byKey(_key));
}

void main() {
  setUp(() => BenchmarkProbe.reset());

  testWidgets('TextSpan 连续拖选只构建一次覆盖层排版', semanticsEnabled: false, (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    await _pumpRich(tester, controller, Colors.blue);
    final gesture = await tester.startGesture(Offset(30, 40), kind: PointerDeviceKind.mouse);
    await tester.pump();
    for (var move = 1; move <= 20; move++) {
      await gesture.moveTo(Offset.lerp(Offset(30, 40), Offset(600, 400), move / 20)!);
      await tester.pump();
    }
    await gesture.up();
    expect(controller.text, isNotNull);
    expect(BenchmarkProbe.selectionOverlayLayoutCount, 1);
  });

  testWidgets('TextSpan 样式更新后只重建一次覆盖层，后续重绘复用缓存', semanticsEnabled: false, (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    final render = await _pumpRich(tester, controller, Colors.blue);
    controller.selectAll();
    await tester.pump();
    expect(BenchmarkProbe.selectionOverlayLayoutCount, 1);
    BenchmarkProbe.reset();
    await _pumpRich(tester, controller, Colors.red);
    expect(BenchmarkProbe.selectionOverlayLayoutCount, 1);
    final layouts = render.debugLayoutCount;
    for (var frame = 0; frame < 5; frame++) {
      render.markNeedsPaint();
      await tester.pump();
    }
    expect(controller.text, isNotNull);
    expect(render.debugLayoutCount, layouts);
    expect(BenchmarkProbe.selectionOverlayLayoutCount, 1);
  });
}
