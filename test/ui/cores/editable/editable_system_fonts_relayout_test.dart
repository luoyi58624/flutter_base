import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter_base/src/ui/cores/editable/render/editable_render_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontSize: 16, height: 1.25, color: Color(0xff303133));

EditableRenderScope _scope(EditableController controller, {bool softWrap = true}) {
  final scope = EditableRenderScope(
    controller: controller,
    config: EditableRenderConfig(
      textStyle: _style,
      textDirection: .ltr,
      textScaler: TextScaler.noScaling,
      softWrap: softWrap,
      caretColor: const Color(0xff303133),
      caretWidth: 2,
      selectionColor: const Color(0x66409eff),
      composingUnderline: true,
    ),
  );
  scope.reportLayoutWidth(240);
  return scope;
}

Widget _host(Widget child) => MaterialApp(
  home: Align(
    alignment: .topLeft,
    child: SizedBox(width: 320, height: 180, child: child),
  ),
);

Future<void> _sendFontsChange(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.system.name,
    SystemChannels.system.codec.encodeMessage(<String, dynamic>{'type': 'fontsChange'}),
    (_) {},
  );
  // 与 Flutter 官方 RelayoutWhenSystemFontsChangeMixin 一致：通知延迟到
  // 下一帧 transientCallbacks，第二帧验证失效链已经完全稳定。
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fontsChange 让全部 mounted 行重新 shape，稳定帧不重复布局', (tester) async {
    final controller = EditableController(text: '今天和中文\n第二行文本\nthird line\n最后一行');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    final mounted = tester.renderObjectList<RenderEditableLine>(find.byType(EditableLineView)).toList();
    expect(mounted.length, greaterThanOrEqualTo(4));
    expect(mounted.every((line) => line.layoutedPainter != null), isTrue);

    RenderEditableLine.debugResetCounters();
    await _sendFontsChange(tester);

    expect(
      RenderEditableLine.debugLayoutCount,
      greaterThanOrEqualTo(mounted.length),
      reason: 'Web 回退字体完成下载后，每个已挂载 Paragraph 都必须重新 shape',
    );
    expect(mounted.every((line) => line.layoutedPainter != null), isTrue);

    final stableLayouts = RenderEditableLine.debugLayoutCount;
    await tester.pump();
    expect(RenderEditableLine.debugLayoutCount, stableLayouts, reason: '一次字体换代只允许触发一轮重排');
  });

  testWidgets('fontsChange 让未挂载行共享 painter 恰好失效一次', (tester) async {
    final controller = EditableController(text: 'mounted\n今天和讨论');
    final scope = _scope(controller);
    addTearDown(controller.dispose);
    addTearDown(scope.dispose);

    EditableRenderScope.debugMeasureLayoutCount = 0;
    scope.painterFor(1);
    expect(EditableRenderScope.debugMeasureLayoutCount, 1);
    scope.painterFor(1);
    expect(EditableRenderScope.debugMeasureLayoutCount, 1, reason: '同配置重复查询必须命中缓存');

    await _sendFontsChange(tester);
    scope.painterFor(1);
    expect(EditableRenderScope.debugMeasureLayoutCount, 2, reason: '字体变化后必须重新 shape 未挂载行');
    scope.painterFor(1);
    expect(EditableRenderScope.debugMeasureLayoutCount, 2, reason: '新字体排版后缓存应恢复命中');
  });

  testWidgets('fontsChange 清空 nowrap 行宽缓存，防止横向滚动沿用旧字形宽度', (tester) async {
    final controller = EditableController(text: '今天和讨论');
    final scope = _scope(controller, softWrap: false);
    addTearDown(controller.dispose);
    addTearDown(scope.dispose);

    final identity = Object();
    scope.reportLineWidth(identity, textWidth: 280, insertTrailingExtent: 4, overwriteTrailingExtent: 18);
    expect(scope.retainsLineWidth(identity), isTrue);
    expect(scope.minimumCrossAxisExtent.value, 284);

    await _sendFontsChange(tester);
    expect(scope.retainsLineWidth(identity), isFalse);
    expect(scope.minimumCrossAxisExtent.value, 0, reason: '新字体宽度必须由 mounted 行重新上报');
  });

  testWidgets('scope 和 EditableView 卸载后移除 systemFonts 监听', (tester) async {
    final directController = EditableController(text: 'direct');
    final directScope = _scope(directController, softWrap: false);
    directScope.reportLineWidth(Object(), textWidth: 120, insertTrailingExtent: 4, overwriteTrailingExtent: 16);
    directScope.dispose();
    directController.dispose();

    final viewController = EditableController(text: '今天和讨论');
    addTearDown(viewController.dispose);
    await tester.pumpWidget(
      _host(
        EditableView(
          controller: viewController,
          style: EditableConfiguration(textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());

    await _sendFontsChange(tester);
    expect(tester.takeException(), isNull, reason: '已 dispose 的 notifier/painter 不得收到延迟回调');
  });
}
