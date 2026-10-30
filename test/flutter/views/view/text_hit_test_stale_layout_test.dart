import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 系统字体换代（平台消息）会作废 painter 的布局缓存、把宿主标脏等待下一帧
/// 重排；而指针命中**不经过 layout**。这个窗口里命中测试不得去读空的布局缓存。
///
/// 对应真机现场：`TextPainter.width → TextPainter.size` 上的空断言
/// （text_painter.dart:1154）经 `_TextEngineBase._textContentRect`
/// （`_painter_base.dart:550`）抛出。
void main() {
  testWidgets('字体换代后未重排时，命中测试不得读取空的布局缓存', (tester) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: ElView(
          event: ElEvent(onTap: (_) {}),
          style: const ElStyle(width: 400, height: 300),
          child: '文本内容',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '重排完成后命中测试应当正常');

    // 平台消息：字体表换代 → painter 布局缓存作废，等下一帧重排。
    await tester.binding.handleSystemMessage(<String, dynamic>{'type': 'fontsChange'});

    // 指针命中不经过 layout，正好落进这个空档。
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();

    expect(tester.takeException(), isNull, reason: '未重排的文本不得去读空的布局缓存');
  });
}
